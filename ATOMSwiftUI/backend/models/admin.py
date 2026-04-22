from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class UserRole(Base, TimestampMixin):
    __tablename__ = "user_roles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True, index=True)
    role: Mapped[str] = mapped_column(String(24), default="user", index=True)  # user, admin, super_admin
    status: Mapped[str] = mapped_column(String(24), default="active", index=True)  # active, suspended, banned


class AdminActionLog(Base, TimestampMixin):
    __tablename__ = "admin_action_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    admin_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(120))
    target_type: Mapped[str] = mapped_column(String(60))
    target_id: Mapped[str] = mapped_column(String(80))
    details_json: Mapped[str] = mapped_column(Text, default="{}")


class ToolControl(Base, TimestampMixin):
    __tablename__ = "tool_controls"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tool_name: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    approved: Mapped[bool] = mapped_column(default=True)
    enabled: Mapped[bool] = mapped_column(default=True)
    note: Mapped[str] = mapped_column(String(255), default="")


class ModerationReport(Base, TimestampMixin):
    __tablename__ = "moderation_reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    reporter_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    target_type: Mapped[str] = mapped_column(String(60))
    target_id: Mapped[str] = mapped_column(String(80))
    reason: Mapped[str] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(String(24), default="open", index=True)  # open, reviewed, actioned, dismissed
    action_note: Mapped[str] = mapped_column(String(255), default="")


class PaymentFraudFlag(Base, TimestampMixin):
    __tablename__ = "payment_fraud_flags"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    payment_intent_id: Mapped[str] = mapped_column(String(36), index=True)
    flagged_by_admin_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    reason: Mapped[str] = mapped_column(String(255))

