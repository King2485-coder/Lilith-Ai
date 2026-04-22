# Lilith Backend Deployment Notes

## Local beta run

1. Install dependencies:
```bash
pip install -r requirements.txt
```
2. Start Redis:
```bash
redis-server
```
3. Copy env template:
```bash
cp .env.example .env
```
4. Run API gateway:
```bash
uvicorn apps.api.main:app --host 0.0.0.0 --port 8000 --reload
```

## Multi-instance readiness

- Websocket fanout and presence use Redis (`REDIS_URL`, `REDIS_PREFIX`).
- Rate limits use Redis if available, else in-memory fallback.
- Push pipeline uses `device_push_tokens` with provider adapter scaffold in `backend/platform/push.py`.
- NeuroCloud scoped credential and passkey RP config is environment-driven:
  - `NEUROCLOUD_SCOPED_TOKEN_SECRET`
  - `NEUROCLOUD_RP_ID`

## Architecture inspection endpoints

- `GET /api/v1/system/architecture`
- `GET /api/v1/system/realtime`
- `GET /api/v1/system/security`
- `GET /api/v1/system/infrastructure`

## Real-user smoke test

1. Register two users (`POST /api/v1/auth/register`).
2. Connect both to `/api/v1/realtime/ws?token=...`.
3. Create conversation and send message (`/api/v1/messages/.../send`).
4. Verify recipient gets:
   - `message.new`
   - `notification.new`
5. Start call (`POST /api/v1/calls/start`) and exchange ICE candidates:
   - `POST /api/v1/calls/{call_id}/ice`
   - `GET /api/v1/calls/{call_id}/ice`
6. Register push token (`POST /api/v1/notifications/push-token`) and verify push logs.
