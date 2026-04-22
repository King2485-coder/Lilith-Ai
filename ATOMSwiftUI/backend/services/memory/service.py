from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from backend.models.neurocloud import GlobalLearningAggregate, UserMemory

MAX_RECENT_COMMANDS = 50


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _utc_ts(dt: datetime | None) -> int:
    if dt is None:
        return 0
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp() * 1000)


def _to_response(row: UserMemory) -> dict[str, Any]:
    return {
        "version": 1,
        "updated_at": _utc_ts(row.updated_at),
        "profile_type": row.profile_type or "casual_user",
        "frequent_contacts": _safe_json(row.frequent_contacts, {}),
        "frequent_intents": _safe_json(row.frequent_intents, {}),
        "recent_commands": _safe_json(row.recent_commands, [])[:MAX_RECENT_COMMANDS],
        "last_used_entities": _safe_json(row.last_used_entities, {}),
        "context_usage": _safe_json(row.context_usage, {}),
        "prediction_feedback": _safe_json(row.prediction_feedback, {}),
        "macros": _safe_json(row.macros_json, {}),
    }


def _merge_count_maps(current: dict[str, int], incoming: dict[str, int]) -> dict[str, int]:
    merged = {**(current or {})}
    for key, value in (incoming or {}).items():
        merged[str(key)] = int(merged.get(str(key), 0)) + int(value or 0)
    return merged


def _merge_recent_commands(current: list[dict], incoming: list[dict]) -> list[dict]:
    all_items = [*(incoming or []), *(current or [])]
    all_items.sort(key=lambda item: int(item.get("ts", 0)), reverse=True)
    deduped: list[dict] = []
    seen: set[str] = set()
    for item in all_items:
        fingerprint = f"{item.get('ts')}::{item.get('command')}::{item.get('intent_type')}"
        if fingerprint in seen:
            continue
        seen.add(fingerprint)
        deduped.append(item)
        if len(deduped) >= MAX_RECENT_COMMANDS:
            break
    return deduped


def _ensure_row(db: Session, user_id: str) -> UserMemory:
    row = db.query(UserMemory).filter(UserMemory.user_id == user_id).first()
    if row is None:
        row = UserMemory(
            user_id=user_id,
            frequent_contacts="{}",
            frequent_intents="{}",
            recent_commands="[]",
            last_used_entities="{}",
            context_usage="{}",
            profile_type="casual_user",
            prediction_feedback="{}",
            macros_json="{}",
        )
        db.add(row)
        db.flush()
    return row


def _ensure_global(db: Session) -> GlobalLearningAggregate:
    row = db.query(GlobalLearningAggregate).filter(GlobalLearningAggregate.id == "global").first()
    if row is None:
        row = GlobalLearningAggregate(
            id="global",
            successful_commands="{}",
            failed_intents="{}",
            common_patterns="{}",
            prediction_stats="{}",
        )
        db.add(row)
        db.flush()
    return row


def _update_global_learning(
    db: Session,
    patch: dict[str, Any],
    incoming_recent: list[dict],
    prediction_feedback: dict[str, Any],
):
    row = _ensure_global(db)
    success = _safe_json(row.successful_commands, {})
    failed = _safe_json(row.failed_intents, {})
    patterns = _safe_json(row.common_patterns, {})
    pred = _safe_json(row.prediction_stats, {})

    incoming_intents = patch.get("frequent_intents") or {}
    for intent, count in incoming_intents.items():
        success[intent] = int(success.get(intent, 0)) + int(count or 0)

    for cmd in incoming_recent:
        command = str(cmd.get("command", "")).lower()
        if not command:
            continue
        patterns[command] = int(patterns.get(command, 0)) + 1
        if not bool(cmd.get("success", True)):
            failed[cmd.get("intent_type", "unknown")] = int(failed.get(cmd.get("intent_type", "unknown"), 0)) + 1

    if prediction_feedback:
        pred["shown"] = int(pred.get("shown", 0)) + int(prediction_feedback.get("shown", 0) or 0)
        pred["used"] = int(pred.get("used", 0)) + int(prediction_feedback.get("used", 0) or 0)
        pred["correct"] = int(pred.get("correct", 0)) + int(prediction_feedback.get("correct", 0) or 0)

    row.successful_commands = json.dumps(success, default=str)
    row.failed_intents = json.dumps(failed, default=str)
    row.common_patterns = json.dumps(patterns, default=str)
    row.prediction_stats = json.dumps(pred, default=str)
    row.updated_at = datetime.utcnow()
    db.add(row)


def get_user_memory(db: Session, user_id: str) -> dict[str, Any]:
    row = _ensure_row(db, user_id)
    db.commit()
    db.refresh(row)
    return _to_response(row)


def get_global_learning(db: Session) -> dict[str, Any]:
    row = _ensure_global(db)
    db.commit()
    db.refresh(row)
    return {
        "successful_commands": _safe_json(row.successful_commands, {}),
        "failed_intents": _safe_json(row.failed_intents, {}),
        "common_patterns": _safe_json(row.common_patterns, {}),
        "prediction_stats": _safe_json(row.prediction_stats, {}),
        "updated_at": _utc_ts(row.updated_at),
    }


def update_user_memory(db: Session, user_id: str, patch: dict[str, Any], client_updated_at: int | None = None) -> dict[str, Any]:
    row = _ensure_row(db, user_id)
    current = _to_response(row)

    incoming_contacts = patch.get("frequent_contacts") or {}
    incoming_intents = patch.get("frequent_intents") or {}
    incoming_context = patch.get("context_usage") or {}
    incoming_recent = patch.get("recent_commands") or []
    incoming_entities = patch.get("last_used_entities") or {}
    incoming_profile = patch.get("profile_type") or current.get("profile_type") or "casual_user"
    incoming_prediction_feedback = patch.get("prediction_feedback") or {}
    incoming_macros = patch.get("macros") or {}

    merged_contacts = _merge_count_maps(current.get("frequent_contacts", {}), incoming_contacts)
    merged_intents = _merge_count_maps(current.get("frequent_intents", {}), incoming_intents)
    merged_context = _merge_count_maps(current.get("context_usage", {}), incoming_context)
    merged_recent = _merge_recent_commands(current.get("recent_commands", []), incoming_recent)

    local_ts = int(current.get("updated_at", 0))
    incoming_ts = int(client_updated_at or patch.get("updated_at") or 0)
    if incoming_ts >= local_ts:
      merged_entities = {**current.get("last_used_entities", {}), **incoming_entities}
    else:
      merged_entities = current.get("last_used_entities", {})

    merged_feedback = {**current.get("prediction_feedback", {}), **incoming_prediction_feedback}
    merged_macros = {**current.get("macros", {}), **incoming_macros}

    row.frequent_contacts = json.dumps(merged_contacts, default=str)
    row.frequent_intents = json.dumps(merged_intents, default=str)
    row.context_usage = json.dumps(merged_context, default=str)
    row.recent_commands = json.dumps(merged_recent, default=str)
    row.last_used_entities = json.dumps(merged_entities, default=str)
    row.profile_type = str(incoming_profile)
    row.prediction_feedback = json.dumps(merged_feedback, default=str)
    row.macros_json = json.dumps(merged_macros, default=str)
    row.updated_at = datetime.utcnow()
    db.add(row)

    _update_global_learning(db, patch, incoming_recent, incoming_prediction_feedback)

    db.commit()
    db.refresh(row)
    return _to_response(row)
