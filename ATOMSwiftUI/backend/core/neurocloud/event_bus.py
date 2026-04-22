from __future__ import annotations

from typing import Any

from backend.core.redis import get_redis


async def publish_event(event: str, payload: dict[str, Any]) -> None:
    redis = await get_redis()
    if redis is None:
        return
    await redis.publish("lilith:neuro:events", str({"event": event, "payload": payload}))

