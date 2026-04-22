from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.reputation.service import (
    business_trust_signals,
    dashboard,
    record_event,
    set_visibility,
    social_reputation,
    soft_recovery,
)


router = APIRouter(prefix="/reputation", tags=["reputation"])


class ReputationEventPayload(BaseModel):
    event_type: str
    completed: bool = True
    consistency_points: float = Field(default=1.0, ge=0)
    misses: int = Field(default=0, ge=0)


class ReputationVisibilityPayload(BaseModel):
    social_visibility: str


@router.get("/dashboard")
def reputation_dashboard(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return dashboard(db, user)


@router.post("/events")
async def reputation_record_event(payload: ReputationEventPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("reputation.events.record", f"user:{user.id}", limit=120, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Reputation event rate limit exceeded")
    return record_event(
        db=db,
        user=user,
        event_type=payload.event_type,
        completed=payload.completed,
        consistency_points=payload.consistency_points,
        misses=payload.misses,
    )


@router.patch("/visibility")
async def reputation_set_visibility(payload: ReputationVisibilityPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("reputation.visibility.patch", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Reputation visibility update rate limit exceeded")
    return set_visibility(db, user, payload.social_visibility)


@router.post("/recovery")
async def reputation_recovery(db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("reputation.recovery.start", f"user:{user.id}", limit=20, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Recovery mode rate limit exceeded")
    return soft_recovery(db, user)


@router.get("/social")
def reputation_social(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return social_reputation(db, user)


@router.get("/business-trust")
def reputation_business_trust(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return business_trust_signals(db, user)
