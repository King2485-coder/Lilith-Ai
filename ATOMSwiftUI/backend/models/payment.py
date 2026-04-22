from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class PaymentAccount(Base, TimestampMixin):
    __tablename__ = "payment_accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    fiat_balance: Mapped[float] = mapped_column(default=0.0)
    usdc_balance: Mapped[float] = mapped_column(default=0.0)


class PaymentIntent(Base, TimestampMixin):
    __tablename__ = "payment_intents"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sender_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    receiver_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    amount: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    status: Mapped[str] = mapped_column(String(24), default="created")
    kind: Mapped[str] = mapped_column(String(24), default="tip")
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class LedgerEntry(Base, TimestampMixin):
    __tablename__ = "ledger_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    payment_intent_id: Mapped[str] = mapped_column(String(36), ForeignKey("payment_intents.id"), index=True)
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("payment_accounts.id"), index=True)
    amount: Mapped[float] = mapped_column(default=0.0)
    direction: Mapped[str] = mapped_column(String(12))


class SubscriptionPlan(Base, TimestampMixin):
    __tablename__ = "subscription_plans"
    # Scaffold for recurring billing integration (Stripe/stablecoin subscriptions in future phase).
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    creator_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    amount: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")


class MonetizationTier(Base, TimestampMixin):
    __tablename__ = "monetization_tiers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    monthly_price: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    features_json: Mapped[str] = mapped_column(Text, default="{}")
    active: Mapped[bool] = mapped_column(default=True)


class UserTierSubscription(Base, TimestampMixin):
    __tablename__ = "user_tier_subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    tier_id: Mapped[str] = mapped_column(String(36), ForeignKey("monetization_tiers.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="active")
    auto_renew: Mapped[bool] = mapped_column(default=True)


class PaymentFeeRecord(Base, TimestampMixin):
    __tablename__ = "payment_fee_records"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    payment_intent_id: Mapped[str] = mapped_column(String(36), ForeignKey("payment_intents.id"), index=True, unique=True)
    kind: Mapped[str] = mapped_column(String(40), default="peer")
    fee_rate: Mapped[float] = mapped_column(default=0.0)
    fee_amount: Mapped[float] = mapped_column(default=0.0)
    net_amount: Mapped[float] = mapped_column(default=0.0)


class CreatorProduct(Base, TimestampMixin):
    __tablename__ = "creator_products"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    creator_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    kind: Mapped[str] = mapped_column(String(32), default="digital_product")
    status: Mapped[str] = mapped_column(String(24), default="active")
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class CreatorSale(Base, TimestampMixin):
    __tablename__ = "creator_sales"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    product_id: Mapped[str] = mapped_column(String(36), ForeignKey("creator_products.id"), index=True)
    buyer_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    payment_intent_id: Mapped[str] = mapped_column(String(36), ForeignKey("payment_intents.id"), index=True)
    gross_amount: Mapped[float] = mapped_column(default=0.0)
    fee_amount: Mapped[float] = mapped_column(default=0.0)
    net_amount: Mapped[float] = mapped_column(default=0.0)
    status: Mapped[str] = mapped_column(String(24), default="completed")


class ToolMarketplaceListing(Base, TimestampMixin):
    __tablename__ = "tool_marketplace_listings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    creator_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    tool_name: Mapped[str] = mapped_column(String(120), index=True)
    title: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    pricing_model: Mapped[str] = mapped_column(String(24), default="per_use")
    price: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    status: Mapped[str] = mapped_column(String(24), default="active")


class ToolMarketplacePurchase(Base, TimestampMixin):
    __tablename__ = "tool_marketplace_purchases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    listing_id: Mapped[str] = mapped_column(String(36), ForeignKey("tool_marketplace_listings.id"), index=True)
    buyer_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    payment_intent_id: Mapped[str] = mapped_column(String(36), ForeignKey("payment_intents.id"), index=True)
    gross_amount: Mapped[float] = mapped_column(default=0.0)
    fee_amount: Mapped[float] = mapped_column(default=0.0)
    net_amount: Mapped[float] = mapped_column(default=0.0)
    status: Mapped[str] = mapped_column(String(24), default="completed")


class StoragePlan(Base, TimestampMixin):
    __tablename__ = "storage_plans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    included_gb: Mapped[int] = mapped_column(default=5)
    monthly_price: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    active: Mapped[bool] = mapped_column(default=True)


class UserStorageSubscription(Base, TimestampMixin):
    __tablename__ = "user_storage_subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    storage_plan_id: Mapped[str] = mapped_column(String(36), ForeignKey("storage_plans.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="active")


class AutomationPlan(Base, TimestampMixin):
    __tablename__ = "automation_plans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    max_slots: Mapped[int] = mapped_column(default=1)
    monthly_price: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    active: Mapped[bool] = mapped_column(default=True)


class UserAutomationSubscription(Base, TimestampMixin):
    __tablename__ = "user_automation_subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    automation_plan_id: Mapped[str] = mapped_column(String(36), ForeignKey("automation_plans.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="active")
    used_slots: Mapped[int] = mapped_column(default=0)


class BusinessSuiteAccount(Base, TimestampMixin):
    __tablename__ = "business_suite_accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    enabled: Mapped[bool] = mapped_column(default=False)
    crm_enabled: Mapped[bool] = mapped_column(default=False)
    invoicing_enabled: Mapped[bool] = mapped_column(default=False)
    payment_tools_enabled: Mapped[bool] = mapped_column(default=False)
    status: Mapped[str] = mapped_column(String(24), default="inactive")
