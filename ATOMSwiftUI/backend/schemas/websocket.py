from __future__ import annotations

from pydantic import BaseModel


class WebsocketInbound(BaseModel):
    event: str
    payload: dict = {}

