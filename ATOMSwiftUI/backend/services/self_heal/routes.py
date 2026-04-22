from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.self_heal import RuntimeOptimizationSuggestion
from backend.models.user import User
from backend.services.self_heal.service import (
    generate_optimization_suggestions,
    list_incidents,
    record_fix_action,
    record_incident,
    safe_clear_cache,
    safe_restart_service,
    safe_retry_request,
)


router = APIRouter(prefix="/self-heal", tags=["self-heal"])


class RetryPayload(BaseModel):
    method: str
    path: str
    body: dict | None = None
    incident_id: str | None = None


class RestartPayload(BaseModel):
    service_name: str
    incident_id: str | None = None


class ClearCachePayload(BaseModel):
    prefix: str = "lilith:"
    incident_id: str | None = None


@router.get("/issues")
def issues(limit: int = 200, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_incidents(db, limit=limit)
    return {
        "items": [
            {
                "id": row.id,
                "category": row.category,
                "classification": row.classification,
                "severity": row.severity,
                "summary": row.summary,
                "route": row.route,
                "resolved": row.resolved,
                "details": json.loads(row.details_json or "{}"),
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/analyze")
def analyze(db: Session = Depends(get_db), user: User = Depends(current_user)):
    suggestions = generate_optimization_suggestions(db)
    return {"generated": suggestions}


@router.get("/optimizations")
def optimizations(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = db.query(RuntimeOptimizationSuggestion).filter(RuntimeOptimizationSuggestion.active.is_(True)).order_by(RuntimeOptimizationSuggestion.created_at.desc()).all()
    return {
        "items": [
            {
                "id": row.id,
                "kind": row.kind,
                "title": row.title,
                "rationale": row.rationale,
                "suggestion": row.suggestion,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/fix/retry")
async def fix_retry(
    payload: RetryPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
    authorization: str | None = Header(default=None),
):
    token = ""
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Bearer token required for retry action")
    try:
        result = await safe_retry_request(payload.method, payload.path, token=token, body=payload.body)
    except Exception as exc:
        record_fix_action(db, action_type="retry_request", status="failed", result={"error": str(exc)}, incident_id=payload.incident_id)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    record_fix_action(db, action_type="retry_request", status="completed", result=result, incident_id=payload.incident_id)
    return result


@router.post("/fix/restart")
async def fix_restart(payload: RestartPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    try:
        result = await safe_restart_service(payload.service_name)
    except Exception as exc:
        record_fix_action(db, action_type="restart_service", status="failed", result={"error": str(exc)}, incident_id=payload.incident_id)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    record_fix_action(db, action_type="restart_service", status="completed", result=result, incident_id=payload.incident_id)
    return result


@router.post("/fix/clear-cache")
async def fix_clear_cache(payload: ClearCachePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    try:
        result = await safe_clear_cache(prefix=payload.prefix)
    except Exception as exc:
        record_fix_action(db, action_type="clear_cache", status="failed", result={"error": str(exc)}, incident_id=payload.incident_id)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    record_fix_action(db, action_type="clear_cache", status="completed", result=result, incident_id=payload.incident_id)
    return result


@router.get("/report")
def report(db: Session = Depends(get_db), user: User = Depends(current_user)):
    issues = list_incidents(db, limit=200)
    performance = len([x for x in issues if x.classification == "performance"])
    network = len([x for x in issues if x.classification == "network"])
    auth = len([x for x in issues if x.classification == "auth"])
    runtime = len([x for x in issues if x.classification == "runtime"])
    return {
        "summary": {
            "total_issues": len(issues),
            "performance": performance,
            "network": network,
            "auth": auth,
            "runtime": runtime,
        }
    }


def record_runtime_issue(
    db: Session,
    *,
    category: str,
    summary: str,
    severity: str = "medium",
    route: str = "",
    details: dict | None = None,
    status_code: int | None = None,
) -> None:
    record_incident(
        db,
        category=category,
        summary=summary,
        severity=severity,
        route=route,
        details=details,
        status_code=status_code,
    )
