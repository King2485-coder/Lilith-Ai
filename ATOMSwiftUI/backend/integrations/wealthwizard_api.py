from __future__ import annotations

from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from backend.integrations.wealthwizard_adapter import analyze_spending, approve_transfer, get_balance, get_transactions, list_approvals, simulate_purchase, transfer_funds


def register_finance_routes(app, get_db, get_current_user_dep) -> None:
    @app.get("/api/finance/balance")
    def finance_balance(
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        return get_balance(db, current_user)

    @app.get("/api/finance/transactions")
    def finance_transactions(
        days: int = 30,
        limit: int = 40,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        return get_transactions(db, current_user, days=days, limit=limit)

    @app.get("/api/finance/analyze")
    def finance_analyze(
        days: int = 7,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        return analyze_spending(db, current_user, days=days)

    @app.post("/api/finance/simulate")
    async def finance_simulate(
        request: Request,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        body = await _safe_json(request)
        amount = float(body.get("amount", 0))
        merchant = body.get("merchant")
        source_account = body.get("sourceAccount", "checking")
        return simulate_purchase(db, current_user, amount=amount, merchant=merchant, source_account=source_account)

    @app.post("/api/finance/transfer")
    async def finance_transfer(
        request: Request,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        body = await _safe_json(request)
        amount = float(body.get("amount", 0))
        source = str(body.get("sourceAccount", "Checking"))
        destination = str(body.get("destinationAccount", "Savings"))
        if amount <= 0:
            raise HTTPException(status_code=400, detail="Transfer amount must be greater than zero.")
        try:
            return transfer_funds(db, current_user, amount=amount, source_account=source, destination_account=destination, require_approval=True)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    @app.get("/api/finance/approvals")
    def finance_approvals(
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        return list_approvals(db, current_user)

    @app.post("/api/finance/approvals/{approval_id}/approve")
    def finance_approve(
        approval_id: str,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user_dep),
    ):
        try:
            return approve_transfer(db, current_user, approval_id)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error


async def _safe_json(request: Request) -> dict:
    try:
        return await request.json()
    except Exception:
        return {}
