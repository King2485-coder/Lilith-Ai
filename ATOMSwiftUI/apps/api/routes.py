from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from backend.core.auth import decode_access_token
from backend.core.events import event_frame
from backend.core.redis import consume_rate_limit, get_redis
from backend.db.session import SessionLocal
from backend.models.user import User
from backend.realtime.manager import realtime_manager
from backend.services.auth.routes import router as auth_router
from backend.services.admin.routes import router as admin_router
from backend.services.applications.routes import router as applications_router
from backend.services.browser.routes import router as browser_router
from backend.services.growth.routes import router as growth_router
from backend.services.finance_hub.routes import router as finance_hub_router
from backend.services.income_engine.routes import router as income_engine_router
from backend.services.messaging.routes import router as messaging_router
from backend.services.memory.routes import router as memory_router
from backend.services.moderation.routes import router as moderation_router
from backend.services.neurocloud.routes import router as neurocloud_router
from backend.services.notifications.routes import router as notifications_router
from backend.services.payments.routes import router as payments_router
from backend.services.presence.routes import router as presence_router
from backend.services.tools.routes import router as tools_router
from backend.services.self_heal.routes import router as self_heal_router
from backend.services.system.routes import router as system_router
from backend.services.social.routes import router as social_router
from backend.services.storage.routes import router as storage_router
from backend.services.reputation.routes import router as reputation_router
from backend.services.real_world.routes import router as real_world_router
from backend.services.first100.routes import router as first100_router
from backend.services.self_heal.routes import record_runtime_issue


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth_router)
api_router.include_router(messaging_router)
api_router.include_router(memory_router)
api_router.include_router(payments_router)
api_router.include_router(tools_router)
api_router.include_router(notifications_router)
api_router.include_router(presence_router)
api_router.include_router(browser_router)
api_router.include_router(growth_router)
api_router.include_router(finance_hub_router)
api_router.include_router(income_engine_router)
api_router.include_router(neurocloud_router)
api_router.include_router(self_heal_router)
api_router.include_router(system_router)
api_router.include_router(social_router)
api_router.include_router(storage_router)
api_router.include_router(reputation_router)
api_router.include_router(real_world_router)
api_router.include_router(first100_router)
api_router.include_router(moderation_router)
api_router.include_router(admin_router)
api_router.include_router(applications_router)


@api_router.websocket("/realtime/ws")
async def realtime_ws(websocket: WebSocket, token: str = Query(...)):
    db: Session = SessionLocal()
    try:
        username = decode_access_token(token)
        user = db.query(User).filter(User.username == username).first()
        if user is None:
            raise HTTPException(status_code=401, detail="Invalid user")
        await realtime_manager.connect(user.id, websocket)
        await realtime_manager.publish_to_users([user.id], event_frame("presence.update", {"user_id": user.id, "status": "online"}))
        while True:
            raw = await websocket.receive_text()
            frame = json.loads(raw)
            event = frame.get("event")
            payload = frame.get("payload", {})
            allowed = await consume_rate_limit("ws.event", f"user:{user.id}", limit=240, window_seconds=60)
            if not allowed:
                continue
            if event == "typing":
                conversation_user_id = str(payload.get("conversation_user_id", ""))
                is_typing = bool(payload.get("typing", True))
                redis = await get_redis()
                if redis is not None and conversation_user_id:
                    key = f"lilith:typing:{user.id}:{conversation_user_id}"
                    if is_typing:
                        await redis.set(key, "1", ex=8)
                    else:
                        await redis.delete(key)
                if conversation_user_id:
                    await realtime_manager.publish_to_users(
                        [conversation_user_id],
                        event_frame("typing", {"from_user_id": user.id, "typing": is_typing}),
                    )
            elif event == "heartbeat":
                await realtime_manager.set_presence(user.id, "online")
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        from backend.observability.state import observability_state

        observability_state.add_log(
            level="error",
            message="Websocket runtime exception",
            source="realtime.ws",
            context={"error": str(exc)},
        )
        record_runtime_issue(
            db,
            category="websocket_issue",
            summary="Websocket runtime exception",
            severity="high",
            route="/api/v1/realtime/ws",
            details={"error": str(exc)},
        )
        raise
    finally:
        try:
            user_id = locals().get("user").id if locals().get("user") else None
            if user_id:
                await realtime_manager.disconnect(user_id, websocket)
        except Exception:
            pass
        db.close()
