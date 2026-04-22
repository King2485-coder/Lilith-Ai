from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.first100.service import record_event, record_feedback, record_session_insight, session_summary, upsert_daily_checkin


router = APIRouter(prefix="/first100", tags=["first100"])


class EventPayload(BaseModel):
    event_type: str
    screen: str = ""
    session_id: str = ""
    payload: dict[str, Any] = {}


class FeedbackPayload(BaseModel):
    session_id: str = ""
    command: str = ""
    sentiment: str = Field(pattern="^(up|down)$")
    reason: str = ""
    context: dict[str, Any] = {}


class SessionInsightPayload(BaseModel):
    session_id: str = ""
    screen: str = ""
    insight_type: str = Field(pattern="^(hesitation|inactivity|confusion)$")
    seconds: int = Field(ge=0, le=7200)
    detail: dict[str, Any] = {}


class DailyCheckinPayload(BaseModel):
    response: str = Field(pattern="^(smooth|confused|stuck)$")
    note: str = ""


@router.post("/events")
async def first100_events(payload: EventPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("first100.events", f"user:{user.id}", limit=240, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Event tracking rate limit exceeded")
    return record_event(db, user, payload.event_type, payload.screen, payload.session_id, payload.payload)


@router.post("/feedback")
async def first100_feedback(payload: FeedbackPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("first100.feedback", f"user:{user.id}", limit=120, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Feedback rate limit exceeded")
    return record_feedback(
        db=db,
        user=user,
        session_id=payload.session_id,
        command=payload.command,
        sentiment=payload.sentiment,
        reason=payload.reason,
        context=payload.context,
    )


@router.post("/session-insight")
async def first100_session_insight(payload: SessionInsightPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("first100.session_insight", f"user:{user.id}", limit=120, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Session insight rate limit exceeded")
    return record_session_insight(
        db=db,
        user=user,
        session_id=payload.session_id,
        screen=payload.screen,
        insight_type=payload.insight_type,
        seconds=payload.seconds,
        detail=payload.detail,
    )


@router.post("/daily-checkin")
async def first100_daily_checkin(payload: DailyCheckinPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("first100.daily_checkin", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Daily check-in rate limit exceeded")
    return upsert_daily_checkin(db, user, payload.response, payload.note)


@router.get("/summary")
def first100_summary(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return session_summary(db, user)
