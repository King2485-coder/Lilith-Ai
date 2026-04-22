from __future__ import annotations

import json

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.models.payment import (
    AutomationPlan,
    BusinessSuiteAccount,
    CreatorProduct,
    CreatorSale,
    MonetizationTier,
    StoragePlan,
    ToolMarketplaceListing,
    ToolMarketplacePurchase,
    UserAutomationSubscription,
    UserStorageSubscription,
    UserTierSubscription,
)
from backend.models.user import User
from backend.services.payments.service import confirm_intent, create_intent
from backend.services.payments.fees import register_fee_record


DEFAULT_TIERS = [
    {
        "slug": "free",
        "name": "Free",
        "monthly_price": 0.0,
        "features": {"ai_messages": 120, "storage_gb": 5, "automation_slots": 1, "business_suite": False},
    },
    {
        "slug": "pro",
        "name": "Pro",
        "monthly_price": 12.0,
        "features": {"ai_messages": 1200, "storage_gb": 100, "automation_slots": 8, "business_suite": False},
    },
    {
        "slug": "power",
        "name": "Power / Business",
        "monthly_price": 39.0,
        "features": {"ai_messages": 9000, "storage_gb": 1024, "automation_slots": 40, "business_suite": True},
    },
]

DEFAULT_STORAGE_PLANS = [
    {"slug": "storage_free", "name": "Storage Free", "included_gb": 5, "monthly_price": 0.0},
    {"slug": "storage_plus", "name": "Storage Plus", "included_gb": 100, "monthly_price": 4.0},
    {"slug": "storage_max", "name": "Storage Max", "included_gb": 1024, "monthly_price": 14.0},
]

DEFAULT_AUTOMATION_PLANS = [
    {"slug": "automation_free", "name": "Automation Free", "max_slots": 1, "monthly_price": 0.0},
    {"slug": "automation_pro", "name": "Automation Pro", "max_slots": 10, "monthly_price": 6.0},
    {"slug": "automation_business", "name": "Automation Business", "max_slots": 100, "monthly_price": 20.0},
]

def ensure_default_catalog(db: Session) -> None:
    changed = False
    for row in DEFAULT_TIERS:
        existing = db.query(MonetizationTier).filter(MonetizationTier.slug == row["slug"]).first()
        if existing is None:
            db.add(
                MonetizationTier(
                    slug=row["slug"],
                    name=row["name"],
                    monthly_price=float(row["monthly_price"]),
                    currency="USD",
                    features_json=json.dumps(row["features"], default=str),
                    active=True,
                )
            )
            changed = True
    for row in DEFAULT_STORAGE_PLANS:
        existing = db.query(StoragePlan).filter(StoragePlan.slug == row["slug"]).first()
        if existing is None:
            db.add(
                StoragePlan(
                    slug=row["slug"],
                    name=row["name"],
                    included_gb=int(row["included_gb"]),
                    monthly_price=float(row["monthly_price"]),
                    currency="USD",
                    active=True,
                )
            )
            changed = True
    for row in DEFAULT_AUTOMATION_PLANS:
        existing = db.query(AutomationPlan).filter(AutomationPlan.slug == row["slug"]).first()
        if existing is None:
            db.add(
                AutomationPlan(
                    slug=row["slug"],
                    name=row["name"],
                    max_slots=int(row["max_slots"]),
                    monthly_price=float(row["monthly_price"]),
                    currency="USD",
                    active=True,
                )
            )
            changed = True
    if changed:
        db.commit()


def list_tiers(db: Session) -> list[MonetizationTier]:
    ensure_default_catalog(db)
    return db.query(MonetizationTier).filter(MonetizationTier.active == True).order_by(MonetizationTier.monthly_price.asc()).all()  # noqa: E712


def select_tier(db: Session, user: User, tier_slug: str) -> UserTierSubscription:
    ensure_default_catalog(db)
    tier = db.query(MonetizationTier).filter(MonetizationTier.slug == tier_slug, MonetizationTier.active == True).first()  # noqa: E712
    if tier is None:
        raise HTTPException(status_code=404, detail="Tier not found")
    sub = db.query(UserTierSubscription).filter(UserTierSubscription.user_id == user.id).first()
    if sub is None:
        sub = UserTierSubscription(user_id=user.id, tier_id=tier.id, status="active", auto_renew=True)
    else:
        sub.tier_id = tier.id
        sub.status = "active"
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub


def current_tier(db: Session, user: User) -> MonetizationTier:
    ensure_default_catalog(db)
    sub = db.query(UserTierSubscription).filter(UserTierSubscription.user_id == user.id, UserTierSubscription.status == "active").first()
    if sub is None:
        return db.query(MonetizationTier).filter(MonetizationTier.slug == "free").first()
    tier = db.query(MonetizationTier).filter(MonetizationTier.id == sub.tier_id).first()
    if tier is None:
        return db.query(MonetizationTier).filter(MonetizationTier.slug == "free").first()
    return tier


def monetization_overview(db: Session, user: User) -> dict:
    tier = current_tier(db, user)
    storage_sub = db.query(UserStorageSubscription).filter(UserStorageSubscription.user_id == user.id, UserStorageSubscription.status == "active").first()
    automation_sub = (
        db.query(UserAutomationSubscription)
        .filter(UserAutomationSubscription.user_id == user.id, UserAutomationSubscription.status == "active")
        .first()
    )
    business = db.query(BusinessSuiteAccount).filter(BusinessSuiteAccount.user_id == user.id).first()
    if business is None:
        business = BusinessSuiteAccount(user_id=user.id, enabled=False, crm_enabled=False, invoicing_enabled=False, payment_tools_enabled=False, status="inactive")
        db.add(business)
        db.commit()
        db.refresh(business)
    tier_features = json.loads(tier.features_json or "{}")
    storage_plan = db.query(StoragePlan).filter(StoragePlan.id == storage_sub.storage_plan_id).first() if storage_sub else None
    automation_plan = db.query(AutomationPlan).filter(AutomationPlan.id == automation_sub.automation_plan_id).first() if automation_sub else None
    return {
        "tier": {"slug": tier.slug, "name": tier.name, "monthly_price": tier.monthly_price, "features": tier_features},
        "storage": {
            "plan": storage_plan.slug if storage_plan else "storage_free",
            "included_gb": storage_plan.included_gb if storage_plan else 5,
        },
        "automation": {
            "plan": automation_plan.slug if automation_plan else "automation_free",
            "max_slots": automation_plan.max_slots if automation_plan else 1,
            "used_slots": automation_sub.used_slots if automation_sub else 0,
        },
        "business_suite": {
            "enabled": business.enabled,
            "crm_enabled": business.crm_enabled,
            "invoicing_enabled": business.invoicing_enabled,
            "payment_tools_enabled": business.payment_tools_enabled,
            "status": business.status,
        },
    }


def list_storage_plans(db: Session) -> list[StoragePlan]:
    ensure_default_catalog(db)
    return db.query(StoragePlan).filter(StoragePlan.active == True).order_by(StoragePlan.monthly_price.asc()).all()  # noqa: E712


def upgrade_storage_plan(db: Session, user: User, plan_slug: str) -> UserStorageSubscription:
    ensure_default_catalog(db)
    plan = db.query(StoragePlan).filter(StoragePlan.slug == plan_slug, StoragePlan.active == True).first()  # noqa: E712
    if plan is None:
        raise HTTPException(status_code=404, detail="Storage plan not found")
    sub = db.query(UserStorageSubscription).filter(UserStorageSubscription.user_id == user.id).first()
    if sub is None:
        sub = UserStorageSubscription(user_id=user.id, storage_plan_id=plan.id, status="active")
    else:
        sub.storage_plan_id = plan.id
        sub.status = "active"
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub


def list_automation_plans(db: Session) -> list[AutomationPlan]:
    ensure_default_catalog(db)
    return db.query(AutomationPlan).filter(AutomationPlan.active == True).order_by(AutomationPlan.monthly_price.asc()).all()  # noqa: E712


def upgrade_automation_plan(db: Session, user: User, plan_slug: str) -> UserAutomationSubscription:
    ensure_default_catalog(db)
    plan = db.query(AutomationPlan).filter(AutomationPlan.slug == plan_slug, AutomationPlan.active == True).first()  # noqa: E712
    if plan is None:
        raise HTTPException(status_code=404, detail="Automation plan not found")
    sub = db.query(UserAutomationSubscription).filter(UserAutomationSubscription.user_id == user.id).first()
    if sub is None:
        sub = UserAutomationSubscription(user_id=user.id, automation_plan_id=plan.id, status="active", used_slots=0)
    else:
        sub.automation_plan_id = plan.id
        sub.status = "active"
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub


def business_suite_status(db: Session, user: User) -> BusinessSuiteAccount:
    row = db.query(BusinessSuiteAccount).filter(BusinessSuiteAccount.user_id == user.id).first()
    if row is None:
        row = BusinessSuiteAccount(user_id=user.id, enabled=False, crm_enabled=False, invoicing_enabled=False, payment_tools_enabled=False, status="inactive")
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


def enable_business_suite(db: Session, user: User) -> BusinessSuiteAccount:
    row = business_suite_status(db, user)
    row.enabled = True
    row.crm_enabled = True
    row.invoicing_enabled = True
    row.payment_tools_enabled = True
    row.status = "active"
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def create_creator_product(db: Session, user: User, title: str, description: str, price: float, currency: str, kind: str = "digital_product") -> CreatorProduct:
    row = CreatorProduct(
        creator_user_id=user.id,
        title=title.strip()[:160],
        description=description.strip()[:2000],
        price=round(float(price), 2),
        currency=currency.upper(),
        kind=kind[:32],
        status="active",
        metadata_json="{}",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_creator_products(db: Session, creator_user_id: str | None = None) -> list[CreatorProduct]:
    query = db.query(CreatorProduct).filter(CreatorProduct.status == "active")
    if creator_user_id:
        query = query.filter(CreatorProduct.creator_user_id == creator_user_id)
    return query.order_by(CreatorProduct.created_at.desc()).all()


def purchase_creator_product(db: Session, buyer: User, product_id: str, payment_method: str | None = None) -> CreatorSale:
    product = db.query(CreatorProduct).filter(CreatorProduct.id == product_id, CreatorProduct.status == "active").first()
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.creator_user_id == buyer.id:
        raise HTTPException(status_code=400, detail="Cannot buy your own product")
    intent = create_intent(
        db,
        buyer,
        product.creator_user_id,
        product.price,
        product.currency,
        "creator_sale",
        idempotency_key=f"creator:{product.id}:{buyer.id}",
    )
    confirm_intent(db, buyer, intent.id)
    fee = db.query(PaymentFeeRecord).filter(PaymentFeeRecord.payment_intent_id == intent.id).first()
    fee_amount = float(fee.fee_amount) if fee else 0.0
    net = round(float(intent.amount) - fee_amount, 2)
    sale = CreatorSale(
        product_id=product.id,
        buyer_user_id=buyer.id,
        payment_intent_id=intent.id,
        gross_amount=float(intent.amount),
        fee_amount=fee_amount,
        net_amount=net,
        status="completed",
    )
    db.add(sale)
    db.commit()
    db.refresh(sale)
    return sale


def create_tool_listing(
    db: Session,
    user: User,
    tool_name: str,
    title: str,
    description: str,
    pricing_model: str,
    price: float,
    currency: str,
) -> ToolMarketplaceListing:
    row = ToolMarketplaceListing(
        creator_user_id=user.id,
        tool_name=tool_name.strip()[:120],
        title=title.strip()[:160],
        description=description.strip()[:2000],
        pricing_model=pricing_model.strip()[:24] or "per_use",
        price=round(float(price), 2),
        currency=currency.upper(),
        status="active",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_tool_listings(db: Session, tool_name: str | None = None) -> list[ToolMarketplaceListing]:
    query = db.query(ToolMarketplaceListing).filter(ToolMarketplaceListing.status == "active")
    if tool_name:
        query = query.filter(ToolMarketplaceListing.tool_name == tool_name)
    return query.order_by(ToolMarketplaceListing.created_at.desc()).all()


def purchase_tool_listing(db: Session, buyer: User, listing_id: str) -> ToolMarketplacePurchase:
    listing = db.query(ToolMarketplaceListing).filter(ToolMarketplaceListing.id == listing_id, ToolMarketplaceListing.status == "active").first()
    if listing is None:
        raise HTTPException(status_code=404, detail="Tool listing not found")
    if listing.creator_user_id == buyer.id:
        raise HTTPException(status_code=400, detail="Cannot buy your own listing")
    intent = create_intent(
        db,
        buyer,
        listing.creator_user_id,
        listing.price,
        listing.currency,
        "tool_purchase",
        idempotency_key=f"tool:{listing.id}:{buyer.id}",
    )
    confirm_intent(db, buyer, intent.id)
    fee = db.query(PaymentFeeRecord).filter(PaymentFeeRecord.payment_intent_id == intent.id).first()
    fee_amount = float(fee.fee_amount) if fee else 0.0
    net = round(float(intent.amount) - fee_amount, 2)
    row = ToolMarketplacePurchase(
        listing_id=listing.id,
        buyer_user_id=buyer.id,
        payment_intent_id=intent.id,
        gross_amount=float(intent.amount),
        fee_amount=fee_amount,
        net_amount=net,
        status="completed",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row

