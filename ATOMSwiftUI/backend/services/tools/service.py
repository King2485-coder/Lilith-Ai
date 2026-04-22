from __future__ import annotations

import json

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.core.safety import content_violations
from backend.models.tool import ToolJob, ToolResult
from backend.models.user import User
from backend.models.admin import ToolControl
from backend.observability.state import observability_state
from backend.services.self_heal.service import record_incident
from backend.services.tools.runner import run_tool


def create_and_run_tool_job(db: Session, user: User, tool_name: str, input_payload: dict) -> ToolJob:
    control = db.query(ToolControl).filter(ToolControl.tool_name == tool_name).first()
    if control is not None and (not control.approved or not control.enabled):
        raise HTTPException(status_code=403, detail=f"Tool '{tool_name}' is disabled by admin policy")
    raw_payload = json.dumps(input_payload or {}, default=str)
    if len(raw_payload) > 12000:
        raise HTTPException(status_code=400, detail="Tool input payload too large")
    violations = content_violations(raw_payload)
    if violations:
        raise HTTPException(status_code=400, detail="Tool input violates safety policy")
    job = ToolJob(user_id=user.id, tool_name=tool_name, input_payload=json.dumps(input_payload, default=str), status="queued")
    db.add(job)
    db.flush()
    job.status = "running"
    db.add(job)
    try:
        output = run_tool(tool_name, input_payload)
        result = ToolResult(tool_job_id=job.id, output_payload=json.dumps(output, default=str))
        db.add(result)
        job.status = "completed"
    except Exception as exc:
        observability_state.add_log(
            level="error",
            message=f"Tool job failed ({tool_name})",
            source="tools.service",
            context={"job_id": job.id, "error": str(exc)},
        )
        job.status = "failed"
        db.add(job)
        db.commit()
        record_incident(
            db,
            category="failed_job",
            summary=f"Tool job failed: {tool_name}",
            severity="high",
            route="/api/v1/tools/run",
            details={"job_id": job.id, "tool_name": tool_name, "error": str(exc)},
        )
        raise HTTPException(status_code=500, detail=f"Tool execution failed: {exc}") from exc
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


def get_job(db: Session, user: User, job_id: str) -> ToolJob:
    row = db.query(ToolJob).filter(ToolJob.id == job_id, ToolJob.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Tool job not found")
    return row


def get_result(db: Session, user: User, job_id: str) -> ToolResult:
    job = get_job(db, user, job_id)
    row = db.query(ToolResult).filter(ToolResult.tool_job_id == job.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Tool result not found")
    return row
