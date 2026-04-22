from __future__ import annotations

import os
import time

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from apps.api.config import cors_origins
from apps.api.routes import api_router
from backend.db.init_db import init_db
from backend.db.seed import seed_dev_data
from backend.db.session import SessionLocal
from backend.core.redis import consume_rate_limit
from backend.core.settings import settings
from backend.core.redis import get_redis
from backend.observability.state import observability_state
from backend.realtime.manager import realtime_manager
from backend.services.self_heal.routes import record_runtime_issue
from sqlalchemy import text


app = FastAPI(title="Lilith Foundation API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(api_router)
SLOW_RESPONSE_MS = int(os.getenv("SELF_HEAL_SLOW_MS", "900"))


@app.middleware("http")
async def monitor_runtime(request, call_next):
    started = time.perf_counter()
    response = None
    error_text = None
    status_code = 500
    route = request.url.path
    client_ip = request.client.host if request.client else "unknown"
    scope = "global"
    limit = settings.global_rate_limit_per_minute
    if route.startswith("/api/v1/auth/"):
        scope = "auth"
        limit = settings.auth_rate_limit_per_minute
    elif route.startswith("/api/v1/messages/"):
        scope = "messages"
        limit = settings.message_rate_limit_per_minute
    elif route.startswith("/api/v1/payments/"):
        scope = "payments"
        limit = settings.payment_rate_limit_per_minute
    elif route.startswith("/api/v1/tools/"):
        scope = "tools"
        limit = settings.tool_rate_limit_per_minute

    allowed = await consume_rate_limit(scope, f"ip:{client_ip}", limit=limit, window_seconds=60)
    if not allowed:
        status_code = 429
        observability_state.add_request(status_code=status_code, latency_ms=0)
        db = SessionLocal()
        try:
            observability_state.add_log(
                level="warning",
                message=f"Rate limit exceeded for {scope}",
                source="api.middleware",
                context={"route": route, "client_ip": client_ip},
            )
            record_runtime_issue(
                db,
                category="api_error",
                summary=f"Rate limited {scope}",
                severity="low",
                route=route,
                details={"scope": scope, "client_ip": client_ip},
                status_code=status_code,
            )
        finally:
            db.close()
        from fastapi.responses import JSONResponse

        return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"})

    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception as exc:
        error_text = str(exc)
        raise
    finally:
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        observability_state.add_request(status_code=status_code, latency_ms=elapsed_ms)
        db = SessionLocal()
        try:
            if elapsed_ms >= SLOW_RESPONSE_MS:
                observability_state.add_log(
                    level="warning",
                    message=f"Slow response detected ({elapsed_ms}ms)",
                    source="api.middleware",
                    context={"route": route, "status_code": status_code},
                )
                record_runtime_issue(
                    db,
                    category="slow_response",
                    summary=f"Slow response {elapsed_ms}ms",
                    severity="medium" if elapsed_ms < 1800 else "high",
                    route=route,
                    details={"elapsed_ms": elapsed_ms, "method": request.method, "status_code": status_code},
                    status_code=status_code,
                )
            if status_code >= 400 or error_text:
                observability_state.add_log(
                    level="error" if status_code >= 500 else "warning",
                    message=f"API error on {request.method} {route}",
                    source="api.middleware",
                    context={"status_code": status_code, "error": error_text},
                )
                record_runtime_issue(
                    db,
                    category="api_error",
                    summary=f"HTTP {status_code} on {request.method} {route}",
                    severity="high" if status_code >= 500 else "low",
                    route=route,
                    details={"status_code": status_code, "error": error_text},
                    status_code=status_code,
                )
        finally:
            db.close()


@app.on_event("startup")
async def startup() -> None:
    init_db()
    db = SessionLocal()
    try:
        seed_dev_data(db)
    finally:
        db.close()
    await realtime_manager.startup()


@app.on_event("shutdown")
async def shutdown() -> None:
    await realtime_manager.shutdown()


@app.get("/")
def root():
    return {"name": "Lilith Foundation API", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/health/ready")
async def health_ready():
    db_ok = True
    redis_ok = True
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    finally:
        db.close()
    redis = await get_redis()
    if redis is None:
        redis_ok = False
    else:
        try:
            await redis.ping()
        except Exception:
            redis_ok = False
    status = "ready" if db_ok and redis_ok else "degraded"
    return {"status": status, "db_ok": db_ok, "redis_ok": redis_ok}
