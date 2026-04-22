from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from backend.models.reputation import ReputationAuditLog, ReputationBadge, ReputationDailyEvent, ReputationProfile
from backend.models.social import FriendConnection
from backend.models.user import User
from backend.services.notifications.service import create_notification


def _now():
    return datetime.utcnow()


def _date_key(value: datetime | None = None):
    base = value or _now()
    return base.date().isoformat()


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _iso(value):
    return value.isoformat() if value else None


def _audit(db: Session, user_id: str, event_type: str, detail: dict[str, Any] | None = None):
    db.add(
        ReputationAuditLog(
            user_id=user_id,
            event_type=event_type[:64],
            detail_json=json.dumps(detail or {}, default=str),
        )
    )
    db.flush()


def ensure_profile(db: Session, user: User):
    row = db.query(ReputationProfile).filter(ReputationProfile.user_id == user.id).first()
    if row is None:
        row = ReputationProfile(
            user_id=user.id,
            work_ethic_score=50.0,
            consistency_days=0,
            active_days_30=0,
            inactive_days_30=30,
            recovery_mode=False,
            social_visibility="friends",
            business_trust_score=50.0,
            reliability_notes_json=json.dumps(
                {
                    "status": "starting",
                    "strengths": [],
                    "gaps": [],
                    "recovery_tip": "Complete one action today to establish momentum.",
                }
            ),
            last_active_at=None,
        )
        db.add(row)
        db.flush()
    return row


def _get_today_event(db: Session, user_id: str):
    key = _date_key()
    row = (
        db.query(ReputationDailyEvent)
        .filter(ReputationDailyEvent.user_id == user_id, ReputationDailyEvent.date_key == key)
        .first()
    )
    if row is None:
        row = ReputationDailyEvent(
            user_id=user_id,
            date_key=key,
            completion_count=0,
            consistency_points=0.0,
            misses=0,
        )
        db.add(row)
        db.flush()
    return row


def _friend_ids(db: Session, user_id: str):
    rows = (
        db.query(FriendConnection)
        .filter(
            FriendConnection.status == "accepted",
            or_(FriendConnection.requester_id == user_id, FriendConnection.addressee_id == user_id),
        )
        .all()
    )
    ids: set[str] = set()
    for row in rows:
        ids.add(row.requester_id if row.requester_id != user_id else row.addressee_id)
    return ids


def _calc_streak(db: Session, user_id: str):
    rows = (
        db.query(ReputationDailyEvent)
        .filter(ReputationDailyEvent.user_id == user_id)
        .order_by(ReputationDailyEvent.date_key.desc())
        .limit(90)
        .all()
    )
    by_day = {row.date_key: row for row in rows}
    cursor = _now().date()
    streak = 0
    while True:
        key = cursor.isoformat()
        event = by_day.get(key)
        if event and float(event.consistency_points) > 0:
            streak += 1
            cursor = cursor - timedelta(days=1)
            continue
        break
    return streak


def _recompute(db: Session, profile: ReputationProfile):
    horizon_key = (_now() - timedelta(days=30)).date().isoformat()
    rows = (
        db.query(ReputationDailyEvent)
        .filter(
            and_(
                ReputationDailyEvent.user_id == profile.user_id,
                ReputationDailyEvent.date_key >= horizon_key,
            )
        )
        .all()
    )
    active_days = sum(1 for row in rows if (row.completion_count > 0 or float(row.consistency_points) > 0))
    inactive_days = max(0, 30 - active_days)
    completion_total = sum(max(0, int(row.completion_count)) for row in rows)
    misses_total = sum(max(0, int(row.misses)) for row in rows)
    completion_ratio = completion_total / max(1, completion_total + misses_total)
    streak = _calc_streak(db, profile.user_id)

    consistency_component = min(40.0, active_days * 1.2)
    streak_component = min(25.0, streak * 1.3)
    completion_component = min(20.0, completion_ratio * 20.0)
    inactivity_penalty = min(20.0, inactive_days * 0.45)
    score = max(0.0, min(100.0, round(25.0 + consistency_component + streak_component + completion_component - inactivity_penalty, 1)))

    trust_completion = completion_ratio * 50.0
    trust_streak = min(30.0, streak * 1.1)
    trust_consistency = min(20.0, active_days * 0.6)
    business_trust = max(0.0, min(100.0, round(trust_completion + trust_streak + trust_consistency, 1)))

    profile.active_days_30 = active_days
    profile.inactive_days_30 = inactive_days
    profile.consistency_days = streak
    profile.work_ethic_score = score
    profile.business_trust_score = business_trust
    profile.recovery_mode = score < 45.0
    profile.reliability_notes_json = json.dumps(
        {
            "status": "steady" if score >= 70 else ("recovering" if score < 45 else "building"),
            "strengths": ["consistency"] if streak >= 5 else [],
            "gaps": ["inactive_days"] if inactive_days > 10 else [],
            "completion_ratio": round(completion_ratio, 3),
            "recovery_tip": "Complete one quick action today and one tomorrow to rebuild momentum.",
        },
        default=str,
    )
    db.add(profile)
    db.flush()


def _ensure_badge(db: Session, user_id: str, code: str, title: str, description: str):
    existing = db.query(ReputationBadge).filter(ReputationBadge.user_id == user_id, ReputationBadge.code == code).first()
    if existing is not None:
        return False
    db.add(
        ReputationBadge(
            user_id=user_id,
            code=code[:64],
            title=title[:120],
            description=description[:400],
            visible=True,
        )
    )
    db.flush()
    return True


def _award_badges(db: Session, user: User, profile: ReputationProfile):
    granted = []
    if profile.consistency_days >= 3 and _ensure_badge(
        db,
        user.id,
        "streak_starter",
        "Consistency Starter",
        "Showed up three days in a row.",
    ):
        granted.append("Consistency Starter")
    if profile.consistency_days >= 14 and _ensure_badge(
        db,
        user.id,
        "habit_stable_14",
        "Stable for 14",
        "Maintained a two-week consistency streak.",
    ):
        granted.append("Stable for 14")
    if profile.work_ethic_score >= 80 and _ensure_badge(
        db,
        user.id,
        "work_ethic_80",
        "High Reliability",
        "Sustained a high work ethic score.",
    ):
        granted.append("High Reliability")
    if profile.business_trust_score >= 75 and _ensure_badge(
        db,
        user.id,
        "biz_trust_75",
        "Business Trusted",
        "Built reliability signals that businesses can trust.",
    ):
        granted.append("Business Trusted")

    for title in granted:
        create_notification(
            db,
            user.id,
            kind="reputation.badge_earned",
            title=f"Badge earned: {title}",
            body="Your consistency and reliability are compounding.",
        )


def _profile_out(profile: ReputationProfile):
    return {
        "work_ethic_score": round(float(profile.work_ethic_score), 1),
        "consistency_days": int(profile.consistency_days or 0),
        "active_days_30": int(profile.active_days_30 or 0),
        "inactive_days_30": int(profile.inactive_days_30 or 0),
        "recovery_mode": bool(profile.recovery_mode),
        "social_visibility": profile.social_visibility,
        "business_trust_score": round(float(profile.business_trust_score), 1),
        "reliability_notes": _safe_json(profile.reliability_notes_json, {}),
        "last_active_at": _iso(profile.last_active_at),
        "updated_at": _iso(profile.updated_at),
    }


def dashboard(db: Session, user: User):
    profile = ensure_profile(db, user)
    _recompute(db, profile)
    badges = (
        db.query(ReputationBadge)
        .filter(ReputationBadge.user_id == user.id, ReputationBadge.visible == True)  # noqa: E712
        .order_by(ReputationBadge.earned_at.desc())
        .limit(12)
        .all()
    )
    recent = (
        db.query(ReputationDailyEvent)
        .filter(ReputationDailyEvent.user_id == user.id)
        .order_by(ReputationDailyEvent.date_key.desc())
        .limit(14)
        .all()
    )
    db.commit()
    return {
        "profile": _profile_out(profile),
        "badges": [
            {
                "id": row.id,
                "code": row.code,
                "title": row.title,
                "description": row.description,
                "earned_at": _iso(row.earned_at),
            }
            for row in badges
        ],
        "consistency_timeline": [
            {
                "date": row.date_key,
                "completion_count": int(row.completion_count or 0),
                "consistency_points": round(float(row.consistency_points or 0), 2),
                "misses": int(row.misses or 0),
            }
            for row in recent
        ],
    }


def record_event(db: Session, user: User, event_type: str, completed: bool, consistency_points: float, misses: int):
    profile = ensure_profile(db, user)
    today = _get_today_event(db, user.id)
    points = max(0.0, round(float(consistency_points), 2))
    if completed:
        today.completion_count = int(today.completion_count or 0) + 1
        today.consistency_points = round(float(today.consistency_points or 0) + max(0.5, points or 1.0), 2)
        profile.last_active_at = _now()
    else:
        today.misses = int(today.misses or 0) + max(1, int(misses or 1))
        today.consistency_points = max(0.0, round(float(today.consistency_points or 0) - 0.25, 2))
    db.add(today)
    _recompute(db, profile)
    _award_badges(db, user, profile)
    _audit(
        db,
        user.id,
        "reputation.event.recorded",
        {
            "event_type": event_type[:64],
            "completed": completed,
            "consistency_points": points,
            "misses": misses,
            "date_key": today.date_key,
        },
    )
    db.commit()
    return {"ok": True, "event_type": event_type[:64], "profile": _profile_out(profile)}


def set_visibility(db: Session, user: User, visibility: str):
    normalized = str(visibility or "").strip().lower()
    if normalized not in {"private", "friends", "public"}:
        raise HTTPException(status_code=400, detail="Invalid visibility")
    profile = ensure_profile(db, user)
    profile.social_visibility = normalized
    db.add(profile)
    _audit(db, user.id, "reputation.visibility.updated", {"social_visibility": normalized})
    db.commit()
    db.refresh(profile)
    return _profile_out(profile)


def soft_recovery(db: Session, user: User):
    profile = ensure_profile(db, user)
    profile.recovery_mode = True
    notes = _safe_json(profile.reliability_notes_json, {})
    notes["status"] = "recovering"
    notes["recovery_tip"] = "Focus on one completed action for three days. Momentum returns fast."
    profile.reliability_notes_json = json.dumps(notes, default=str)
    db.add(profile)
    _audit(db, user.id, "reputation.recovery.started", {"tip": notes["recovery_tip"]})
    db.commit()
    db.refresh(profile)
    return {
        "ok": True,
        "message": "Recovery mode enabled. You are not penalized; focus on consistency resets.",
        "profile": _profile_out(profile),
    }


def social_reputation(db: Session, user: User):
    friend_ids = _friend_ids(db, user.id)
    if not friend_ids:
        return {"items": []}
    profiles = (
        db.query(ReputationProfile, User)
        .join(User, User.id == ReputationProfile.user_id)
        .filter(
            ReputationProfile.user_id.in_(friend_ids),
            ReputationProfile.social_visibility.in_(["friends", "public"]),
        )
        .order_by(ReputationProfile.work_ethic_score.desc(), ReputationProfile.consistency_days.desc())
        .limit(50)
        .all()
    )
    return {
        "items": [
            {
                "user": {"id": user_row.id, "username": user_row.username},
                "work_ethic_score": round(float(profile.work_ethic_score), 1),
                "consistency_days": int(profile.consistency_days or 0),
                "business_trust_score": round(float(profile.business_trust_score), 1),
                "recovery_mode": bool(profile.recovery_mode),
            }
            for profile, user_row in profiles
        ]
    }


def business_trust_signals(db: Session, user: User):
    profile = ensure_profile(db, user)
    _recompute(db, profile)
    timeline = (
        db.query(ReputationDailyEvent)
        .filter(ReputationDailyEvent.user_id == user.id)
        .order_by(ReputationDailyEvent.date_key.desc())
        .limit(30)
        .all()
    )
    completion_total = sum(int(item.completion_count or 0) for item in timeline)
    misses_total = sum(int(item.misses or 0) for item in timeline)
    completion_rate = 0.0 if (completion_total + misses_total) == 0 else round(completion_total / (completion_total + misses_total), 3)
    response_reliability = max(0.0, min(1.0, round((profile.business_trust_score / 100.0), 3)))
    db.commit()
    return {
        "business_trust_score": round(float(profile.business_trust_score), 1),
        "completion_rate": completion_rate,
        "response_reliability": response_reliability,
        "consistency_days": int(profile.consistency_days or 0),
        "active_days_30": int(profile.active_days_30 or 0),
        "summary": "Reliable and improving" if profile.business_trust_score >= 70 else "Building reliability through consistency",
    }
