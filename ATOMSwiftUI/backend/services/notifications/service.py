from __future__ import annotations

from sqlalchemy.orm import Session

from backend.models.notification import Notification


def create_notification(db: Session, user_id: str, kind: str, title: str, body: str) -> Notification:
    row = Notification(user_id=user_id, type=kind, title=title, body=body, read=False)
    db.add(row)
    db.flush()
    return row


def list_notifications(db: Session, user_id: str, limit: int = 100) -> list[Notification]:
    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(max(1, min(limit, 200)))
        .all()
    )

