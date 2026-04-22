from __future__ import annotations

from datetime import timedelta
from typing import Any

from sqlalchemy.orm import Session

from backend.state import ApprovalRequest, FinanceAccount, FinanceTransaction, User, iso, json_dumps, json_loads, record_activity, top_categories, utcnow


def _account_map(accounts: list[FinanceAccount]) -> dict[str, FinanceAccount]:
    return {account.name.lower(): account for account in accounts}


def _serialize_transaction(transaction: FinanceTransaction) -> dict[str, Any]:
    signed_amount = float(transaction.amount) * (-1 if transaction.direction == "debit" else 1)
    return {
        "id": transaction.id,
        "accountId": transaction.account_id,
        "merchant": transaction.merchant,
        "category": transaction.category,
        "amount": round(signed_amount, 2),
        "direction": transaction.direction,
        "note": transaction.note or "",
        "occurredAt": iso(transaction.occurred_at),
    }


def get_balance(db: Session, user: User) -> dict[str, Any]:
    accounts = (
        db.query(FinanceAccount)
        .filter(FinanceAccount.user_id == user.id)
        .order_by(FinanceAccount.name.asc())
        .all()
    )
    total_balance = sum(float(account.balance) for account in accounts)
    return {
        "currency": "USD",
        "totalBalance": round(total_balance, 2),
        "accounts": [
            {
                "id": account.id,
                "name": account.name,
                "kind": account.kind,
                "balance": round(float(account.balance), 2),
                "currency": account.currency,
                "updatedAt": iso(account.updated_at),
            }
            for account in accounts
        ],
    }


def get_transactions(db: Session, user: User, days: int = 30, limit: int = 40) -> dict[str, Any]:
    cutoff = utcnow() - timedelta(days=max(days, 1))
    query = (
        db.query(FinanceTransaction)
        .filter(FinanceTransaction.user_id == user.id, FinanceTransaction.occurred_at >= cutoff)
        .order_by(FinanceTransaction.occurred_at.desc())
    )
    rows = query.limit(limit).all()
    return {
        "days": days,
        "transactions": [_serialize_transaction(row) for row in rows],
    }


def analyze_spending(db: Session, user: User, days: int = 7) -> dict[str, Any]:
    window_days = max(days, 1)
    current_cutoff = utcnow() - timedelta(days=window_days)
    previous_cutoff = utcnow() - timedelta(days=window_days * 2)

    current_rows = (
        db.query(FinanceTransaction)
        .filter(
            FinanceTransaction.user_id == user.id,
            FinanceTransaction.occurred_at >= current_cutoff,
        )
        .all()
    )
    previous_rows = (
        db.query(FinanceTransaction)
        .filter(
            FinanceTransaction.user_id == user.id,
            FinanceTransaction.occurred_at >= previous_cutoff,
            FinanceTransaction.occurred_at < current_cutoff,
        )
        .all()
    )

    current_spend = sum(float(row.amount) for row in current_rows if row.direction == "debit")
    previous_spend = sum(float(row.amount) for row in previous_rows if row.direction == "debit")
    delta = round(current_spend - previous_spend, 2)
    change = 0.0 if previous_spend == 0 else round((delta / previous_spend) * 100, 1)

    merchants: dict[str, float] = {}
    for row in current_rows:
        if row.direction == "debit":
            merchants[row.merchant] = merchants.get(row.merchant, 0.0) + float(row.amount)

    top_merchants = [
        {"merchant": merchant, "amount": round(amount, 2)}
        for merchant, amount in sorted(merchants.items(), key=lambda item: item[1], reverse=True)[:4]
    ]

    return {
        "periodDays": window_days,
        "spent": round(current_spend, 2),
        "previousSpent": round(previous_spend, 2),
        "delta": delta,
        "percentChange": change,
        "topCategories": top_categories(current_rows),
        "topMerchants": top_merchants,
        "transactionCount": len(current_rows),
    }


def simulate_purchase(
    db: Session,
    user: User,
    amount: float,
    merchant: str | None = None,
    source_account: str = "checking",
) -> dict[str, Any]:
    normalized = source_account.lower()
    accounts = (
        db.query(FinanceAccount)
        .filter(FinanceAccount.user_id == user.id)
        .all()
    )
    account_lookup = _account_map(accounts)
    account = account_lookup.get(normalized) or next(iter(account_lookup.values()))
    current_balance = float(account.balance)
    remainder = round(current_balance - amount, 2)
    return {
        "account": account.name,
        "merchant": merchant or "Purchase",
        "amount": round(amount, 2),
        "currentBalance": round(current_balance, 2),
        "remainingBalance": remainder,
        "canAfford": remainder >= 0,
        "message": (
            f"Yes. {account.name} would have ${remainder:,.2f} left."
            if remainder >= 0
            else f"No. {account.name} would be short by ${abs(remainder):,.2f}."
        ),
    }


def transfer_funds(
    db: Session,
    user: User,
    amount: float,
    source_account: str = "Checking",
    destination_account: str = "Savings",
    require_approval: bool = True,
) -> dict[str, Any]:
    accounts = (
        db.query(FinanceAccount)
        .filter(FinanceAccount.user_id == user.id)
        .all()
    )
    lookup = _account_map(accounts)
    source = lookup.get(source_account.lower())
    destination = lookup.get(destination_account.lower())
    if source is None or destination is None:
        raise ValueError("Source or destination account was not found.")

    preview = (
        f"Transfer ${amount:,.2f} from {source.name} to {destination.name}. "
        f"{source.name} would move from ${float(source.balance):,.2f} to ${float(source.balance) - amount:,.2f}."
    )

    if require_approval:
        approval = ApprovalRequest(
            user_id=user.id,
            domain="finance",
            title=f"Transfer ${amount:,.2f}",
            preview=preview,
            payload_json=json_dumps(
                {
                    "action": "transfer_funds",
                    "amount": amount,
                    "source": source.name,
                    "destination": destination.name,
                }
            ),
        )
        db.add(approval)
        record_activity(
            db,
            user.id,
            kind="approval",
            title="Finance transfer awaiting approval",
            detail=preview,
            status="pending",
            metadata={"approvalId": approval.id},
        )
        db.commit()
        db.refresh(approval)
        return {
            "status": "pending_approval",
            "approvalId": approval.id,
            "preview": approval.preview,
        }

    return execute_transfer(db, user, source.name, destination.name, amount)


def list_approvals(db: Session, user: User) -> dict[str, Any]:
    approvals = (
        db.query(ApprovalRequest)
        .filter(ApprovalRequest.user_id == user.id)
        .order_by(ApprovalRequest.created_at.desc())
        .all()
    )
    return {
        "approvals": [
            {
                "id": approval.id,
                "domain": approval.domain,
                "title": approval.title,
                "preview": approval.preview,
                "status": approval.status,
                "createdAt": iso(approval.created_at),
                "resolvedAt": iso(approval.resolved_at) if approval.resolved_at else None,
            }
            for approval in approvals
        ]
    }


def approve_transfer(db: Session, user: User, approval_id: str) -> dict[str, Any]:
    approval = (
        db.query(ApprovalRequest)
        .filter(
            ApprovalRequest.id == approval_id,
            ApprovalRequest.user_id == user.id,
            ApprovalRequest.domain == "finance",
        )
        .first()
    )
    if approval is None:
        raise ValueError("Approval request not found.")
    if approval.status != "pending":
        raise ValueError("Approval request is no longer pending.")

    payload = json_loads(approval.payload_json)
    if payload.get("action") != "transfer_funds":
        raise ValueError("Unsupported approval action.")

    result = execute_transfer(
        db,
        user,
        source_account=str(payload.get("source", "Checking")),
        destination_account=str(payload.get("destination", "Savings")),
        amount=float(payload.get("amount", 0)),
    )
    approval.status = "approved"
    approval.resolved_at = utcnow()
    db.add(approval)
    record_activity(
        db,
        user.id,
        kind="approval",
        title="Finance transfer approved",
        detail=approval.preview,
        status="approved",
        metadata={"approvalId": approval.id},
    )
    db.commit()
    return {
        "status": "approved",
        "approvalId": approval.id,
        "transfer": result,
    }


def execute_transfer(
    db: Session,
    user: User,
    source_account: str,
    destination_account: str,
    amount: float,
) -> dict[str, Any]:
    accounts = (
        db.query(FinanceAccount)
        .filter(FinanceAccount.user_id == user.id)
        .all()
    )
    lookup = _account_map(accounts)
    source = lookup.get(source_account.lower())
    destination = lookup.get(destination_account.lower())
    if source is None or destination is None:
        raise ValueError("Source or destination account was not found.")
    if float(source.balance) < amount:
        raise ValueError(f"Insufficient balance in {source.name}.")

    source.balance = round(float(source.balance) - amount, 2)
    destination.balance = round(float(destination.balance) + amount, 2)
    source.updated_at = utcnow()
    destination.updated_at = utcnow()

    debit = FinanceTransaction(
        user_id=user.id,
        account_id=source.id,
        merchant=f"Transfer to {destination.name}",
        category="transfer",
        amount=amount,
        direction="debit",
        note=f"Approved transfer into {destination.name}",
    )
    credit = FinanceTransaction(
        user_id=user.id,
        account_id=destination.id,
        merchant=f"Transfer from {source.name}",
        category="transfer",
        amount=amount,
        direction="credit",
        note=f"Approved transfer from {source.name}",
    )
    db.add_all([source, destination, debit, credit])
    record_activity(
        db,
        user.id,
        kind="finance",
        title="Funds transferred",
        detail=f"${amount:,.2f} moved from {source.name} to {destination.name}.",
        metadata={"source": source.name, "destination": destination.name, "amount": amount},
    )
    db.flush()
    return {
        "source": source.name,
        "destination": destination.name,
        "amount": round(amount, 2),
        "sourceBalance": round(float(source.balance), 2),
        "destinationBalance": round(float(destination.balance), 2),
    }
