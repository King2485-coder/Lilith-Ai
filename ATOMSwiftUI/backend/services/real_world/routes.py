from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.real_world.service import (
    apply_to_job,
    connect_connector,
    create_pipeline,
    dashboard,
    draft_proposal,
    execute_pipeline,
    income_summary,
    jobs_search,
    list_applications,
    list_connectors,
    list_pipelines,
    prepare_transfer_preview,
    record_income,
    suggest_allocation,
)


router = APIRouter(prefix="/real-world", tags=["real-world"])


class ConnectorPayload(BaseModel):
    connector_type: str
    provider: str = ""
    scopes: list[str] = []
    credential_ref: str = ""
    metadata: dict[str, Any] = {}


class ApplyPayload(BaseModel):
    opportunity_id: str
    confirm_submit: bool = False
    use_autofill: bool = True
    proposal_text: str = ""


class IncomePayload(BaseModel):
    source_type: str
    amount: float = Field(gt=0)
    currency: str = "USD"
    metadata: dict[str, Any] = {}


class TransferPreviewPayload(BaseModel):
    amount: float = Field(gt=0)
    destination: str = "savings"
    reason: str = ""


class PipelineCreatePayload(BaseModel):
    action_type: str
    steps: list[dict[str, Any]]
    context: dict[str, Any] = {}
    auto_execute: bool = False


class PipelineExecutePayload(BaseModel):
    approve_sensitive: bool = False


@router.get("/dashboard")
def real_world_dashboard(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return dashboard(db, user)


@router.get("/connectors")
def real_world_connectors(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_connectors(db, user)


@router.post("/connectors")
async def real_world_connect(payload: ConnectorPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.connectors.connect", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Connector link rate limit exceeded")
    return connect_connector(
        db=db,
        user=user,
        connector_type=payload.connector_type,
        provider=payload.provider,
        scopes=payload.scopes,
        credential_ref=payload.credential_ref,
        metadata=payload.metadata,
    )


@router.get("/jobs/search")
def real_world_jobs_search(
    query: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    return jobs_search(db, user, query=query, category=category, limit=limit)


@router.post("/jobs/proposal")
async def real_world_draft_proposal(opportunity_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.jobs.proposal", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Proposal draft rate limit exceeded")
    return draft_proposal(db, user, opportunity_id)


@router.post("/jobs/apply")
async def real_world_apply(payload: ApplyPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.jobs.apply", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Job apply rate limit exceeded")
    return apply_to_job(
        db=db,
        user=user,
        opportunity_id=payload.opportunity_id,
        confirm_submit=payload.confirm_submit,
        use_autofill=payload.use_autofill,
        proposal_text=payload.proposal_text,
    )


@router.get("/jobs/applications")
def real_world_applications(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_applications(db, user)


@router.post("/payments/income")
async def real_world_record_income(payload: IncomePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.payments.income", f"user:{user.id}", limit=80, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Income record rate limit exceeded")
    return record_income(db, user, payload.source_type, payload.amount, payload.currency, payload.metadata)


@router.get("/payments/income-summary")
def real_world_income_summary(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return income_summary(db, user)


@router.get("/payments/allocation")
def real_world_allocation(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return suggest_allocation(db, user)


@router.post("/payments/transfer/prepare")
async def real_world_prepare_transfer(payload: TransferPreviewPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.payments.transfer.prepare", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Transfer preview rate limit exceeded")
    return prepare_transfer_preview(db, user, payload.amount, payload.destination, payload.reason)


@router.get("/pipelines")
def real_world_pipelines(limit: int = Query(default=40, ge=1, le=200), db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_pipelines(db, user, limit)


@router.post("/pipelines")
async def real_world_create_pipeline(payload: PipelineCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("real_world.pipeline.create", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Pipeline creation rate limit exceeded")
    return create_pipeline(
        db=db,
        user=user,
        action_type=payload.action_type,
        steps=payload.steps,
        context=payload.context,
        auto_execute=payload.auto_execute,
    )


@router.post("/pipelines/{pipeline_id}/execute")
async def real_world_execute_pipeline(
    pipeline_id: str,
    payload: PipelineExecutePayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    allowed = await consume_rate_limit("real_world.pipeline.execute", f"user:{user.id}", limit=50, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Pipeline execution rate limit exceeded")
    return execute_pipeline(db, user, pipeline_id, payload.approve_sensitive)
