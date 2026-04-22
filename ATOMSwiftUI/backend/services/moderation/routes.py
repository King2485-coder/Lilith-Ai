from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.admin import ModerationReport
from backend.models.user import User


router = APIRouter(prefix="/moderation", tags=["moderation"])


class ReportPayload(BaseModel):
    target_type: str
    target_id: str
    reason: str


@router.post("/report")
def moderation_report(payload: ReportPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = ModerationReport(
        reporter_user_id=user.id,
        target_type=payload.target_type[:60],
        target_id=payload.target_id[:80],
        reason=payload.reason[:255],
        status="open",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "status": row.status}

