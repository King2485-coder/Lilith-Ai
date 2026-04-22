from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict
import json
import time

from backend.realtime.zeroconf_service import start_zeroconf, stop_zeroconf


@asynccontextmanager
async def lifespan(app: FastAPI):
    start_zeroconf()
    yield
    stop_zeroconf()


app = FastAPI(lifespan=lifespan)

# ======================
# CORS
# ======================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ======================
# STORAGE
# ======================

connections: Dict[str, WebSocket] = {}
rooms: Dict[str, list] = {}
last_seen: Dict[str, float] = {}

# ======================
# HELPERS
# ======================

async def send_to_user(user_id: str, data: dict):
    if user_id in connections:
        await connections[user_id].send_text(json.dumps(data))


async def broadcast(room: str, data: dict):
    if room in rooms:
        for user in rooms[room]:
            await send_to_user(user, data)


# ======================
# HEALTH CHECK
# ======================

@app.get("/")
def root():
    return {"status": "Lilith backend running 🚀"}


@app.get("/api/ice")
def get_ice():
    return {
        "iceServers": [
            {"urls": ["stun:stun.l.google.com:19302"]},
            {
                "urls": [
                    "turn:YOUR_TURN_HOST:3478?transport=udp",
                    "turn:YOUR_TURN_HOST:3478?transport=tcp",
                    "turns:YOUR_TURN_HOST:5349?transport=tcp",
                ],
                "username": "TURN_USERNAME",
                "credential": "TURN_PASSWORD",
            },
        ]
    }


# ======================
# WEBSOCKET
# ======================

@app.websocket("/ws/{user_id}")
async def websocket(ws: WebSocket, user_id: str):
    await ws.accept()
    connections[user_id] = ws
    last_seen[user_id] = time.time()

    try:
        while True:
            raw = await ws.receive_text()
            data = json.loads(raw)

            event = data.get("type")

            # JOIN ROOM
            if event == "join":
                room = data["room"]
                rooms.setdefault(room, []).append(user_id)

                await broadcast(
                    room,
                    {
                        "type": "presence",
                        "user": user_id,
                        "status": "online",
                    },
                )

            # HEARTBEAT
            elif event == "heartbeat":
                last_seen[user_id] = time.time()

            # MESSAGE
            elif event == "message":
                await send_to_user(data["to"], data)

            # TYPING
            elif event == "typing":
                await send_to_user(data["to"], data)

            # WEBRTC SIGNALING
            elif event in ["offer", "answer", "ice"]:
                target = data.get("to")
                if target in connections:
                    await connections[target].send_text(json.dumps(data))

    except WebSocketDisconnect:
        connections.pop(user_id, None)
