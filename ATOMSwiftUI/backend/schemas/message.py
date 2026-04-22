from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class MessageSendPayload(BaseModel):
    receiver_id: str
    content: str


class MessageOut(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    content: str
    created_at: datetime
    read_at: datetime | None = None

    class Config:
        from_attributes = True
