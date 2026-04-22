from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.applications.service import (
    analytics_for_template,
    auto_field_suggestions,
    clone_template,
    create_template,
    get_instance,
    get_template,
    list_instances,
    list_public_templates,
    list_templates,
    list_user_profiles,
    preview_template,
    public_categories,
    public_instance_by_token,
    public_submit_by_token,
    quick_send,
    recent_users,
    replace_fields,
    replace_rules,
    save_user_profile,
    send_request,
    submit_response,
    update_marketplace_settings,
)


router = APIRouter(prefix="/applications", tags=["applications"])


class CreateTemplatePayload(BaseModel):
    name: str
    description: str = ""
    delivery_mode: str = "direct"
    pricing_model: str = "subscription"
    per_request_fee: float = Field(default=0.0, ge=0)
    currency: str = "USD"
    metadata: dict[str, Any] = {}


class FieldPayload(BaseModel):
    key: str
    label: str
    field_type: str = "text"
    required: bool = False
    position: int = 0
    source_type: str = "manual"
    source_key: str = ""
    options: list[Any] = []
    validation: dict[str, Any] = {}


class RulePayload(BaseModel):
    name: str
    condition: dict[str, Any] = {}
    effect: dict[str, Any] = {}
    active: bool = True


class ReplaceFieldsPayload(BaseModel):
    fields: list[FieldPayload]


class ReplaceRulesPayload(BaseModel):
    rules: list[RulePayload]


class PreviewPayload(BaseModel):
    vault_profile_id: str | None = None
    reusable_profile_id: str | None = None
    manual_data: dict[str, Any] = {}


class SendRequestPayload(BaseModel):
    target_user_id: str | None = None
    channel: str = "direct"
    prefill: dict[str, Any] = {}
    metadata: dict[str, Any] = {}


class QuickSendPayload(BaseModel):
    target_user_id: str | None = None


class SubmitResponsePayload(BaseModel):
    data: dict[str, Any] = {}
    status: str = "submitted"
    metadata: dict[str, Any] = {}


class PublicSubmitPayload(BaseModel):
    data: dict[str, Any] = {}
    responder_user_id: str | None = None


class MarketplaceUpdatePayload(BaseModel):
    is_public: bool | None = None
    category: str | None = None
    tags: list[str] | None = None


class SaveProfilePayload(BaseModel):
    profile_name: str
    fields: dict[str, Any] = {}
    is_default: bool = False
    source: str = "application_builder"


@router.post("/templates")
async def templates_create(payload: CreateTemplatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.templates.create", f"user:{user.id}", limit=25, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Template creation rate limit exceeded")
    return create_template(
        db,
        user,
        payload.name,
        payload.description,
        payload.delivery_mode,
        payload.pricing_model,
        payload.per_request_fee,
        payload.currency,
        payload.metadata,
    )


@router.get("/templates")
def templates_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": list_templates(db, user)}


@router.get("/templates/{template_id}")
def templates_get(template_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return get_template(db, user, template_id)


@router.post("/templates/{template_id}/fields")
async def templates_replace_fields(template_id: str, payload: ReplaceFieldsPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.fields.replace", f"user:{user.id}", limit=50, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Field update rate limit exceeded")
    return replace_fields(db, user, template_id, [item.model_dump() for item in payload.fields])


@router.post("/templates/{template_id}/rules")
async def templates_replace_rules(template_id: str, payload: ReplaceRulesPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.rules.replace", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Rule update rate limit exceeded")
    return replace_rules(db, user, template_id, [item.model_dump() for item in payload.rules])


@router.post("/templates/{template_id}/preview")
def templates_preview(template_id: str, payload: PreviewPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return preview_template(
        db,
        template_id=template_id,
        actor=user,
        vault_profile_id=payload.vault_profile_id,
        reusable_profile_id=payload.reusable_profile_id,
        manual_data=payload.manual_data,
    )


@router.post("/templates/{template_id}/send")
async def templates_send(template_id: str, payload: SendRequestPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.templates.send", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Request send rate limit exceeded")
    return send_request(
        db,
        template_id=template_id,
        requester=user,
        target_user_id=payload.target_user_id,
        channel=payload.channel,
        prefill=payload.prefill,
        metadata=payload.metadata,
    )


@router.post("/templates/{template_id}/quick-send")
async def templates_quick_send(template_id: str, payload: QuickSendPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.templates.quick_send", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Quick send rate limit exceeded")
    return quick_send(db, user, template_id, payload.target_user_id)


@router.post("/templates/{template_id}/marketplace")
def templates_marketplace_update(template_id: str, payload: MarketplaceUpdatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return update_marketplace_settings(db, user, template_id, payload.is_public, payload.category, payload.tags)


@router.get("/templates/{template_id}/analytics")
def templates_analytics(template_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return analytics_for_template(db, user, template_id)


@router.get("/templates/{template_id}/suggest-fields")
def templates_suggest_fields(
    template_id: str,
    category: str | None = Query(default=None),
    limit: int = Query(default=8, ge=1, le=20),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    _ = template_id
    return {"items": auto_field_suggestions(db, user, category, limit)}


@router.post("/templates/{template_id}/clone")
def templates_clone(template_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return clone_template(db, user, template_id)


@router.get("/recent-users")
def applications_recent_users(limit: int = Query(default=8, ge=1, le=50), db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": recent_users(db, user, limit)}


@router.get("/instances")
def instances_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": list_instances(db, user)}


@router.get("/instances/{instance_id}")
def instances_get(instance_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return get_instance(db, user, instance_id)


@router.post("/instances/{instance_id}/respond")
async def instances_respond(instance_id: str, payload: SubmitResponsePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.instances.respond", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Response rate limit exceeded")
    return submit_response(db, user, instance_id, payload.data, payload.status, payload.metadata)


@router.get("/marketplace/templates")
def marketplace_templates(
    category: str | None = Query(default=None),
    query: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    _ = user
    return {"items": list_public_templates(db, category, query, limit)}


@router.get("/marketplace/categories")
def marketplace_categories(db: Session = Depends(get_db), user: User = Depends(current_user)):
    _ = user
    return {"items": public_categories(db)}


@router.get("/profiles")
def application_profiles(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": list_user_profiles(db, user)}


@router.post("/profiles")
def application_profiles_save(payload: SaveProfilePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return save_user_profile(db, user, payload.profile_name, payload.fields, payload.is_default, payload.source)


@router.post("/api/request-create")
async def api_request_create(payload: CreateTemplatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.api.request_create", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="API request-create rate limit exceeded")
    return create_template(
        db,
        user,
        payload.name,
        payload.description,
        payload.delivery_mode,
        payload.pricing_model,
        payload.per_request_fee,
        payload.currency,
        payload.metadata,
    )


@router.post("/api/request-send/{template_id}")
async def api_request_send(template_id: str, payload: SendRequestPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("applications.api.request_send", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="API request-send rate limit exceeded")
    return send_request(
        db,
        template_id=template_id,
        requester=user,
        target_user_id=payload.target_user_id,
        channel=payload.channel,
        prefill=payload.prefill,
        metadata=payload.metadata,
    )


@router.get("/public/apply/{token}")
def public_apply(token: str, db: Session = Depends(get_db)):
    return public_instance_by_token(db, token)


@router.post("/public/apply/{token}/respond")
def public_apply_respond(token: str, payload: PublicSubmitPayload, db: Session = Depends(get_db)):
    return public_submit_by_token(db, token, payload.data, payload.responder_user_id)
