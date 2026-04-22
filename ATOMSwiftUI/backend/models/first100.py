from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class First100Event(Base, TimestampMixin):
    __tablename__ = "first100_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)  # onboarding_started, first_action_completed, drop_off_point, confusion_detected
    screen: Mapped[str] = mapped_column(String(40), default="", index=True)
    session_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    payload_json: Mapped[str] = mapped_column(Text, default="{}")


class First100MicroFeedback(Base, TimestampMixin):
    __tablename__ = "first100_micro_feedback"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    session_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    command: Mapped[str] = mapped_column(Text, default="")
    sentiment: Mapped[str] = mapped_column(String(16), index=True)  # up, down
    reason: Mapped[str] = mapped_column(String(120), default="")
    context_json: Mapped[str] = mapped_column(Text, default="{}")


class First100SessionInsight(Base, TimestampMixin):
    __tablename__ = "first100_session_insights"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    session_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    screen: Mapped[str] = mapped_column(String(40), default="", index=True)
    insight_type: Mapped[str] = mapped_column(String(40), index=True)  # hesitation, inactivity, confusion
    seconds: Mapped[int] = mapped_column(default=0)
    detail_json: Mapped[str] = mapped_column(Text, default="{}")


class First100DailyCheckin(Base, TimestampMixin):
    __tablename__ = "first100_daily_checkins"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    date_key: Mapped[str] = mapped_column(String(16), index=True)  # YYYY-MM-DD UTC
    response: Mapped[str] = mapped_column(String(32), default="", index=True)  # smooth, confused, stuck
    note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
