from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.schemas.message import MessageSendPayload
from backend.realtime.broadcaster import broadcast_message_new, broadcast_message_read, broadcast_notification
from backend.services.messaging.service import enforce_spam_guard, mark_message_read, present_message_content, send_message, thread_messages
from backend.services.notifications.service import list_notifications


router = APIRouter(prefix="/messages", tags=["messages"])


@router.post("/send")
async def message_send(payload: MessageSendPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("messages.user", f"user:{user.id}", limit=90, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Message rate limit exceeded")
    await enforce_spam_guard(user.id, payload.receiver_id, payload.content)
    row = send_message(db, user, payload.receiver_id, payload.content)
    message_text = present_message_content(row)
    await broadcast_message_new(payload.receiver_id, row.id, user.id, message_text)
    notifications = list_notifications(db, payload.receiver_id, limit=1)
    if notifications:
        note = notifications[0]
        await broadcast_notification(payload.receiver_id, note.id, note.title, note.body)
    return {"id": row.id, "created_at": row.created_at.isoformat()}


@router.get("/thread/{user_id}")
def message_thread(user_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = thread_messages(db, user.id, user_id)
    return {
        "items": [
            {
                "id": row.id,
                "sender_id": row.sender_id,
                "receiver_id": row.receiver_id,
                "content": present_message_content(row),
                "created_at": row.created_at.isoformat(),
                "read_at": row.read_at.isoformat() if row.read_at else None,
            }
            for row in rows
        ]
    }


@router.post("/read/{message_id}")
async def message_mark_read(message_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = mark_message_read(db, message_id, user.id)
    await broadcast_message_read(row.sender_id, row.id)
    return {"ok": True, "read_at": row.read_at.isoformat() if row.read_at else None}
