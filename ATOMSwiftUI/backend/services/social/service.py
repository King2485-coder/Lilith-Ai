from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.models.income_engine import IncomeAction, IncomeAuditLog
from backend.models.social import (
    AccountabilityCheckin,
    AccountabilityNudge,
    FriendConnection,
    SharedGoal,
    SharedGoalParticipant,
    SocialActivityEvent,
    SocialPrivacySetting,
)
from backend.models.user import User
from backend.services.notifications.service import create_notification


def _iso(value):
    return value.isoformat() if value else None


def _now():
    return datetime.utcnow()


def _user_brief(row: User | None):
    if row is None:
        return {"id": "", "username": ""}
    return {"id": row.id, "username": row.username}


def _find_user_by_username(db: Session, username: str):
    normalized = username.strip().lstrip("@").lower()
    if not normalized:
        return None
    return db.query(User).filter(User.username == normalized).first()


def _friend_user_ids(db: Session, user_id: str):
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


def _ensure_privacy(db: Session, user_id: str):
    row = db.query(SocialPrivacySetting).filter(SocialPrivacySetting.user_id == user_id).first()
    if row is None:
        row = SocialPrivacySetting(user_id=user_id, share_presence=True, share_earnings=False, allow_nudges=True)
        db.add(row)
        db.flush()
    return row


def _activity_out(row: SocialActivityEvent, users: dict[str, User]):
    return {
        "id": row.id,
        "user": _user_brief(users.get(row.user_id)),
        "activity_type": row.activity_type,
        "summary": row.summary,
        "score_delta": row.score_delta,
        "created_at": _iso(row.created_at),
    }


def record_activity(db: Session, user_id: str, activity_type: str, summary: str, score_delta: float = 0.0, visibility: str = "friends"):
    row = SocialActivityEvent(
        user_id=user_id,
        activity_type=activity_type[:40],
        summary=summary[:220],
        score_delta=round(float(score_delta), 2),
        visibility="private" if visibility == "private" else "friends",
    )
    db.add(row)
    db.flush()
    return row


def request_friend(db: Session, user: User, username: str):
    target = _find_user_by_username(db, username)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    if target.id == user.id:
        raise HTTPException(status_code=400, detail="Cannot friend yourself")

    existing = (
        db.query(FriendConnection)
        .filter(
            or_(
                (FriendConnection.requester_id == user.id) & (FriendConnection.addressee_id == target.id),
                (FriendConnection.requester_id == target.id) & (FriendConnection.addressee_id == user.id),
            )
        )
        .first()
    )
    if existing is not None:
        if existing.status == "accepted":
            return {"status": "already_friends", "connection_id": existing.id}
        if existing.status == "pending":
            return {"status": "already_pending", "connection_id": existing.id}
        existing.status = "pending"
        existing.requester_id = user.id
        existing.addressee_id = target.id
        existing.responded_at = None
        db.add(existing)
        create_notification(
            db,
            user_id=target.id,
            kind="social.friend_request",
            title=f"Friend request from @{user.username}",
            body="Open Social to accept or decline.",
        )
        record_activity(db, user.id, "friend_request", f"Sent friend request to @{target.username}", 2)
        db.commit()
        return {"status": "requested", "connection_id": existing.id}

    row = FriendConnection(requester_id=user.id, addressee_id=target.id, status="pending", responded_at=None)
    db.add(row)
    create_notification(
        db,
        user_id=target.id,
        kind="social.friend_request",
        title=f"Friend request from @{user.username}",
        body="Open Social to accept or decline.",
    )
    record_activity(db, user.id, "friend_request", f"Sent friend request to @{target.username}", 2)
    db.commit()
    db.refresh(row)
    return {"status": "requested", "connection_id": row.id}


def respond_friend(db: Session, user: User, connection_id: str, decision: str):
    row = db.query(FriendConnection).filter(FriendConnection.id == connection_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if row.addressee_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this request")
    if row.status != "pending":
        return {"status": row.status, "connection_id": row.id}
    normalized = decision.strip().lower()
    if normalized not in {"accept", "decline"}:
        raise HTTPException(status_code=400, detail="Invalid decision")
    row.status = "accepted" if normalized == "accept" else "declined"
    row.responded_at = _now()
    db.add(row)
    create_notification(
        db,
        user_id=row.requester_id,
        kind="social.friend_response",
        title=f"@{user.username} {'accepted' if row.status == 'accepted' else 'declined'} your request",
        body="You can now share goals and accountability updates." if row.status == "accepted" else "Try connecting with someone else.",
    )
    if row.status == "accepted":
        record_activity(db, user.id, "friend_connected", "Accepted a new friend", 5)
        record_activity(db, row.requester_id, "friend_connected", f"Connected with @{user.username}", 5)
    db.commit()
    return {"status": row.status, "connection_id": row.id}


def list_friends(db: Session, user: User):
    rows = (
        db.query(FriendConnection)
        .filter(or_(FriendConnection.requester_id == user.id, FriendConnection.addressee_id == user.id))
        .order_by(FriendConnection.created_at.desc())
        .all()
    )
    users = {u.id: u for u in db.query(User).filter(User.id.in_({x.requester_id for x in rows} | {x.addressee_id for x in rows})).all()} if rows else {}
    out = []
    for row in rows:
        friend_id = row.requester_id if row.requester_id != user.id else row.addressee_id
        out.append(
            {
                "connection_id": row.id,
                "status": row.status,
                "friend": _user_brief(users.get(friend_id)),
                "direction": "incoming" if row.addressee_id == user.id else "outgoing",
                "created_at": _iso(row.created_at),
            }
        )
    return {"items": out}


def create_shared_goal(db: Session, user: User, title: str, description: str, daily_target: float, member_usernames: list[str] | None):
    row = SharedGoal(
        owner_user_id=user.id,
        title=title.strip()[:180] or "Shared Goal",
        description=description.strip()[:2000],
        daily_target=max(0.0, round(float(daily_target), 2)),
        status="active",
    )
    db.add(row)
    db.flush()

    owner_participant = SharedGoalParticipant(goal_id=row.id, user_id=user.id, role="owner", status="accepted", joined_at=_now())
    db.add(owner_participant)

    friend_ids = _friend_user_ids(db, user.id)
    for username in member_usernames or []:
        target = _find_user_by_username(db, username)
        if target is None or target.id == user.id or target.id not in friend_ids:
            continue
        existing = (
            db.query(SharedGoalParticipant)
            .filter(SharedGoalParticipant.goal_id == row.id, SharedGoalParticipant.user_id == target.id)
            .first()
        )
        if existing is None:
            db.add(SharedGoalParticipant(goal_id=row.id, user_id=target.id, role="member", status="invited", joined_at=None))
        create_notification(
            db,
            user_id=target.id,
            kind="social.goal_invite",
            title=f"@{user.username} invited you to a shared goal",
            body=row.title,
        )
    record_activity(db, user.id, "goal_created", f"Created shared goal: {row.title}", 8)

    db.commit()
    db.refresh(row)
    return {"goal_id": row.id, "title": row.title, "daily_target": row.daily_target, "status": row.status}


def respond_shared_goal(db: Session, user: User, goal_id: str, decision: str):
    participant = (
        db.query(SharedGoalParticipant)
        .filter(SharedGoalParticipant.goal_id == goal_id, SharedGoalParticipant.user_id == user.id)
        .first()
    )
    if participant is None:
        raise HTTPException(status_code=404, detail="Goal invite not found")
    normalized = decision.strip().lower()
    if normalized not in {"accept", "decline"}:
        raise HTTPException(status_code=400, detail="Invalid decision")
    participant.status = "accepted" if normalized == "accept" else "declined"
    participant.joined_at = _now() if participant.status == "accepted" else None
    db.add(participant)
    if participant.status == "accepted":
        goal = db.query(SharedGoal).filter(SharedGoal.id == goal_id).first()
        record_activity(db, user.id, "goal_joined", f"Joined shared goal: {goal.title if goal else 'Goal'}", 6)
    db.commit()
    return {"goal_id": goal_id, "status": participant.status}


def list_shared_goals(db: Session, user: User):
    memberships = (
        db.query(SharedGoalParticipant)
        .filter(SharedGoalParticipant.user_id == user.id)
        .order_by(SharedGoalParticipant.created_at.desc())
        .all()
    )
    goal_ids = [x.goal_id for x in memberships]
    goals = {x.id: x for x in db.query(SharedGoal).filter(SharedGoal.id.in_(goal_ids)).all()} if goal_ids else {}
    participants = (
        db.query(SharedGoalParticipant).filter(SharedGoalParticipant.goal_id.in_(goal_ids)).all() if goal_ids else []
    )
    users = {x.id: x for x in db.query(User).filter(User.id.in_({p.user_id for p in participants})).all()} if participants else {}
    checkins = (
        db.query(AccountabilityCheckin)
        .filter(AccountabilityCheckin.goal_id.in_(goal_ids), AccountabilityCheckin.created_at >= (_now() - timedelta(days=1)))
        .all()
        if goal_ids
        else []
    )
    progress_map: dict[str, float] = {}
    for checkin in checkins:
        progress_map[checkin.goal_id] = round(progress_map.get(checkin.goal_id, 0.0) + float(checkin.progress_amount), 2)

    out = []
    for member in memberships:
        goal = goals.get(member.goal_id)
        if goal is None:
            continue
        goal_members = [
            {"user": _user_brief(users.get(p.user_id)), "role": p.role, "status": p.status}
            for p in participants
            if p.goal_id == goal.id
        ]
        out.append(
            {
                "goal_id": goal.id,
                "title": goal.title,
                "description": goal.description,
                "daily_target": goal.daily_target,
                "status": goal.status,
                "membership_status": member.status,
                "today_progress": progress_map.get(goal.id, 0.0),
                "members": goal_members,
            }
        )
    return {"items": out}


def create_checkin(db: Session, user: User, goal_id: str, note: str, progress_amount: float):
    member = (
        db.query(SharedGoalParticipant)
        .filter(
            SharedGoalParticipant.goal_id == goal_id,
            SharedGoalParticipant.user_id == user.id,
            SharedGoalParticipant.status == "accepted",
        )
        .first()
    )
    if member is None:
        raise HTTPException(status_code=403, detail="Join this goal before check-ins")
    row = AccountabilityCheckin(
        goal_id=goal_id,
        user_id=user.id,
        note=note.strip()[:600],
        progress_amount=max(0.0, round(float(progress_amount), 2)),
    )
    db.add(row)

    peers = (
        db.query(SharedGoalParticipant)
        .filter(
            SharedGoalParticipant.goal_id == goal_id,
            SharedGoalParticipant.user_id != user.id,
            SharedGoalParticipant.status == "accepted",
        )
        .all()
    )
    for peer in peers:
        privacy = _ensure_privacy(db, peer.user_id)
        if not bool(privacy.allow_nudges):
            continue
        create_notification(
            db,
            user_id=peer.user_id,
            kind="social.accountability",
            title=f"@{user.username} checked in",
            body=note.strip()[:120] or "Progress update posted.",
        )
    goal = db.query(SharedGoal).filter(SharedGoal.id == goal_id).first()
    record_activity(
        db,
        user.id,
        "checkin",
        f"Checked in on {goal.title if goal else 'shared goal'} (+${row.progress_amount:.0f})",
        score_delta=max(3.0, row.progress_amount / 10.0),
    )
    db.commit()
    db.refresh(row)
    return {
        "checkin_id": row.id,
        "goal_id": row.goal_id,
        "note": row.note,
        "progress_amount": row.progress_amount,
        "created_at": _iso(row.created_at),
    }


def leaderboard(db: Session, user: User, scope: str = "friends", days: int = 7):
    cutoff = _now() - timedelta(days=max(1, min(days, 30)))
    if scope == "global":
        user_ids = {x.id for x in db.query(User.id).limit(200).all()}  # bounded
    else:
        user_ids = _friend_user_ids(db, user.id)
        user_ids.add(user.id)
    if not user_ids:
        user_ids = {user.id}

    actions = (
        db.query(IncomeAction)
        .filter(IncomeAction.user_id.in_(user_ids), IncomeAction.status == "completed", IncomeAction.updated_at >= cutoff)
        .all()
    )
    checkins = (
        db.query(AccountabilityCheckin)
        .filter(AccountabilityCheckin.user_id.in_(user_ids), AccountabilityCheckin.created_at >= cutoff)
        .all()
    )
    lesson_events = (
        db.query(IncomeAuditLog)
        .filter(
            IncomeAuditLog.user_id.in_(user_ids),
            IncomeAuditLog.event_type == "income.skill.lesson_completed",
            IncomeAuditLog.created_at >= cutoff,
        )
        .all()
    )

    board: dict[str, dict[str, Any]] = {}
    for uid in user_ids:
        board[uid] = {"user_id": uid, "earnings": 0.0, "checkins": 0, "lessons": 0, "score": 0.0}
    for row in actions:
        payout = float(row.actual_payout or row.expected_payout or 0.0)
        board[row.user_id]["earnings"] += payout
        board[row.user_id]["score"] += payout
    for row in checkins:
        board[row.user_id]["checkins"] += 1
        board[row.user_id]["score"] += 15
    for row in lesson_events:
        board[row.user_id]["lessons"] += 1
        board[row.user_id]["score"] += 10

    users = {x.id: x for x in db.query(User).filter(User.id.in_(user_ids)).all()}
    items = []
    for data in board.values():
        items.append(
            {
                "user": _user_brief(users.get(data["user_id"])),
                "earnings": round(float(data["earnings"]), 2),
                "checkins": int(data["checkins"]),
                "lessons": int(data["lessons"]),
                "score": round(float(data["score"]), 2),
            }
        )
    items.sort(key=lambda x: x["score"], reverse=True)
    for idx, row in enumerate(items, start=1):
        row["rank"] = idx
    return {"items": items[:50], "scope": scope, "days": days}


def accountability_feed(db: Session, user: User, limit: int = 30):
    goal_memberships = (
        db.query(SharedGoalParticipant)
        .filter(SharedGoalParticipant.user_id == user.id, SharedGoalParticipant.status == "accepted")
        .all()
    )
    goal_ids = [x.goal_id for x in goal_memberships]
    if not goal_ids:
        return {"items": []}
    rows = (
        db.query(AccountabilityCheckin)
        .filter(AccountabilityCheckin.goal_id.in_(goal_ids))
        .order_by(AccountabilityCheckin.created_at.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    users = {x.id: x for x in db.query(User).filter(User.id.in_({r.user_id for r in rows})).all()} if rows else {}
    return {
        "items": [
            {
                "checkin_id": row.id,
                "goal_id": row.goal_id,
                "user": _user_brief(users.get(row.user_id)),
                "note": row.note,
                "progress_amount": row.progress_amount,
                "created_at": _iso(row.created_at),
            }
            for row in rows
        ]
    }


def set_privacy(db: Session, user: User, patch: dict[str, Any]):
    row = _ensure_privacy(db, user.id)
    if "share_presence" in patch:
        row.share_presence = bool(patch["share_presence"])
    if "share_earnings" in patch:
        row.share_earnings = bool(patch["share_earnings"])
    if "allow_nudges" in patch:
        row.allow_nudges = bool(patch["allow_nudges"])
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"share_presence": bool(row.share_presence), "share_earnings": bool(row.share_earnings), "allow_nudges": bool(row.allow_nudges)}


def get_privacy(db: Session, user: User):
    row = _ensure_privacy(db, user.id)
    db.commit()
    return {"share_presence": bool(row.share_presence), "share_earnings": bool(row.share_earnings), "allow_nudges": bool(row.allow_nudges)}


def live_presence(db: Session, user: User, limit: int = 12):
    friend_ids = list(_friend_user_ids(db, user.id))
    if not friend_ids:
        return {"items": []}
    rows = (
        db.query(SocialActivityEvent)
        .filter(SocialActivityEvent.user_id.in_(friend_ids), SocialActivityEvent.visibility == "friends")
        .order_by(SocialActivityEvent.created_at.desc())
        .all()
    )
    users = {u.id: u for u in db.query(User).filter(User.id.in_(friend_ids)).all()}
    privacy = {p.user_id: p for p in db.query(SocialPrivacySetting).filter(SocialPrivacySetting.user_id.in_(friend_ids)).all()}

    seen: set[str] = set()
    out = []
    now = _now()
    for row in rows:
        if row.user_id in seen:
            continue
        setting = privacy.get(row.user_id)
        if setting is not None and not bool(setting.share_presence):
            continue
        age = (now - row.created_at).total_seconds() if row.created_at else 99999
        status = "active_now" if age <= 180 else ("recently_active" if age <= 900 else "away")
        out.append(
            {
                "user": _user_brief(users.get(row.user_id)),
                "status": status,
                "activity_type": row.activity_type,
                "summary": row.summary,
                "updated_at": _iso(row.created_at),
            }
        )
        seen.add(row.user_id)
        if len(out) >= max(1, min(limit, 30)):
            break
    return {"items": out}


def micro_celebrations(db: Session, user: User, limit: int = 12):
    friend_ids = _friend_user_ids(db, user.id)
    target_ids = set(friend_ids)
    target_ids.add(user.id)
    rows = (
        db.query(SocialActivityEvent)
        .filter(
            SocialActivityEvent.user_id.in_(target_ids),
            SocialActivityEvent.created_at >= (_now() - timedelta(days=1)),
            SocialActivityEvent.activity_type.in_(["checkin", "goal_joined", "goal_created", "friend_connected"]),
        )
        .order_by(SocialActivityEvent.created_at.desc())
        .limit(max(1, min(limit, 50)))
        .all()
    )
    users = {u.id: u for u in db.query(User).filter(User.id.in_(target_ids)).all()}
    return {"items": [_activity_out(row, users) for row in rows]}


def chase_mode(db: Session, user: User):
    board = leaderboard(db, user, scope="friends", days=7)["items"]
    current = next((x for x in board if x["user"]["id"] == user.id), None)
    if current is None:
        return {"current_rank": None, "ahead": None, "behind": None}
    idx = int(current["rank"]) - 1
    ahead = board[idx - 1] if idx - 1 >= 0 else None
    behind = board[idx + 1] if idx + 1 < len(board) else None
    out = {
        "current_rank": current["rank"],
        "score": current["score"],
        "ahead": None,
        "behind": None,
    }
    if ahead:
        out["ahead"] = {
            "user": ahead["user"],
            "gap_score": round(float(ahead["score"]) - float(current["score"]), 2),
        }
    if behind:
        out["behind"] = {
            "user": behind["user"],
            "lead_score": round(float(current["score"]) - float(behind["score"]), 2),
        }
    return out


def send_accountability_nudge(db: Session, user: User, to_user_id: str, goal_id: str, message: str):
    friend_ids = _friend_user_ids(db, user.id)
    if to_user_id not in friend_ids:
        raise HTTPException(status_code=403, detail="Can only nudge friends")
    target_privacy = _ensure_privacy(db, to_user_id)
    if not bool(target_privacy.allow_nudges):
        raise HTTPException(status_code=400, detail="User disabled nudges")

    goal_member = (
        db.query(SharedGoalParticipant)
        .filter(
            SharedGoalParticipant.goal_id == goal_id,
            SharedGoalParticipant.user_id == to_user_id,
            SharedGoalParticipant.status == "accepted",
        )
        .first()
    )
    if goal_member is None:
        raise HTTPException(status_code=400, detail="Target user is not active in this goal")

    row = AccountabilityNudge(
        from_user_id=user.id,
        to_user_id=to_user_id,
        goal_id=goal_id,
        message=message.strip()[:280] or "Quick check-in? You’re close to your goal.",
        status="sent",
    )
    db.add(row)
    create_notification(
        db,
        user_id=to_user_id,
        kind="social.nudge",
        title=f"@{user.username} sent an accountability nudge",
        body=row.message[:120],
    )
    target_user = db.query(User).filter(User.id == to_user_id).first()
    record_activity(db, user.id, "nudge_sent", f"Sent an accountability nudge to @{target_user.username if target_user else 'friend'}", 1)
    db.commit()
    db.refresh(row)
    return {"nudge_id": row.id, "status": row.status, "created_at": _iso(row.created_at)}


def live_engagement(db: Session, user: User):
    goals = list_shared_goals(db, user)["items"]
    due = [x for x in goals if x.get("membership_status") == "accepted" and float(x.get("today_progress", 0.0)) <= 0.0]
    return {
        "live_presence": live_presence(db, user, limit=8)["items"],
        "micro_celebrations": micro_celebrations(db, user, limit=10)["items"],
        "chase_mode": chase_mode(db, user),
        "shared_goal_urgency": [
            {
                "goal_id": row["goal_id"],
                "title": row["title"],
                "today_progress": row["today_progress"],
                "daily_target": row["daily_target"],
                "remaining": max(0.0, round(float(row["daily_target"]) - float(row["today_progress"]), 2)),
            }
            for row in due[:5]
        ],
        "accountability_prompt": (
            "Send one nudge to keep your group moving."
            if due
            else "Post a quick check-in to keep momentum."
        ),
    }


def social_overview(db: Session, user: User):
    last_active = (
        db.query(SocialActivityEvent)
        .filter(SocialActivityEvent.user_id == user.id, SocialActivityEvent.activity_type == "active")
        .order_by(SocialActivityEvent.created_at.desc())
        .first()
    )
    if last_active is None or (last_active.created_at and (_now() - last_active.created_at) > timedelta(minutes=5)):
        record_activity(db, user.id, "active", "Opened social layer", 0.2)
    friends = list_friends(db, user)["items"]
    goals = list_shared_goals(db, user)["items"]
    board = leaderboard(db, user, scope="friends", days=7)["items"]
    pending = [x for x in friends if x["status"] == "pending" and x["direction"] == "incoming"]
    due_checkins = [x for x in goals if x.get("membership_status") == "accepted" and float(x.get("today_progress", 0.0)) <= 0.0]
    return {
        "friends_count": len([x for x in friends if x["status"] == "accepted"]),
        "pending_requests": len(pending),
        "shared_goals": len(goals),
        "due_checkins": len(due_checkins),
        "leaderboard_top": board[:5],
        "next_prompt": (
            "Send one accountability check-in now."
            if due_checkins
            else "Invite a friend to a shared goal."
        ),
    }
