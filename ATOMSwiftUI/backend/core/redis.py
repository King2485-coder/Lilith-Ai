from __future__ import annotations

from typing import Optional
from time import time

try:
    import redis.asyncio as redis  # type: ignore
except Exception:  # pragma: no cover
    redis = None  # type: ignore

from backend.core.settings import settings


_client: Optional["redis.Redis"] = None
_local_buckets: dict[str, tuple[int, float]] = {}


async def get_redis() -> Optional["redis.Redis"]:
    global _client
    if redis is None:
        return None
    if _client is not None:
        return _client
    try:
        client = redis.from_url(settings.redis_url, decode_responses=True)
        await client.ping()
        _client = client
        return _client
    except Exception:
        return None


async def consume_rate_limit(scope: str, key: str, limit: int, window_seconds: int) -> bool:
    client = await get_redis()
    bucket = f"lilith:ratelimit:{scope}:{key}"
    if client is None:
        now = time()
        count, reset = _local_buckets.get(bucket, (0, now + window_seconds))
        if now > reset:
            count, reset = 0, now + window_seconds
        count += 1
        _local_buckets[bucket] = (count, reset)
        return int(count) <= int(limit)
    count = await client.incr(bucket)
    if count == 1:
        await client.expire(bucket, window_seconds)
    return int(count) <= int(limit)
