from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from datetime import datetime
from typing import Any

from fastapi import WebSocket

from backend.core.redis import get_redis


class RealtimeManager:
    def __init__(self) -> None:
        self.connections: dict[str, set[WebSocket]] = defaultdict(set)
        self.presence: dict[str, dict[str, Any]] = {}
        self.redis_listener_task: asyncio.Task | None = None

    async def startup(self) -> None:
        redis = await get_redis()
        if redis is None:
            return
        pubsub = redis.pubsub(ignore_subscribe_messages=True)
        await pubsub.subscribe("lilith:realtime")

        async def listen() -> None:
            while True:
                msg = await pubsub.get_message(timeout=1)
                if not msg:
                    await asyncio.sleep(0.05)
                    continue
                data = json.loads(msg["data"])
                targets = data.get("targets", [])
                frame = data.get("frame", {})
                for uid in targets:
                    await self.publish_to_user(str(uid), frame)

        self.redis_listener_task = asyncio.create_task(listen())

    async def shutdown(self) -> None:
        if self.redis_listener_task is not None:
            self.redis_listener_task.cancel()
            try:
                await self.redis_listener_task
            except Exception:
                pass

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections[user_id].add(websocket)
        await self.set_presence(user_id, "online")

    async def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        self.connections[user_id].discard(websocket)
        if not self.connections[user_id]:
            await self.set_presence(user_id, "offline")

    async def set_presence(self, user_id: str, status: str) -> None:
        state = {"status": status, "last_seen": datetime.utcnow().isoformat()}
        self.presence[user_id] = state
        redis = await get_redis()
        if redis is not None:
            await redis.set(f"lilith:presence:{user_id}", json.dumps(state), ex=120)
        await self.broadcast({"event": "presence.update", "payload": {"user_id": user_id, **state}})

    async def publish_to_user(self, user_id: str, frame: dict[str, Any]) -> None:
        for ws in list(self.connections.get(user_id, set())):
            try:
                await ws.send_text(json.dumps(frame, default=str))
            except Exception:
                self.connections[user_id].discard(ws)

    async def publish_to_users(self, user_ids: list[str], frame: dict[str, Any]) -> None:
        for uid in user_ids:
            await self.publish_to_user(uid, frame)
        redis = await get_redis()
        if redis is not None:
            await redis.publish("lilith:realtime", json.dumps({"targets": user_ids, "frame": frame}, default=str))

    async def broadcast(self, frame: dict[str, Any]) -> None:
        for user_id in list(self.connections.keys()):
            await self.publish_to_user(user_id, frame)


realtime_manager = RealtimeManager()

