from __future__ import annotations

import json
import secrets
from collections import Counter
from datetime import datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from backend.models.application import (
    ApplicationField,
    ApplicationInstance,
    ApplicationInstanceEvent,
    ApplicationResponse,
    ApplicationRule,
    ApplicationTemplate,
    ApplicationTemplateMarket,
    ApplicationUserProfile,
)
from backend.models.neurocloud import UserMemory
from backend.models.storage import VaultProfile
from backend.models.user import User


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _iso(value):
    return value.isoformat() if value else None


def _now_iso():
    return datetime.utcnow().isoformat()


def _field_out(row: ApplicationField):
    return {
        "id": row.id,
        "key": row.key,
        "label": row.label,
        "field_type": row.field_type,
        "required": bool(row.required),
        "position": int(row.position),
        "source_type": row.source_type,
        "source_key": row.source_key,
        "options": _safe_json(row.options_json, []),
        "validation": _safe_json(row.validation_json, {}),
    }


def _rule_out(row: ApplicationRule):
    return {
        "id": row.id,
        "name": row.name,
        "condition": _safe_json(row.condition_json, {}),
        "effect": _safe_json(row.effect_json, {}),
        "active": bool(row.active),
    }


def _ensure_market_row(db: Session, template_id: str):
    row = db.query(ApplicationTemplateMarket).filter(ApplicationTemplateMarket.template_id == template_id).first()
    if row is None:
        row = ApplicationTemplateMarket(
            template_id=template_id,
            is_public=False,
            category="General",
            tags_json="[]",
            clone_source_template_id="",
            usage_count=0,
        )
        db.add(row)
        db.flush()
    return row


def _event(db: Session, instance_id: str, template_id: str, event_type: str, field_key: str = "", metadata: dict[str, Any] | None = None):
    db.add(
        ApplicationInstanceEvent(
            instance_id=instance_id,
            template_id=template_id,
            event_type=event_type[:40],
            field_key=field_key[:120],
            metadata_json=json.dumps(metadata or {}, default=str),
        )
    )


def _template_out(db: Session, row: ApplicationTemplate):
    fields = (
        db.query(ApplicationField)
        .filter(ApplicationField.template_id == row.id)
        .order_by(ApplicationField.position.asc(), ApplicationField.created_at.asc())
        .all()
    )
    rules = db.query(ApplicationRule).filter(ApplicationRule.template_id == row.id).order_by(ApplicationRule.created_at.asc()).all()
    market = _ensure_market_row(db, row.id)
    return {
        "id": row.id,
        "business_user_id": row.business_user_id,
        "name": row.name,
        "description": row.description,
        "status": row.status,
        "delivery_mode": row.delivery_mode,
        "pricing_model": row.pricing_model,
        "per_request_fee": row.per_request_fee,
        "currency": row.currency,
        "metadata": _safe_json(row.metadata_json, {}),
        "market": {
            "is_public": bool(market.is_public),
            "category": market.category,
            "tags": _safe_json(market.tags_json, []),
            "clone_source_template_id": market.clone_source_template_id or "",
            "usage_count": int(market.usage_count or 0),
        },
        "fields": [_field_out(f) for f in fields],
        "rules": [_rule_out(r) for r in rules],
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def create_template(
    db: Session,
    user: User,
    name: str,
    description: str,
    delivery_mode: str,
    pricing_model: str,
    per_request_fee: float,
    currency: str,
    metadata: dict[str, Any] | None = None,
):
    incoming_meta = metadata or {}
    row = ApplicationTemplate(
        business_user_id=user.id,
        name=name.strip()[:180] or "Untitled request",
        description=description.strip()[:2000],
        status="active",
        delivery_mode=(delivery_mode or "direct").strip().lower(),
        pricing_model=(pricing_model or "subscription").strip().lower(),
        per_request_fee=max(round(float(per_request_fee), 2), 0.0),
        currency=(currency or "USD").upper(),
        metadata_json=json.dumps(incoming_meta, default=str),
    )
    db.add(row)
    db.flush()
    market = _ensure_market_row(db, row.id)
    market.is_public = bool(incoming_meta.get("is_public", False))
    market.category = str(incoming_meta.get("category", "General"))[:64]
    market.tags_json = json.dumps(incoming_meta.get("tags", []), default=str)
    db.add(market)
    db.commit()
    db.refresh(row)
    return _template_out(db, row)


def list_templates(db: Session, user: User):
    rows = db.query(ApplicationTemplate).filter(ApplicationTemplate.business_user_id == user.id).order_by(ApplicationTemplate.updated_at.desc()).all()
    out = []
    for row in rows:
        out.append(_template_out(db, row))
    db.commit()
    return out


def get_template(db: Session, user: User, template_id: str):
    row = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Template not found")
    if row.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this template")
    out = _template_out(db, row)
    db.commit()
    return out


def list_public_templates(db: Session, category: str | None = None, query: str | None = None, limit: int = 30):
    q = db.query(ApplicationTemplate, ApplicationTemplateMarket).join(
        ApplicationTemplateMarket, ApplicationTemplateMarket.template_id == ApplicationTemplate.id
    ).filter(
        ApplicationTemplate.status == "active",
        ApplicationTemplateMarket.is_public == True,  # noqa: E712
    )
    if category and category.lower() != "all":
        q = q.filter(func.lower(ApplicationTemplateMarket.category) == category.lower())
    if query:
        like = f"%{query.strip()}%"
        q = q.filter((ApplicationTemplate.name.ilike(like)) | (ApplicationTemplate.description.ilike(like)))
    rows = q.order_by(ApplicationTemplateMarket.usage_count.desc(), ApplicationTemplate.updated_at.desc()).limit(max(1, min(limit, 100))).all()
    items = []
    for template, market in rows:
        items.append(
            {
                "id": template.id,
                "business_user_id": template.business_user_id,
                "name": template.name,
                "description": template.description,
                "delivery_mode": template.delivery_mode,
                "pricing_model": template.pricing_model,
                "per_request_fee": template.per_request_fee,
                "currency": template.currency,
                "category": market.category,
                "tags": _safe_json(market.tags_json, []),
                "usage_count": int(market.usage_count or 0),
                "created_at": _iso(template.created_at),
            }
        )
    return items


def public_categories(db: Session):
    rows = (
        db.query(ApplicationTemplateMarket.category, func.count(ApplicationTemplateMarket.id))
        .filter(ApplicationTemplateMarket.is_public == True)  # noqa: E712
        .group_by(ApplicationTemplateMarket.category)
        .order_by(func.count(ApplicationTemplateMarket.id).desc())
        .all()
    )
    return [{"category": category or "General", "count": int(count or 0)} for category, count in rows]


def clone_template(db: Session, user: User, template_id: str):
    source = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if source is None:
        raise HTTPException(status_code=404, detail="Template not found")
    src_market = _ensure_market_row(db, source.id)
    if not src_market.is_public and source.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Template is not publicly cloneable")
    clone = ApplicationTemplate(
        business_user_id=user.id,
        name=f"{source.name} (Clone)"[:180],
        description=source.description,
        status="active",
        delivery_mode=source.delivery_mode,
        pricing_model=source.pricing_model,
        per_request_fee=source.per_request_fee,
        currency=source.currency,
        metadata_json=source.metadata_json,
    )
    db.add(clone)
    db.flush()

    src_fields = db.query(ApplicationField).filter(ApplicationField.template_id == source.id).order_by(ApplicationField.position.asc()).all()
    for field in src_fields:
        db.add(
            ApplicationField(
                template_id=clone.id,
                key=field.key,
                label=field.label,
                field_type=field.field_type,
                required=field.required,
                position=field.position,
                source_type=field.source_type,
                source_key=field.source_key,
                options_json=field.options_json,
                validation_json=field.validation_json,
            )
        )

    src_rules = db.query(ApplicationRule).filter(ApplicationRule.template_id == source.id).all()
    for rule in src_rules:
        db.add(
            ApplicationRule(
                template_id=clone.id,
                name=rule.name,
                condition_json=rule.condition_json,
                effect_json=rule.effect_json,
                active=rule.active,
            )
        )
    clone_market = _ensure_market_row(db, clone.id)
    clone_market.is_public = False
    clone_market.category = src_market.category
    clone_market.tags_json = src_market.tags_json
    clone_market.clone_source_template_id = source.id
    src_market.usage_count = int(src_market.usage_count or 0) + 1
    db.add(src_market)
    db.add(clone_market)
    db.commit()
    db.refresh(clone)
    return _template_out(db, clone)


def update_marketplace_settings(
    db: Session,
    user: User,
    template_id: str,
    is_public: bool | None = None,
    category: str | None = None,
    tags: list[str] | None = None,
):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this template")
    row = _ensure_market_row(db, template_id)
    if is_public is not None:
        row.is_public = bool(is_public)
    if category is not None:
        row.category = category.strip()[:64] or "General"
    if tags is not None:
        row.tags_json = json.dumps([str(t).strip()[:32] for t in tags if str(t).strip()], default=str)
    db.add(row)
    db.commit()
    return _template_out(db, template)


def replace_fields(db: Session, user: User, template_id: str, fields: list[dict[str, Any]]):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this template")
    db.query(ApplicationField).filter(ApplicationField.template_id == template.id).delete()
    for i, field in enumerate(fields):
        db.add(
            ApplicationField(
                template_id=template.id,
                key=str(field.get("key", f"field_{i+1}")).strip()[:120],
                label=str(field.get("label", f"Field {i+1}")).strip()[:180],
                field_type=str(field.get("field_type", "text")).strip()[:40],
                required=bool(field.get("required", False)),
                position=int(field.get("position", i)),
                source_type=str(field.get("source_type", "manual")).strip()[:24],
                source_key=str(field.get("source_key", "")).strip()[:120],
                options_json=json.dumps(field.get("options", []), default=str),
                validation_json=json.dumps(field.get("validation", {}), default=str),
            )
        )
    db.commit()
    return get_template(db, user, template_id)


def replace_rules(db: Session, user: User, template_id: str, rules: list[dict[str, Any]]):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this template")
    db.query(ApplicationRule).filter(ApplicationRule.template_id == template.id).delete()
    for i, rule in enumerate(rules):
        db.add(
            ApplicationRule(
                template_id=template.id,
                name=str(rule.get("name", f"Rule {i+1}")).strip()[:180],
                condition_json=json.dumps(rule.get("condition", {}), default=str),
                effect_json=json.dumps(rule.get("effect", {}), default=str),
                active=bool(rule.get("active", True)),
            )
        )
    db.commit()
    return get_template(db, user, template_id)


def _apply_rules(fields: list[dict[str, Any]], rules: list[dict[str, Any]], values: dict[str, Any]):
    by_key = {f["key"]: dict(f) for f in fields}
    for rule in rules:
        if not rule.get("active", True):
            continue
        condition = rule.get("condition", {}) or {}
        effect = rule.get("effect", {}) or {}
        field_key = condition.get("field")
        equals = condition.get("equals")
        if not field_key:
            continue
        if str(values.get(field_key, "")) != str(equals):
            continue
        for req_key in effect.get("require", []) or []:
            if req_key in by_key:
                by_key[req_key]["required"] = True
    return list(by_key.values())


def _manual_profile_values(db: Session, user_id: str, profile_id: str | None):
    if not profile_id:
        return {}
    row = db.query(ApplicationUserProfile).filter(ApplicationUserProfile.id == profile_id, ApplicationUserProfile.user_id == user_id).first()
    if row is None:
        return {}
    return _safe_json(row.fields_json, {})


def preview_template(
    db: Session,
    template_id: str,
    actor: User,
    vault_profile_id: str | None = None,
    manual_data: dict[str, Any] | None = None,
    reusable_profile_id: str | None = None,
):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    fields = (
        db.query(ApplicationField)
        .filter(ApplicationField.template_id == template.id)
        .order_by(ApplicationField.position.asc(), ApplicationField.created_at.asc())
        .all()
    )
    rules = db.query(ApplicationRule).filter(ApplicationRule.template_id == template.id).all()
    profile_values = {}
    if vault_profile_id:
        vp = db.query(VaultProfile).filter(VaultProfile.id == vault_profile_id, VaultProfile.user_id == actor.id).first()
        if vp:
            profile_values = _safe_json(vp.fields_json, {})
    reusable_values = _manual_profile_values(db, actor.id, reusable_profile_id)
    manual_values = manual_data or {}
    merged = {**profile_values, **reusable_values, **manual_values}
    applied = []
    autofilled = 0
    for row in fields:
        item = _field_out(row)
        value = None
        source = "manual"
        if item["source_type"] == "vault":
            source_key = item["source_key"] or item["key"]
            if source_key in merged:
                value = merged.get(source_key)
                source = "vault"
        elif item["source_type"] == "upload":
            source = "upload"
        if value is None and item["key"] in merged:
            value = merged.get(item["key"])
            source = "profile"
        if source in {"vault", "profile"} and value not in (None, ""):
            autofilled += 1
        item["preview_value"] = value
        item["preview_source"] = source
        applied.append(item)
    applied = _apply_rules(applied, [_rule_out(r) for r in rules], merged)
    missing = [f["key"] for f in applied if f.get("required") and not f.get("preview_value")]
    total = max(len(applied), 1)
    return {
        "template_id": template.id,
        "template_name": template.name,
        "pricing_model": template.pricing_model,
        "per_request_fee": template.per_request_fee,
        "currency": template.currency,
        "fields": applied,
        "missing_required": missing,
        "can_auto_complete": len(missing) == 0,
        "autofill_success_rate": round(autofilled / total, 4),
    }


def send_request(
    db: Session,
    template_id: str,
    requester: User,
    target_user_id: str | None,
    channel: str,
    prefill: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    token = secrets.token_urlsafe(18)
    instance = ApplicationInstance(
        template_id=template.id,
        business_user_id=template.business_user_id,
        requester_user_id=requester.id,
        target_user_id=(target_user_id or "").strip(),
        channel=(channel or template.delivery_mode or "direct").strip().lower(),
        status="pending",
        token=token,
        prefill_json=json.dumps(prefill or {}, default=str),
        metadata_json=json.dumps(metadata or {}, default=str),
    )
    db.add(instance)
    db.flush()
    _event(
        db,
        instance_id=instance.id,
        template_id=instance.template_id,
        event_type="started",
        metadata={"channel": instance.channel, "target_user_id": instance.target_user_id},
    )
    market = _ensure_market_row(db, template.id)
    market.usage_count = int(market.usage_count or 0) + 1
    db.add(market)
    db.commit()
    db.refresh(instance)
    return {
        "id": instance.id,
        "template_id": instance.template_id,
        "channel": instance.channel,
        "status": instance.status,
        "target_user_id": instance.target_user_id,
        "link": f"/apply/{instance.token}",
        "public_link_token": instance.token,
        "pricing_model": template.pricing_model,
        "per_request_fee": template.per_request_fee,
        "currency": template.currency,
        "created_at": _iso(instance.created_at),
    }


def quick_send(db: Session, user: User, template_id: str, target_user_id: str | None = None):
    recent = recent_users(db, user)
    resolved_target = (target_user_id or "").strip() or (recent[0]["user_id"] if recent else "")
    channel = "direct" if resolved_target else "link"
    sent = send_request(
        db,
        template_id=template_id,
        requester=user,
        target_user_id=resolved_target,
        channel=channel,
        prefill={},
        metadata={"quick_send": True},
    )
    sent["resolved_target"] = resolved_target
    return sent


def recent_users(db: Session, user: User, limit: int = 8):
    rows = (
        db.query(ApplicationInstance.target_user_id, func.max(ApplicationInstance.created_at))
        .filter(ApplicationInstance.requester_user_id == user.id, ApplicationInstance.target_user_id != "")
        .group_by(ApplicationInstance.target_user_id)
        .order_by(func.max(ApplicationInstance.created_at).desc())
        .limit(max(1, min(limit, 50)))
        .all()
    )
    items = []
    for user_id, last_at in rows:
        profile = db.query(User).filter(User.id == user_id).first()
        items.append(
            {
                "user_id": user_id,
                "username": profile.username if profile else "",
                "last_sent_at": _iso(last_at),
            }
        )
    return items


def list_instances(db: Session, user: User):
    rows = (
        db.query(ApplicationInstance)
        .filter(
            (ApplicationInstance.business_user_id == user.id)
            | (ApplicationInstance.requester_user_id == user.id)
            | (ApplicationInstance.target_user_id == user.id)
        )
        .order_by(ApplicationInstance.created_at.desc())
        .all()
    )
    return [
        {
            "id": row.id,
            "template_id": row.template_id,
            "business_user_id": row.business_user_id,
            "requester_user_id": row.requester_user_id,
            "target_user_id": row.target_user_id,
            "channel": row.channel,
            "status": row.status,
            "submitted_at": row.submitted_at,
            "created_at": _iso(row.created_at),
        }
        for row in rows
    ]


def get_instance(db: Session, user: User, instance_id: str):
    row = db.query(ApplicationInstance).filter(ApplicationInstance.id == instance_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Instance not found")
    if user.id not in {row.business_user_id, row.requester_user_id, row.target_user_id}:
        raise HTTPException(status_code=403, detail="Not authorized for this instance")
    responses = db.query(ApplicationResponse).filter(ApplicationResponse.instance_id == row.id).order_by(ApplicationResponse.created_at.desc()).all()
    events = db.query(ApplicationInstanceEvent).filter(ApplicationInstanceEvent.instance_id == row.id).order_by(ApplicationInstanceEvent.created_at.asc()).all()
    return {
        "id": row.id,
        "template_id": row.template_id,
        "business_user_id": row.business_user_id,
        "requester_user_id": row.requester_user_id,
        "target_user_id": row.target_user_id,
        "channel": row.channel,
        "status": row.status,
        "token": row.token,
        "prefill": _safe_json(row.prefill_json, {}),
        "metadata": _safe_json(row.metadata_json, {}),
        "responses": [
            {
                "id": r.id,
                "responder_user_id": r.responder_user_id,
                "status": r.status,
                "data": _safe_json(r.data_json, {}),
                "created_at": _iso(r.created_at),
            }
            for r in responses
        ],
        "events": [
            {
                "event_type": e.event_type,
                "field_key": e.field_key,
                "metadata": _safe_json(e.metadata_json, {}),
                "created_at": _iso(e.created_at),
            }
            for e in events
        ],
    }


def submit_response(
    db: Session,
    user: User,
    instance_id: str,
    data: dict[str, Any],
    status: str = "submitted",
    metadata: dict[str, Any] | None = None,
):
    instance = db.query(ApplicationInstance).filter(ApplicationInstance.id == instance_id).first()
    if instance is None:
        raise HTTPException(status_code=404, detail="Instance not found")
    if user.id not in {instance.requester_user_id, instance.target_user_id, instance.business_user_id}:
        raise HTTPException(status_code=403, detail="Not authorized to respond")
    payload = dict(data or {})
    if metadata:
        payload["_meta"] = metadata
    row = ApplicationResponse(
        instance_id=instance.id,
        responder_user_id=user.id,
        data_json=json.dumps(payload, default=str),
        status=status[:32] or "submitted",
    )
    instance.status = "submitted"
    instance.submitted_at = _now_iso()
    db.add(row)
    db.add(instance)
    _event(
        db,
        instance_id=instance.id,
        template_id=instance.template_id,
        event_type="submitted",
        metadata={"responder_user_id": user.id, "status": row.status},
    )
    auto_meta = metadata or {}
    if auto_meta.get("autofilled_count") is not None:
        _event(
            db,
            instance_id=instance.id,
            template_id=instance.template_id,
            event_type="autofill",
            metadata={"autofilled_count": auto_meta.get("autofilled_count"), "total_fields": auto_meta.get("total_fields")},
        )
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "instance_id": row.instance_id,
        "responder_user_id": row.responder_user_id,
        "status": row.status,
        "data": _safe_json(row.data_json, {}),
        "created_at": _iso(row.created_at),
    }


def public_instance_by_token(db: Session, token: str):
    row = db.query(ApplicationInstance).filter(ApplicationInstance.token == token).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Application link not found")
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == row.template_id).first()
    fields = (
        db.query(ApplicationField)
        .filter(ApplicationField.template_id == row.template_id)
        .order_by(ApplicationField.position.asc(), ApplicationField.created_at.asc())
        .all()
    )
    _event(db, row.id, row.template_id, "viewed", metadata={"public": True})
    db.commit()
    return {
        "instance_id": row.id,
        "token": row.token,
        "status": row.status,
        "channel": row.channel,
        "template": {
            "id": template.id if template else row.template_id,
            "name": template.name if template else "Application",
            "description": template.description if template else "",
            "pricing_model": template.pricing_model if template else "subscription",
            "per_request_fee": template.per_request_fee if template else 0,
            "currency": template.currency if template else "USD",
            "fields": [_field_out(f) for f in fields],
        },
        "prefill": _safe_json(row.prefill_json, {}),
    }


def public_submit_by_token(db: Session, token: str, data: dict[str, Any], responder_user_id: str | None = None):
    row = db.query(ApplicationInstance).filter(ApplicationInstance.token == token).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Application link not found")
    responder = responder_user_id or row.target_user_id or row.requester_user_id or row.business_user_id
    response = ApplicationResponse(
        instance_id=row.id,
        responder_user_id=responder,
        data_json=json.dumps(data or {}, default=str),
        status="submitted",
    )
    row.status = "submitted"
    row.submitted_at = _now_iso()
    db.add(response)
    db.add(row)
    _event(db, row.id, row.template_id, "submitted", metadata={"public": True, "responder_user_id": responder})
    db.commit()
    db.refresh(response)
    return {
        "id": response.id,
        "instance_id": response.instance_id,
        "status": response.status,
        "created_at": _iso(response.created_at),
    }


def analytics_for_template(db: Session, user: User, template_id: str):
    template = db.query(ApplicationTemplate).filter(ApplicationTemplate.id == template_id).first()
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    if template.business_user_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this template")
    instances = db.query(ApplicationInstance).filter(ApplicationInstance.template_id == template.id).all()
    total = len(instances)
    submitted = len([i for i in instances if i.status in {"submitted", "completed"}])
    completion_rate = round((submitted / total), 4) if total else 0.0

    fields = db.query(ApplicationField).filter(ApplicationField.template_id == template.id).all()
    required_keys = [f.key for f in fields if f.required]
    responses = (
        db.query(ApplicationResponse)
        .join(ApplicationInstance, ApplicationInstance.id == ApplicationResponse.instance_id)
        .filter(ApplicationInstance.template_id == template.id)
        .all()
    )

    drop_counts: Counter[str] = Counter()
    autofill_hits = 0
    autofill_total_fields = 0
    for response in responses:
        data = _safe_json(response.data_json, {})
        meta = data.get("_meta", {}) if isinstance(data, dict) else {}
        for key in required_keys:
            if not (isinstance(data, dict) and data.get(key)):
                drop_counts[key] += 1
        autofill_hits += int(meta.get("autofilled_count", 0) or 0)
        autofill_total_fields += int(meta.get("total_fields", 0) or 0)

    events = db.query(ApplicationInstanceEvent).filter(ApplicationInstanceEvent.template_id == template.id).all()
    event_counts = Counter([e.event_type for e in events])
    autofill_success = round((autofill_hits / autofill_total_fields), 4) if autofill_total_fields else 0.0

    return {
        "template_id": template.id,
        "totals": {
            "requests_created": total,
            "responses_submitted": submitted,
            "completion_rate": completion_rate,
            "views": int(event_counts.get("viewed", 0)),
        },
        "dropoff_points": [{"field_key": key, "count": count} for key, count in drop_counts.most_common(10)],
        "autofill": {
            "success_rate": autofill_success,
            "autofilled_fields": autofill_hits,
            "total_fields_measured": autofill_total_fields,
        },
        "events": dict(event_counts),
    }


def auto_field_suggestions(db: Session, user: User, category: str | None = None, limit: int = 8):
    base = (
        db.query(ApplicationField, ApplicationTemplateMarket)
        .join(ApplicationTemplate, ApplicationTemplate.id == ApplicationField.template_id)
        .join(ApplicationTemplateMarket, ApplicationTemplateMarket.template_id == ApplicationTemplate.id)
        .filter(ApplicationTemplate.status == "active")
    )
    if category and category.lower() != "all":
        base = base.filter(func.lower(ApplicationTemplateMarket.category) == category.lower())
    samples = base.limit(400).all()

    weighted: dict[str, dict[str, Any]] = {}
    for field, market in samples:
        key = field.key
        weight = 2.0 if market.is_public else 1.0
        usage = max(int(market.usage_count or 0), 1)
        score = weight * (1 + min(usage, 50) / 50)
        entry = weighted.get(
            key,
            {
                "key": key,
                "label": field.label,
                "field_type": field.field_type,
                "source_type": field.source_type,
                "source_key": field.source_key,
                "required_weight": 0.0,
                "score": 0.0,
            },
        )
        entry["score"] += score
        if field.required:
            entry["required_weight"] += score
        weighted[key] = entry

    memory = db.query(UserMemory).filter(UserMemory.user_id == user.id).first()
    frequent_intents = _safe_json(memory.frequent_intents, {}) if memory else {}
    profile_type = (memory.profile_type if memory else "casual_user") or "casual_user"

    boost = 1.2 if profile_type in {"business_user", "creator"} else 1.0
    if float(frequent_intents.get("storage.save", 0)) > 0:
        boost += 0.1
    if float(frequent_intents.get("payment.send", 0)) > 0:
        boost += 0.1

    ranked = []
    for value in weighted.values():
        required_ratio = (value["required_weight"] / value["score"]) if value["score"] else 0
        confidence = min(0.99, round((0.35 + min(value["score"], 20) / 30 + required_ratio * 0.25) * boost, 4))
        ranked.append(
            {
                "key": value["key"],
                "label": value["label"],
                "field_type": value["field_type"],
                "source_type": value["source_type"],
                "source_key": value["source_key"],
                "required": required_ratio >= 0.5,
                "confidence": confidence,
                "reason": "template_pattern+learning",
            }
        )
    ranked.sort(key=lambda x: x["confidence"], reverse=True)
    return ranked[: max(1, min(limit, 20))]


def save_user_profile(db: Session, user: User, profile_name: str, fields: dict[str, Any], is_default: bool = False, source: str = "application_builder"):
    if is_default:
        db.query(ApplicationUserProfile).filter(ApplicationUserProfile.user_id == user.id).update({"is_default": False})
    row = ApplicationUserProfile(
        user_id=user.id,
        profile_name=profile_name.strip()[:120] or "Application Profile",
        fields_json=json.dumps(fields or {}, default=str),
        is_default=bool(is_default),
        source=source[:32] or "application_builder",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "profile_name": row.profile_name,
        "fields": _safe_json(row.fields_json, {}),
        "is_default": row.is_default,
        "source": row.source,
        "created_at": _iso(row.created_at),
    }


def list_user_profiles(db: Session, user: User):
    rows = (
        db.query(ApplicationUserProfile)
        .filter(ApplicationUserProfile.user_id == user.id)
        .order_by(ApplicationUserProfile.is_default.desc(), ApplicationUserProfile.updated_at.desc())
        .all()
    )
    return [
        {
            "id": row.id,
            "profile_name": row.profile_name,
            "fields": _safe_json(row.fields_json, {}),
            "is_default": row.is_default,
            "source": row.source,
            "created_at": _iso(row.created_at),
            "updated_at": _iso(row.updated_at),
        }
        for row in rows
    ]
