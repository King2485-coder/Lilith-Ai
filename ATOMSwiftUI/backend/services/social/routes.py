from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.services.social.service import (
    accountability_feed,
    create_checkin,
    create_shared_goal,
    get_privacy,
    leaderboard,
    live_engagement,
    list_friends,
    list_shared_goals,
    request_friend,
    respond_friend,
    respond_shared_goal,
    send_accountability_nudge,
    set_privacy,
    social_overview,
)


router = APIRouter(prefix="/social", tags=["social"])


class FriendRequestPayload(BaseModel):
    username: str


class FriendResponsePayload(BaseModel):
    connection_id: str
    decision: str


class SharedGoalPayload(BaseModel):
    title: str
    description: str = ""
    daily_target: float = Field(default=0.0, ge=0)
    member_usernames: list[str] = []


class SharedGoalResponsePayload(BaseModel):
    decision: str


class CheckinPayload(BaseModel):
    note: str = ""
    progress_amount: float = Field(default=0.0, ge=0)


class SocialPrivacyPatch(BaseModel):
    share_presence: bool | None = None
    share_earnings: bool | None = None
    allow_nudges: bool | None = None


class NudgePayload(BaseModel):
    to_user_id: str
    goal_id: str
    message: str = ""


@router.get("/overview")
def social_overview_route(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return social_overview(db, user)


@router.get("/live-engagement")
def social_live_engagement_route(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return live_engagement(db, user)


@router.get("/friends")
def social_friends_route(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_friends(db, user)


@router.post("/friends/request")
async def social_friend_request(payload: FriendRequestPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.friends.request", f"user:{user.id}", limit=40, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Friend request rate limit exceeded")
    return request_friend(db, user, payload.username)


@router.post("/friends/respond")
async def social_friend_respond(payload: FriendResponsePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.friends.respond", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Friend response rate limit exceeded")
    return respond_friend(db, user, payload.connection_id, payload.decision)


@router.get("/goals")
def social_goals_route(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return list_shared_goals(db, user)


@router.post("/goals")
async def social_goal_create(payload: SharedGoalPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.goals.create", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Shared goal creation rate limit exceeded")
    return create_shared_goal(db, user, payload.title, payload.description, payload.daily_target, payload.member_usernames)


@router.post("/goals/{goal_id}/respond")
async def social_goal_respond(goal_id: str, payload: SharedGoalResponsePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.goals.respond", f"user:{user.id}", limit=60, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Shared goal response rate limit exceeded")
    return respond_shared_goal(db, user, goal_id, payload.decision)


@router.post("/goals/{goal_id}/checkin")
async def social_goal_checkin(goal_id: str, payload: CheckinPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.goals.checkin", f"user:{user.id}", limit=100, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Check-in rate limit exceeded")
    return create_checkin(db, user, goal_id, payload.note, payload.progress_amount)


@router.get("/leaderboard")
def social_leaderboard_route(
    scope: str = Query(default="friends"),
    days: int = Query(default=7, ge=1, le=30),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    normalized = scope.strip().lower()
    if normalized not in {"friends", "global"}:
        normalized = "friends"
    return leaderboard(db, user, normalized, days)


@router.get("/accountability")
def social_accountability_route(
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    return accountability_feed(db, user, limit)


@router.get("/privacy")
def social_privacy_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return get_privacy(db, user)


@router.patch("/privacy")
async def social_privacy_patch(payload: SocialPrivacyPatch, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.privacy.patch", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Social privacy update rate limit exceeded")
    return set_privacy(db, user, payload.model_dump(exclude_none=True))


@router.post("/nudges/send")
async def social_nudge_send(payload: NudgePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("social.nudge.send", f"user:{user.id}", limit=30, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Nudge rate limit exceeded")
    return send_accountability_nudge(db, user, payload.to_user_id, payload.goal_id, payload.message)
