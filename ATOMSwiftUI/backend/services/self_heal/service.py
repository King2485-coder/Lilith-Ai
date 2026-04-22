from __future__ import annotations

import json
import os
from collections import Counter
from typing import Any

import httpx
from sqlalchemy.orm import Session

from backend.core.redis import get_redis
from backend.models.self_heal import RuntimeFixAction, RuntimeIncident, RuntimeOptimizationSuggestion
from backend.realtime.manager import realtime_manager


SAFE_RETRY_ROUTE_PREFIXES = ("/api/v1/tools/", "/api/v1/browser/analyze", "/api/v1/growth/send-email")
SAFE_RESTART_SERVICES = {"realtime", "redis"}
SAFE_CACHE_PREFIX = "lilith:"


def classify_incident(category: str, status_code: int | None = None, route: str = "") -> str:
    if category == "slow_response":
        return "performance"
    if category == "websocket_issue":
        return "network"
    if category == "api_error":
        if status_code in {401, 403} or "/auth" in route:
            return "auth"
        if status_code in {502, 503, 504}:
            return "network"
    return "runtime"


def record_incident(
    db: Session,
    *,
    category: str,
    summary: str,
    severity: str = "medium",
    route: str = "",
    details: dict[str, Any] | None = None,
    status_code: int | None = None,
) -> RuntimeIncident:
    row = RuntimeIncident(
        category=category,
        classification=classify_incident(category, status_code=status_code, route=route),
        severity=severity,
        summary=summary[:255],
        route=route[:255],
        details_json=json.dumps(details or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def record_fix_action(
    db: Session,
    *,
    action_type: str,
    status: str,
    result: dict[str, Any] | None = None,
    incident_id: str | None = None,
) -> RuntimeFixAction:
    row = RuntimeFixAction(
        incident_id=incident_id,
        action_type=action_type,
        status=status,
        result_json=json.dumps(result or {}, default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_incidents(db: Session, limit: int = 200) -> list[RuntimeIncident]:
    return db.query(RuntimeIncident).order_by(RuntimeIncident.created_at.desc()).limit(max(1, min(limit, 500))).all()


def generate_optimization_suggestions(db: Session) -> list[dict[str, str]]:
    rows = db.query(RuntimeIncident).order_by(RuntimeIncident.created_at.desc()).limit(500).all()
    counts = Counter([row.classification for row in rows])
    suggestions: list[dict[str, str]] = []
    if counts.get("performance", 0) >= 3:
        suggestions.append(
            {
                "kind": "caching",
                "title": "Cache frequently requested endpoints",
                "rationale": "Multiple slow responses detected.",
                "suggestion": "Apply short-lived Redis caching for read-heavy GET routes.",
            }
        )
    if counts.get("runtime", 0) >= 3:
        suggestions.append(
            {
                "kind": "query",
                "title": "Optimize database query paths",
                "rationale": "Runtime issues suggest expensive DB operations.",
                "suggestion": "Add indexes and reduce ORM query fanout on hot routes.",
            }
        )
    if counts.get("network", 0) >= 3:
        suggestions.append(
            {
                "kind": "batching",
                "title": "Batch outbound realtime payloads",
                "rationale": "Frequent network/websocket instability detected.",
                "suggestion": "Coalesce high-frequency events and apply jittered retries.",
            }
        )
    for item in suggestions:
        exists = (
            db.query(RuntimeOptimizationSuggestion)
            .filter(RuntimeOptimizationSuggestion.title == item["title"], RuntimeOptimizationSuggestion.active.is_(True))
            .first()
        )
        if exists is None:
            db.add(
                RuntimeOptimizationSuggestion(
                    kind=item["kind"],
                    title=item["title"],
                    rationale=item["rationale"],
                    suggestion=item["suggestion"],
                    active=True,
                )
            )
    db.commit()
    return suggestions


async def safe_retry_request(method: str, path: str, token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    if method.upper() not in {"GET", "POST"}:
        raise ValueError("Retry allowed only for GET/POST")
    if not any(path.startswith(prefix) for prefix in SAFE_RETRY_ROUTE_PREFIXES):
        raise ValueError("Path not allowed by retry guardrail")
    base_url = os.getenv("SELF_HEAL_INTERNAL_BASE_URL", "http://127.0.0.1:8000")
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.request(
            method=method.upper(),
            url=f"{base_url}{path}",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json=body or None,
        )
    return {"status_code": response.status_code, "body": response.text[:2000]}


async def safe_restart_service(service_name: str) -> dict[str, Any]:
    if service_name not in SAFE_RESTART_SERVICES:
        raise ValueError("Service not allowed by restart guardrail")
    if service_name == "realtime":
        await realtime_manager.shutdown()
        await realtime_manager.startup()
        return {"service": service_name, "status": "restarted"}
    redis = await get_redis()
    if redis is None:
        return {"service": service_name, "status": "unavailable"}
    await redis.ping()
    return {"service": service_name, "status": "healthy"}


async def safe_clear_cache(prefix: str = SAFE_CACHE_PREFIX) -> dict[str, Any]:
    if not prefix.startswith(SAFE_CACHE_PREFIX):
        raise ValueError("Cache prefix blocked by guardrail")
    redis = await get_redis()
    if redis is None:
        return {"status": "noop", "deleted": 0}
    keys = await redis.keys(f"{prefix}*")
    if not keys:
        return {"status": "ok", "deleted": 0}
    deleted = await redis.delete(*keys)
    return {"status": "ok", "deleted": int(deleted)}

