from __future__ import annotations

import asyncio
import json
import os
from collections import defaultdict
from datetime import datetime
from typing import Any
from uuid import uuid4

from fastapi import WebSocket

from backend.platform.observability import audit_event

try:
    import redis.asyncio as redis  # type: ignore
except Exception:  # pragma: no cover - optional dependency fallback
    redis = None  # type: ignore


class RealtimeHub:
    def __init__(self) -> None:
        self.user_sockets: dict[int, set[WebSocket]] = defaultdict(set)
        self.presence: dict[int, dict[str, Any]] = {}
        self._rate_limits: dict[str, tuple[int, float]] = {}

        self.instance_id = os.getenv("RT_INSTANCE_ID", str(uuid4()))
        self.redis_url = os.getenv("REDIS_URL", "").strip()
        self.redis_prefix = os.getenv("REDIS_PREFIX", "lilith")
        self.redis_enabled = bool(self.redis_url and redis is not None)
        self._redis_client = None
        self._pubsub = None
        self._listener_task: asyncio.Task | None = None

    async def _ensure_redis(self) -> None:
        if not self.redis_enabled or self._redis_client is not None:
            return
        self._redis_client = redis.from_url(self.redis_url, decode_responses=True)
        await self._redis_client.ping()
        self._pubsub = self._redis_client.pubsub(ignore_subscribe_messages=True)
        await self._pubsub.subscribe(self._channel_name())
        self._listener_task = asyncio.create_task(self._listen_loop())
        audit_event("realtime.redis.connected", instance_id=self.instance_id)

    def _channel_name(self) -> str:
        return f"{self.redis_prefix}:realtime:events"

    def _presence_key(self, user_id: int) -> str:
        return f"{self.redis_prefix}:presence:{user_id}"

    async def _listen_loop(self) -> None:
        if self._pubsub is None:
            return
        while True:
            try:
                message = await self._pubsub.get_message(timeout=1.0)
                if not message:
                    await asyncio.sleep(0.05)
                    continue
                payload = json.loads(message["data"])
                if payload.get("instanceId") == self.instance_id:
                    continue
                frame = payload.get("frame", {})
                for user_id in payload.get("targets", []):
                    await self.broadcast_user(int(user_id), frame)
            except asyncio.CancelledError:
                return
            except Exception:
                await asyncio.sleep(0.25)

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await self._ensure_redis()
        await websocket.accept()
        self.user_sockets[user_id].add(websocket)
        await self.set_presence(user_id, online=True, active_now=True)
        await self.publish_to_all(
            "presence.update",
            {"userId": user_id, **self.presence.get(user_id, {})},
        )

    async def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        sockets = self.user_sockets.get(user_id, set())
        if websocket in sockets:
            sockets.remove(websocket)
        if not sockets:
            await self.set_presence(user_id, online=False, active_now=False)
            await self.publish_to_all(
                "presence.update",
                {"userId": user_id, **self.presence.get(user_id, {})},
            )

    async def set_presence(self, user_id: int, online: bool, active_now: bool, status_text: str | None = None) -> None:
        state = {
            "online": online,
            "activeNow": active_now,
            "statusText": status_text,
            "lastSeenAt": datetime.utcnow().isoformat(),
        }
        self.presence[user_id] = state
        await self._ensure_redis()
        if self._redis_client is not None:
            await self._redis_client.set(self._presence_key(user_id), json.dumps(state), ex=120)

    async def get_presence(self, user_id: int) -> dict[str, Any]:
        await self._ensure_redis()
        if self._redis_client is not None:
            raw = await self._redis_client.get(self._presence_key(user_id))
            if raw:
                return json.loads(raw)
        return self.presence.get(user_id, {"online": False, "activeNow": False, "lastSeenAt": None})

    async def set_typing(self, conversation_id: str, user_id: int, typing: bool) -> None:
        await self._ensure_redis()
        if self._redis_client is None:
            return
        key = f"{self.redis_prefix}:typing:{conversation_id}:{user_id}"
        if typing:
            await self._redis_client.set(key, "1", ex=8)
        else:
            await self._redis_client.delete(key)

    async def consume_rate_limit(self, scope: str, key: str, limit: int, window_seconds: int) -> bool:
        await self._ensure_redis()
        bucket = f"{self.redis_prefix}:ratelimit:{scope}:{key}"
        if self._redis_client is not None:
            count = await self._redis_client.incr(bucket)
            if count == 1:
                await self._redis_client.expire(bucket, window_seconds)
            return int(count) <= int(limit)

        now = datetime.utcnow().timestamp()
        current_count, reset_at = self._rate_limits.get(bucket, (0, now + window_seconds))
        if now > reset_at:
            current_count = 0
            reset_at = now + window_seconds
        current_count += 1
        self._rate_limits[bucket] = (current_count, reset_at)
        return current_count <= limit

    async def publish(self, user_ids: list[int], event: str, payload: dict[str, Any]) -> None:
        frame = {"event": event, "payload": payload}
        await self._dispatch_local(user_ids, frame)
        await self._dispatch_cluster(user_ids, frame)

    async def publish_to_all(self, event: str, payload: dict[str, Any]) -> None:
        user_ids = list(self.user_sockets.keys())
        if not user_ids:
            return
        await self.publish(user_ids, event, payload)

    async def _dispatch_local(self, user_ids: list[int], frame: dict[str, Any]) -> None:
        for user_id in user_ids:
            await self.broadcast_user(int(user_id), frame)

    async def _dispatch_cluster(self, user_ids: list[int], frame: dict[str, Any]) -> None:
        await self._ensure_redis()
        if self._redis_client is None:
            return
        envelope = {
            "instanceId": self.instance_id,
            "targets": [int(user_id) for user_id in user_ids],
            "frame": frame,
        }
        await self._redis_client.publish(self._channel_name(), json.dumps(envelope, default=str))

    async def broadcast_user(self, user_id: int, frame: dict[str, Any]) -> None:
        sockets = list(self.user_sockets.get(user_id, set()))
        for websocket in sockets:
            try:
                await websocket.send_text(json.dumps(frame, default=str))
            except Exception:
                try:
                    await websocket.close()
                except Exception:
                    pass
                self.user_sockets[user_id].discard(websocket)

    async def shutdown(self) -> None:
        if self._listener_task is not None:
            self._listener_task.cancel()
            try:
                await self._listener_task
            except Exception:
                pass
        if self._pubsub is not None:
            await self._pubsub.close()
        if self._redis_client is not None:
            await self._redis_client.close()


hub = RealtimeHub()

