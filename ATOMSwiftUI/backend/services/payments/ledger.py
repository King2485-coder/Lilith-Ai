from __future__ import annotations

from sqlalchemy.orm import Session

from backend.models.payment import LedgerEntry, PaymentAccount, PaymentIntent


def apply_transfer(
    db: Session,
    intent: PaymentIntent,
    sender_account: PaymentAccount,
    receiver_account: PaymentAccount,
    fee_amount: float = 0.0,
) -> None:
    amount = float(intent.amount)
    net_amount = max(round(amount - float(fee_amount), 2), 0.0)
    if intent.currency.upper() == "USDC":
        sender_account.usdc_balance -= amount
        receiver_account.usdc_balance += net_amount
    else:
        sender_account.fiat_balance -= amount
        receiver_account.fiat_balance += net_amount

    db.add(
        LedgerEntry(
            payment_intent_id=intent.id,
            account_id=sender_account.id,
            amount=amount,
            direction="debit",
        )
    )
    db.add(
        LedgerEntry(
            payment_intent_id=intent.id,
            account_id=receiver_account.id,
            amount=net_amount,
            direction="credit",
        )
    )
    if fee_amount > 0:
        db.add(
            LedgerEntry(
                payment_intent_id=intent.id,
                account_id=sender_account.id,
                amount=float(fee_amount),
                direction="fee",
            )
        )
