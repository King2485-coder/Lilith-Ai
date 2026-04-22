from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.models.finance_hub import (
    FinancialAccessPolicy,
    FinancialActionPreview,
    FinancialAuditLog,
    FinancialAutomationRule,
    FinancialLinkedAccount,
    FinancialOpportunity,
    FinancialRecurringItem,
)
from backend.models.payment import PaymentAccount, PaymentIntent
from backend.models.user import User


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _iso(value):
    return value.isoformat() if value else None


def _now():
    return datetime.utcnow()


def _audit(
    db: Session,
    user_id: str,
    event_type: str,
    entity_type: str = "",
    entity_id: str = "",
    detail: dict[str, Any] | None = None,
):
    db.add(
        FinancialAuditLog(
            user_id=user_id,
            event_type=event_type[:64],
            entity_type=entity_type[:64],
            entity_id=entity_id[:64],
            detail_json=json.dumps(detail or {}, default=str),
        )
    )
    db.flush()


def ensure_policy(db: Session, user: User) -> FinancialAccessPolicy:
    row = db.query(FinancialAccessPolicy).filter(FinancialAccessPolicy.user_id == user.id).first()
    if row is None:
        row = FinancialAccessPolicy(
            user_id=user.id,
            access_level="observe",
            max_transfer_limit=250.0,
            bill_runway_days=14,
            available_cash_buffer=300.0,
            require_biometric_sensitive=True,
            first_time_hard_confirm_required=True,
            one_click_trade_enabled=False,
            one_click_trade_max=100.0,
        )
        db.add(row)
        db.flush()
    return row


def ensure_financial_account(db: Session, user: User) -> PaymentAccount:
    row = db.query(PaymentAccount).filter(PaymentAccount.user_id == user.id).first()
    if row is None:
        row = PaymentAccount(user_id=user.id, fiat_balance=0.0, usdc_balance=0.0)
        db.add(row)
        db.flush()
    return row


def access_policy_response(row: FinancialAccessPolicy):
    return {
        "access_level": row.access_level,
        "max_transfer_limit": row.max_transfer_limit,
        "bill_runway_days": row.bill_runway_days,
        "available_cash_buffer": row.available_cash_buffer,
        "require_biometric_sensitive": bool(row.require_biometric_sensitive),
        "first_time_hard_confirm_required": bool(row.first_time_hard_confirm_required),
        "one_click_trade_enabled": bool(row.one_click_trade_enabled),
        "one_click_trade_max": row.one_click_trade_max,
        "updated_at": _iso(row.updated_at),
    }


def update_access_policy(db: Session, user: User, patch: dict[str, Any]):
    row = ensure_policy(db, user)
    if "access_level" in patch:
        level = str(patch.get("access_level", "observe")).lower()
        if level not in {"observe", "assist", "auto"}:
            raise HTTPException(status_code=400, detail="Invalid access level")
        row.access_level = level
    if "max_transfer_limit" in patch:
        row.max_transfer_limit = max(0.0, round(float(patch["max_transfer_limit"]), 2))
    if "bill_runway_days" in patch:
        row.bill_runway_days = max(1, int(patch["bill_runway_days"]))
    if "available_cash_buffer" in patch:
        row.available_cash_buffer = max(0.0, round(float(patch["available_cash_buffer"]), 2))
    if "require_biometric_sensitive" in patch:
        row.require_biometric_sensitive = bool(patch["require_biometric_sensitive"])
    if "first_time_hard_confirm_required" in patch:
        row.first_time_hard_confirm_required = bool(patch["first_time_hard_confirm_required"])
    if "one_click_trade_enabled" in patch:
        row.one_click_trade_enabled = bool(patch["one_click_trade_enabled"])
    if "one_click_trade_max" in patch:
        row.one_click_trade_max = max(0.0, round(float(patch["one_click_trade_max"]), 2))
    db.add(row)
    _audit(db, user.id, "finance.access_policy.updated", "access_policy", user.id, access_policy_response(row))
    db.commit()
    db.refresh(row)
    return access_policy_response(row)


def link_account(db: Session, user: User, payload: dict[str, Any]):
    provider = str(payload.get("provider", "wealthwizard")).strip().lower()
    provider_account_ref = str(payload.get("provider_account_ref", "")).strip()
    if not provider_account_ref:
        raise HTTPException(status_code=400, detail="provider_account_ref is required")
    display_name = str(payload.get("display_name", "Linked Account")).strip()[:180]
    account_type = str(payload.get("account_type", "checking")).strip()[:40]
    credential_ref = str(payload.get("credential_ref", "")).strip()
    if payload.get("raw_credentials"):
        raise HTTPException(status_code=400, detail="Raw credentials are not allowed. Use secure credential references.")
    row = FinancialLinkedAccount(
        user_id=user.id,
        provider=provider[:64],
        provider_account_ref=provider_account_ref[:180],
        display_name=display_name,
        account_type=account_type,
        currency=str(payload.get("currency", "USD")).upper()[:12],
        status="linked",
        last_synced_at=_now(),
        credential_ref=credential_ref[:220],
        metadata_json=json.dumps(payload.get("metadata", {}), default=str),
    )
    db.add(row)
    _audit(
        db,
        user.id,
        "finance.linked_account.created",
        "linked_account",
        row.id,
        {"provider": row.provider, "display_name": row.display_name},
    )
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "provider": row.provider,
        "display_name": row.display_name,
        "account_type": row.account_type,
        "status": row.status,
        "last_synced_at": _iso(row.last_synced_at),
    }


def list_linked_accounts(db: Session, user: User):
    rows = db.query(FinancialLinkedAccount).filter(FinancialLinkedAccount.user_id == user.id).order_by(FinancialLinkedAccount.created_at.desc()).all()
    return {
        "items": [
            {
                "id": row.id,
                "provider": row.provider,
                "display_name": row.display_name,
                "account_type": row.account_type,
                "status": row.status,
                "last_synced_at": _iso(row.last_synced_at),
                "created_at": _iso(row.created_at),
            }
            for row in rows
        ]
    }


def _payment_spending_breakdown(intents: list[PaymentIntent]):
    categories: dict[str, float] = {}
    for item in intents:
        category = (item.kind or "other").lower()
        categories[category] = categories.get(category, 0.0) + float(item.amount)
    return [{"category": k, "amount": round(v, 2)} for k, v in sorted(categories.items(), key=lambda x: x[1], reverse=True)]


def _recurring_summary(recurring: list[FinancialRecurringItem]):
    bills = [r for r in recurring if r.kind == "bill" and r.active]
    subs = [r for r in recurring if r.kind == "subscription" and r.active]
    return {
        "bills_total": round(sum(float(x.amount) for x in bills), 2),
        "subscriptions_total": round(sum(float(x.amount) for x in subs), 2),
        "bills_count": len(bills),
        "subscriptions_count": len(subs),
        "items": [
            {
                "id": x.id,
                "name": x.name,
                "kind": x.kind,
                "amount": x.amount,
                "frequency": x.frequency,
                "next_due_at": _iso(x.next_due_at),
            }
            for x in recurring
        ],
    }


def _first_time_action(db: Session, user: User, action_type: str) -> bool:
    prior = (
        db.query(FinancialActionPreview)
        .filter(
            FinancialActionPreview.user_id == user.id,
            FinancialActionPreview.action_type == action_type,
            FinancialActionPreview.status.in_(["approved", "executed"]),
        )
        .first()
    )
    return prior is None


def _guardrail_report(db: Session, user: User, action_type: str, payload: dict[str, Any]):
    policy = ensure_policy(db, user)
    account = ensure_financial_account(db, user)
    amount = round(float(payload.get("amount", 0.0)), 2)
    recurring = db.query(FinancialRecurringItem).filter(FinancialRecurringItem.user_id == user.id, FinancialRecurringItem.active == True).all()  # noqa: E712
    monthly_outgoing = sum(float(x.amount) for x in recurring if x.kind in {"bill", "subscription"})
    runway_requirement = (monthly_outgoing / 30.0) * float(policy.bill_runway_days)
    post_balance = float(account.fiat_balance) - amount
    checks = {
        "available_cash_check": post_balance >= float(policy.available_cash_buffer),
        "max_transfer_limit_check": amount <= float(policy.max_transfer_limit),
        "bill_runway_check": post_balance >= runway_requirement,
    }
    blocked_reasons = []
    for key, ok in checks.items():
        if not ok:
            blocked_reasons.append(key)
    return {
        "amount": amount,
        "current_balance": round(float(account.fiat_balance), 2),
        "post_action_balance": round(post_balance, 2),
        "available_cash_buffer": round(float(policy.available_cash_buffer), 2),
        "bill_runway_required": round(runway_requirement, 2),
        "checks": checks,
        "blocked": len(blocked_reasons) > 0,
        "blocked_reasons": blocked_reasons,
        "action_type": action_type,
    }


def generate_read_only_analysis(db: Session, user: User):
    now = _now()
    cutoff = now - timedelta(days=30)
    prev_cutoff = now - timedelta(days=60)
    account = ensure_financial_account(db, user)
    intents_30 = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.sender_id == user.id, PaymentIntent.created_at >= cutoff, PaymentIntent.status.in_(["created", "confirmed"]))
        .all()
    )
    intents_prev = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.sender_id == user.id, PaymentIntent.created_at >= prev_cutoff, PaymentIntent.created_at < cutoff, PaymentIntent.status.in_(["created", "confirmed"]))
        .all()
    )
    recurring = db.query(FinancialRecurringItem).filter(FinancialRecurringItem.user_id == user.id).order_by(FinancialRecurringItem.next_due_at.asc().nulls_last()).all()
    recurring_info = _recurring_summary(recurring)
    current_spend = round(sum(float(i.amount) for i in intents_30), 2)
    prev_spend = round(sum(float(i.amount) for i in intents_prev), 2)
    trend_change = round(current_spend - prev_spend, 2)
    trend_percent = 0.0 if prev_spend == 0 else round((trend_change / prev_spend) * 100, 1)

    wasted_subscriptions = [x for x in recurring if x.kind == "subscription" and float(x.amount) > 20]
    idle_cash = max(0.0, round(float(account.fiat_balance) - (float(recurring_info["bills_total"]) + 300), 2))
    debt_items = [x for x in recurring if x.kind == "bill" and "debt" in x.name.lower()]

    opportunities = [
        {
            "type": "wasted_subscriptions",
            "title": "Potential subscription waste detected",
            "impact_amount": round(sum(float(x.amount) for x in wasted_subscriptions), 2),
            "items": [{"name": x.name, "amount": x.amount} for x in wasted_subscriptions],
        },
        {
            "type": "idle_cash",
            "title": "Excess idle cash available",
            "impact_amount": idle_cash,
            "items": [{"suggested_transfer_to_savings": idle_cash}],
        },
        {
            "type": "debt_payoff",
            "title": "Debt payoff opportunity",
            "impact_amount": round(sum(float(x.amount) for x in debt_items), 2),
            "items": [{"name": x.name, "amount": x.amount} for x in debt_items],
        },
    ]

    db.query(FinancialOpportunity).filter(FinancialOpportunity.user_id == user.id).delete()
    for opp in opportunities:
        db.add(
            FinancialOpportunity(
                user_id=user.id,
                opportunity_type=opp["type"],
                title=opp["title"],
                summary=opp["title"],
                confidence=0.72,
                impact_amount=float(opp["impact_amount"]),
                status="open",
                payload_json=json.dumps(opp, default=str),
            )
        )

    _audit(
        db,
        user.id,
        "finance.analysis.generated",
        "analysis",
        user.id,
        {
            "spend_30d": current_spend,
            "trend_percent": trend_percent,
            "opportunity_count": len(opportunities),
        },
    )
    db.commit()
    return {
        "cash_flow": {
            "spend_30d": current_spend,
            "spend_previous_30d": prev_spend,
            "trend_change": trend_change,
            "trend_percent": trend_percent,
        },
        "spending_categories": _payment_spending_breakdown(intents_30),
        "recurring": recurring_info,
        "opportunities": opportunities,
    }


def financial_hub_dashboard(db: Session, user: User):
    policy = ensure_policy(db, user)
    account = ensure_financial_account(db, user)
    linked = list_linked_accounts(db, user)["items"]
    automations = db.query(FinancialAutomationRule).filter(FinancialAutomationRule.user_id == user.id).order_by(FinancialAutomationRule.updated_at.desc()).all()
    opportunities = db.query(FinancialOpportunity).filter(FinancialOpportunity.user_id == user.id, FinancialOpportunity.status == "open").order_by(FinancialOpportunity.created_at.desc()).all()
    recurring = db.query(FinancialRecurringItem).filter(FinancialRecurringItem.user_id == user.id).order_by(FinancialRecurringItem.next_due_at.asc().nulls_last()).all()
    return {
        "access_policy": access_policy_response(policy),
        "linked_accounts": linked,
        "balances": {"fiat_balance": round(float(account.fiat_balance), 2), "usdc_balance": round(float(account.usdc_balance), 2)},
        "recurring": _recurring_summary(recurring),
        "opportunities": [
            {
                "id": row.id,
                "type": row.opportunity_type,
                "title": row.title,
                "summary": row.summary,
                "impact_amount": row.impact_amount,
                "confidence": row.confidence,
                "payload": _safe_json(row.payload_json, {}),
            }
            for row in opportunities
        ],
        "automation_rules": [
            {
                "id": row.id,
                "name": row.name,
                "rule_type": row.rule_type,
                "enabled": row.enabled,
                "require_approval": row.require_approval,
                "config": _safe_json(row.config_json, {}),
                "last_run_at": _iso(row.last_run_at),
                "last_result": _safe_json(row.last_result_json, {}),
            }
            for row in automations
        ],
    }


def list_opportunities(db: Session, user: User):
    rows = db.query(FinancialOpportunity).filter(FinancialOpportunity.user_id == user.id).order_by(FinancialOpportunity.created_at.desc()).all()
    return {
        "items": [
            {
                "id": row.id,
                "type": row.opportunity_type,
                "title": row.title,
                "summary": row.summary,
                "confidence": row.confidence,
                "impact_amount": row.impact_amount,
                "status": row.status,
                "payload": _safe_json(row.payload_json, {}),
            }
            for row in rows
        ]
    }


def create_action_preview(db: Session, user: User, payload: dict[str, Any]):
    policy = ensure_policy(db, user)
    action_type = str(payload.get("action_type", "")).strip().lower()
    if action_type not in {"transfer_savings", "pay_bill", "trade", "investment"}:
        raise HTTPException(status_code=400, detail="Unsupported action_type")
    if action_type in {"trade", "investment"} and policy.access_level == "observe":
        raise HTTPException(status_code=403, detail="Observe mode blocks trade previews. Switch to Assist/Auto.")
    if action_type in {"transfer_savings", "pay_bill"} and policy.access_level == "observe":
        raise HTTPException(status_code=403, detail="Observe mode blocks money-moving previews. Switch to Assist/Auto.")

    report = _guardrail_report(db, user, action_type, payload)
    first_time = _first_time_action(db, user, action_type)
    requires_hard = bool(policy.first_time_hard_confirm_required and first_time) or bool(action_type in {"trade", "investment"})
    biometric_required = bool(policy.require_biometric_sensitive and action_type in {"trade", "investment", "transfer_savings", "pay_bill"})
    status = "blocked" if report["blocked"] else "pending"
    reason = str(payload.get("reason", "Action preview requested by Lilith analysis")).strip()

    row = FinancialActionPreview(
        user_id=user.id,
        action_type=action_type,
        reason=reason,
        payload_json=json.dumps(payload, default=str),
        guardrail_report_json=json.dumps(report, default=str),
        status=status,
        requires_hard_confirmation=requires_hard,
        biometric_required=biometric_required,
        first_time_action=first_time,
    )
    db.add(row)
    _audit(
        db,
        user.id,
        "finance.action.previewed",
        "action_preview",
        row.id,
        {"action_type": action_type, "status": status, "blocked_reasons": report["blocked_reasons"]},
    )
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "action_type": row.action_type,
        "status": row.status,
        "reason": row.reason,
        "payload": _safe_json(row.payload_json, {}),
        "guardrails": _safe_json(row.guardrail_report_json, {}),
        "controls": {
            "requires_hard_confirmation": bool(row.requires_hard_confirmation),
            "biometric_required": bool(row.biometric_required),
            "first_time_action": bool(row.first_time_action),
            "one_click_trade_available": bool(
                row.action_type in {"trade", "investment"}
                and policy.one_click_trade_enabled
                and float(_safe_json(row.payload_json, {}).get("amount", 0)) <= float(policy.one_click_trade_max)
            ),
        },
    }


def list_action_previews(db: Session, user: User):
    rows = db.query(FinancialActionPreview).filter(FinancialActionPreview.user_id == user.id).order_by(FinancialActionPreview.created_at.desc()).all()
    return {
        "items": [
            {
                "id": row.id,
                "action_type": row.action_type,
                "status": row.status,
                "reason": row.reason,
                "payload": _safe_json(row.payload_json, {}),
                "guardrails": _safe_json(row.guardrail_report_json, {}),
                "requires_hard_confirmation": bool(row.requires_hard_confirmation),
                "biometric_required": bool(row.biometric_required),
                "first_time_action": bool(row.first_time_action),
                "created_at": _iso(row.created_at),
                "resolved_at": _iso(row.resolved_at),
            }
            for row in rows
        ]
    }


def update_action_preview_payload(db: Session, user: User, preview_id: str, patch: dict[str, Any]):
    row = db.query(FinancialActionPreview).filter(FinancialActionPreview.id == preview_id, FinancialActionPreview.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Preview not found")
    if row.status not in {"pending", "blocked"}:
        raise HTTPException(status_code=400, detail="Preview is already resolved")
    current_payload = _safe_json(row.payload_json, {})
    next_payload = {**current_payload, **(patch or {})}
    report = _guardrail_report(db, user, row.action_type, next_payload)
    row.payload_json = json.dumps(next_payload, default=str)
    row.guardrail_report_json = json.dumps(report, default=str)
    row.status = "blocked" if report["blocked"] else "pending"
    db.add(row)
    _audit(db, user.id, "finance.action.edited", "action_preview", row.id, {"status": row.status})
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "status": row.status,
        "payload": _safe_json(row.payload_json, {}),
        "guardrails": _safe_json(row.guardrail_report_json, {}),
    }


def approve_action_preview(db: Session, user: User, preview_id: str, approve_mode: str = "standard", biometric_ok: bool = False):
    policy = ensure_policy(db, user)
    row = db.query(FinancialActionPreview).filter(FinancialActionPreview.id == preview_id, FinancialActionPreview.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Preview not found")
    if row.status == "blocked":
        raise HTTPException(status_code=400, detail="Preview blocked by guardrails")
    if row.status not in {"pending"}:
        raise HTTPException(status_code=400, detail="Preview already resolved")

    payload = _safe_json(row.payload_json, {})
    amount = float(payload.get("amount", 0.0))
    if row.biometric_required and not biometric_ok:
        raise HTTPException(status_code=400, detail="Biometric/passkey confirmation required")

    if row.action_type in {"trade", "investment"} and approve_mode == "one_click":
        if not policy.one_click_trade_enabled or amount > float(policy.one_click_trade_max):
            raise HTTPException(status_code=403, detail="One-click trade not allowed by policy")

    row.status = "approved"
    row.resolved_at = _now()
    row.executed_at = _now()
    db.add(row)
    _audit(
        db,
        user.id,
        "finance.action.approved",
        "action_preview",
        row.id,
        {"mode": approve_mode, "action_type": row.action_type, "amount": amount},
    )
    db.commit()
    return {
        "id": row.id,
        "status": row.status,
        "executed_at": _iso(row.executed_at),
        "execution_mode": "external_execution_placeholder",
        "note": "Approved. Execution is routed through linked provider integrations.",
    }


def decline_action_preview(db: Session, user: User, preview_id: str, reason: str = ""):
    row = db.query(FinancialActionPreview).filter(FinancialActionPreview.id == preview_id, FinancialActionPreview.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Preview not found")
    if row.status not in {"pending", "blocked"}:
        raise HTTPException(status_code=400, detail="Preview already resolved")
    row.status = "declined"
    row.resolved_at = _now()
    db.add(row)
    _audit(db, user.id, "finance.action.declined", "action_preview", row.id, {"reason": reason[:240]})
    db.commit()
    return {"id": row.id, "status": row.status}


def create_automation_rule(db: Session, user: User, payload: dict[str, Any]):
    rule_type = str(payload.get("rule_type", "")).strip().lower()
    if rule_type not in {"fixed_after_payday", "round_up", "unusual_charge_alert", "recurring_bill_reminder"}:
        raise HTTPException(status_code=400, detail="Unsupported rule_type")
    row = FinancialAutomationRule(
        user_id=user.id,
        name=str(payload.get("name", rule_type.replace("_", " ").title()))[:180],
        rule_type=rule_type,
        config_json=json.dumps(payload.get("config", {}), default=str),
        enabled=bool(payload.get("enabled", True)),
        require_approval=bool(payload.get("require_approval", True)),
        last_result_json="{}",
    )
    db.add(row)
    _audit(db, user.id, "finance.automation.created", "automation_rule", row.id, {"rule_type": rule_type})
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "name": row.name,
        "rule_type": row.rule_type,
        "enabled": row.enabled,
        "require_approval": row.require_approval,
        "config": _safe_json(row.config_json, {}),
    }


def list_automation_rules(db: Session, user: User):
    rows = db.query(FinancialAutomationRule).filter(FinancialAutomationRule.user_id == user.id).order_by(FinancialAutomationRule.created_at.desc()).all()
    return {
        "items": [
            {
                "id": row.id,
                "name": row.name,
                "rule_type": row.rule_type,
                "enabled": row.enabled,
                "require_approval": row.require_approval,
                "config": _safe_json(row.config_json, {}),
                "last_run_at": _iso(row.last_run_at),
                "last_result": _safe_json(row.last_result_json, {}),
            }
            for row in rows
        ]
    }


def run_automation_rule(db: Session, user: User, rule_id: str):
    policy = ensure_policy(db, user)
    row = db.query(FinancialAutomationRule).filter(FinancialAutomationRule.id == rule_id, FinancialAutomationRule.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Rule not found")
    if not row.enabled:
        raise HTTPException(status_code=400, detail="Rule is disabled")
    config = _safe_json(row.config_json, {})
    result: dict[str, Any]

    if row.rule_type == "fixed_after_payday":
        amount = float(config.get("amount", 0))
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Rule amount must be > 0")
        preview = create_action_preview(
            db,
            user,
            {
                "action_type": "transfer_savings",
                "amount": amount,
                "reason": "Fixed savings transfer after payday",
                "source": config.get("source", "checking"),
                "destination": config.get("destination", "savings"),
                "rule_id": row.id,
            },
        )
        result = {"mode": "preview_created", "preview": preview}
    elif row.rule_type == "round_up":
        recent_intent = (
            db.query(PaymentIntent)
            .filter(PaymentIntent.sender_id == user.id)
            .order_by(PaymentIntent.created_at.desc())
            .first()
        )
        if recent_intent is None:
            result = {"mode": "skipped", "reason": "No recent purchases"}
        else:
            amount = float(recent_intent.amount)
            round_up = round((int(amount) + 1) - amount, 2) if amount % 1 else 0.0
            if round_up <= 0:
                result = {"mode": "skipped", "reason": "No roundup needed"}
            else:
                preview = create_action_preview(
                    db,
                    user,
                    {
                        "action_type": "transfer_savings",
                        "amount": round_up,
                        "reason": "Round-up transfer into savings",
                        "rule_id": row.id,
                    },
                )
                result = {"mode": "preview_created", "preview": preview}
    elif row.rule_type == "unusual_charge_alert":
        intents = (
            db.query(PaymentIntent)
            .filter(PaymentIntent.sender_id == user.id)
            .order_by(PaymentIntent.created_at.desc())
            .limit(15)
            .all()
        )
        avg = (sum(float(x.amount) for x in intents[1:]) / max(len(intents[1:]), 1)) if intents else 0
        unusual = intents[0] if intents and float(intents[0].amount) > (avg * 2.5 if avg else 500) else None
        result = {"mode": "alert", "unusual_charge": float(unusual.amount) if unusual else None, "threshold_avg": round(avg, 2)}
    else:
        recurring = db.query(FinancialRecurringItem).filter(FinancialRecurringItem.user_id == user.id, FinancialRecurringItem.kind == "bill", FinancialRecurringItem.active == True).all()  # noqa: E712
        due_soon = [x for x in recurring if x.next_due_at and x.next_due_at <= (_now() + timedelta(days=3))]
        result = {"mode": "reminder", "due_soon_count": len(due_soon), "items": [{"name": x.name, "amount": x.amount} for x in due_soon]}

    row.last_run_at = _now()
    row.last_result_json = json.dumps(result, default=str)
    db.add(row)
    _audit(db, user.id, "finance.automation.ran", "automation_rule", row.id, result)
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "name": row.name,
        "rule_type": row.rule_type,
        "last_run_at": _iso(row.last_run_at),
        "result": result,
    }


def list_audit_logs(db: Session, user: User, limit: int = 200):
    rows = (
        db.query(FinancialAuditLog)
        .filter(FinancialAuditLog.user_id == user.id)
        .order_by(FinancialAuditLog.created_at.desc())
        .limit(max(1, min(limit, 500)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "event_type": row.event_type,
                "entity_type": row.entity_type,
                "entity_id": row.entity_id,
                "detail": _safe_json(row.detail_json, {}),
                "created_at": _iso(row.created_at),
            }
            for row in rows
        ]
    }


def upsert_recurring_item(db: Session, user: User, payload: dict[str, Any]):
    recurring_id = str(payload.get("id", "")).strip()
    if recurring_id:
        row = db.query(FinancialRecurringItem).filter(FinancialRecurringItem.id == recurring_id, FinancialRecurringItem.user_id == user.id).first()
    else:
        row = None
    if row is None:
        row = FinancialRecurringItem(
            user_id=user.id,
            name=str(payload.get("name", "Recurring Item"))[:180],
            kind=str(payload.get("kind", "subscription"))[:24],
            amount=max(0.0, round(float(payload.get("amount", 0.0)), 2)),
            frequency=str(payload.get("frequency", "monthly"))[:24],
            active=bool(payload.get("active", True)),
            metadata_json=json.dumps(payload.get("metadata", {}), default=str),
        )
    else:
        row.name = str(payload.get("name", row.name))[:180]
        row.kind = str(payload.get("kind", row.kind))[:24]
        row.amount = max(0.0, round(float(payload.get("amount", row.amount)), 2))
        row.frequency = str(payload.get("frequency", row.frequency))[:24]
        row.active = bool(payload.get("active", row.active))
        row.metadata_json = json.dumps(payload.get("metadata", _safe_json(row.metadata_json, {})), default=str)
    next_due = payload.get("next_due_at")
    if next_due:
        try:
            row.next_due_at = datetime.fromisoformat(str(next_due).replace("Z", "+00:00"))
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid next_due_at format. Use ISO format")
    db.add(row)
    _audit(db, user.id, "finance.recurring.upserted", "recurring_item", row.id, {"kind": row.kind, "amount": row.amount})
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "name": row.name,
        "kind": row.kind,
        "amount": row.amount,
        "frequency": row.frequency,
        "next_due_at": _iso(row.next_due_at),
        "active": row.active,
    }

