from __future__ import annotations

import uuid

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class RuntimeIncident(Base, TimestampMixin):
    __tablename__ = "runtime_incidents"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    category: Mapped[str] = mapped_column(String(40), index=True)  # api_error, slow_response, failed_job, websocket_issue
    classification: Mapped[str] = mapped_column(String(40), index=True)  # performance, network, auth, runtime
    severity: Mapped[str] = mapped_column(String(16), default="medium")
    summary: Mapped[str] = mapped_column(String(255))
    route: Mapped[str] = mapped_column(String(255), default="")
    details_json: Mapped[str] = mapped_column(Text, default="{}")
    resolved: Mapped[bool] = mapped_column(default=False)


class RuntimeFixAction(Base, TimestampMixin):
    __tablename__ = "runtime_fix_actions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    incident_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    action_type: Mapped[str] = mapped_column(String(40))  # retry_request, restart_service, clear_cache
    status: Mapped[str] = mapped_column(String(24), default="completed")
    result_json: Mapped[str] = mapped_column(Text, default="{}")


class RuntimeOptimizationSuggestion(Base, TimestampMixin):
    __tablename__ = "runtime_optimization_suggestions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    kind: Mapped[str] = mapped_column(String(40))  # caching, query, batching
    title: Mapped[str] = mapped_column(String(180))
    rationale: Mapped[str] = mapped_column(Text)
    suggestion: Mapped[str] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(default=True)

