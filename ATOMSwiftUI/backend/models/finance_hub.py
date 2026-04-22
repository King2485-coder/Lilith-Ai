from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class FinancialLinkedAccount(Base, TimestampMixin):
    __tablename__ = "financial_linked_accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    provider: Mapped[str] = mapped_column(String(64), default="wealthwizard", index=True)
    provider_account_ref: Mapped[str] = mapped_column(String(180), index=True)
    display_name: Mapped[str] = mapped_column(String(180))
    account_type: Mapped[str] = mapped_column(String(40), default="checking")
    currency: Mapped[str] = mapped_column(String(12), default="USD")
    status: Mapped[str] = mapped_column(String(24), default="linked")
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    credential_ref: Mapped[str] = mapped_column(String(220), default="")  # secure broker reference only
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class FinancialAccessPolicy(Base, TimestampMixin):
    __tablename__ = "financial_access_policies"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    access_level: Mapped[str] = mapped_column(String(16), default="observe")  # observe, assist, auto
    max_transfer_limit: Mapped[float] = mapped_column(default=250.0)
    bill_runway_days: Mapped[int] = mapped_column(default=14)
    available_cash_buffer: Mapped[float] = mapped_column(default=300.0)
    require_biometric_sensitive: Mapped[bool] = mapped_column(Boolean, default=True)
    first_time_hard_confirm_required: Mapped[bool] = mapped_column(Boolean, default=True)
    one_click_trade_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    one_click_trade_max: Mapped[float] = mapped_column(default=100.0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class FinancialRecurringItem(Base, TimestampMixin):
    __tablename__ = "financial_recurring_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(180))
    kind: Mapped[str] = mapped_column(String(24), default="subscription")  # subscription, bill
    amount: Mapped[float] = mapped_column(default=0.0)
    frequency: Mapped[str] = mapped_column(String(24), default="monthly")
    next_due_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class FinancialOpportunity(Base, TimestampMixin):
    __tablename__ = "financial_opportunities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    opportunity_type: Mapped[str] = mapped_column(String(40), index=True)
    title: Mapped[str] = mapped_column(String(220))
    summary: Mapped[str] = mapped_column(Text, default="")
    confidence: Mapped[float] = mapped_column(default=0.0)
    impact_amount: Mapped[float] = mapped_column(default=0.0)
    status: Mapped[str] = mapped_column(String(24), default="open")
    payload_json: Mapped[str] = mapped_column(Text, default="{}")


class FinancialActionPreview(Base, TimestampMixin):
    __tablename__ = "financial_action_previews"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    action_type: Mapped[str] = mapped_column(String(40), index=True)  # transfer_savings, pay_bill, trade
    reason: Mapped[str] = mapped_column(Text, default="")
    payload_json: Mapped[str] = mapped_column(Text, default="{}")
    guardrail_report_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(24), default="pending")  # pending, approved, declined, blocked, executed
    requires_hard_confirmation: Mapped[bool] = mapped_column(Boolean, default=True)
    biometric_required: Mapped[bool] = mapped_column(Boolean, default=True)
    first_time_action: Mapped[bool] = mapped_column(Boolean, default=True)
    executed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class FinancialAutomationRule(Base, TimestampMixin):
    __tablename__ = "financial_automation_rules"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(180))
    rule_type: Mapped[str] = mapped_column(String(40), index=True)  # fixed_after_payday, round_up, unusual_charge_alert, recurring_bill_reminder
    config_json: Mapped[str] = mapped_column(Text, default="{}")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    require_approval: Mapped[bool] = mapped_column(Boolean, default=True)
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_result_json: Mapped[str] = mapped_column(Text, default="{}")


class FinancialAuditLog(Base, TimestampMixin):
    __tablename__ = "financial_audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    entity_type: Mapped[str] = mapped_column(String(64), default="")
    entity_id: Mapped[str] = mapped_column(String(64), default="")
    detail_json: Mapped[str] = mapped_column(Text, default="{}")
