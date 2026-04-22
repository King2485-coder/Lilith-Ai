from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.income_engine.service import (
    auto_optimize_recommendations,
    coach_active_guidance,
    coach_end_of_day_review,
    coach_morning_brief,
    coach_record_event,
    coach_weekly,
    complete_lesson,
    dashboard,
    draft_proposal,
    get_tone_mode,
    list_actions,
    list_audit_logs,
    list_opportunities,
    profile_out,
    schedule_followup,
    start_action,
    set_tone_mode,
    unified_loop_advance,
    unified_loop_overview,
    update_action_status,
    update_profile,
    ensure_profile,
    skills_dashboard,
)


router = APIRouter(prefix="/income-engine", tags=["income-engine"])


class IncomeProfilePatch(BaseModel):
    daily_target: float | None = Field(default=None, ge=10)
    monthly_target: float | None = Field(default=None, ge=300)
    skills: list[str] | None = None
    location: str | None = None
    availability_hours_per_day: float | None = Field(default=None, ge=0.5, le=16)
    preferred_categories: list[str] | None = None
    risk_mode: str | None = None


class StartActionPayload(BaseModel):
    opportunity_id: str
    confirm: bool = False
    autofill_profile: dict[str, Any] | None = None


class UpdateActionPayload(BaseModel):
    status: str
    actual_payout: float | None = Field(default=None, ge=0)


class FollowupPayload(BaseModel):
    hours_until_followup: int = Field(default=24, ge=1, le=168)


class LessonCompletePayload(BaseModel):
    lesson_id: str


class UnifiedLoopAdvancePayload(BaseModel):
    action_type: str
    ref_id: str = ""
    confirm: bool = False


class CoachEventPayload(BaseModel):
    event_type: str
    payload: dict[str, Any] = {}


class CoachTonePayload(BaseModel):
    tone_mode: str


@router.get("/dashboard")
def income_dashboard(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return dashboard(db, user)


@router.get("/profile")
def income_profile_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = ensure_profile(db, user)
    db.commit()
    return profile_out(row)


@router.patch("/profile")
async def income_profile_patch(payload: IncomeProfilePatch, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.profile.patch", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Income profile update rate limit exceeded")
    patch = payload.model_dump(exclude_none=True)
    return update_profile(db, user, patch)


@router.get("/opportunities")
def income_opportunities(
    category: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    return list_opportunities(db, user, category=category, limit=limit)


@router.get("/skills/dashboard")
def income_skills_dashboard(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return skills_dashboard(db, user)


@router.post("/skills/lessons/complete")
async def income_complete_lesson(payload: LessonCompletePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.skills.lesson.complete", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Lesson completion rate limit exceeded")
    return complete_lesson(db, user, payload.lesson_id)


@router.get("/optimize")
def income_optimize(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return auto_optimize_recommendations(db, user)


@router.get("/coach/morning-brief")
def income_coach_morning(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return coach_morning_brief(db, user)


@router.get("/coach/active-guidance")
def income_coach_active(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return coach_active_guidance(db, user)


@router.post("/coach/event")
async def income_coach_event(payload: CoachEventPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.coach.event", f"user:{user.id}", limit=120, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Coach event rate limit exceeded")
    return coach_record_event(db, user, payload.event_type, payload.payload)


@router.get("/coach/tone")
def income_coach_tone_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return get_tone_mode(db, user)


@router.patch("/coach/tone")
async def income_coach_tone_patch(payload: CoachTonePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.coach.tone", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Coach tone update rate limit exceeded")
    return set_tone_mode(db, user, payload.tone_mode)


@router.get("/coach/end-of-day")
def income_coach_end_day(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return coach_end_of_day_review(db, user)


@router.get("/coach/weekly")
def income_coach_weekly(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return coach_weekly(db, user)


@router.get("/unified-loop")
def income_unified_loop(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return unified_loop_overview(db, user)


@router.post("/unified-loop/advance")
async def income_unified_loop_advance(payload: UnifiedLoopAdvancePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.unified_loop.advance", f"user:{user.id}", limit=80, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Unified loop advance rate limit exceeded")
    return unified_loop_advance(db, user, payload.action_type, payload.ref_id, payload.confirm)


@router.post("/actions/start")
async def income_start_action(payload: StartActionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.action.start", f"user:{user.id}", limit=80, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Income action rate limit exceeded")
    return start_action(
        db=db,
        user=user,
        opportunity_id=payload.opportunity_id,
        confirm=payload.confirm,
        autofill_profile=payload.autofill_profile,
    )


@router.get("/actions")
def income_actions(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_actions(db, user)


@router.post("/actions/{action_id}/status")
async def income_action_status(action_id: str, payload: UpdateActionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.action.status", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Income status update rate limit exceeded")
    return update_action_status(db, user, action_id, payload.status, payload.actual_payout)


@router.post("/actions/{action_id}/draft-proposal")
async def income_draft_proposal(action_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.action.proposal", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Proposal drafting rate limit exceeded")
    return draft_proposal(db, user, action_id)


@router.post("/actions/{action_id}/schedule-followup")
async def income_schedule_followup(action_id: str, payload: FollowupPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("income_engine.action.followup", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Follow-up scheduling rate limit exceeded")
    return schedule_followup(db, user, action_id, payload.hours_until_followup)


@router.get("/audit")
def income_audit(limit: int = Query(default=200, ge=1, le=500), db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_audit_logs(db, user, limit)
