from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from backend.models.neurocloud import NeuroExecutionLog


def log_execution(
    db: Session,
    *,
    user_id: str,
    action: str,
    input_payload: dict[str, Any] | None,
    output_payload: dict[str, Any] | None,
    status: str = "completed",
) -> NeuroExecutionLog:
    row = NeuroExecutionLog(
        user_id=user_id,
        action=action,
        input_json=json.dumps(input_payload or {}, default=str),
        output_json=json.dumps(output_payload or {}, default=str),
        status=status,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row

