from __future__ import annotations

import hashlib
import hmac
import json
import os
from dataclasses import dataclass
from typing import Any

from sqlalchemy import desc
from sqlalchemy.orm import Session

from backend.platform.models import (
    Dispute,
    LedgerAccount,
    LedgerEntry,
    MonetizationEligibility,
    PaymentAttempt,
    PaymentCustomer,
    PaymentEvent,
    PaymentIntent,
    PaymentMethod,
    Refund,
    Report,
    RiskReview,
    WebhookEvent,
)
from backend.state import User, new_id, utcnow


SUPPORTED_STABLECOIN = "usdc"
SUPPORTED_NETWORKS = {"base", "ethereum", "solana"}


@dataclass
class RiskDecision:
    score: float
    decision: str
    reasons: list[str]


class NeuroCloudTrust:
    """
    NeuroCloud-backed trust abstraction.
    This wraps secret access and policy checks server-side only.
    """

    def __init__(self) -> None:
        self._global_secret = os.getenv("NEUROCLOUD_SIGNING_SECRET", "dev-neurocloud-signing-secret")
        self._passkey_required_for_amount = float(os.getenv("PASSKEY_STEP_UP_MIN_AMOUNT", "250"))

    def get_secret(self, key: str, default: str = "") -> str:
        env_key = f"NEUROCLOUD_{key.upper()}"
        return os.getenv(env_key, default)

    def webhook_secret(self, provider: str) -> str:
        return self.get_secret(f"webhook_{provider}_secret", self._global_secret)

    def sign_payload(self, payload: str, secret: str | None = None) -> str:
        key = (secret or self._global_secret).encode("utf-8")
        return hmac.new(key, payload.encode("utf-8"), hashlib.sha256).hexdigest()

    def verify_signature(self, payload: str, signature: str, secret: str) -> bool:
        expected = self.sign_payload(payload, secret=secret)
        return hmac.compare_digest(expected, signature or "")

    def requires_step_up(self, amount: float, intent_type: str) -> bool:
        if intent_type in {"payout", "refund"}:
            return True
        return amount >= self._passkey_required_for_amount

    def verify_passkey_assertion(self, assertion: str | None, challenge_id: str | None = None) -> bool:
        # Hook point for full WebAuthn verification service.
        if not assertion:
            return False
        if len(assertion.strip()) < 20:
            return False
        if challenge_id and len(challenge_id.strip()) < 8:
            return False
        return True


trust = NeuroCloudTrust()


def ensure_payment_customer(db: Session, user: User) -> PaymentCustomer:
    row = db.query(PaymentCustomer).filter(PaymentCustomer.user_id == user.id).first()
    if row:
        return row
    row = PaymentCustomer(
        user_id=user.id,
        provider_customer_id=f"cust_{new_id()}",
        metadata_json=json.dumps({"createdBy": "lilith_pay"}),
    )
    db.add(row)
    db.flush()
    return row


def set_default_payment_method(db: Session, customer: PaymentCustomer, method: PaymentMethod) -> None:
    rows = db.query(PaymentMethod).filter(PaymentMethod.customer_id == customer.id).all()
    for row in rows:
        row.is_default = row.id == method.id
        row.updated_at = utcnow()
        db.add(row)
    customer.default_payment_method_id = method.id
    customer.updated_at = utcnow()
    db.add(customer)


def upsert_payment_method(
    db: Session,
    user: User,
    method_type: str,
    provider: str,
    provider_payment_method_id: str | None,
    last4: str | None,
    brand: str | None,
    exp_month: int | None,
    exp_year: int | None,
    billing_name: str | None,
    billing_email: str | None,
    encrypted_reference: str | None,
    make_default: bool,
    metadata: dict[str, Any] | None = None,
) -> PaymentMethod:
    customer = ensure_payment_customer(db, user)
    row = None
    if provider_payment_method_id:
        row = (
            db.query(PaymentMethod)
            .filter(
                PaymentMethod.customer_id == customer.id,
                PaymentMethod.provider == provider,
                PaymentMethod.provider_payment_method_id == provider_payment_method_id,
            )
            .first()
        )
    if row is None:
        row = PaymentMethod(
            customer_id=customer.id,
            method_type=method_type,
            provider=provider,
            provider_payment_method_id=provider_payment_method_id,
            last4=last4,
            brand=brand,
            exp_month=exp_month,
            exp_year=exp_year,
            billing_name=billing_name,
            billing_email=billing_email,
            encrypted_reference=encrypted_reference,
            metadata_json=json.dumps(metadata or {}, default=str),
            is_default=False,
        )
    else:
        row.method_type = method_type
        row.last4 = last4
        row.brand = brand
        row.exp_month = exp_month
        row.exp_year = exp_year
        row.billing_name = billing_name
        row.billing_email = billing_email
        row.encrypted_reference = encrypted_reference
        row.metadata_json = json.dumps(metadata or {}, default=str)
        row.updated_at = utcnow()
    db.add(row)
    db.flush()
    if make_default:
        set_default_payment_method(db, customer, row)
    return row


def get_or_create_ledger_account(db: Session, user_id: int | None, account_type: str, currency: str) -> LedgerAccount:
    row = (
        db.query(LedgerAccount)
        .filter(
            LedgerAccount.user_id == user_id,
            LedgerAccount.account_type == account_type,
            LedgerAccount.currency == currency.upper(),
        )
        .first()
    )
    if row:
        return row
    row = LedgerAccount(
        user_id=user_id,
        account_type=account_type,
        currency=currency.upper(),
        status="active",
        metadata_json=json.dumps({"createdBy": "lilith_pay"}),
    )
    db.add(row)
    db.flush()
    return row


def _latest_event_hash(db: Session) -> str | None:
    row = db.query(PaymentEvent).order_by(desc(PaymentEvent.created_at)).first()
    return row.event_hash if row else None


def record_payment_event(
    db: Session,
    user_id: int | None,
    event_type: str,
    object_type: str,
    object_id: str,
    payload: dict[str, Any] | None = None,
    idempotency_key: str | None = None,
) -> PaymentEvent:
    payload_obj = payload or {}
    payload_str = json.dumps(payload_obj, sort_keys=True, default=str)
    prev_hash = _latest_event_hash(db)
    hash_source = f"{prev_hash or ''}|{event_type}|{object_type}|{object_id}|{payload_str}|{utcnow().isoformat()}"
    event_hash = trust.sign_payload(hash_source)
    row = PaymentEvent(
        user_id=user_id,
        event_type=event_type,
        object_type=object_type,
        object_id=object_id,
        idempotency_key=idempotency_key,
        payload_json=payload_str,
        prev_hash=prev_hash,
        event_hash=event_hash,
    )
    db.add(row)
    db.flush()
    return row


def create_ledger_transfer(
    db: Session,
    from_account: LedgerAccount,
    to_account: LedgerAccount,
    amount: float,
    currency: str,
    reference_type: str,
    reference_id: str,
    event_id: str | None,
    description: str,
    metadata: dict[str, Any] | None = None,
) -> tuple[LedgerEntry, LedgerEntry]:
    meta = json.dumps(metadata or {}, default=str)
    debit = LedgerEntry(
        account_id=from_account.id,
        related_account_id=to_account.id,
        event_id=event_id,
        direction="debit",
        amount=amount,
        currency=currency.upper(),
        reference_type=reference_type,
        reference_id=reference_id,
        description=description,
        metadata_json=meta,
    )
    credit = LedgerEntry(
        account_id=to_account.id,
        related_account_id=from_account.id,
        event_id=event_id,
        direction="credit",
        amount=amount,
        currency=currency.upper(),
        reference_type=reference_type,
        reference_id=reference_id,
        description=description,
        metadata_json=meta,
    )
    db.add(debit)
    db.add(credit)
    db.flush()
    return debit, credit


def evaluate_risk(db: Session, user_id: int, amount: float, intent_type: str) -> RiskDecision:
    reasons: list[str] = []
    score = 0.0

    recent_reports = (
        db.query(Report)
        .filter(Report.reporter_user_id == user_id)
        .order_by(desc(Report.created_at))
        .limit(50)
        .count()
    )
    recent_refunds = db.query(Refund).filter(Refund.user_id == user_id).order_by(desc(Refund.created_at)).limit(100).count()
    recent_disputes = db.query(Dispute).filter(Dispute.user_id == user_id).order_by(desc(Dispute.created_at)).limit(100).count()

    score += min(amount / 250.0, 6.0)
    score += min(recent_refunds * 0.75, 4.0)
    score += min(recent_disputes * 1.2, 5.0)
    score += min(recent_reports * 0.15, 2.5)

    if amount >= 1000:
        reasons.append("high_amount")
    if recent_refunds >= 3:
        reasons.append("refund_pattern")
    if recent_disputes >= 2:
        reasons.append("dispute_pattern")
    if intent_type in {"payout", "refund"}:
        reasons.append("sensitive_action")
        score += 1.0

    if score >= 8.0:
        decision = "deny"
    elif score >= 4.5:
        decision = "review"
    else:
        decision = "allow"
    return RiskDecision(score=round(score, 2), decision=decision, reasons=reasons)


def save_risk_review(
    db: Session,
    user_id: int,
    action_type: str,
    score: float,
    decision: str,
    reasons: list[str],
    payment_intent_id: str | None = None,
) -> RiskReview:
    review = RiskReview(
        user_id=user_id,
        payment_intent_id=payment_intent_id,
        action_type=action_type,
        score=score,
        decision=decision,
        reasons_json=json.dumps(reasons, default=str),
    )
    db.add(review)
    db.flush()
    return review


def update_monetization_eligibility(db: Session, user_id: int) -> MonetizationEligibility:
    report_count = db.query(Report).filter(Report.target_type == "user", Report.target_id == str(user_id)).count()
    refund_total = db.query(Refund).filter(Refund.user_id == user_id).count()
    dispute_total = db.query(Dispute).filter(Dispute.user_id == user_id).count()
    verification_score = 1.0
    report_rate = min(report_count / 20.0, 1.0)
    refund_rate = min(refund_total / 20.0, 1.0)
    dispute_rate = min(dispute_total / 20.0, 1.0)
    fraud_score = min((report_rate * 0.4) + (refund_rate * 0.3) + (dispute_rate * 0.3), 1.0)
    status = "active"
    reason = None
    if fraud_score >= 0.65:
        status = "review"
        reason = "risk_threshold_exceeded"
    if fraud_score >= 0.85:
        status = "suspended"
        reason = "high_risk_profile"

    row = db.query(MonetizationEligibility).filter(MonetizationEligibility.user_id == user_id).first()
    if row is None:
        row = MonetizationEligibility(user_id=user_id)
    row.status = status
    row.verification_score = verification_score
    row.report_rate = report_rate
    row.refund_rate = refund_rate
    row.dispute_rate = dispute_rate
    row.fraud_score = fraud_score
    row.reason = reason
    row.updated_at = utcnow()
    db.add(row)
    db.flush()
    return row


def verify_and_store_webhook(
    db: Session,
    provider: str,
    event_id: str,
    event_type: str,
    signature: str,
    payload: dict[str, Any],
) -> WebhookEvent:
    existing = db.query(WebhookEvent).filter(WebhookEvent.provider == provider, WebhookEvent.event_id == event_id).first()
    if existing:
        return existing
    payload_json = json.dumps(payload or {}, sort_keys=True, default=str)
    verified = trust.verify_signature(payload_json, signature, trust.webhook_secret(provider))
    row = WebhookEvent(
        provider=provider,
        event_id=event_id,
        event_type=event_type,
        signature=signature,
        payload_json=payload_json,
        verified=verified,
        processed=False,
    )
    db.add(row)
    db.flush()
    return row

