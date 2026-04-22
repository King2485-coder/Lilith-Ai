from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class RealWorldConnector(Base, TimestampMixin):
    __tablename__ = "real_world_connectors"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    connector_type: Mapped[str] = mapped_column(String(40), index=True)  # jobs, payments, communication, automation
    provider: Mapped[str] = mapped_column(String(80), index=True)
    status: Mapped[str] = mapped_column(String(24), default="connected", index=True)
    scopes_json: Mapped[str] = mapped_column(Text, default="[]")
    credential_ref: Mapped[str] = mapped_column(String(220), default="")  # secure broker reference only
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class RealWorldOpportunity(Base, TimestampMixin):
    __tablename__ = "real_world_opportunities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    connector_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("real_world_connectors.id"), nullable=True, index=True)
    external_ref: Mapped[str] = mapped_column(String(120), default="", index=True)
    title: Mapped[str] = mapped_column(String(220))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(40), index=True)  # task, freelance, gig, contract
    payout_min: Mapped[float] = mapped_column(default=0.0)
    payout_max: Mapped[float] = mapped_column(default=0.0)
    location_mode: Mapped[str] = mapped_column(String(24), default="remote")
    apply_url: Mapped[str] = mapped_column(String(320), default="")
    verified: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    scam_risk_score: Mapped[float] = mapped_column(default=0.0)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class RealWorldApplication(Base, TimestampMixin):
    __tablename__ = "real_world_applications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    opportunity_id: Mapped[str] = mapped_column(String(36), ForeignKey("real_world_opportunities.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="draft", index=True)  # draft, pending_approval, submitted, rejected, accepted
    autofill_used: Mapped[bool] = mapped_column(Boolean, default=False)
    proposal_text: Mapped[str] = mapped_column(Text, default="")
    payload_json: Mapped[str] = mapped_column(Text, default="{}")
    confirmation_required: Mapped[bool] = mapped_column(Boolean, default=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class RealWorldActionPipeline(Base, TimestampMixin):
    __tablename__ = "real_world_action_pipelines"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    action_type: Mapped[str] = mapped_column(String(64), index=True)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)  # pending, running, needs_approval, completed, failed
    steps_json: Mapped[str] = mapped_column(Text, default="[]")
    context_json: Mapped[str] = mapped_column(Text, default="{}")
    result_json: Mapped[str] = mapped_column(Text, default="{}")
    requires_approval: Mapped[bool] = mapped_column(Boolean, default=True)
    approval_state: Mapped[str] = mapped_column(String(24), default="required", index=True)  # required, approved, declined, not_required
    executed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class RealWorldIncomeEvent(Base, TimestampMixin):
    __tablename__ = "real_world_income_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    source_type: Mapped[str] = mapped_column(String(40), index=True)  # freelance, gig, sale, tip, transfer
    amount: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    status: Mapped[str] = mapped_column(String(24), default="recorded", index=True)
    happened_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class RealWorldAuditLog(Base, TimestampMixin):
    __tablename__ = "real_world_audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    entity_type: Mapped[str] = mapped_column(String(64), default="")
    entity_id: Mapped[str] = mapped_column(String(64), default="")
    detail_json: Mapped[str] = mapped_column(Text, default="{}")
