from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.schemas.tool import ToolRunPayload
from backend.services.tools.registry import REGISTRY
from backend.services.tools.service import create_and_run_tool_job, get_job, get_result


router = APIRouter(prefix="/tools", tags=["tools"])


@router.post("/run")
async def tools_run(payload: ToolRunPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    allowed = await consume_rate_limit("tools.user.run", f"user:{user.id}", limit=80, window_seconds=60)
    if not allowed:
        raise HTTPException(status_code=429, detail="Tool run rate limit exceeded")
    if payload.tool_name not in REGISTRY:
        raise HTTPException(status_code=404, detail="Tool not found")
    row = create_and_run_tool_job(db, user, payload.tool_name, payload.input_payload)
    return {"job_id": row.id, "status": row.status}


@router.get("/jobs/{job_id}")
def tools_job(job_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = get_job(db, user, job_id)
    return {
        "id": row.id,
        "tool_name": row.tool_name,
        "status": row.status,
        "input_payload": json.loads(row.input_payload),
        "created_at": row.created_at.isoformat(),
    }


@router.get("/results/{job_id}")
def tools_result(job_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = get_result(db, user, job_id)
    return {
        "id": row.id,
        "tool_job_id": row.tool_job_id,
        "output_payload": json.loads(row.output_payload),
        "created_at": row.created_at.isoformat(),
    }
