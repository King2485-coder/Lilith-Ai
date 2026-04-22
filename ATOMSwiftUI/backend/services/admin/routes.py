from __future__ import annotations

import json

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend.core.deps import current_admin_user, get_db
from backend.models.user import User
from backend.services.admin.service import (
    admin_metrics_snapshot,
    admin_refund,
    admin_trigger_clear_cache,
    admin_trigger_restart,
    flag_payment_fraud,
    list_reports,
    list_tool_controls,
    list_transactions,
    list_users,
    log_admin_action,
    moderate_report,
    set_tool_control,
    set_user_status,
    tool_usage_summary,
)
from backend.services.system.routes import system_alerts, system_health, system_logs, system_metrics


router = APIRouter(prefix="/admin", tags=["admin"])


class UserStatusPayload(BaseModel):
    status: str  # active/suspended/banned


class RefundPayload(BaseModel):
    payment_intent_id: str


class FraudPayload(BaseModel):
    payment_intent_id: str
    reason: str


class ToolControlPayload(BaseModel):
    tool_name: str
    approved: bool
    enabled: bool
    note: str = ""


class ModerationActionPayload(BaseModel):
    status: str  # reviewed/actioned/dismissed
    note: str = ""


class RestartPayload(BaseModel):
    service_name: str


class ClearCachePayload(BaseModel):
    prefix: str = "lilith:"


@router.get("/users")
def admin_users(limit: int = 200, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    return {"items": list_users(db, limit=limit)}


@router.post("/users/{user_id}/status")
def admin_user_status(user_id: str, payload: UserStatusPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    row = set_user_status(db, user_id, payload.status)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="user.status.update",
        target_type="user",
        target_id=user_id,
        details={"status": payload.status},
    )
    return {"user_id": row.user_id, "status": row.status}


@router.get("/payments/transactions")
def admin_transactions(limit: int = 200, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    rows = list_transactions(db, limit=limit)
    return {
        "items": [
            {
                "id": row.id,
                "sender_id": row.sender_id,
                "receiver_id": row.receiver_id,
                "amount": row.amount,
                "currency": row.currency,
                "status": row.status,
                "kind": row.kind,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/payments/refund")
def admin_payments_refund(payload: RefundPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    row = admin_refund(db, payload.payment_intent_id)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="payments.refund",
        target_type="payment_intent",
        target_id=row.id,
        details={"status": row.status},
    )
    return {"id": row.id, "status": row.status}


@router.post("/payments/flag-fraud")
def admin_payments_flag_fraud(payload: FraudPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    row = flag_payment_fraud(db, payload.payment_intent_id, admin.id, payload.reason)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="payments.flag_fraud",
        target_type="payment_intent",
        target_id=payload.payment_intent_id,
        details={"reason": payload.reason},
    )
    return {"id": row.id, "payment_intent_id": row.payment_intent_id}


@router.get("/tools")
def admin_tools(db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    controls = list_tool_controls(db)
    usage = tool_usage_summary(db)
    return {
        "controls": [
            {
                "tool_name": row.tool_name,
                "approved": row.approved,
                "enabled": row.enabled,
                "note": row.note,
            }
            for row in controls
        ],
        "usage": usage,
    }


@router.post("/tools/control")
def admin_tools_control(payload: ToolControlPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    row = set_tool_control(db, payload.tool_name, payload.approved, payload.enabled, payload.note)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="tools.control.update",
        target_type="tool",
        target_id=row.tool_name,
        details={"approved": row.approved, "enabled": row.enabled, "note": row.note},
    )
    return {"tool_name": row.tool_name, "approved": row.approved, "enabled": row.enabled, "note": row.note}


@router.get("/moderation/reports")
def admin_moderation_reports(status: str | None = None, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    rows = list_reports(db, status=status)
    return {
        "items": [
            {
                "id": row.id,
                "reporter_user_id": row.reporter_user_id,
                "target_type": row.target_type,
                "target_id": row.target_id,
                "reason": row.reason,
                "status": row.status,
                "action_note": row.action_note,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/moderation/reports/{report_id}/action")
def admin_moderation_action(report_id: str, payload: ModerationActionPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    row = moderate_report(db, report_id, payload.status, payload.note)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="moderation.report.action",
        target_type="moderation_report",
        target_id=row.id,
        details={"status": row.status, "note": row.action_note},
    )
    return {"id": row.id, "status": row.status, "action_note": row.action_note}


@router.get("/system/metrics")
def admin_system_metrics(db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    return system_metrics(db=db, user=admin)


@router.get("/system/logs")
def admin_system_logs(limit: int = 150, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    return system_logs(limit=limit, db=db, user=admin)


@router.get("/system/alerts")
def admin_system_alerts(db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    return system_alerts(db=db, user=admin)


@router.get("/system/health")
async def admin_system_health(db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    return await system_health(db=db, user=admin)


@router.post("/system/fix/restart")
async def admin_system_fix_restart(payload: RestartPayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    out = await admin_trigger_restart(payload.service_name)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="system.fix.restart",
        target_type="service",
        target_id=payload.service_name,
        details=out,
    )
    return out


@router.post("/system/fix/clear-cache")
async def admin_system_fix_clear_cache(payload: ClearCachePayload, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    out = await admin_trigger_clear_cache(payload.prefix)
    log_admin_action(
        db,
        admin_user_id=admin.id,
        action="system.fix.clear_cache",
        target_type="cache_prefix",
        target_id=payload.prefix,
        details=out,
    )
    return out


@router.get("/actions")
def admin_actions(limit: int = 200, db: Session = Depends(get_db), admin: User = Depends(current_admin_user)):
    from backend.models.admin import AdminActionLog

    rows = db.query(AdminActionLog).order_by(AdminActionLog.created_at.desc()).limit(max(1, min(limit, 500))).all()
    return {
        "items": [
            {
                "id": row.id,
                "admin_user_id": row.admin_user_id,
                "action": row.action,
                "target_type": row.target_type,
                "target_id": row.target_id,
                "details": json.loads(row.details_json or "{}"),
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }

