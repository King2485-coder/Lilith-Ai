from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class NeuroMemory(Base, TimestampMixin):
    __tablename__ = "neuro_memories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    preferences_json: Mapped[str] = mapped_column(Text, default="{}")


class NeuroExecutionLog(Base, TimestampMixin):
    __tablename__ = "neuro_execution_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(120))
    input_json: Mapped[str] = mapped_column(Text, default="{}")
    output_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(24), default="completed")


class UserMemory(Base):
    __tablename__ = "user_memory"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    frequent_contacts: Mapped[str] = mapped_column(Text, default="{}")
    frequent_intents: Mapped[str] = mapped_column(Text, default="{}")
    recent_commands: Mapped[str] = mapped_column(Text, default="[]")
    last_used_entities: Mapped[str] = mapped_column(Text, default="{}")
    context_usage: Mapped[str] = mapped_column(Text, default="{}")
    profile_type: Mapped[str] = mapped_column(String(32), default="casual_user")
    prediction_feedback: Mapped[str] = mapped_column(Text, default="{}")
    macros_json: Mapped[str] = mapped_column(Text, default="{}")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class GlobalLearningAggregate(Base):
    __tablename__ = "global_learning_aggregate"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default="global")
    successful_commands: Mapped[str] = mapped_column(Text, default="{}")
    failed_intents: Mapped[str] = mapped_column(Text, default="{}")
    common_patterns: Mapped[str] = mapped_column(Text, default="{}")
    prediction_stats: Mapped[str] = mapped_column(Text, default="{}")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
