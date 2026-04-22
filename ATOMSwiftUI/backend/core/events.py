from __future__ import annotations

from typing import Any


def event_frame(event: str, payload: dict[str, Any]) -> dict[str, Any]:
    return {"event": event, "payload": payload}

