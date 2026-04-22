from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class ApplicationTemplate(Base, TimestampMixin):
    __tablename__ = "application_templates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    business_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(180))
    description: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), default="active")  # active, paused, archived
    delivery_mode: Mapped[str] = mapped_column(String(24), default="direct")  # direct, link, api
    pricing_model: Mapped[str] = mapped_column(String(24), default="subscription")  # subscription, per_request, enterprise
    per_request_fee: Mapped[float] = mapped_column(default=0.0)
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class ApplicationField(Base, TimestampMixin):
    __tablename__ = "application_fields"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_templates.id"), index=True)
    key: Mapped[str] = mapped_column(String(120), index=True)
    label: Mapped[str] = mapped_column(String(180))
    field_type: Mapped[str] = mapped_column(String(40), default="text")
    required: Mapped[bool] = mapped_column(Boolean, default=False)
    position: Mapped[int] = mapped_column(default=0, index=True)
    source_type: Mapped[str] = mapped_column(String(24), default="manual")  # vault, upload, manual
    source_key: Mapped[str] = mapped_column(String(120), default="")
    options_json: Mapped[str] = mapped_column(Text, default="[]")
    validation_json: Mapped[str] = mapped_column(Text, default="{}")


class ApplicationRule(Base, TimestampMixin):
    __tablename__ = "application_rules"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_templates.id"), index=True)
    name: Mapped[str] = mapped_column(String(180))
    condition_json: Mapped[str] = mapped_column(Text, default="{}")
    effect_json: Mapped[str] = mapped_column(Text, default="{}")
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class ApplicationInstance(Base, TimestampMixin):
    __tablename__ = "application_instances"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_templates.id"), index=True)
    business_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    requester_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    target_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True, default="")
    channel: Mapped[str] = mapped_column(String(24), default="direct")  # direct, link, api
    status: Mapped[str] = mapped_column(String(32), default="pending")  # pending, in_progress, submitted, completed, cancelled
    token: Mapped[str] = mapped_column(String(64), index=True, default="")
    prefill_json: Mapped[str] = mapped_column(Text, default="{}")
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")
    submitted_at: Mapped[str] = mapped_column(String(64), default="")


class ApplicationResponse(Base, TimestampMixin):
    __tablename__ = "application_responses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    instance_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_instances.id"), index=True)
    responder_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    data_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(32), default="submitted")


class ApplicationTemplateMarket(Base, TimestampMixin):
    __tablename__ = "application_template_market"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_templates.id"), unique=True, index=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    category: Mapped[str] = mapped_column(String(64), default="General", index=True)
    tags_json: Mapped[str] = mapped_column(Text, default="[]")
    clone_source_template_id: Mapped[str] = mapped_column(String(36), default="", index=True)
    usage_count: Mapped[int] = mapped_column(default=0)


class ApplicationInstanceEvent(Base, TimestampMixin):
    __tablename__ = "application_instance_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    instance_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_instances.id"), index=True)
    template_id: Mapped[str] = mapped_column(String(36), ForeignKey("application_templates.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(40), index=True)  # viewed, started, submitted, completed, dropoff, autofill
    field_key: Mapped[str] = mapped_column(String(120), default="", index=True)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class ApplicationUserProfile(Base, TimestampMixin):
    __tablename__ = "application_user_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    profile_name: Mapped[str] = mapped_column(String(120))
    fields_json: Mapped[str] = mapped_column(Text, default="{}")
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    source: Mapped[str] = mapped_column(String(32), default="application_builder")  # application_builder, import, vault_bridge
