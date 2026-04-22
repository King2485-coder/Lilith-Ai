from __future__ import annotations

import json

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.schemas.payment import (
    CreatorProductCreatePayload,
    FeeEstimatePayload,
    PaymentIntentConfirmPayload,
    PaymentIntentCreatePayload,
    PlanUpgradePayload,
    SelectTierPayload,
    ToolListingCreatePayload,
)
from backend.services.payments.fees import fee_rate
from backend.services.payments.monetization import (
    business_suite_status,
    create_creator_product,
    create_tool_listing,
    enable_business_suite,
    list_automation_plans,
    list_creator_products,
    list_storage_plans,
    list_tiers,
    list_tool_listings,
    monetization_overview,
    purchase_creator_product,
    purchase_tool_listing,
    select_tier,
    upgrade_automation_plan,
    upgrade_storage_plan,
)
from backend.services.payments.service import confirm_intent, create_intent, payment_balance, payment_history


router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("/create-intent")
async def payments_create_intent(payload: PaymentIntentCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    # Additional per-user guard on top of global middleware limits.
    allowed = await consume_rate_limit("payments.user.create", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Payment intent rate limit exceeded")
    row = create_intent(
        db,
        user,
        payload.receiver_id,
        payload.amount,
        payload.currency,
        payload.kind,
        payload.idempotency_key,
    )
    return {
        "id": row.id,
        "status": row.status,
        "amount": row.amount,
        "currency": row.currency,
        "receiver_id": row.receiver_id,
        "kind": row.kind,
        "created_at": row.created_at.isoformat(),
    }


@router.post("/confirm")
async def payments_confirm(payload: PaymentIntentConfirmPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("payments.user.confirm", f"user:{user.id}", limit=50, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Payment confirm rate limit exceeded")
    row = confirm_intent(db, user, payload.intent_id)
    return {"id": row.id, "status": row.status}


@router.get("/history")
def payments_history(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = payment_history(db, user)
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


@router.get("/balance")
def payments_balance(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = payment_balance(db, user)
    return {"fiat_balance": row.fiat_balance, "usdc_balance": row.usdc_balance}


@router.post("/fees/estimate")
def payments_fee_estimate(payload: FeeEstimatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rate = fee_rate(payload.kind)
    fee = round(float(payload.amount) * rate, 2)
    return {"amount": payload.amount, "kind": payload.kind, "fee_rate": rate, "fee_amount": fee, "net_amount": round(payload.amount - fee, 2)}


@router.get("/monetization/tiers")
def monetization_tiers(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_tiers(db)
    return {
        "tiers": [
            {
                "slug": row.slug,
                "name": row.name,
                "monthly_price": row.monthly_price,
                "currency": row.currency,
                "features": json.loads(row.features_json or "{}"),
            }
            for row in rows
        ]
    }


@router.post("/monetization/tier/select")
def monetization_tier_select(payload: SelectTierPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = select_tier(db, user, payload.tier_slug)
    return {"subscription_id": row.id, "status": row.status}


@router.get("/monetization/overview")
def monetization_overview_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return monetization_overview(db, user)


@router.post("/creator/products")
async def creator_products_create(payload: CreatorProductCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("payments.creator.products.create", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Creator product rate limit exceeded")
    row = create_creator_product(db, user, payload.title, payload.description, payload.price, payload.currency, payload.kind)
    return {"id": row.id, "title": row.title, "price": row.price, "currency": row.currency, "kind": row.kind}


@router.get("/creator/products")
def creator_products_list(creator_user_id: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_creator_products(db, creator_user_id)
    return {
        "items": [
            {
                "id": row.id,
                "creator_user_id": row.creator_user_id,
                "title": row.title,
                "description": row.description,
                "price": row.price,
                "currency": row.currency,
                "kind": row.kind,
                "status": row.status,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/creator/products/{product_id}/buy")
async def creator_products_buy(product_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("payments.creator.products.buy", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Creator purchase rate limit exceeded")
    row = purchase_creator_product(db, user, product_id)
    return {
        "sale_id": row.id,
        "product_id": row.product_id,
        "payment_intent_id": row.payment_intent_id,
        "gross_amount": row.gross_amount,
        "fee_amount": row.fee_amount,
        "net_amount": row.net_amount,
        "status": row.status,
    }


@router.post("/tools/listings")
async def tool_listing_create(payload: ToolListingCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("payments.tools.listing.create", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Tool listing rate limit exceeded")
    row = create_tool_listing(
        db,
        user,
        payload.tool_name,
        payload.title,
        payload.description,
        payload.pricing_model,
        payload.price,
        payload.currency,
    )
    return {"id": row.id, "tool_name": row.tool_name, "price": row.price, "pricing_model": row.pricing_model}


@router.get("/tools/listings")
def tool_listing_list(tool_name: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_tool_listings(db, tool_name)
    return {
        "items": [
            {
                "id": row.id,
                "creator_user_id": row.creator_user_id,
                "tool_name": row.tool_name,
                "title": row.title,
                "description": row.description,
                "pricing_model": row.pricing_model,
                "price": row.price,
                "currency": row.currency,
                "status": row.status,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/tools/listings/{listing_id}/buy")
async def tool_listing_buy(listing_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("payments.tools.listing.buy", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Tool purchase rate limit exceeded")
    row = purchase_tool_listing(db, user, listing_id)
    return {
        "purchase_id": row.id,
        "listing_id": row.listing_id,
        "payment_intent_id": row.payment_intent_id,
        "gross_amount": row.gross_amount,
        "fee_amount": row.fee_amount,
        "net_amount": row.net_amount,
        "status": row.status,
    }


@router.get("/storage/plans")
def storage_plan_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_storage_plans(db)
    return {
        "plans": [
            {
                "slug": row.slug,
                "name": row.name,
                "included_gb": row.included_gb,
                "monthly_price": row.monthly_price,
                "currency": row.currency,
            }
            for row in rows
        ]
    }


@router.post("/storage/upgrade")
def storage_plan_upgrade(payload: PlanUpgradePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = upgrade_storage_plan(db, user, payload.plan_slug)
    return {"subscription_id": row.id, "status": row.status}


@router.get("/automation/plans")
def automation_plan_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_automation_plans(db)
    return {
        "plans": [
            {
                "slug": row.slug,
                "name": row.name,
                "max_slots": row.max_slots,
                "monthly_price": row.monthly_price,
                "currency": row.currency,
            }
            for row in rows
        ]
    }


@router.post("/automation/upgrade")
def automation_plan_upgrade(payload: PlanUpgradePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = upgrade_automation_plan(db, user, payload.plan_slug)
    return {"subscription_id": row.id, "status": row.status, "used_slots": row.used_slots}


@router.get("/business-suite")
def business_suite_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = business_suite_status(db, user)
    return {
        "enabled": row.enabled,
        "crm_enabled": row.crm_enabled,
        "invoicing_enabled": row.invoicing_enabled,
        "payment_tools_enabled": row.payment_tools_enabled,
        "status": row.status,
    }


@router.post("/business-suite/enable")
def business_suite_enable(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = enable_business_suite(db, user)
    return {
        "enabled": row.enabled,
        "crm_enabled": row.crm_enabled,
        "invoicing_enabled": row.invoicing_enabled,
        "payment_tools_enabled": row.payment_tools_enabled,
        "status": row.status,
    }
