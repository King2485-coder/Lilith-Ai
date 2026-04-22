from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.notification import Notification
from backend.models.user import User
from backend.services.notifications.service import list_notifications


router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
def notifications_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_notifications(db, user.id)
    return {
        "items": [
            {
                "id": row.id,
                "type": row.type,
                "title": row.title,
                "body": row.body,
                "read": row.read,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/read/{notification_id}")
def notification_mark_read(notification_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    row.read = True
    db.add(row)
    db.commit()
    return {"ok": True}

