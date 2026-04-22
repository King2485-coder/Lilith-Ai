from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel


class ToolRunPayload(BaseModel):
    tool_name: str
    input_payload: dict[str, Any]


class ToolJobOut(BaseModel):
    id: str
    user_id: str
    tool_name: str
    input_payload: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class ToolResultOut(BaseModel):
    id: str
    tool_job_id: str
    output_payload: str
    created_at: datetime

    class Config:
        from_attributes = True
