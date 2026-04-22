from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.finance_hub.service import (
    access_policy_response,
    approve_action_preview,
    create_action_preview,
    create_automation_rule,
    decline_action_preview,
    financial_hub_dashboard,
    generate_read_only_analysis,
    link_account,
    list_action_previews,
    list_audit_logs,
    list_automation_rules,
    list_linked_accounts,
    list_opportunities,
    run_automation_rule,
    update_access_policy,
    update_action_preview_payload,
    upsert_recurring_item,
    ensure_policy,
)


router = APIRouter(prefix="/finance-hub", tags=["finance-hub"])


class AccessPolicyPatch(BaseModel):
    access_level: str | None = None
    max_transfer_limit: float | None = Field(default=None, ge=0)
    bill_runway_days: int | None = Field(default=None, ge=1)
    available_cash_buffer: float | None = Field(default=None, ge=0)
    require_biometric_sensitive: bool | None = None
    first_time_hard_confirm_required: bool | None = None
    one_click_trade_enabled: bool | None = None
    one_click_trade_max: float | None = Field(default=None, ge=0)


class LinkAccountPayload(BaseModel):
    provider: str = "wealthwizard"
    provider_account_ref: str
    display_name: str
    account_type: str = "checking"
    currency: str = "USD"
    credential_ref: str = ""
    metadata: dict[str, Any] = {}
    raw_credentials: dict[str, Any] | None = None


class ActionPreviewPayload(BaseModel):
    action_type: str
    reason: str = ""
    amount: float = Field(default=0, ge=0)
    source: str = ""
    destination: str = ""
    symbol: str = ""
    metadata: dict[str, Any] = {}


class ActionEditPayload(BaseModel):
    amount: float | None = Field(default=None, ge=0)
    reason: str | None = None
    source: str | None = None
    destination: str | None = None
    symbol: str | None = None
    metadata: dict[str, Any] | None = None


class ActionDecisionPayload(BaseModel):
    approve_mode: str = "standard"
    biometric_ok: bool = False
    reason: str = ""


class AutomationPayload(BaseModel):
    name: str = ""
    rule_type: str
    config: dict[str, Any] = {}
    enabled: bool = True
    require_approval: bool = True


class RecurringPayload(BaseModel):
    id: str | None = None
    name: str
    kind: str = "subscription"
    amount: float = Field(default=0, ge=0)
    frequency: str = "monthly"
    next_due_at: str | None = None
    active: bool = True
    metadata: dict[str, Any] = {}


@router.get("/dashboard")
def finance_dashboard(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return financial_hub_dashboard(db, user)


@router.get("/access")
def finance_access_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = ensure_policy(db, user)
    db.commit()
    return access_policy_response(row)


@router.patch("/access")
async def finance_access_patch(payload: AccessPolicyPatch, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.access.patch", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Access policy rate limit exceeded")
    patch = payload.model_dump(exclude_none=True)
    return update_access_policy(db, user, patch)


@router.post("/linked-accounts")
async def finance_link_account(payload: LinkAccountPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.link_account", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Link account rate limit exceeded")
    return link_account(db, user, payload.model_dump())


@router.get("/linked-accounts")
def finance_linked_accounts(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_linked_accounts(db, user)


@router.get("/analysis")
def finance_analysis(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return generate_read_only_analysis(db, user)


@router.get("/opportunities")
def finance_opportunities(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_opportunities(db, user)


@router.post("/actions/preview")
async def finance_preview_action(payload: ActionPreviewPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.action.preview", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Action preview rate limit exceeded")
    return create_action_preview(db, user, payload.model_dump())


@router.get("/actions/previews")
def finance_list_previews(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_action_previews(db, user)


@router.patch("/actions/{preview_id}")
async def finance_edit_preview(preview_id: str, payload: ActionEditPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.action.edit", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Action edit rate limit exceeded")
    return update_action_preview_payload(db, user, preview_id, payload.model_dump(exclude_none=True))


@router.post("/actions/{preview_id}/approve")
async def finance_approve_preview(preview_id: str, payload: ActionDecisionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.action.approve", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Action approve rate limit exceeded")
    return approve_action_preview(db, user, preview_id, payload.approve_mode, payload.biometric_ok)


@router.post("/actions/{preview_id}/decline")
async def finance_decline_preview(preview_id: str, payload: ActionDecisionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.action.decline", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Action decline rate limit exceeded")
    return decline_action_preview(db, user, preview_id, payload.reason)


@router.post("/automations")
async def finance_create_automation(payload: AutomationPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.automation.create", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Automation creation rate limit exceeded")
    return create_automation_rule(db, user, payload.model_dump())


@router.get("/automations")
def finance_list_automations(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_automation_rules(db, user)


@router.post("/automations/{rule_id}/run")
async def finance_run_automation(rule_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.automation.run", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Automation run rate limit exceeded")
    return run_automation_rule(db, user, rule_id)


@router.post("/recurring")
async def finance_upsert_recurring(payload: RecurringPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("finance_hub.recurring.upsert", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Recurring update rate limit exceeded")
    return upsert_recurring_item(db, user, payload.model_dump(exclude_none=True))


@router.get("/audit")
def finance_audit(limit: int = Query(default=200, ge=1, le=500), db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_audit_logs(db, user, limit)
