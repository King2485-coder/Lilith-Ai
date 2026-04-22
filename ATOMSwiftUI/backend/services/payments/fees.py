from __future__ import annotations

from sqlalchemy.orm import Session

from backend.models.payment import PaymentFeeRecord, PaymentIntent


def fee_rate(kind: str) -> float:
    normalized = (kind or "").strip().lower()
    if normalized in {"tip", "peer", "peer_payment"}:
        return 0.0
    if normalized in {"business_payment", "invoice", "invoice_payment"}:
        return 0.029
    if normalized in {"creator_tip", "creator_subscription", "creator_sale"}:
        return 0.05
    if normalized in {"tool_purchase", "tool_subscription"}:
        return 0.1
    return 0.01


def register_fee_record(db: Session, intent: PaymentIntent) -> PaymentFeeRecord:
    existing = db.query(PaymentFeeRecord).filter(PaymentFeeRecord.payment_intent_id == intent.id).first()
    if existing is not None:
        return existing
    rate = fee_rate(intent.kind)
    fee = round(float(intent.amount) * rate, 2)
    net = round(float(intent.amount) - fee, 2)
    row = PaymentFeeRecord(
        payment_intent_id=intent.id,
        kind=intent.kind,
        fee_rate=rate,
        fee_amount=fee,
        net_amount=net,
    )
    db.add(row)
    db.flush()
    return row
