from __future__ import annotations

import json
from collections import Counter
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.models.income_engine import (
    CoachTonePreference,
    DailyCoachSnapshot,
    IncomeAction,
    IncomeAuditLog,
    IncomeOpportunity,
    IncomeProfile,
    IncomeSkillLesson,
    IncomeSkillProfile,
)
from backend.models.application import ApplicationInstance, ApplicationTemplate, ApplicationUserProfile
from backend.models.payment import PaymentIntent
from backend.models.user import User


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _iso(value):
    return value.isoformat() if value else None


def _now():
    return datetime.utcnow()


def _date_key(value: datetime | None = None):
    base = value or _now()
    return base.date().isoformat()


def _micro_rewards_out(items: list[dict[str, Any]]):
    return sorted(items, key=lambda x: x.get("created_at", ""), reverse=True)[:8]


def _coach_level_from_monthly(earnings_month: float):
    if earnings_month >= 10000:
        return 5
    if earnings_month >= 6000:
        return 4
    if earnings_month >= 3000:
        return 3
    if earnings_month >= 1000:
        return 2
    return 1


def _normalize_tone_mode(value: str | None):
    normalized = str(value or "supportive").strip().lower()
    return normalized if normalized in {"supportive", "direct", "aggressive"} else "supportive"


def _ensure_tone_pref(db: Session, user: User):
    row = db.query(CoachTonePreference).filter(CoachTonePreference.user_id == user.id).first()
    if row is None:
        row = CoachTonePreference(user_id=user.id, tone_mode="supportive")
        db.add(row)
        db.flush()
    return row


def set_tone_mode(db: Session, user: User, tone_mode: str):
    row = _ensure_tone_pref(db, user)
    row.tone_mode = _normalize_tone_mode(tone_mode)
    db.add(row)
    _audit(db, user.id, "coach.tone.updated", "coach_tone_preferences", user.id, {"tone_mode": row.tone_mode})
    db.commit()
    db.refresh(row)
    return {"tone_mode": row.tone_mode, "updated_at": _iso(row.updated_at)}


def get_tone_mode(db: Session, user: User):
    row = _ensure_tone_pref(db, user)
    db.commit()
    return {"tone_mode": row.tone_mode, "updated_at": _iso(row.updated_at)}


def _ensure_daily_snapshot(db: Session, user: User, key: str | None = None):
    today = key or _date_key()
    row = (
        db.query(DailyCoachSnapshot)
        .filter(DailyCoachSnapshot.user_id == user.id, DailyCoachSnapshot.date_key == today)
        .first()
    )
    if row is None:
        row = DailyCoachSnapshot(
            user_id=user.id,
            date_key=today,
            streak_count=0,
            engagement_points=0,
            completed_actions=0,
            micro_rewards_json="[]",
            morning_plan_json="{}",
            end_day_review_json="{}",
            last_event_at=None,
        )
        db.add(row)
        db.flush()
    return row


def _streak_count(db: Session, user: User):
    rows = (
        db.query(DailyCoachSnapshot)
        .filter(DailyCoachSnapshot.user_id == user.id)
        .order_by(DailyCoachSnapshot.date_key.desc())
        .limit(30)
        .all()
    )
    days = {x.date_key for x in rows if int(x.engagement_points or 0) > 0 or int(x.completed_actions or 0) > 0}
    streak = 0
    cursor = _now().date()
    while True:
        key = cursor.isoformat()
        if key in days:
            streak += 1
            cursor = cursor - timedelta(days=1)
            continue
        if streak == 0:
            # allow yesterday carry if user has not engaged yet today
            y_key = (cursor - timedelta(days=1)).isoformat()
            if y_key in days:
                cursor = cursor - timedelta(days=1)
                continue
        break
    return streak


def _audit(
    db: Session,
    user_id: str,
    event_type: str,
    entity_type: str = "",
    entity_id: str = "",
    detail: dict[str, Any] | None = None,
):
    db.add(
        IncomeAuditLog(
            user_id=user_id,
            event_type=event_type[:64],
            entity_type=entity_type[:64],
            entity_id=entity_id[:64],
            detail_json=json.dumps(detail or {}, default=str),
        )
    )
    db.flush()


DEFAULT_OPPORTUNITIES = [
    {
        "source": "lilith_curated",
        "title": "Customer Support Inbox Sprint",
        "description": "Clear support backlog for startup clients with templated responses.",
        "category": "task",
        "payout_min": 40,
        "payout_max": 80,
        "estimated_minutes": 90,
        "location_mode": "remote",
        "required_skills": ["support", "writing"],
        "verified": True,
        "scam_risk_score": 0.02,
    },
    {
        "source": "lilith_curated",
        "title": "Freelance Landing Page Copy Refresh",
        "description": "Update homepage and CTA copy for conversion uplift.",
        "category": "freelance",
        "payout_min": 120,
        "payout_max": 280,
        "estimated_minutes": 180,
        "location_mode": "remote",
        "required_skills": ["copywriting", "marketing"],
        "verified": True,
        "scam_risk_score": 0.05,
    },
    {
        "source": "lilith_curated",
        "title": "Local Event Photo Gig",
        "description": "Capture event photos and deliver edited highlights.",
        "category": "gig",
        "payout_min": 150,
        "payout_max": 350,
        "estimated_minutes": 240,
        "location_mode": "local",
        "required_skills": ["photography", "editing"],
        "verified": True,
        "scam_risk_score": 0.08,
    },
    {
        "source": "lilith_curated",
        "title": "Digital Product Template Pack",
        "description": "Package reusable templates and publish to marketplace.",
        "category": "monetization",
        "payout_min": 60,
        "payout_max": 300,
        "estimated_minutes": 120,
        "location_mode": "remote",
        "required_skills": ["design", "templates"],
        "verified": True,
        "scam_risk_score": 0.03,
    },
]

DEFAULT_SKILL_LESSONS = [
    {"skill": "writing", "title": "High-converting proposal openers", "duration_minutes": 10, "difficulty": "beginner", "earning_impact": 0.08},
    {"skill": "support", "title": "Fast inbox triage system", "duration_minutes": 12, "difficulty": "beginner", "earning_impact": 0.06},
    {"skill": "copywriting", "title": "Landing page conversion copy", "duration_minutes": 15, "difficulty": "intermediate", "earning_impact": 0.11},
    {"skill": "marketing", "title": "Offer positioning for higher rates", "duration_minutes": 14, "difficulty": "intermediate", "earning_impact": 0.09},
    {"skill": "design", "title": "Template packaging for repeat sales", "duration_minutes": 16, "difficulty": "intermediate", "earning_impact": 0.1},
    {"skill": "photography", "title": "Event shot list for faster delivery", "duration_minutes": 12, "difficulty": "beginner", "earning_impact": 0.07},
    {"skill": "editing", "title": "Batch editing workflow", "duration_minutes": 13, "difficulty": "intermediate", "earning_impact": 0.08},
]


def ensure_seed_opportunities(db: Session) -> None:
    existing = db.query(IncomeOpportunity).count()
    if existing > 0:
        return
    for item in DEFAULT_OPPORTUNITIES:
        db.add(
            IncomeOpportunity(
                source=item["source"],
                title=item["title"],
                description=item["description"],
                category=item["category"],
                payout_min=float(item["payout_min"]),
                payout_max=float(item["payout_max"]),
                estimated_minutes=int(item["estimated_minutes"]),
                location_mode=item["location_mode"],
                required_skills_json=json.dumps(item["required_skills"], default=str),
                verified=bool(item["verified"]),
                scam_risk_score=float(item["scam_risk_score"]),
                active=True,
                metadata_json="{}",
            )
        )
    db.commit()


def ensure_seed_skill_lessons(db: Session) -> None:
    existing = db.query(IncomeSkillLesson).count()
    if existing > 0:
        return
    for item in DEFAULT_SKILL_LESSONS:
        db.add(
            IncomeSkillLesson(
                skill=item["skill"],
                title=item["title"],
                duration_minutes=int(item["duration_minutes"]),
                difficulty=item["difficulty"],
                earning_impact=float(item["earning_impact"]),
                active=True,
            )
        )
    db.commit()


def ensure_profile(db: Session, user: User) -> IncomeProfile:
    row = db.query(IncomeProfile).filter(IncomeProfile.user_id == user.id).first()
    if row is None:
        row = IncomeProfile(
            user_id=user.id,
            daily_target=300.0,
            monthly_target=10000.0,
            skills_json="[]",
            location="",
            availability_hours_per_day=2.0,
            preferred_categories_json="[]",
            risk_mode="safe",
        )
        db.add(row)
        db.flush()
    return row


def _get_or_create_skill_profile(db: Session, user_id: str, skill: str) -> IncomeSkillProfile:
    normalized = skill.strip().lower()
    row = (
        db.query(IncomeSkillProfile)
        .filter(IncomeSkillProfile.user_id == user_id, IncomeSkillProfile.skill == normalized)
        .first()
    )
    if row is None:
        row = IncomeSkillProfile(
            user_id=user_id,
            skill=normalized[:80],
            proficiency=0.2,
            earnings_generated=0.0,
            attempts=0,
            completions=0,
            growth_score=0.0,
            last_used_at=None,
        )
        db.add(row)
        db.flush()
    return row


def _ensure_skill_profiles_for_user(db: Session, user: User, skills: list[str]) -> None:
    for skill in skills:
        if skill.strip():
            _get_or_create_skill_profile(db, user.id, skill)


def _scam_tag(score: float):
    if score >= 0.6:
        return "high"
    if score >= 0.3:
        return "medium"
    return "low"


def _action_out(row: IncomeAction):
    return {
        "id": row.id,
        "opportunity_id": row.opportunity_id,
        "status": row.status,
        "autofill_used": row.autofill_used,
        "proposal_drafted": row.proposal_drafted,
        "followup_scheduled": row.followup_scheduled,
        "expected_payout": row.expected_payout,
        "actual_payout": row.actual_payout,
        "notes": _safe_json(row.notes_json, {}),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def update_profile(db: Session, user: User, patch: dict[str, Any]):
    row = ensure_profile(db, user)
    if "daily_target" in patch:
        row.daily_target = max(10.0, round(float(patch["daily_target"]), 2))
    if "monthly_target" in patch:
        row.monthly_target = max(300.0, round(float(patch["monthly_target"]), 2))
    if "skills" in patch:
        normalized_skills = [str(x).strip().lower() for x in (patch.get("skills") or []) if str(x).strip()]
        row.skills_json = json.dumps(normalized_skills, default=str)
        _ensure_skill_profiles_for_user(db, user, normalized_skills)
    if "location" in patch:
        row.location = str(patch["location"])[:120]
    if "availability_hours_per_day" in patch:
        row.availability_hours_per_day = max(0.5, min(16.0, float(patch["availability_hours_per_day"])))
    if "preferred_categories" in patch:
        row.preferred_categories_json = json.dumps([str(x).strip().lower() for x in (patch.get("preferred_categories") or []) if str(x).strip()], default=str)
    if "risk_mode" in patch:
        normalized = str(patch.get("risk_mode", "safe")).strip().lower()
        if normalized not in {"safe", "balanced", "growth"}:
            raise HTTPException(status_code=400, detail="Unsupported risk_mode")
        row.risk_mode = normalized
    db.add(row)
    _audit(db, user.id, "income.profile.updated", "income_profile", user.id, patch)
    db.commit()
    db.refresh(row)
    return profile_out(row)


def profile_out(row: IncomeProfile):
    return {
        "daily_target": row.daily_target,
        "monthly_target": row.monthly_target,
        "skills": _safe_json(row.skills_json, []),
        "location": row.location,
        "availability_hours_per_day": row.availability_hours_per_day,
        "preferred_categories": _safe_json(row.preferred_categories_json, []),
        "risk_mode": row.risk_mode,
        "updated_at": _iso(row.updated_at),
    }


def _skill_profile_summary(db: Session, user: User):
    profile = ensure_profile(db, user)
    base_skills = _safe_json(profile.skills_json, [])
    _ensure_skill_profiles_for_user(db, user, base_skills)
    rows = (
        db.query(IncomeSkillProfile)
        .filter(IncomeSkillProfile.user_id == user.id)
        .order_by(IncomeSkillProfile.earnings_generated.desc(), IncomeSkillProfile.proficiency.desc())
        .all()
    )
    return [
        {
            "skill": row.skill,
            "proficiency": round(float(row.proficiency), 4),
            "level": min(10, max(1, int(round(float(row.proficiency) * 10)))),
            "earnings_generated": round(float(row.earnings_generated), 2),
            "attempts": int(row.attempts),
            "completions": int(row.completions),
            "growth_score": round(float(row.growth_score), 4),
            "last_used_at": _iso(row.last_used_at),
        }
        for row in rows
    ]


def _progression_level(earnings_month: float):
    thresholds = [
        ("starter", 0),
        ("builder", 1000),
        ("operator", 3000),
        ("pro", 6000),
        ("elite", 10000),
    ]
    current = "starter"
    next_level = "builder"
    next_threshold = 1000
    for idx, (name, amount) in enumerate(thresholds):
        if earnings_month >= amount:
            current = name
            if idx + 1 < len(thresholds):
                next_level, next_threshold = thresholds[idx + 1]
            else:
                next_level, next_threshold = name, amount
    remaining = max(0.0, round(next_threshold - earnings_month, 2))
    return {
        "current_level": current,
        "next_level": next_level,
        "remaining_to_next": remaining,
        "next_threshold": float(next_threshold),
    }


def _earnings_progress(db: Session, user: User):
    today_cutoff = _now() - timedelta(days=1)
    month_cutoff = _now() - timedelta(days=30)
    today = (
        db.query(IncomeAction)
        .filter(IncomeAction.user_id == user.id, IncomeAction.status == "completed", IncomeAction.updated_at >= today_cutoff)
        .all()
    )
    month = (
        db.query(IncomeAction)
        .filter(IncomeAction.user_id == user.id, IncomeAction.status == "completed", IncomeAction.updated_at >= month_cutoff)
        .all()
    )
    earnings_today = round(sum(float(x.actual_payout or x.expected_payout) for x in today), 2)
    earnings_month = round(sum(float(x.actual_payout or x.expected_payout) for x in month), 2)
    return earnings_today, earnings_month


def _behavior_category_bias(db: Session, user: User):
    actions = (
        db.query(IncomeAction)
        .filter(IncomeAction.user_id == user.id, IncomeAction.status.in_(["applied", "completed"]))
        .all()
    )
    counts: Counter[str] = Counter()
    if not actions:
        return counts
    opp_map = {
        x.id: x.category
        for x in db.query(IncomeOpportunity)
        .filter(IncomeOpportunity.id.in_([a.opportunity_id for a in actions]))
        .all()
    }
    for action in actions:
        cat = opp_map.get(action.opportunity_id)
        if cat:
            counts[cat] += 1
    return counts


def list_opportunities(db: Session, user: User, category: str | None = None, limit: int = 20):
    ensure_seed_opportunities(db)
    profile = ensure_profile(db, user)
    skills = set(_safe_json(profile.skills_json, []))
    preferred = set(_safe_json(profile.preferred_categories_json, []))
    behavior_bias = _behavior_category_bias(db, user)

    query = db.query(IncomeOpportunity).filter(IncomeOpportunity.active == True, IncomeOpportunity.verified == True)  # noqa: E712
    if category and category.lower() != "all":
        query = query.filter(IncomeOpportunity.category == category.lower())
    rows = query.order_by(IncomeOpportunity.created_at.desc()).limit(max(1, min(limit, 100))).all()

    scored = []
    for row in rows:
        req_skills = set(_safe_json(row.required_skills_json, []))
        skill_match = (len(req_skills.intersection(skills)) / max(len(req_skills), 1)) if req_skills else 0.6
        location_bonus = 0.2 if row.location_mode == "remote" else (0.1 if profile.location else 0.0)
        preference_bonus = 0.2 if row.category in preferred else 0.0
        behavior_bonus = min(0.2, behavior_bias.get(row.category, 0) * 0.05)
        safety_penalty = max(0.0, row.scam_risk_score - 0.1)
        score = max(0.0, min(1.0, 0.4 + skill_match * 0.3 + location_bonus + preference_bonus + behavior_bonus - safety_penalty))
        scored.append(
            {
                "id": row.id,
                "title": row.title,
                "description": row.description,
                "category": row.category,
                "payout_min": row.payout_min,
                "payout_max": row.payout_max,
                "estimated_minutes": row.estimated_minutes,
                "location_mode": row.location_mode,
                "required_skills": list(req_skills),
                "verified": row.verified,
                "scam_risk_score": row.scam_risk_score,
                "scam_risk_level": _scam_tag(row.scam_risk_score),
                "match_score": round(score, 4),
                "why_matched": [
                    f"Skill overlap: {len(req_skills.intersection(skills))}",
                    f"Preferred category: {'yes' if row.category in preferred else 'no'}",
                    f"Behavior fit: {behavior_bias.get(row.category, 0)} prior wins",
                ],
            }
        )
    scored.sort(key=lambda x: x["match_score"], reverse=True)
    return {"items": scored}


def _skill_money_mapping(db: Session, user: User):
    skills = _skill_profile_summary(db, user)
    opps = list_opportunities(db, user, limit=40)["items"]
    by_skill: dict[str, dict[str, Any]] = {}
    for row in opps:
        avg_pay = (float(row["payout_min"]) + float(row["payout_max"])) / 2.0
        for skill in row["required_skills"]:
            item = by_skill.setdefault(
                skill,
                {"skill": skill, "opportunity_count": 0, "avg_payout": 0.0, "top_categories": Counter()},
            )
            item["opportunity_count"] += 1
            item["avg_payout"] += avg_pay
            item["top_categories"][row["category"]] += 1
    result = []
    skill_index = {x["skill"]: x for x in skills}
    for skill, item in by_skill.items():
        opportunity_count = int(item["opportunity_count"])
        avg_payout = round(item["avg_payout"] / max(1, opportunity_count), 2)
        top_categories = [k for k, _ in item["top_categories"].most_common(2)]
        result.append(
            {
                "skill": skill,
                "opportunity_count": opportunity_count,
                "avg_payout": avg_payout,
                "top_categories": top_categories,
                "proficiency": float(skill_index.get(skill, {}).get("proficiency", 0.2)),
                "earnings_generated": float(skill_index.get(skill, {}).get("earnings_generated", 0.0)),
            }
        )
    result.sort(key=lambda x: (x["opportunity_count"], x["avg_payout"]), reverse=True)
    return result[:12]


def _earning_path_builder(db: Session, user: User, daily_target: float, earnings_today: float):
    remaining = max(0.0, round(daily_target - earnings_today, 2))
    if remaining <= 0:
        return {"remaining": 0.0, "steps": [], "summary": "Daily target reached."}
    opportunities = list_opportunities(db, user, limit=15)["items"]
    steps = []
    covered = 0.0
    for opp in opportunities:
        avg_payout = round((float(opp["payout_min"]) + float(opp["payout_max"])) / 2.0, 2)
        if avg_payout <= 0:
            continue
        steps.append(
            {
                "opportunity_id": opp["id"],
                "title": opp["title"],
                "category": opp["category"],
                "estimated_minutes": opp["estimated_minutes"],
                "expected_payout": avg_payout,
            }
        )
        covered += avg_payout
        if covered >= remaining or len(steps) >= 4:
            break
    return {
        "remaining": remaining,
        "steps": steps,
        "summary": f"Estimated ${round(covered, 2)} available from top {len(steps)} actions today.",
    }


def _skill_upgrade_suggestions(db: Session, user: User):
    ensure_seed_skill_lessons(db)
    skill_map = {x["skill"]: x for x in _skill_profile_summary(db, user)}
    lessons = db.query(IncomeSkillLesson).filter(IncomeSkillLesson.active == True).all()  # noqa: E712
    suggestions = []
    for lesson in lessons:
        row = skill_map.get(lesson.skill, {"proficiency": 0.2, "earnings_generated": 0.0})
        proficiency = float(row.get("proficiency", 0.2))
        if proficiency >= 0.9:
            continue
        suggestions.append(
            {
                "lesson_id": lesson.id,
                "skill": lesson.skill,
                "title": lesson.title,
                "duration_minutes": lesson.duration_minutes,
                "difficulty": lesson.difficulty,
                "earning_impact": lesson.earning_impact,
                "projected_proficiency_after": round(min(1.0, proficiency + lesson.earning_impact * 0.6), 4),
            }
        )
    suggestions.sort(key=lambda x: x["earning_impact"], reverse=True)
    return suggestions[:6]


def skills_dashboard(db: Session, user: User):
    profile = ensure_profile(db, user)
    daily, monthly = _earnings_progress(db, user)
    mapping = _skill_money_mapping(db, user)
    path = _earning_path_builder(db, user, profile.daily_target, daily)
    upgrades = _skill_upgrade_suggestions(db, user)
    return {
        "skills": _skill_profile_summary(db, user),
        "skill_to_money_mapping": mapping,
        "earning_path": path,
        "upgrades": upgrades,
        "progression": _progression_level(monthly),
    }


def _purchase_intelligence(db: Session, user: User, amount: float):
    intents = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.sender_id == user.id, PaymentIntent.status.in_(["created", "confirmed"]))
        .order_by(PaymentIntent.created_at.desc())
        .limit(120)
        .all()
    )
    month_spend = sum(float(i.amount) for i in intents if i.created_at >= (_now() - timedelta(days=30)))
    avg_daily = month_spend / 30 if month_spend else 0
    projected_month = month_spend + amount
    danger = projected_month > (month_spend * 1.25 if month_spend else amount > 250)
    note = (
        "This purchase may stress your monthly runway."
        if danger
        else "Purchase appears within current cash-flow pattern."
    )
    return {
        "amount": round(amount, 2),
        "month_spend": round(month_spend, 2),
        "avg_daily_spend": round(avg_daily, 2),
        "projected_month_spend": round(projected_month, 2),
        "warning": danger,
        "note": note,
    }


def _credit_optimization_stub(db: Session, user: User):
    intents = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.sender_id == user.id, PaymentIntent.status.in_(["created", "confirmed"]))
        .order_by(PaymentIntent.created_at.desc())
        .limit(90)
        .all()
    )
    card_like = sum(float(x.amount) for x in intents if x.kind in {"card", "credit_card", "invoice_payment"})
    utilization_estimate = min(95.0, round((card_like / 5000.0) * 100, 1))  # safe heuristic placeholder
    recommendation = "Keep estimated utilization under 30% for score improvement."
    return {
        "utilization_estimate_percent": utilization_estimate,
        "recommendation": recommendation,
        "status": "heuristic",
    }


def dashboard(db: Session, user: User):
    ensure_seed_opportunities(db)
    profile = ensure_profile(db, user)
    daily, monthly = _earnings_progress(db, user)
    opp = list_opportunities(db, user, limit=8)["items"]
    progress_daily = 0.0 if profile.daily_target <= 0 else min(1.0, round(daily / profile.daily_target, 4))
    progress_month = 0.0 if profile.monthly_target <= 0 else min(1.0, round(monthly / profile.monthly_target, 4))
    return {
        "targets": {
            "daily_target": profile.daily_target,
            "monthly_target": profile.monthly_target,
            "earnings_today": daily,
            "earnings_month": monthly,
            "daily_progress": progress_daily,
            "monthly_progress": progress_month,
        },
        "profile": profile_out(profile),
        "opportunities": opp,
        "purchase_intelligence": _purchase_intelligence(db, user, amount=50.0),
        "credit_optimization": _credit_optimization_stub(db, user),
        "skills_engine": skills_dashboard(db, user),
    }


def start_action(
    db: Session,
    user: User,
    opportunity_id: str,
    confirm: bool,
    autofill_profile: dict[str, Any] | None = None,
):
    row = db.query(IncomeOpportunity).filter(IncomeOpportunity.id == opportunity_id, IncomeOpportunity.active == True).first()  # noqa: E712
    if row is None:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    if not row.verified or row.scam_risk_score >= 0.5:
        raise HTTPException(status_code=400, detail="Opportunity blocked by safety checks")

    autofill = autofill_profile or {}
    preview = {
        "opportunity_id": row.id,
        "title": row.title,
        "estimated_payout_range": [row.payout_min, row.payout_max],
        "estimated_minutes": row.estimated_minutes,
        "autofill_fields": list(autofill.keys()),
        "requires_confirmation": True,
    }
    if not confirm:
        _audit(db, user.id, "income.action.previewed", "opportunity", row.id, preview)
        db.commit()
        return {"status": "preview", "preview": preview}

    expected = round((float(row.payout_min) + float(row.payout_max)) / 2, 2)
    action = IncomeAction(
        user_id=user.id,
        opportunity_id=row.id,
        status="started",
        autofill_used=bool(len(autofill) > 0),
        proposal_drafted=False,
        followup_scheduled=False,
        expected_payout=expected,
        actual_payout=0.0,
        notes_json=json.dumps({"autofill": autofill}, default=str),
    )
    db.add(action)
    _audit(
        db,
        user.id,
        "income.action.started",
        "income_action",
        action.id,
        {"opportunity_id": row.id, "expected_payout": expected, "autofill_used": action.autofill_used},
    )
    db.commit()
    db.refresh(action)
    return {"status": "started", "action": _action_out(action)}


def update_action_status(
    db: Session,
    user: User,
    action_id: str,
    status: str,
    actual_payout: float | None = None,
):
    row = db.query(IncomeAction).filter(IncomeAction.id == action_id, IncomeAction.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Action not found")
    normalized = status.lower().strip()
    if normalized not in {"started", "applied", "completed", "declined"}:
        raise HTTPException(status_code=400, detail="Unsupported action status")
    row.status = normalized
    if actual_payout is not None:
        row.actual_payout = max(0.0, round(float(actual_payout), 2))
    if normalized in {"applied", "completed"}:
        opp = db.query(IncomeOpportunity).filter(IncomeOpportunity.id == row.opportunity_id).first()
        if opp is not None:
            skill_list = _safe_json(opp.required_skills_json, [])
            payout = float(row.actual_payout or row.expected_payout or 0.0)
            for skill in skill_list:
                skill_row = _get_or_create_skill_profile(db, user.id, skill)
                skill_row.attempts = int(skill_row.attempts) + 1
                skill_row.last_used_at = _now()
                if normalized == "completed":
                    skill_row.completions = int(skill_row.completions) + 1
                    skill_row.earnings_generated = round(float(skill_row.earnings_generated) + payout, 2)
                    skill_row.proficiency = min(1.0, float(skill_row.proficiency) + 0.03)
                    skill_row.growth_score = round(float(skill_row.growth_score) + 0.05 + payout / 5000.0, 4)
                else:
                    skill_row.proficiency = min(1.0, float(skill_row.proficiency) + 0.01)
                    skill_row.growth_score = round(float(skill_row.growth_score) + 0.01, 4)
                db.add(skill_row)
    db.add(row)
    _audit(
        db,
        user.id,
        "income.action.updated",
        "income_action",
        row.id,
        {"status": row.status, "actual_payout": row.actual_payout},
    )
    db.commit()
    db.refresh(row)
    if normalized == "completed":
        coach_record_event(db, user, "action_completed", {"title": "Income action completed"})
    return _action_out(row)


def list_actions(db: Session, user: User):
    rows = db.query(IncomeAction).filter(IncomeAction.user_id == user.id).order_by(IncomeAction.updated_at.desc()).all()
    return {"items": [_action_out(x) for x in rows]}


def draft_proposal(db: Session, user: User, action_id: str):
    row = db.query(IncomeAction).filter(IncomeAction.id == action_id, IncomeAction.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Action not found")
    opp = db.query(IncomeOpportunity).filter(IncomeOpportunity.id == row.opportunity_id).first()
    if opp is None:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    profile = ensure_profile(db, user)
    skills = _safe_json(profile.skills_json, [])
    draft = (
        f"Hi, I can help with '{opp.title}'. "
        f"My relevant skills: {', '.join(skills[:5]) or 'execution, communication, reliability'}. "
        "I can start immediately and deliver high-quality work quickly."
    )
    row.proposal_drafted = True
    notes = _safe_json(row.notes_json, {})
    notes["proposal_draft"] = draft
    row.notes_json = json.dumps(notes, default=str)
    db.add(row)
    _audit(db, user.id, "income.automation.proposal_drafted", "income_action", row.id, {"opportunity_id": row.opportunity_id})
    db.commit()
    db.refresh(row)
    return {"action_id": row.id, "proposal_draft": draft}


def schedule_followup(db: Session, user: User, action_id: str, hours_until_followup: int = 24):
    row = db.query(IncomeAction).filter(IncomeAction.id == action_id, IncomeAction.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Action not found")
    row.followup_scheduled = True
    notes = _safe_json(row.notes_json, {})
    notes["followup_at"] = (_now() + timedelta(hours=max(1, min(hours_until_followup, 168)))).isoformat()
    row.notes_json = json.dumps(notes, default=str)
    db.add(row)
    _audit(db, user.id, "income.automation.followup_scheduled", "income_action", row.id, {"hours_until_followup": hours_until_followup})
    db.commit()
    db.refresh(row)
    return {"action_id": row.id, "followup_at": notes["followup_at"]}


def complete_lesson(db: Session, user: User, lesson_id: str):
    ensure_seed_skill_lessons(db)
    lesson = db.query(IncomeSkillLesson).filter(IncomeSkillLesson.id == lesson_id, IncomeSkillLesson.active == True).first()  # noqa: E712
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    skill_row = _get_or_create_skill_profile(db, user.id, lesson.skill)
    before = float(skill_row.proficiency)
    skill_row.proficiency = min(1.0, before + float(lesson.earning_impact) * 0.5)
    skill_row.growth_score = round(float(skill_row.growth_score) + float(lesson.earning_impact), 4)
    db.add(skill_row)
    _audit(
        db,
        user.id,
        "income.skill.lesson_completed",
        "lesson",
        lesson.id,
        {"skill": lesson.skill, "proficiency_before": before, "proficiency_after": skill_row.proficiency},
    )
    db.commit()
    db.refresh(skill_row)
    return {
        "lesson_id": lesson.id,
        "skill": lesson.skill,
        "proficiency_before": round(before, 4),
        "proficiency_after": round(float(skill_row.proficiency), 4),
    }


def auto_optimize_recommendations(db: Session, user: User):
    profile = ensure_profile(db, user)
    daily, _ = _earnings_progress(db, user)
    remaining = max(0.0, profile.daily_target - daily)
    mapping = _skill_money_mapping(db, user)
    top_skills = mapping[:3]
    suggestions = []
    for item in top_skills:
        if item["proficiency"] < 0.7:
            suggestions.append(
                {
                    "type": "upgrade_skill",
                    "skill": item["skill"],
                    "reason": f"Higher demand + avg payout ${item['avg_payout']}",
                }
            )
        else:
            suggestions.append(
                {
                    "type": "prioritize_opportunities",
                    "skill": item["skill"],
                    "reason": f"Strong skill fit and {item['opportunity_count']} open matches",
                }
            )
    if remaining > 0:
        suggestions.append(
            {
                "type": "target_recovery",
                "reason": f"${round(remaining, 2)} remaining toward daily target",
            }
        )
    return {"items": suggestions[:4]}


def coach_record_event(db: Session, user: User, event_type: str, payload: dict[str, Any] | None = None):
    data = payload or {}
    snap = _ensure_daily_snapshot(db, user)
    points_map = {
        "open_wallet": 1,
        "run_next_action": 2,
        "lesson_completed": 3,
        "opportunity_started": 3,
        "action_completed": 5,
        "proposal_drafted": 2,
    }
    points = points_map.get(event_type.strip().lower(), 1)
    snap.engagement_points = int(snap.engagement_points or 0) + points
    if event_type.strip().lower() in {"action_completed", "lesson_completed", "opportunity_started"}:
        snap.completed_actions = int(snap.completed_actions or 0) + 1

    rewards = _safe_json(snap.micro_rewards_json, [])
    rewards.append(
        {
            "event_type": event_type,
            "title": data.get("title") or f"{event_type.replace('_', ' ').title()} logged",
            "xp": points,
            "created_at": _now().isoformat(),
        }
    )
    snap.micro_rewards_json = json.dumps(_micro_rewards_out(rewards), default=str)
    snap.last_event_at = _now()
    snap.streak_count = _streak_count(db, user)
    db.add(snap)
    _audit(db, user.id, "coach.event.recorded", "daily_coach_snapshot", snap.id, {"event_type": event_type, "points": points})
    db.commit()
    db.refresh(snap)
    return {
        "date_key": snap.date_key,
        "engagement_points": int(snap.engagement_points or 0),
        "completed_actions": int(snap.completed_actions or 0),
        "streak_count": int(snap.streak_count or 0),
        "micro_rewards": _safe_json(snap.micro_rewards_json, []),
    }


def _effective_tone(db: Session, user: User, progress_today: float, streak_count: int, earnings_today: float, daily_goal: float):
    pref = _ensure_tone_pref(db, user).tone_mode
    # Adaptive policy:
    # - near goal => encouraging
    # - missed/low progress => supportive
    # - high performance + strong streak => direct
    if progress_today >= 0.9:
        adaptive = "supportive"
    elif progress_today < 0.4 and streak_count <= 2:
        adaptive = "supportive"
    elif progress_today >= 0.7 and streak_count >= 3 and earnings_today >= daily_goal * 0.6:
        adaptive = "direct"
    elif progress_today >= 1.0 and streak_count >= 7:
        adaptive = "direct"
    else:
        adaptive = pref
    if pref == "aggressive" and progress_today < 0.5:
        # Guardrail: avoid punitive tone on low-performance days.
        adaptive = "supportive"
    return {"preferred_tone": pref, "adaptive_tone": adaptive}


def _tone_wrap(tone: str, text: str):
    clean = text.strip()
    if tone == "direct":
        return clean
    if tone == "aggressive":
        return f"{clean} Push now."
    return f"{clean} You’re on track."


def _tone_list(tone: str, lines: list[str]):
    return [_tone_wrap(tone, x) for x in lines if str(x).strip()]


def coach_morning_brief(db: Session, user: User):
    core = dashboard(db, user)
    loop = unified_loop_overview(db, user)
    snap = _ensure_daily_snapshot(db, user)
    targets = core.get("targets", {})
    daily_goal = float(targets.get("daily_target", 300.0))
    progress_today = float(targets.get("daily_progress", 0.0))
    earnings_today = float(targets.get("earnings_today", 0.0))
    tone = _effective_tone(db, user, progress_today, int(snap.streak_count or 0), earnings_today, daily_goal)
    next_actions = loop.get("next_actions", [])
    dominant = next_actions[0] if next_actions else None
    alerts = []
    purchase = core.get("purchase_intelligence", {})
    if purchase.get("warning"):
        alerts.append("Spending alert: keep today non-essential purchases low.")
    if float(loop.get("daily_remaining", 0.0)) > 0:
        alerts.append(f"${loop.get('daily_remaining', 0.0)} remaining to hit daily goal.")
    plan = {
        "daily_goal": daily_goal,
        "progress_today": progress_today,
        "dominant_action": dominant,
        "alerts": _tone_list(tone["adaptive_tone"], alerts[:3]),
        "simple_plan": _tone_list(tone["adaptive_tone"], [x.get("title", "") for x in next_actions[:3]]),
        "tone_mode": tone["adaptive_tone"],
    }
    snap.morning_plan_json = json.dumps(plan, default=str)
    snap.streak_count = _streak_count(db, user)
    db.add(snap)
    db.commit()
    return {
        "streak_count": int(snap.streak_count or 0),
        "brief": plan,
        "tone": tone,
    }


def coach_active_guidance(db: Session, user: User):
    loop = unified_loop_overview(db, user)
    targets = dashboard(db, user).get("targets", {})
    snap = _ensure_daily_snapshot(db, user)
    tone = _effective_tone(
        db,
        user,
        float(targets.get("daily_progress", 0.0)),
        int(snap.streak_count or 0),
        float(targets.get("earnings_today", 0.0)),
        float(targets.get("daily_target", 300.0)),
    )
    opportunities = list_opportunities(db, user, limit=5)["items"]
    compare = []
    if len(opportunities) >= 2:
        a, b = opportunities[0], opportunities[1]
        a_rate = round(((a["payout_min"] + a["payout_max"]) / 2) / max(1, a["estimated_minutes"]), 2)
        b_rate = round(((b["payout_min"] + b["payout_max"]) / 2) / max(1, b["estimated_minutes"]), 2)
        better = a if a_rate >= b_rate else b
        compare.append(
            {
                "title": "Opportunity comparison",
                "detail": f"Best rate now: {better['title']} (${max(a_rate, b_rate)}/min est).",
            }
        )
    return {
        "dominant_action": (loop.get("next_actions") or [None])[0],
        "prompts": [
            {"label": _tone_wrap(tone["adaptive_tone"], x.get("title", "")), "action_type": x.get("action_type", ""), "ref_id": x.get("ref_id", "")}
            for x in loop.get("next_actions", [])[:3]
        ],
        "decision_support": [{"title": x["title"], "detail": _tone_wrap(tone["adaptive_tone"], x["detail"])} for x in compare],
        "tone": tone,
    }


def coach_end_of_day_review(db: Session, user: User):
    core = dashboard(db, user)
    snap = _ensure_daily_snapshot(db, user)
    targets = core.get("targets", {})
    tone = _effective_tone(
        db,
        user,
        float(targets.get("daily_progress", 0.0)),
        int(snap.streak_count or 0),
        float(targets.get("earnings_today", 0.0)),
        float(targets.get("daily_target", 300.0)),
    )
    actions_today = (
        db.query(IncomeAction)
        .filter(IncomeAction.user_id == user.id, IncomeAction.updated_at >= (_now() - timedelta(days=1)))
        .all()
    )
    completed = [x for x in actions_today if x.status == "completed"]
    wins = []
    if completed:
        wins.append(f"Completed {len(completed)} income actions.")
    if float(core.get("targets", {}).get("daily_progress", 0.0)) >= 1.0:
        wins.append("Daily earnings target reached.")
    if int(snap.completed_actions or 0) > 0:
        wins.append(f"Executed {int(snap.completed_actions)} meaningful steps today.")
    next_steps = [x.get("title", "") for x in unified_loop_overview(db, user).get("next_actions", [])[:2]]
    review = {
        "earnings_today": float(targets.get("earnings_today", 0.0)),
        "daily_target": float(targets.get("daily_target", 300.0)),
        "wins": _tone_list(tone["adaptive_tone"], wins[:4]),
        "next_steps": _tone_list(tone["adaptive_tone"], next_steps),
        "tone_mode": tone["adaptive_tone"],
    }
    snap.end_day_review_json = json.dumps(review, default=str)
    db.add(snap)
    db.commit()
    out = dict(review)
    out["tone"] = tone
    return out


def coach_weekly(db: Session, user: User):
    since = _now() - timedelta(days=7)
    actions = db.query(IncomeAction).filter(IncomeAction.user_id == user.id, IncomeAction.updated_at >= since).all()
    completed = [x for x in actions if x.status == "completed"]
    earnings = round(sum(float(x.actual_payout or x.expected_payout) for x in completed), 2)
    by_day: dict[str, float] = {}
    for action in completed:
        key = _date_key(action.updated_at or _now())
        by_day[key] = round(by_day.get(key, 0.0) + float(action.actual_payout or action.expected_payout or 0.0), 2)
    trend = "up" if len(by_day) >= 2 and list(by_day.values())[-1] >= list(by_day.values())[0] else "stable"
    profile = ensure_profile(db, user)
    avg_daily = round(earnings / 7.0, 2)
    tone = _effective_tone(
        db,
        user,
        min(1.0, avg_daily / max(1.0, float(profile.daily_target))),
        _streak_count(db, user),
        avg_daily,
        float(profile.daily_target),
    )
    return {
        "weekly_earnings": earnings,
        "completed_actions": len(completed),
        "trend": trend,
        "daily_breakdown": [{"date": k, "earnings": v} for k, v in sorted(by_day.items())],
        "strategy": _tone_list(tone["adaptive_tone"], [
            "Prioritize highest match opportunities first.",
            "Complete one skill lesson before noon for better proposal quality.",
            "Review spending alert before non-essential purchases.",
        ]),
        "tone": tone,
    }


def _applications_summary(db: Session, user: User):
    since = _now() - timedelta(days=30)
    templates_created = (
        db.query(ApplicationTemplate)
        .filter(ApplicationTemplate.business_user_id == user.id, ApplicationTemplate.created_at >= since)
        .count()
    )
    requests_sent = (
        db.query(ApplicationInstance)
        .filter(ApplicationInstance.requester_user_id == user.id, ApplicationInstance.created_at >= since)
        .count()
    )
    submitted = (
        db.query(ApplicationInstance)
        .filter(
            ApplicationInstance.requester_user_id == user.id,
            ApplicationInstance.status.in_(["submitted", "completed"]),
            ApplicationInstance.created_at >= since,
        )
        .count()
    )
    profiles_saved = db.query(ApplicationUserProfile).filter(ApplicationUserProfile.user_id == user.id).count()
    completion_rate = 0.0 if requests_sent == 0 else round(submitted / requests_sent, 4)
    return {
        "templates_created_30d": int(templates_created),
        "requests_sent_30d": int(requests_sent),
        "submitted_30d": int(submitted),
        "completion_rate": completion_rate,
        "profiles_saved": int(profiles_saved),
    }


def unified_loop_overview(db: Session, user: User):
    core = dashboard(db, user)
    skills = core.get("skills_engine", {})
    targets = core.get("targets", {})
    opportunities = core.get("opportunities", [])
    _ = opportunities
    app_stats = _applications_summary(db, user)
    snap = _ensure_daily_snapshot(db, user)

    # Financial read-only snapshot is imported lazily to avoid service hard-coupling at import time.
    from backend.services.finance_hub.service import generate_read_only_analysis  # local import by design

    finance = generate_read_only_analysis(db, user)
    daily_remaining = max(0.0, round(float(targets.get("daily_target", 300.0)) - float(targets.get("earnings_today", 0.0)), 2))

    stage_scores = {
        "skills": round(min(1.0, (sum(float(x.get("proficiency", 0.0)) for x in skills.get("skills", [])[:5]) / max(1, len(skills.get("skills", [])[:5])))), 4)
        if skills.get("skills")
        else 0.2,
        "income": float(targets.get("daily_progress", 0.0)),
        "financial": 0.3 if finance.get("cash_flow", {}).get("trend_percent", 0) > 10 else 0.7,
        "applications": min(1.0, float(app_stats.get("completion_rate", 0.0)) + (0.2 if app_stats.get("profiles_saved", 0) > 0 else 0.0)),
    }
    overall = round(sum(stage_scores.values()) / 4.0, 4)

    next_actions: list[dict[str, Any]] = []
    upgrades = skills.get("upgrades", [])
    path_steps = skills.get("earning_path", {}).get("steps", [])
    optimize = auto_optimize_recommendations(db, user).get("items", [])

    if upgrades:
        top = upgrades[0]
        next_actions.append(
            {
                "action_type": "complete_lesson",
                "title": f"Upgrade {top.get('skill')} in {top.get('duration_minutes')}m",
                "subtitle": top.get("title", ""),
                "ref_id": top.get("lesson_id", ""),
            }
        )
    if path_steps and daily_remaining > 0:
        step = path_steps[0]
        next_actions.append(
            {
                "action_type": "preview_opportunity",
                "title": f"Start {step.get('title')}",
                "subtitle": f"Est. ${step.get('expected_payout')} toward today target",
                "ref_id": step.get("opportunity_id", ""),
            }
        )
    if app_stats.get("profiles_saved", 0) == 0:
        next_actions.append(
            {
                "action_type": "open_applications",
                "title": "Set application profile once",
                "subtitle": "Reuse it for faster submissions",
                "ref_id": "",
            }
        )
    if finance.get("opportunities"):
        next_actions.append(
            {
                "action_type": "run_finance_analysis",
                "title": "Review spending optimization",
                "subtitle": "Use savings insights to increase runway",
                "ref_id": "",
            }
        )
    if optimize:
        hint = optimize[0]
        next_actions.append(
            {
                "action_type": "optimize_focus",
                "title": "Focus optimization",
                "subtitle": hint.get("reason", ""),
                "ref_id": hint.get("skill", ""),
            }
        )

    stages = [
        {"key": "skills", "label": "Skills → Income", "score": stage_scores["skills"]},
        {"key": "income", "label": "Income → Financial", "score": stage_scores["income"]},
        {"key": "financial", "label": "Financial → Applications", "score": stage_scores["financial"]},
        {"key": "applications", "label": "Applications → Skills", "score": stage_scores["applications"]},
    ]
    dominant_action = next_actions[0] if next_actions else None
    active_stage = min(stages, key=lambda x: x["score"])["key"] if stages else "skills"
    level = _coach_level_from_monthly(float(targets.get("earnings_month", 0.0)))
    progress_percent = round(float(targets.get("daily_progress", 0.0)) * 100, 2)

    return {
        "overall_score": overall,
        "daily_remaining": daily_remaining,
        "stages": stages,
        "active_stage": active_stage,
        "metrics": {
            "earnings_today": targets.get("earnings_today", 0.0),
            "daily_target": targets.get("daily_target", 300.0),
            "cashflow_trend_percent": finance.get("cash_flow", {}).get("trend_percent", 0.0),
            "application_completion_rate": app_stats.get("completion_rate", 0.0),
        },
        "habit": {
            "streak_count": _streak_count(db, user),
            "engagement_points": int(snap.engagement_points or 0),
            "progress_percent": progress_percent,
            "level": level,
            "micro_rewards": _safe_json(snap.micro_rewards_json, []),
            "dominant_action": dominant_action,
        },
        "next_actions": next_actions[:5],
    }


def unified_loop_advance(db: Session, user: User, action_type: str, ref_id: str = "", confirm: bool = False):
    normalized = action_type.strip().lower()
    if normalized == "complete_lesson":
        if not ref_id:
            raise HTTPException(status_code=400, detail="lesson ref_id required")
        result = complete_lesson(db, user, ref_id)
        coach_record_event(db, user, "lesson_completed", {"title": "Skill lesson completed"})
        return {"status": "ok", "action_type": normalized, "result": result}
    if normalized == "preview_opportunity":
        if not ref_id:
            raise HTTPException(status_code=400, detail="opportunity ref_id required")
        result = start_action(db, user, ref_id, confirm=False, autofill_profile={"source": "unified_loop"})
        coach_record_event(db, user, "run_next_action", {"title": "Opportunity preview generated"})
        return {"status": "ok", "action_type": normalized, "result": result}
    if normalized == "start_opportunity":
        if not ref_id:
            raise HTTPException(status_code=400, detail="opportunity ref_id required")
        if not confirm:
            raise HTTPException(status_code=400, detail="confirm=true required")
        result = start_action(db, user, ref_id, confirm=True, autofill_profile={"source": "unified_loop"})
        coach_record_event(db, user, "opportunity_started", {"title": "Opportunity started"})
        return {"status": "ok", "action_type": normalized, "result": result}
    if normalized == "run_finance_analysis":
        from backend.services.finance_hub.service import generate_read_only_analysis  # local import by design

        result = generate_read_only_analysis(db, user)
        coach_record_event(db, user, "run_next_action", {"title": "Financial analysis run"})
        return {"status": "ok", "action_type": normalized, "result": result}
    if normalized in {"open_applications", "optimize_focus"}:
        coach_record_event(db, user, "run_next_action", {"title": normalized.replace("_", " ").title()})
        return {"status": "ok", "action_type": normalized, "result": {"hint": "handled_in_client"}}
    raise HTTPException(status_code=400, detail="Unsupported unified-loop action")


def list_audit_logs(db: Session, user: User, limit: int = 200):
    rows = (
        db.query(IncomeAuditLog)
        .filter(IncomeAuditLog.user_id == user.id)
        .order_by(IncomeAuditLog.created_at.desc())
        .limit(max(1, min(limit, 500)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "event_type": row.event_type,
                "entity_type": row.entity_type,
                "entity_id": row.entity_id,
                "detail": _safe_json(row.detail_json, {}),
                "created_at": _iso(row.created_at),
            }
            for row in rows
        ]
    }
