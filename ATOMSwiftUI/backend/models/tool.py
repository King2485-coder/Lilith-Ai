from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class ToolJob(Base, TimestampMixin):
    __tablename__ = "tool_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    tool_name: Mapped[str] = mapped_column(String(120))
    input_payload: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(24), default="queued")


class ToolResult(Base, TimestampMixin):
    __tablename__ = "tool_results"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    tool_job_id: Mapped[str] = mapped_column(String(36), ForeignKey("tool_jobs.id"), index=True, unique=True)
    output_payload: Mapped[str] = mapped_column(Text, default="{}")

