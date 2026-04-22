from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.core.safety import content_violations, validate_url
from backend.models.browser import ConnectedApp
from backend.models.user import User
from backend.services.tools.service import create_and_run_tool_job


def list_connected_apps(db: Session, user: User) -> list[ConnectedApp]:
    return db.query(ConnectedApp).filter(ConnectedApp.user_id == user.id).order_by(ConnectedApp.last_sync.desc()).all()


def connect_app(db: Session, user: User, name: str, domain: str) -> ConnectedApp:
    if not name.strip() or not domain.strip():
        raise HTTPException(status_code=400, detail="Name and domain are required")
    row = ConnectedApp(user_id=user.id, name=name.strip()[:120], domain=domain.strip()[:255], last_sync=datetime.utcnow())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def analyze_page(url: str, note: str | None = None) -> dict:
    clean_url = validate_url(url)
    if note:
        violations = content_violations(note)
        if violations:
            raise HTTPException(status_code=400, detail="Analyze note violates safety policy")
    summary = f"Analyzed {clean_url}. Key sections and actions extracted."
    return {"url": clean_url, "summary": summary, "note": note or "", "actionable": ["summarize", "extract tasks", "send to chat"]}


def send_to_chat(db: Session, user: User, target_user_id: str, text: str) -> dict:
    if not target_user_id:
        raise HTTPException(status_code=400, detail="target_user_id is required")
    violations = content_violations(text)
    if violations:
        raise HTTPException(status_code=400, detail="Message content violates safety policy")
    from backend.services.messaging.service import send_message

    row = send_message(db, user, target_user_id, text)
    return {"message_id": row.id}


def run_tool_from_browser(db: Session, user: User, tool_name: str, input_payload: dict) -> dict:
    job = create_and_run_tool_job(db, user, tool_name, input_payload)
    return {"job_id": job.id, "status": job.status}
