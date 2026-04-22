from __future__ import annotations

from fastapi import APIRouter, Depends

from backend.core.deps import current_user
from backend.models.user import User
from backend.services.presence.service import user_heartbeat


router = APIRouter(prefix="/presence", tags=["presence"])


@router.post("/heartbeat")
async def presence_heartbeat(user: User = Depends(current_user)):
    data = await user_heartbeat(user.id)
    return {"ok": True, "presence": data}

