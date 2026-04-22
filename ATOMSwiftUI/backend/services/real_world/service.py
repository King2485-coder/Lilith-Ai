from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from backend.models.application import ApplicationUserProfile
from backend.models.income_engine import IncomeOpportunity
from backend.models.real_world import (
    RealWorldActionPipeline,
    RealWorldApplication,
    RealWorldAuditLog,
    RealWorldConnector,
    RealWorldIncomeEvent,
    RealWorldOpportunity,
)
from backend.models.user import User
from backend.services.finance_hub.service import create_action_preview
from backend.services.notifications.service import create_notification


def _now():
    return datetime.utcnow()


def _iso(value):
    return value.isoformat() if value else None


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _audit(
    db: Session,
    user_id: str,
    event_type: str,
    entity_type: str = "",
    entity_id: str = "",
    detail: dict[str, Any] | None = None,
):
    db.add(
        RealWorldAuditLog(
            user_id=user_id,
            event_type=event_type[:64],
            entity_type=entity_type[:64],
            entity_id=entity_id[:64],
            detail_json=json.dumps(detail or {}, default=str),
        )
    )
    db.flush()


def _connector_out(row: RealWorldConnector):
    return {
        "id": row.id,
        "connector_type": row.connector_type,
        "provider": row.provider,
        "status": row.status,
        "scopes": _safe_json(row.scopes_json, []),
        "last_synced_at": _iso(row.last_synced_at),
    }


def _opportunity_out(row: RealWorldOpportunity):
    return {
        "id": row.id,
        "title": row.title,
        "description": row.description,
        "category": row.category,
        "payout_min": round(float(row.payout_min), 2),
        "payout_max": round(float(row.payout_max), 2),
        "location_mode": row.location_mode,
        "apply_url": row.apply_url,
        "verified": bool(row.verified),
        "scam_risk_score": float(row.scam_risk_score),
        "metadata": _safe_json(row.metadata_json, {}),
        "active": bool(row.active),
    }


def _application_out(row: RealWorldApplication):
    return {
        "id": row.id,
        "opportunity_id": row.opportunity_id,
        "status": row.status,
        "autofill_used": bool(row.autofill_used),
        "proposal_text": row.proposal_text,
        "payload": _safe_json(row.payload_json, {}),
        "confirmation_required": bool(row.confirmation_required),
        "approved_at": _iso(row.approved_at),
        "submitted_at": _iso(row.submitted_at),
        "created_at": _iso(row.created_at),
    }


def _pipeline_out(row: RealWorldActionPipeline):
    return {
        "id": row.id,
        "action_type": row.action_type,
        "status": row.status,
        "steps": _safe_json(row.steps_json, []),
        "context": _safe_json(row.context_json, {}),
        "result": _safe_json(row.result_json, {}),
        "requires_approval": bool(row.requires_approval),
        "approval_state": row.approval_state,
        "executed_at": _iso(row.executed_at),
        "created_at": _iso(row.created_at),
    }


def _ensure_default_connectors(db: Session, user: User):
    defaults = [
        ("jobs", "lilith_jobs"),
        ("payments", "lilith_pay"),
        ("communication", "lilith_mail"),
        ("automation", "lilith_automation"),
    ]
    for connector_type, provider in defaults:
        existing = (
            db.query(RealWorldConnector)
            .filter(
                RealWorldConnector.user_id == user.id,
                RealWorldConnector.connector_type == connector_type,
                RealWorldConnector.provider == provider,
            )
            .first()
        )
        if existing is None:
            db.add(
                RealWorldConnector(
                    user_id=user.id,
                    connector_type=connector_type,
                    provider=provider,
                    status="connected",
                    scopes_json=json.dumps(["read"] if connector_type != "payments" else ["read", "assist"], default=str),
                    credential_ref="",
                    metadata_json=json.dumps({"default": True}, default=str),
                    last_synced_at=_now(),
                )
            )
    db.flush()


def _ensure_seed_opportunities(db: Session):
    if db.query(RealWorldOpportunity).count() > 0:
        return
    samples = [
        {
            "title": "Remote Support Sprint",
            "description": "Handle triage queue for a startup over 2 hours.",
            "category": "task",
            "payout_min": 50,
            "payout_max": 120,
            "location_mode": "remote",
            "apply_url": "https://jobs.lilith.local/support-sprint",
            "verified": True,
            "scam_risk_score": 0.04,
        },
        {
            "title": "Landing Page Copy Refresh",
            "description": "Rewrite hero + CTA sections for conversion lift.",
            "category": "freelance",
            "payout_min": 150,
            "payout_max": 320,
            "location_mode": "remote",
            "apply_url": "https://jobs.lilith.local/copy-refresh",
            "verified": True,
            "scam_risk_score": 0.05,
        },
        {
            "title": "Weekend Event Photo Coverage",
            "description": "Capture and deliver 30 edited photos for a local event.",
            "category": "gig",
            "payout_min": 180,
            "payout_max": 420,
            "location_mode": "local",
            "apply_url": "https://jobs.lilith.local/photo-coverage",
            "verified": True,
            "scam_risk_score": 0.08,
        },
    ]
    for item in samples:
        db.add(
            RealWorldOpportunity(
                connector_id=None,
                external_ref="",
                title=item["title"],
                description=item["description"],
                category=item["category"],
                payout_min=item["payout_min"],
                payout_max=item["payout_max"],
                location_mode=item["location_mode"],
                apply_url=item["apply_url"],
                verified=item["verified"],
                scam_risk_score=item["scam_risk_score"],
                metadata_json="{}",
                active=True,
            )
        )
    db.flush()


def connect_connector(
    db: Session,
    user: User,
    connector_type: str,
    provider: str,
    scopes: list[str] | None,
    credential_ref: str,
    metadata: dict[str, Any] | None,
):
    normalized_type = str(connector_type).strip().lower()
    if normalized_type not in {"jobs", "payments", "communication", "automation"}:
        raise HTTPException(status_code=400, detail="Unsupported connector_type")
    normalized_provider = str(provider).strip().lower() or f"lilith_{normalized_type}"
    if not credential_ref and normalized_provider not in {"lilith_jobs", "lilith_pay", "lilith_mail", "lilith_automation"}:
        raise HTTPException(status_code=400, detail="credential_ref is required for external providers")

    existing = (
        db.query(RealWorldConnector)
        .filter(
            RealWorldConnector.user_id == user.id,
            RealWorldConnector.connector_type == normalized_type,
            RealWorldConnector.provider == normalized_provider,
        )
        .first()
    )
    row = existing or RealWorldConnector(
        user_id=user.id,
        connector_type=normalized_type,
        provider=normalized_provider,
        status="connected",
        scopes_json="[]",
        credential_ref="",
        metadata_json="{}",
        last_synced_at=_now(),
    )
    row.status = "connected"
    row.scopes_json = json.dumps(scopes or ["read"], default=str)
    row.credential_ref = credential_ref[:220]
    row.metadata_json = json.dumps(metadata or {}, default=str)
    row.last_synced_at = _now()
    db.add(row)
    _audit(
        db,
        user.id,
        "real_world.connector.connected",
        "real_world_connector",
        row.id,
        {"connector_type": row.connector_type, "provider": row.provider},
    )
    db.commit()
    db.refresh(row)
    return _connector_out(row)


def list_connectors(db: Session, user: User):
    _ensure_default_connectors(db, user)
    rows = (
        db.query(RealWorldConnector)
        .filter(RealWorldConnector.user_id == user.id)
        .order_by(RealWorldConnector.created_at.desc())
        .all()
    )
    db.commit()
    return {"items": [_connector_out(row) for row in rows]}


def jobs_search(db: Session, user: User, query: str | None, category: str | None, limit: int):
    _ensure_default_connectors(db, user)
    _ensure_seed_opportunities(db)
    q = db.query(RealWorldOpportunity).filter(RealWorldOpportunity.active == True)  # noqa: E712
    if category and category.lower() != "all":
        q = q.filter(func.lower(RealWorldOpportunity.category) == category.lower())
    if query:
        like = f"%{query.strip()}%"
        q = q.filter((RealWorldOpportunity.title.ilike(like)) | (RealWorldOpportunity.description.ilike(like)))
    rows = q.order_by(RealWorldOpportunity.verified.desc(), RealWorldOpportunity.created_at.desc()).limit(max(1, min(limit, 100))).all()

    # Fallback if seed table is empty but income opportunities exist.
    if not rows:
        income_rows = db.query(IncomeOpportunity).filter(IncomeOpportunity.active == True).limit(max(1, min(limit, 100))).all()  # noqa: E712
        for item in income_rows:
            rows.append(
                RealWorldOpportunity(
                    id=item.id,
                    connector_id=None,
                    external_ref=item.id,
                    title=item.title,
                    description=item.description,
                    category=item.category,
                    payout_min=item.payout_min,
                    payout_max=item.payout_max,
                    location_mode=item.location_mode,
                    apply_url="",
                    verified=item.verified,
                    scam_risk_score=item.scam_risk_score,
                    metadata_json=item.metadata_json,
                    active=item.active,
                )
            )
    db.commit()
    return {"items": [_opportunity_out(row) for row in rows]}


def _resolve_user_profile_payload(db: Session, user: User):
    profile = db.query(ApplicationUserProfile).filter(ApplicationUserProfile.user_id == user.id).order_by(ApplicationUserProfile.updated_at.desc()).first()
    if profile is None:
        return {
            "full_name": user.username,
            "email": user.email or "",
            "headline": "Lilith user profile",
        }
    return _safe_json(profile.profile_json, {})


def draft_proposal(db: Session, user: User, opportunity_id: str):
    row = db.query(RealWorldOpportunity).filter(RealWorldOpportunity.id == opportunity_id, RealWorldOpportunity.active == True).first()  # noqa: E712
    if row is None:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    proposal = (
        f"Hi, I can deliver \"{row.title}\" with clear milestones and fast turnaround. "
        f"My background aligns with {row.category} work and I can start immediately."
    )
    _audit(
        db,
        user.id,
        "real_world.proposal.drafted",
        "real_world_opportunity",
        row.id,
        {"title": row.title},
    )
    db.commit()
    return {"opportunity_id": row.id, "proposal_text": proposal, "generated_at": _iso(_now())}


def apply_to_job(
    db: Session,
    user: User,
    opportunity_id: str,
    confirm_submit: bool,
    use_autofill: bool,
    proposal_text: str,
):
    row = db.query(RealWorldOpportunity).filter(RealWorldOpportunity.id == opportunity_id, RealWorldOpportunity.active == True).first()  # noqa: E712
    if row is None:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    profile_payload = _resolve_user_profile_payload(db, user) if use_autofill else {}
    status = "submitted" if confirm_submit else "pending_approval"
    app = RealWorldApplication(
        user_id=user.id,
        opportunity_id=row.id,
        status=status,
        autofill_used=use_autofill,
        proposal_text=proposal_text.strip()[:4000],
        payload_json=json.dumps(
            {
                "profile_payload": profile_payload,
                "source": "lilith_canvas_apply",
            },
            default=str,
        ),
        confirmation_required=True,
        approved_at=_now() if confirm_submit else None,
        submitted_at=_now() if confirm_submit else None,
    )
    db.add(app)
    _audit(
        db,
        user.id,
        "real_world.job.applied" if confirm_submit else "real_world.job.previewed",
        "real_world_application",
        app.id,
        {"opportunity_id": row.id, "confirmed": confirm_submit, "autofill": use_autofill},
    )
    if confirm_submit:
        create_notification(
            db,
            user.id,
            kind="real_world.application_submitted",
            title="Application submitted",
            body=f"Your application for \"{row.title}\" was sent.",
        )
    db.commit()
    db.refresh(app)
    return {
        "application": _application_out(app),
        "opportunity": _opportunity_out(row),
        "next_action": "approve_submit" if not confirm_submit else "track_status",
    }


def list_applications(db: Session, user: User):
    rows = (
        db.query(RealWorldApplication)
        .filter(RealWorldApplication.user_id == user.id)
        .order_by(RealWorldApplication.created_at.desc())
        .limit(100)
        .all()
    )
    return {"items": [_application_out(row) for row in rows]}


def record_income(db: Session, user: User, source_type: str, amount: float, currency: str, metadata: dict[str, Any] | None):
    if float(amount) <= 0:
        raise HTTPException(status_code=400, detail="amount must be positive")
    row = RealWorldIncomeEvent(
        user_id=user.id,
        source_type=str(source_type or "other").strip().lower()[:40],
        amount=round(float(amount), 2),
        currency=str(currency or "USD").upper()[:12],
        status="recorded",
        happened_at=_now(),
        metadata_json=json.dumps(metadata or {}, default=str),
    )
    db.add(row)
    _audit(db, user.id, "real_world.income.recorded", "real_world_income_event", row.id, {"amount": row.amount, "currency": row.currency})
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "source_type": row.source_type,
        "amount": row.amount,
        "currency": row.currency,
        "status": row.status,
        "happened_at": _iso(row.happened_at),
    }


def income_summary(db: Session, user: User):
    start = (_now() - timedelta(days=30))
    rows = (
        db.query(RealWorldIncomeEvent)
        .filter(RealWorldIncomeEvent.user_id == user.id, RealWorldIncomeEvent.happened_at >= start)
        .order_by(RealWorldIncomeEvent.happened_at.desc())
        .all()
    )
    total = round(sum(float(row.amount) for row in rows if row.currency.upper() == "USD"), 2)
    by_source: dict[str, float] = {}
    for row in rows:
        key = row.source_type
        by_source[key] = round(by_source.get(key, 0.0) + float(row.amount), 2)
    return {
        "total_30d_usd": total,
        "event_count": len(rows),
        "by_source": [{"source_type": key, "amount": amount} for key, amount in sorted(by_source.items(), key=lambda x: x[1], reverse=True)],
        "items": [
            {
                "id": row.id,
                "source_type": row.source_type,
                "amount": row.amount,
                "currency": row.currency,
                "happened_at": _iso(row.happened_at),
            }
            for row in rows[:30]
        ],
    }


def suggest_allocation(db: Session, user: User):
    summary = income_summary(db, user)
    total = float(summary["total_30d_usd"])
    if total <= 0:
        total = 1.0
    allocations = {
        "essentials": round(total * 0.5, 2),
        "savings": round(total * 0.2, 2),
        "tax": round(total * 0.2, 2),
        "reinvest": round(total * 0.1, 2),
    }
    return {
        "window": "30d",
        "base_amount_usd": round(float(summary["total_30d_usd"]), 2),
        "allocations": allocations,
        "note": "Allocation suggestions are advisory. All transfers require explicit approval.",
    }


def prepare_transfer_preview(db: Session, user: User, amount: float, destination: str, reason: str):
    payload = {
        "action_type": "transfer_savings",
        "amount": round(float(amount), 2),
        "source": "primary_balance",
        "destination": destination.strip()[:120] or "savings",
        "reason": reason.strip()[:300] or "Real-world allocation transfer",
        "metadata": {"surface": "real_world"},
    }
    preview = create_action_preview(db, user, payload)
    _audit(db, user.id, "real_world.transfer.prepared", "financial_action_preview", preview["id"], {"amount": payload["amount"]})
    return preview


def _run_pipeline_steps(db: Session, user: User, row: RealWorldActionPipeline, approve_sensitive: bool):
    steps = _safe_json(row.steps_json, [])
    results: list[dict[str, Any]] = []
    sensitive_blocked = False
    for idx, step in enumerate(steps):
        step_type = str(step.get("type", "")).strip().lower()
        payload = step.get("payload", {})
        sensitive = bool(step.get("sensitive", False))
        if sensitive and not approve_sensitive:
            sensitive_blocked = True
            results.append({"index": idx, "type": step_type, "status": "approval_required"})
            continue

        if step_type == "jobs.apply":
            app_result = apply_to_job(
                db,
                user=user,
                opportunity_id=str(payload.get("opportunity_id", "")),
                confirm_submit=True,
                use_autofill=bool(payload.get("use_autofill", True)),
                proposal_text=str(payload.get("proposal_text", "")),
            )
            results.append({"index": idx, "type": step_type, "status": "completed", "application_id": app_result["application"]["id"]})
        elif step_type == "communication.send_email":
            results.append(
                {
                    "index": idx,
                    "type": step_type,
                    "status": "completed",
                    "to": str(payload.get("to", "")),
                    "subject": str(payload.get("subject", "")),
                }
            )
        elif step_type == "payments.prepare_transfer":
            preview = prepare_transfer_preview(
                db,
                user=user,
                amount=float(payload.get("amount", 0)),
                destination=str(payload.get("destination", "savings")),
                reason=str(payload.get("reason", "Pipeline transfer")),
            )
            results.append({"index": idx, "type": step_type, "status": "completed", "preview_id": preview["id"]})
        else:
            results.append({"index": idx, "type": step_type or "unknown", "status": "skipped"})

    row.result_json = json.dumps({"step_results": results}, default=str)
    row.executed_at = _now()
    if sensitive_blocked:
        row.status = "needs_approval"
        row.approval_state = "required"
    else:
        row.status = "completed"
        row.approval_state = "approved" if row.requires_approval else "not_required"
    db.add(row)
    db.flush()
    return row


def create_pipeline(
    db: Session,
    user: User,
    action_type: str,
    steps: list[dict[str, Any]],
    context: dict[str, Any] | None,
    auto_execute: bool,
):
    normalized_action = str(action_type or "pipeline.run").strip().lower()[:64]
    requires_approval = any(bool(step.get("sensitive", False)) for step in (steps or []))
    row = RealWorldActionPipeline(
        user_id=user.id,
        action_type=normalized_action,
        status="pending",
        steps_json=json.dumps(steps or [], default=str),
        context_json=json.dumps(context or {}, default=str),
        result_json="{}",
        requires_approval=requires_approval,
        approval_state="required" if requires_approval else "not_required",
        executed_at=None,
    )
    db.add(row)
    db.flush()
    _audit(
        db,
        user.id,
        "real_world.pipeline.created",
        "real_world_action_pipeline",
        row.id,
        {"action_type": normalized_action, "requires_approval": requires_approval},
    )
    if auto_execute:
        row.status = "running"
        db.add(row)
        _run_pipeline_steps(db, user, row, approve_sensitive=not requires_approval)
    db.commit()
    db.refresh(row)
    return _pipeline_out(row)


def execute_pipeline(db: Session, user: User, pipeline_id: str, approve_sensitive: bool):
    row = (
        db.query(RealWorldActionPipeline)
        .filter(RealWorldActionPipeline.id == pipeline_id, RealWorldActionPipeline.user_id == user.id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Pipeline not found")
    row.status = "running"
    if approve_sensitive and row.requires_approval:
        row.approval_state = "approved"
    db.add(row)
    _run_pipeline_steps(db, user, row, approve_sensitive=approve_sensitive)
    _audit(db, user.id, "real_world.pipeline.executed", "real_world_action_pipeline", row.id, {"approve_sensitive": approve_sensitive})
    db.commit()
    db.refresh(row)
    return _pipeline_out(row)


def list_pipelines(db: Session, user: User, limit: int = 40):
    rows = (
        db.query(RealWorldActionPipeline)
        .filter(RealWorldActionPipeline.user_id == user.id)
        .order_by(RealWorldActionPipeline.created_at.desc())
        .limit(max(1, min(limit, 200)))
        .all()
    )
    return {"items": [_pipeline_out(row) for row in rows]}


def dashboard(db: Session, user: User):
    _ensure_default_connectors(db, user)
    _ensure_seed_opportunities(db)
    connectors = db.query(RealWorldConnector).filter(RealWorldConnector.user_id == user.id).all()
    pending_applications = (
        db.query(RealWorldApplication)
        .filter(RealWorldApplication.user_id == user.id, RealWorldApplication.status.in_(["draft", "pending_approval"]))
        .count()
    )
    pending_pipelines = (
        db.query(RealWorldActionPipeline)
        .filter(RealWorldActionPipeline.user_id == user.id, RealWorldActionPipeline.status.in_(["pending", "needs_approval"]))
        .count()
    )
    opportunity_count = db.query(RealWorldOpportunity).filter(RealWorldOpportunity.active == True).count()  # noqa: E712
    income = income_summary(db, user)
    allocation = suggest_allocation(db, user)
    db.commit()
    return {
        "connectors": [_connector_out(row) for row in connectors],
        "opportunity_count": int(opportunity_count),
        "pending_applications": int(pending_applications),
        "pending_pipelines": int(pending_pipelines),
        "income_summary": income,
        "allocation_suggestion": allocation,
        "next_actions": [
            {"type": "jobs.search", "title": "Find verified jobs"},
            {"type": "jobs.apply", "title": "Apply with autofill + approval"},
            {"type": "payments.prepare_transfer", "title": "Prepare savings transfer"},
        ],
    }
