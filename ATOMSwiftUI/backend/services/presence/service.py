from __future__ import annotations

from backend.realtime.manager import realtime_manager
from backend.realtime.presence import heartbeat


async def user_heartbeat(user_id: str) -> dict:
    data = await heartbeat(user_id)
    await realtime_manager.set_presence(user_id, "online")
    return data

