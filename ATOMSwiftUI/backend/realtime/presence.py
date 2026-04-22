from __future__ import annotations

import json
from datetime import datetime

from backend.core.redis import get_redis


async def heartbeat(user_id: str) -> dict:
    data = {"status": "online", "last_seen": datetime.utcnow().isoformat()}
    redis = await get_redis()
    if redis is not None:
        await redis.set(f"lilith:presence:{user_id}", json.dumps(data), ex=120)
    return data

