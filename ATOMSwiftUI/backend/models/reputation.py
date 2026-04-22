from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class ReputationProfile(Base, TimestampMixin):
    __tablename__ = "reputation_profiles"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    work_ethic_score: Mapped[float] = mapped_column(default=50.0)  # 0..100
    consistency_days: Mapped[int] = mapped_column(default=0)
    active_days_30: Mapped[int] = mapped_column(default=0)
    inactive_days_30: Mapped[int] = mapped_column(default=30)
    recovery_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    social_visibility: Mapped[str] = mapped_column(String(24), default="friends")  # private, friends, public
    business_trust_score: Mapped[float] = mapped_column(default=50.0)  # 0..100
    reliability_notes_json: Mapped[str] = mapped_column(Text, default="{}")
    last_active_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ReputationDailyEvent(Base, TimestampMixin):
    __tablename__ = "reputation_daily_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    date_key: Mapped[str] = mapped_column(String(16), index=True)  # YYYY-MM-DD UTC
    completion_count: Mapped[int] = mapped_column(default=0)
    consistency_points: Mapped[float] = mapped_column(default=0.0)
    misses: Mapped[int] = mapped_column(default=0)


class ReputationBadge(Base, TimestampMixin):
    __tablename__ = "reputation_badges"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    code: Mapped[str] = mapped_column(String(64), index=True)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    visible: Mapped[bool] = mapped_column(Boolean, default=True)
    earned_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ReputationAuditLog(Base, TimestampMixin):
    __tablename__ = "reputation_audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    detail_json: Mapped[str] = mapped_column(Text, default="{}")
