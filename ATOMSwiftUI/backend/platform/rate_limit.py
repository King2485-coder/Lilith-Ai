from __future__ import annotations

from fastapi import HTTPException

from backend.platform.realtime import hub


async def enforce_rate_limit(scope: str, identity: str, limit: int, window_seconds: int) -> None:
    allowed = await hub.consume_rate_limit(
        scope=scope,
        key=identity,
        limit=limit,
        window_seconds=window_seconds,
    )
    if allowed:
        return
    raise HTTPException(
        status_code=429,
        detail=f"Rate limit exceeded for {scope}. Try again shortly.",
    )

