from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from backend.models.first100 import First100DailyCheckin, First100Event, First100MicroFeedback, First100SessionInsight
from backend.models.user import User


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _now():
    return datetime.utcnow()


def _date_key(value: datetime | None = None):
    base = value or _now()
    return base.date().isoformat()


def _iso(value):
    return value.isoformat() if value else None


def record_event(db: Session, user: User, event_type: str, screen: str, session_id: str, payload: dict[str, Any] | None):
    row = First100Event(
        user_id=user.id,
        event_type=event_type.strip().lower()[:64],
        screen=screen.strip().lower()[:40],
        session_id=session_id.strip()[:64],
        payload_json=json.dumps(payload or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "event_type": row.event_type,
        "screen": row.screen,
        "session_id": row.session_id,
        "created_at": _iso(row.created_at),
    }


def record_feedback(
    db: Session,
    user: User,
    session_id: str,
    command: str,
    sentiment: str,
    reason: str,
    context: dict[str, Any] | None,
):
    row = First100MicroFeedback(
        user_id=user.id,
        session_id=session_id.strip()[:64],
        command=command.strip()[:1000],
        sentiment=sentiment.strip().lower()[:16],
        reason=reason.strip()[:120],
        context_json=json.dumps(context or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "sentiment": row.sentiment, "reason": row.reason, "created_at": _iso(row.created_at)}


def record_session_insight(
    db: Session,
    user: User,
    session_id: str,
    screen: str,
    insight_type: str,
    seconds: int,
    detail: dict[str, Any] | None,
):
    row = First100SessionInsight(
        user_id=user.id,
        session_id=session_id.strip()[:64],
        screen=screen.strip().lower()[:40],
        insight_type=insight_type.strip().lower()[:40],
        seconds=max(0, int(seconds)),
        detail_json=json.dumps(detail or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {
        "id": row.id,
        "insight_type": row.insight_type,
        "seconds": row.seconds,
        "screen": row.screen,
        "created_at": _iso(row.created_at),
    }


def upsert_daily_checkin(db: Session, user: User, response: str, note: str):
    key = _date_key()
    row = (
        db.query(First100DailyCheckin)
        .filter(First100DailyCheckin.user_id == user.id, First100DailyCheckin.date_key == key)
        .order_by(First100DailyCheckin.created_at.desc())
        .first()
    )
    if row is None:
        row = First100DailyCheckin(
            user_id=user.id,
            date_key=key,
            response=response.strip().lower()[:32],
            note=note.strip()[:1000],
        )
        db.add(row)
    else:
        row.response = response.strip().lower()[:32]
        row.note = note.strip()[:1000]
        db.add(row)
    db.commit()
    db.refresh(row)
    return {"date_key": row.date_key, "response": row.response, "note": row.note, "created_at": _iso(row.created_at)}


def session_summary(db: Session, user: User):
    start = _now() - timedelta(days=14)
    events = (
        db.query(First100Event)
        .filter(First100Event.user_id == user.id, First100Event.created_at >= start)
        .order_by(First100Event.created_at.desc())
        .all()
    )
    insights = (
        db.query(First100SessionInsight)
        .filter(First100SessionInsight.user_id == user.id, First100SessionInsight.created_at >= start)
        .order_by(First100SessionInsight.created_at.desc())
        .all()
    )
    feedback = (
        db.query(First100MicroFeedback)
        .filter(First100MicroFeedback.user_id == user.id, First100MicroFeedback.created_at >= start)
        .order_by(First100MicroFeedback.created_at.desc())
        .all()
    )
    checkins = (
        db.query(First100DailyCheckin)
        .filter(First100DailyCheckin.user_id == user.id, First100DailyCheckin.created_at >= start)
        .order_by(First100DailyCheckin.created_at.desc())
        .all()
    )

    drop_off = sum(1 for row in events if row.event_type == "drop_off_point")
    first_wins = sum(1 for row in events if row.event_type == "first_action_completed")
    onboarding_started = sum(1 for row in events if row.event_type == "onboarding_started")
    confusion = sum(1 for row in events if row.event_type == "confusion_detected")
    avg_hesitation = (
        round(sum(int(x.seconds or 0) for x in insights if x.insight_type == "hesitation") / max(1, sum(1 for x in insights if x.insight_type == "hesitation")), 1)
        if insights
        else 0.0
    )
    avg_inactivity = (
        round(sum(int(x.seconds or 0) for x in insights if x.insight_type == "inactivity") / max(1, sum(1 for x in insights if x.insight_type == "inactivity")), 1)
        if insights
        else 0.0
    )
    thumbs_up = sum(1 for row in feedback if row.sentiment == "up")
    thumbs_down = sum(1 for row in feedback if row.sentiment == "down")

    top_dropoff_rows = (
        db.query(First100Event.screen, func.count(First100Event.id))
        .filter(First100Event.user_id == user.id, First100Event.event_type == "drop_off_point", First100Event.created_at >= start)
        .group_by(First100Event.screen)
        .order_by(func.count(First100Event.id).desc())
        .limit(5)
        .all()
    )

    return {
        "window_days": 14,
        "onboarding_started": onboarding_started,
        "first_action_completed": first_wins,
        "drop_off_points": drop_off,
        "confusion_detected": confusion,
        "avg_hesitation_seconds": avg_hesitation,
        "avg_inactivity_seconds": avg_inactivity,
        "feedback": {
            "thumbs_up": thumbs_up,
            "thumbs_down": thumbs_down,
            "recent": [
                {
                    "sentiment": row.sentiment,
                    "reason": row.reason,
                    "command": row.command,
                    "context": _safe_json(row.context_json, {}),
                    "created_at": _iso(row.created_at),
                }
                for row in feedback[:20]
            ],
        },
        "top_dropoff_screens": [{"screen": screen or "unknown", "count": int(count or 0)} for screen, count in top_dropoff_rows],
        "daily_checkins": [{"date_key": row.date_key, "response": row.response, "note": row.note, "created_at": _iso(row.created_at)} for row in checkins[:14]],
    }
