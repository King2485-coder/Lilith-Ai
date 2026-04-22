from __future__ import annotations

from datetime import datetime
import hashlib

from fastapi import HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from backend.core.crypto import decrypt_text, encrypt_text
from backend.core.redis import get_redis
from backend.core.safety import content_violations, normalize_text
from backend.models.admin import ModerationReport, UserRole
from backend.models.message import Message
from backend.models.user import User
from backend.observability.state import observability_state
from backend.services.notifications.service import create_notification


def send_message(db: Session, sender: User, receiver_id: str, content: str) -> Message:
    receiver = db.query(User).filter(User.id == receiver_id).first()
    if receiver is None:
        raise HTTPException(status_code=404, detail="Receiver not found")
    sender_role = db.query(UserRole).filter(UserRole.user_id == sender.id).first()
    receiver_role = db.query(UserRole).filter(UserRole.user_id == receiver.id).first()
    sender_child = sender_role is not None and sender_role.role == "child"
    receiver_child = receiver_role is not None and receiver_role.role == "child"

    normalized = normalize_text(content)
    if not normalized:
        raise HTTPException(status_code=400, detail="Message content is required")
    if len(normalized) > 4000:
        raise HTTPException(status_code=400, detail="Message too long")

    violations = content_violations(normalized, child_mode=(sender_child or receiver_child))
    if violations:
        db.add(
            ModerationReport(
                reporter_user_id=sender.id,
                target_type="message",
                target_id=receiver_id,
                reason=f"Blocked terms: {', '.join(sorted(set(violations)))}",
                status="open",
            )
        )
        db.commit()
        observability_state.add_log(
            level="warning",
            message="Message blocked by safety policy",
            source="messaging.service",
            context={"sender_id": sender.id, "receiver_id": receiver_id, "violations": violations},
        )
        raise HTTPException(status_code=400, detail="Message violates safety policy")

    encrypted_content = encrypt_text(normalized)
    row = Message(sender_id=sender.id, receiver_id=receiver_id, content=encrypted_content)
    db.add(row)
    create_notification(db, receiver_id, "message", f"New message from {sender.username}", normalized[:240])
    db.flush()
    db.commit()
    db.refresh(row)
    return row


def thread_messages(db: Session, user_id: str, other_user_id: str) -> list[Message]:
    return (
        db.query(Message)
        .filter(
            or_(
                and_(Message.sender_id == user_id, Message.receiver_id == other_user_id),
                and_(Message.sender_id == other_user_id, Message.receiver_id == user_id),
            )
        )
        .order_by(Message.created_at.asc())
        .all()
    )


def mark_message_read(db: Session, message_id: str, reader_id: str) -> Message:
    row = db.query(Message).filter(Message.id == message_id, Message.receiver_id == reader_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Message not found")
    row.read_at = datetime.utcnow()
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def present_message_content(row: Message) -> str:
    return decrypt_text(row.content)


async def enforce_spam_guard(sender_id: str, receiver_id: str, content: str) -> None:
    redis = await get_redis()
    if redis is None:
        return
    normalized = normalize_text(content)
    digest = hashlib.sha256(f"{sender_id}:{receiver_id}:{normalized.lower()}".encode("utf-8")).hexdigest()
    key = f"lilith:spam:{digest}"
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, 20)
    if int(count) > 3:
        raise HTTPException(status_code=429, detail="Spam protection triggered")
