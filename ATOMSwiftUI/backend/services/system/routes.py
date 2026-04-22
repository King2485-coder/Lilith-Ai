from __future__ import annotations

import asyncio
import json
import time

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import text
from sqlalchemy.orm import Session

from backend.core.auth import decode_access_token
from backend.core.deps import current_user, get_db
from backend.core.redis import get_redis
from backend.db.session import SessionLocal
from backend.models.self_heal import RuntimeIncident
from backend.models.user import User
from backend.observability.state import observability_state
from backend.realtime.manager import realtime_manager


router = APIRouter(prefix="/system", tags=["system"])


def _alerts_from_runtime(db: Session) -> list[dict]:
    alerts: list[dict] = []
    high_open = (
        db.query(RuntimeIncident)
        .filter(RuntimeIncident.severity == "high", RuntimeIncident.resolved.is_(False))
        .order_by(RuntimeIncident.created_at.desc())
        .limit(25)
        .all()
    )
    for row in high_open:
        alerts.append(
            {
                "id": row.id,
                "level": "critical",
                "source": row.classification,
                "title": row.summary,
                "route": row.route,
                "created_at": row.created_at.isoformat(),
            }
        )
    metrics = observability_state.metrics_snapshot()
    if metrics["error_rate_percent"] >= 8:
        alerts.append(
            {
                "id": "runtime-error-rate",
                "level": "warning",
                "source": "performance",
                "title": f"High recent API error rate ({metrics['error_rate_percent']}%)",
                "route": "*",
                "created_at": str(int(time.time())),
            }
        )
    if metrics["latency_p95_ms"] >= 1200:
        alerts.append(
            {
                "id": "runtime-latency-p95",
                "level": "warning",
                "source": "performance",
                "title": f"High P95 latency ({metrics['latency_p95_ms']}ms)",
                "route": "*",
                "created_at": str(int(time.time())),
            }
        )
    return alerts


@router.get("/metrics")
def system_metrics(db: Session = Depends(get_db), user: User = Depends(current_user)):
    metrics = observability_state.metrics_snapshot()
    metrics["active_websocket_connections"] = sum(len(v) for v in realtime_manager.connections.values())
    return metrics


@router.get("/logs")
def system_logs(limit: int = 150, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": observability_state.logs_snapshot(limit=limit)}


@router.get("/alerts")
def system_alerts(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": _alerts_from_runtime(db)}


@router.get("/health")
async def system_health(db: Session = Depends(get_db), user: User = Depends(current_user)):
    db_ok = True
    redis_ok = True
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    redis = await get_redis()
    if redis is None:
        redis_ok = False
    else:
        try:
            await redis.ping()
        except Exception:
            redis_ok = False
    ws_count = sum(len(v) for v in realtime_manager.connections.values())
    status = "healthy" if db_ok and redis_ok else ("degraded" if db_ok else "unhealthy")
    return {
        "status": status,
        "db": {"ok": db_ok},
        "redis": {"ok": redis_ok},
        "realtime": {"connections": ws_count},
    }


@router.websocket("/stream")
async def system_stream(websocket: WebSocket, token: str = Query(...)):
    db = SessionLocal()
    try:
        username = decode_access_token(token)
        user = db.query(User).filter(User.username == username).first()
        if user is None:
            await websocket.close(code=4401)
            return
        await websocket.accept()
        while True:
            metrics = observability_state.metrics_snapshot()
            metrics["active_websocket_connections"] = sum(len(v) for v in realtime_manager.connections.values())
            payload = {"event": "system.metrics", "payload": metrics}
            await websocket.send_text(json.dumps(payload, default=str))
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        pass
    finally:
        db.close()

