from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, model_validator


class PaymentIntentCreatePayload(BaseModel):
    receiver_id: str
    amount: float = Field(gt=0)
    currency: str = "USD"
    kind: str = "tip"
    idempotency_key: str | None = None


class PaymentIntentConfirmPayload(BaseModel):
    intent_id: str | None = None
    payment_intent_id: str | None = None

    @model_validator(mode="after")
    def validate_ids(self):
        if not self.intent_id and self.payment_intent_id:
            self.intent_id = self.payment_intent_id
        if not self.intent_id:
            raise ValueError("intent_id is required")
        return self


class PaymentIntentOut(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    amount: float
    currency: str
    status: str
    kind: str
    created_at: datetime

    class Config:
        from_attributes = True


class PaymentBalanceOut(BaseModel):
    fiat_balance: float
    usdc_balance: float


class SelectTierPayload(BaseModel):
    tier_slug: str


class CreatorProductCreatePayload(BaseModel):
    title: str
    description: str = ""
    price: float = Field(ge=0)
    currency: str = "USD"
    kind: str = "digital_product"


class ToolListingCreatePayload(BaseModel):
    tool_name: str
    title: str
    description: str = ""
    pricing_model: str = "per_use"
    price: float = Field(ge=0)
    currency: str = "USD"


class PlanUpgradePayload(BaseModel):
    plan_slug: str


class MonetizationTierOut(BaseModel):
    slug: str
    name: str
    monthly_price: float
    currency: str
    features: dict[str, Any]


class FeeEstimatePayload(BaseModel):
    amount: float = Field(gt=0)
    kind: str = "tip"
