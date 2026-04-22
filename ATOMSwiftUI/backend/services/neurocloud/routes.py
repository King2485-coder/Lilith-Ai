from __future__ import annotations

from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.neurocloud.event_bus import publish_event
from backend.core.neurocloud.execution_engine import log_execution
from backend.core.neurocloud.memory_service import get_memory, patch_memory
from backend.core.neurocloud.permission_engine import can_execute
from backend.models.user import User


router = APIRouter(prefix="/neurocloud", tags=["neurocloud"])


class MemoryPatchPayload(BaseModel):
    patch: dict


class ExecutePayload(BaseModel):
    permission: str
    action: str
    input_payload: dict = {}


@router.get("/memory")
def neuro_memory(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"memory": get_memory(db, user.id)}


@router.patch("/memory")
async def neuro_memory_patch(payload: MemoryPatchPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    memory = patch_memory(db, user.id, payload.patch)
    await publish_event("neuro.memory.updated", {"user_id": user.id})
    return {"memory": memory}


@router.post("/execute")
async def neuro_execute(payload: ExecutePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if not can_execute(payload.permission):
        raise HTTPException(status_code=403, detail="Permission denied")
    output = {"ok": True, "action": payload.action}
    log = log_execution(
        db,
        user_id=user.id,
        action=payload.action,
        input_payload=payload.input_payload,
        output_payload=output,
        status="completed",
    )
    await publish_event("neuro.execution.completed", {"user_id": user.id, "execution_id": log.id, "action": payload.action})
    return {"execution_id": log.id, "output": output}

