from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.user import User
from backend.services.memory.service import get_global_learning, get_user_memory, update_user_memory


router = APIRouter(prefix="/memory", tags=["memory"])


class MemoryUpdatePayload(BaseModel):
    patch: dict = Field(default_factory=dict)
    client_updated_at: int | None = None


@router.get("")
def memory_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"memory": get_user_memory(db, user.id)}


@router.post("/update")
def memory_update(payload: MemoryUpdatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    memory = update_user_memory(
        db,
        user.id,
        patch=payload.patch or {},
        client_updated_at=payload.client_updated_at,
    )
    return {"memory": memory}


@router.get("/global")
def memory_global(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"global_learning": get_global_learning(db)}
