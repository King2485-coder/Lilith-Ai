from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class FriendConnection(Base, TimestampMixin):
    __tablename__ = "friend_connections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    requester_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    addressee_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)  # pending, accepted, declined, blocked
    responded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class SharedGoal(Base, TimestampMixin):
    __tablename__ = "shared_goals"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(180))
    description: Mapped[str] = mapped_column(Text, default="")
    daily_target: Mapped[float] = mapped_column(default=0.0)
    status: Mapped[str] = mapped_column(String(24), default="active", index=True)  # active, paused, archived


class SharedGoalParticipant(Base, TimestampMixin):
    __tablename__ = "shared_goal_participants"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    goal_id: Mapped[str] = mapped_column(String(36), ForeignKey("shared_goals.id"), index=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    role: Mapped[str] = mapped_column(String(24), default="member")  # owner, member
    status: Mapped[str] = mapped_column(String(24), default="invited", index=True)  # invited, accepted, declined
    joined_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class AccountabilityCheckin(Base, TimestampMixin):
    __tablename__ = "accountability_checkins"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    goal_id: Mapped[str] = mapped_column(String(36), ForeignKey("shared_goals.id"), index=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    note: Mapped[str] = mapped_column(Text, default="")
    progress_amount: Mapped[float] = mapped_column(default=0.0)


class SocialActivityEvent(Base, TimestampMixin):
    __tablename__ = "social_activity_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    activity_type: Mapped[str] = mapped_column(String(40), index=True)  # checkin, goal_created, goal_progress, streak, win, active
    summary: Mapped[str] = mapped_column(String(220), default="")
    score_delta: Mapped[float] = mapped_column(default=0.0)
    visibility: Mapped[str] = mapped_column(String(24), default="friends")  # private, friends


class SocialPrivacySetting(Base, TimestampMixin):
    __tablename__ = "social_privacy_settings"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    share_presence: Mapped[bool] = mapped_column(default=True)
    share_earnings: Mapped[bool] = mapped_column(default=False)
    allow_nudges: Mapped[bool] = mapped_column(default=True)


class AccountabilityNudge(Base, TimestampMixin):
    __tablename__ = "accountability_nudges"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    from_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    to_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    goal_id: Mapped[str] = mapped_column(String(36), ForeignKey("shared_goals.id"), index=True)
    message: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(24), default="sent", index=True)  # sent, seen, dismissed
