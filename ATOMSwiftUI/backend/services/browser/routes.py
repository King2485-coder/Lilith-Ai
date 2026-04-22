from __future__ import annotations

from pydantic import BaseModel
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.neurocloud.event_bus import publish_event
from backend.models.user import User
from backend.services.browser.service import analyze_page, connect_app, list_connected_apps, run_tool_from_browser, send_to_chat


router = APIRouter(prefix="/browser", tags=["browser"])


class BrowserConnectPayload(BaseModel):
    name: str
    domain: str


class BrowserAnalyzePayload(BaseModel):
    url: str
    note: str | None = None


class BrowserSendToChatPayload(BaseModel):
    target_user_id: str
    text: str


class BrowserRunToolPayload(BaseModel):
    tool_name: str
    input_payload: dict


@router.get("/apps")
def browser_apps(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_connected_apps(db, user)
    return {
        "items": [
            {"id": row.id, "name": row.name, "domain": row.domain, "last_sync": row.last_sync.isoformat()}
            for row in rows
        ]
    }


@router.post("/connect")
async def browser_connect(payload: BrowserConnectPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = connect_app(db, user, payload.name, payload.domain)
    await publish_event("browser.connected", {"user_id": user.id, "app_id": row.id})
    return {"id": row.id, "name": row.name, "domain": row.domain, "last_sync": row.last_sync.isoformat()}


@router.post("/analyze")
async def browser_analyze(payload: BrowserAnalyzePayload, user: User = Depends(current_user)):
    result = analyze_page(payload.url, payload.note)
    await publish_event("browser.analyze", {"user_id": user.id, "url": payload.url})
    return result


@router.post("/send-to-chat")
async def browser_send_to_chat(payload: BrowserSendToChatPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    out = send_to_chat(db, user, payload.target_user_id, payload.text)
    await publish_event("browser.send_to_chat", {"user_id": user.id, "message_id": out["message_id"]})
    return out


@router.post("/run-tool")
async def browser_run_tool(payload: BrowserRunToolPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    out = run_tool_from_browser(db, user, payload.tool_name, payload.input_payload)
    await publish_event("browser.run_tool", {"user_id": user.id, "job_id": out["job_id"], "tool_name": payload.tool_name})
    return out

