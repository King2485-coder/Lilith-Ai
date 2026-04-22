from __future__ import annotations

import json
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.models.payment import PaymentAccount, PaymentIntent
from backend.models.user import User
from backend.services.notifications.service import create_notification
from backend.services.payments.fees import register_fee_record
from backend.services.payments.ledger import apply_transfer


def _ensure_account(db: Session, user_id: str) -> PaymentAccount:
    row = db.query(PaymentAccount).filter(PaymentAccount.user_id == user_id).first()
    if row is None:
        row = PaymentAccount(user_id=user_id, fiat_balance=0.0, usdc_balance=0.0)
        db.add(row)
        db.flush()
    return row


def _fraud_risk_check(db: Session, sender: User, amount: float, currency: str) -> None:
    if amount > 5000:
        raise HTTPException(status_code=403, detail="Transaction blocked by fraud policy")
    since = datetime.utcnow() - timedelta(minutes=10)
    recent = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.sender_id == sender.id, PaymentIntent.created_at >= since)
        .count()
    )
    if recent >= 20:
        raise HTTPException(status_code=429, detail="Too many payment attempts")
    if currency.upper() not in {"USD", "USDC"}:
        raise HTTPException(status_code=400, detail="Unsupported currency")


def _assert_ledger_sane(
    intent: PaymentIntent,
    sender_account: PaymentAccount,
    receiver_account: PaymentAccount,
    before_sender: float,
    before_receiver: float,
    fee_amount: float = 0.0,
) -> None:
    amount = float(intent.amount)
    net_amount = round(amount - float(fee_amount), 6)
    if intent.currency.upper() == "USDC":
        after_sender = float(sender_account.usdc_balance)
        after_receiver = float(receiver_account.usdc_balance)
    else:
        after_sender = float(sender_account.fiat_balance)
        after_receiver = float(receiver_account.fiat_balance)
    if after_sender < 0 or after_receiver < 0:
        raise HTTPException(status_code=500, detail="Ledger integrity check failed: negative balance")
    delta_before = round(before_sender + before_receiver, 6)
    delta_after = round(after_sender + after_receiver, 6)
    expected_after = round(delta_before - float(fee_amount), 6)
    if delta_after != expected_after:
        raise HTTPException(
            status_code=500,
            detail=f"Ledger integrity check failed: expected delta {expected_after}, got {delta_after}",
        )
    if round((before_receiver + net_amount), 6) != round(after_receiver, 6):
        raise HTTPException(status_code=500, detail="Ledger integrity check failed: receiver net mismatch")


def create_intent(
    db: Session,
    sender: User,
    receiver_id: str,
    amount: float,
    currency: str,
    kind: str,
    idempotency_key: str | None = None,
) -> PaymentIntent:
    if sender.id == receiver_id:
        raise HTTPException(status_code=400, detail="Cannot pay yourself")
    _fraud_risk_check(db, sender, float(amount), currency)
    if idempotency_key:
        previous = (
            db.query(PaymentIntent)
            .filter(
                PaymentIntent.sender_id == sender.id,
                PaymentIntent.metadata_json.like(f"%\"idempotencyKey\": \"{idempotency_key}\"%"),
            )
            .order_by(PaymentIntent.created_at.desc())
            .first()
        )
        if previous is not None:
            return previous
    receiver = db.query(User).filter(User.id == receiver_id).first()
    if receiver is None:
        raise HTTPException(status_code=404, detail="Receiver not found")
    intent = PaymentIntent(
        sender_id=sender.id,
        receiver_id=receiver_id,
        amount=round(float(amount), 2),
        currency=currency.upper(),
        status="created",
        kind=kind,
        metadata_json=json.dumps({"kind": kind, "idempotencyKey": idempotency_key}),
    )
    db.add(intent)
    db.commit()
    db.refresh(intent)
    return intent


def confirm_intent(db: Session, sender: User, intent_id: str) -> PaymentIntent:
    intent = db.query(PaymentIntent).filter(PaymentIntent.id == intent_id, PaymentIntent.sender_id == sender.id).first()
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    if intent.status == "confirmed":
        return intent
    sender_account = _ensure_account(db, sender.id)
    receiver_account = _ensure_account(db, intent.receiver_id)
    amount = float(intent.amount)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid payment amount")
    if intent.status == "flagged":
        raise HTTPException(status_code=403, detail="Payment is flagged for review")
    fee_record = register_fee_record(db, intent)
    fee_amount = float(fee_record.fee_amount)
    net_amount = round(amount - fee_amount, 2)
    if net_amount <= 0:
        raise HTTPException(status_code=400, detail="Payment net amount must be positive")
    before_sender = float(sender_account.usdc_balance if intent.currency.upper() == "USDC" else sender_account.fiat_balance)
    before_receiver = float(receiver_account.usdc_balance if intent.currency.upper() == "USDC" else receiver_account.fiat_balance)
    if intent.currency.upper() == "USDC":
        if sender_account.usdc_balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient USDC balance")
    else:
        if sender_account.fiat_balance < amount:
            raise HTTPException(status_code=400, detail="Insufficient fiat balance")
    apply_transfer(db, intent, sender_account, receiver_account, fee_amount=fee_amount)
    _assert_ledger_sane(intent, sender_account, receiver_account, before_sender, before_receiver, fee_amount=fee_amount)
    intent.status = "confirmed"
    db.add(intent)
    create_notification(
        db,
        sender.id,
        "payment",
        "Payment sent",
        f"{amount:.2f} {intent.currency} sent ({fee_amount:.2f} fee).",
    )
    create_notification(
        db,
        intent.receiver_id,
        "payment",
        "Payment received",
        f"{net_amount:.2f} {intent.currency} received.",
    )
    db.commit()
    db.refresh(intent)
    return intent


def payment_history(db: Session, user: User) -> list[PaymentIntent]:
    return (
        db.query(PaymentIntent)
        .filter(or_(PaymentIntent.sender_id == user.id, PaymentIntent.receiver_id == user.id))
        .order_by(PaymentIntent.created_at.desc())
        .all()
    )


def payment_balance(db: Session, user: User) -> PaymentAccount:
    account = _ensure_account(db, user.id)
    db.commit()
    db.refresh(account)
    return account
