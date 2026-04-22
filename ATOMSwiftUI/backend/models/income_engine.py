from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.db.base import Base, TimestampMixin


class IncomeProfile(Base, TimestampMixin):
    __tablename__ = "income_profiles"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    daily_target: Mapped[float] = mapped_column(default=300.0)
    monthly_target: Mapped[float] = mapped_column(default=10000.0)
    skills_json: Mapped[str] = mapped_column(Text, default="[]")
    location: Mapped[str] = mapped_column(String(120), default="")
    availability_hours_per_day: Mapped[float] = mapped_column(default=2.0)
    preferred_categories_json: Mapped[str] = mapped_column(Text, default="[]")
    risk_mode: Mapped[str] = mapped_column(String(24), default="safe")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class IncomeOpportunity(Base, TimestampMixin):
    __tablename__ = "income_opportunities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    source: Mapped[str] = mapped_column(String(64), default="lilith_curated", index=True)
    title: Mapped[str] = mapped_column(String(220))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(40), index=True)  # task, freelance, gig, monetization
    payout_min: Mapped[float] = mapped_column(default=0.0)
    payout_max: Mapped[float] = mapped_column(default=0.0)
    estimated_minutes: Mapped[int] = mapped_column(default=30)
    location_mode: Mapped[str] = mapped_column(String(24), default="remote")  # remote, local, hybrid
    required_skills_json: Mapped[str] = mapped_column(Text, default="[]")
    verified: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    scam_risk_score: Mapped[float] = mapped_column(default=0.0)  # 0.0 safe -> 1.0 high risk
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")


class IncomeAction(Base, TimestampMixin):
    __tablename__ = "income_actions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    opportunity_id: Mapped[str] = mapped_column(String(36), ForeignKey("income_opportunities.id"), index=True)
    status: Mapped[str] = mapped_column(String(24), default="started", index=True)  # previewed, started, applied, completed, declined
    autofill_used: Mapped[bool] = mapped_column(Boolean, default=False)
    proposal_drafted: Mapped[bool] = mapped_column(Boolean, default=False)
    followup_scheduled: Mapped[bool] = mapped_column(Boolean, default=False)
    expected_payout: Mapped[float] = mapped_column(default=0.0)
    actual_payout: Mapped[float] = mapped_column(default=0.0)
    notes_json: Mapped[str] = mapped_column(Text, default="{}")


class IncomeAuditLog(Base, TimestampMixin):
    __tablename__ = "income_audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    entity_type: Mapped[str] = mapped_column(String(64), default="")
    entity_id: Mapped[str] = mapped_column(String(64), default="")
    detail_json: Mapped[str] = mapped_column(Text, default="{}")


class IncomeSkillProfile(Base, TimestampMixin):
    __tablename__ = "income_skill_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    skill: Mapped[str] = mapped_column(String(80), index=True)
    proficiency: Mapped[float] = mapped_column(default=0.2)  # 0..1
    earnings_generated: Mapped[float] = mapped_column(default=0.0)
    attempts: Mapped[int] = mapped_column(default=0)
    completions: Mapped[int] = mapped_column(default=0)
    growth_score: Mapped[float] = mapped_column(default=0.0)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class IncomeSkillLesson(Base, TimestampMixin):
    __tablename__ = "income_skill_lessons"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    skill: Mapped[str] = mapped_column(String(80), index=True)
    title: Mapped[str] = mapped_column(String(180))
    duration_minutes: Mapped[int] = mapped_column(default=12)
    difficulty: Mapped[str] = mapped_column(String(20), default="beginner")
    earning_impact: Mapped[float] = mapped_column(default=0.05)
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class DailyCoachSnapshot(Base, TimestampMixin):
    __tablename__ = "daily_coach_snapshots"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    date_key: Mapped[str] = mapped_column(String(16), index=True)  # YYYY-MM-DD UTC
    streak_count: Mapped[int] = mapped_column(default=0)
    engagement_points: Mapped[int] = mapped_column(default=0)
    completed_actions: Mapped[int] = mapped_column(default=0)
    micro_rewards_json: Mapped[str] = mapped_column(Text, default="[]")
    morning_plan_json: Mapped[str] = mapped_column(Text, default="{}")
    end_day_review_json: Mapped[str] = mapped_column(Text, default="{}")
    last_event_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class CoachTonePreference(Base, TimestampMixin):
    __tablename__ = "coach_tone_preferences"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    tone_mode: Mapped[str] = mapped_column(String(24), default="supportive")  # supportive | direct | aggressive
