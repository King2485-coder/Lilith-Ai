from __future__ import annotations

import json
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.models.admin import AdminActionLog, ModerationReport, PaymentFraudFlag, ToolControl, UserRole
from backend.models.payment import LedgerEntry, PaymentAccount, PaymentIntent
from backend.models.tool import ToolJob
from backend.models.user import User
from backend.observability.state import observability_state
from backend.services.self_heal.service import safe_clear_cache, safe_restart_service


def log_admin_action(
    db: Session,
    *,
    admin_user_id: str,
    action: str,
    target_type: str,
    target_id: str,
    details: dict[str, Any] | None = None,
) -> AdminActionLog:
    row = AdminActionLog(
        admin_user_id=admin_user_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details_json=json.dumps(details or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_users(db: Session, limit: int = 200) -> list[dict[str, Any]]:
    users = db.query(User).order_by(User.created_at.desc()).limit(max(1, min(limit, 500))).all()
    rows = []
    for user in users:
        role = db.query(UserRole).filter(UserRole.user_id == user.id).first()
        rows.append(
            {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "created_at": user.created_at.isoformat(),
                "role": (role.role if role else "user"),
                "status": (role.status if role else "active"),
            }
        )
    return rows


def set_user_status(db: Session, target_user_id: str, status: str) -> UserRole:
    user = db.query(User).filter(User.id == target_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    role = db.query(UserRole).filter(UserRole.user_id == target_user_id).first()
    if role is None:
        role = UserRole(user_id=target_user_id, role="user", status=status)
    else:
        role.status = status
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


def list_transactions(db: Session, limit: int = 200) -> list[PaymentIntent]:
    return db.query(PaymentIntent).order_by(PaymentIntent.created_at.desc()).limit(max(1, min(limit, 500))).all()


def _account_for(db: Session, user_id: str) -> PaymentAccount:
    row = db.query(PaymentAccount).filter(PaymentAccount.user_id == user_id).first()
    if row is None:
        row = PaymentAccount(user_id=user_id, fiat_balance=0.0, usdc_balance=0.0)
        db.add(row)
        db.flush()
    return row


def admin_refund(db: Session, intent_id: str) -> PaymentIntent:
    intent = db.query(PaymentIntent).filter(PaymentIntent.id == intent_id).first()
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    if intent.status == "refunded":
        return intent
    if intent.status != "confirmed":
        raise HTTPException(status_code=400, detail="Only confirmed intents can be refunded")
    sender_account = _account_for(db, intent.sender_id)
    receiver_account = _account_for(db, intent.receiver_id)
    amount = float(intent.amount)
    if intent.currency.upper() == "USDC":
        if receiver_account.usdc_balance < amount:
            raise HTTPException(status_code=400, detail="Receiver has insufficient USDC for refund")
        receiver_account.usdc_balance -= amount
        sender_account.usdc_balance += amount
    else:
        if receiver_account.fiat_balance < amount:
            raise HTTPException(status_code=400, detail="Receiver has insufficient fiat for refund")
        receiver_account.fiat_balance -= amount
        sender_account.fiat_balance += amount
    intent.status = "refunded"
    db.add(intent)
    db.add(LedgerEntry(payment_intent_id=intent.id, account_id=receiver_account.id, amount=amount, direction="debit"))
    db.add(LedgerEntry(payment_intent_id=intent.id, account_id=sender_account.id, amount=amount, direction="credit"))
    db.commit()
    db.refresh(intent)
    return intent


def flag_payment_fraud(db: Session, payment_intent_id: str, admin_user_id: str, reason: str) -> PaymentFraudFlag:
    intent = db.query(PaymentIntent).filter(PaymentIntent.id == payment_intent_id).first()
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    row = PaymentFraudFlag(payment_intent_id=payment_intent_id, flagged_by_admin_user_id=admin_user_id, reason=reason[:255])
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_tool_controls(db: Session) -> list[ToolControl]:
    return db.query(ToolControl).order_by(ToolControl.tool_name.asc()).all()


def set_tool_control(db: Session, tool_name: str, approved: bool, enabled: bool, note: str = "") -> ToolControl:
    row = db.query(ToolControl).filter(ToolControl.tool_name == tool_name).first()
    if row is None:
        row = ToolControl(tool_name=tool_name, approved=approved, enabled=enabled, note=note[:255])
    else:
        row.approved = approved
        row.enabled = enabled
        row.note = note[:255]
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def tool_usage_summary(db: Session, limit: int = 500) -> list[dict[str, Any]]:
    rows = db.query(ToolJob).order_by(ToolJob.created_at.desc()).limit(max(1, min(limit, 2000))).all()
    usage: dict[str, dict[str, int]] = {}
    for row in rows:
        usage.setdefault(row.tool_name, {"total": 0, "failed": 0})
        usage[row.tool_name]["total"] += 1
        if row.status == "failed":
            usage[row.tool_name]["failed"] += 1
    return [{"tool_name": name, **values} for name, values in sorted(usage.items(), key=lambda x: x[0])]


def list_reports(db: Session, status: str | None = None) -> list[ModerationReport]:
    query = db.query(ModerationReport).order_by(ModerationReport.created_at.desc())
    if status:
        query = query.filter(ModerationReport.status == status)
    return query.limit(500).all()


def moderate_report(db: Session, report_id: str, status: str, note: str) -> ModerationReport:
    row = db.query(ModerationReport).filter(ModerationReport.id == report_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Report not found")
    row.status = status
    row.action_note = note[:255]
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def admin_metrics_snapshot() -> dict[str, Any]:
    return observability_state.metrics_snapshot()


async def admin_trigger_restart(service_name: str) -> dict[str, Any]:
    return await safe_restart_service(service_name)


async def admin_trigger_clear_cache(prefix: str) -> dict[str, Any]:
    return await safe_clear_cache(prefix=prefix)

