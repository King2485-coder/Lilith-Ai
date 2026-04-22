# Lilith Foundation (Modular Monolith)

This repository now contains a first complete working foundation for Lilith with:
- FastAPI API gateway
- JWT auth
- DB-backed messaging
- websocket realtime
- Lilith Pay starter (intents + ledger + balances)
- AI tools execution starter
- Browser layer APIs + Expo browser screen scaffold
- Growth APIs (subscribe/email/landing pages)
- NeuroCloud core APIs (memory + execution + permission checks)
- Controlled self-healing + optimization APIs (runtime-only, no code mutation)
- Real-time observability dashboard APIs (metrics, logs, alerts, health, live stream)
- Admin Control Panel APIs (users, payments, tools, moderation, system control + audit logs)
- Production-hardening controls (JWT issuer/audience, rate limits, safety policies, payment guardrails)
- Redis scaling foundation
- SwiftUI connection layer (services/models/viewmodels/views)

## Structure

```text
apps/
  api/
    main.py
    config.py
    routes.py
  worker/
    worker.py
    jobs/
  realtime/
    ws_server.py
    events.py

backend/
  core/
  db/
  models/
  schemas/
  services/
    auth/
    messaging/
    payments/
    tools/
    notifications/
    presence/
    browser/
    growth/
    neurocloud/
    self_heal/
    admin/
    moderation/
  realtime/

mobile/
  ios/
    LilithApp/
      Services/
      Models/
      ViewModels/
      Views/
```

## Prerequisites

- Python 3.11+
- Docker (for Postgres + Redis local)

## Environment

1. Copy env:
```bash
cp .env.example .env
```

2. For Postgres mode, set:
```env
DATABASE_URL=postgresql+psycopg2://lilith:lilith@localhost:5432/lilith
REDIS_URL=redis://localhost:6379/0
```

Security-focused env (recommended for production-like runs):
```env
JWT_SECRET=<strong-random-secret>
JWT_ISSUER=lilith-api
JWT_AUDIENCE=lilith-clients
DATA_ENCRYPTION_KEY=<fernet-key-or-secret-phrase>
GLOBAL_RATE_LIMIT_PER_MINUTE=300
AUTH_RATE_LIMIT_PER_MINUTE=40
MESSAGE_RATE_LIMIT_PER_MINUTE=90
PAYMENT_RATE_LIMIT_PER_MINUTE=50
TOOL_RATE_LIMIT_PER_MINUTE=80
```

For SQLite local-only fallback:
```env
DATABASE_URL=sqlite:///./lilith.db
```

## Run with Docker Compose

```bash
docker compose up --build
```

API: `http://127.0.0.1:8000`

## Run API directly

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn apps.api.main:app --host 0.0.0.0 --port 8000 --reload
```

## Health

- `GET /`
- `GET /health`
- `GET /health/ready` (checks DB + Redis readiness)

## API Quick Test Flow

### 1) Register two users

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"123456"}'

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"123456"}'
```

### 2) Login

```bash
ALICE_TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"123456"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### 3) Capture Bob user id

Use the `id` returned by Bob’s `/api/v1/auth/register` response as `<BOB_USER_ID>`.

### 4) Send message

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"receiver_id":"<BOB_USER_ID>","content":"Hi Bob"}'
```

### 5) Create + confirm payment

```bash
INTENT_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/payments/create-intent \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"receiver_id":"<BOB_USER_ID>","amount":5.0,"currency":"USD","kind":"tip"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

curl -s -X POST http://127.0.0.1:8000/api/v1/payments/confirm \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"intent_id\":\"$INTENT_ID\"}"
```

### 6) Run tool

```bash
JOB_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/tools/run \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool_name":"text_summarizer","input_payload":{"text":"Lilith is building a powerful modular monolith foundation with realtime and payments."}}' | python3 -c "import sys,json; print(json.load(sys.stdin)['job_id'])")

curl -s -H "Authorization: Bearer $ALICE_TOKEN" \
  http://127.0.0.1:8000/api/v1/tools/results/$JOB_ID
```

### 7) Websocket

Connect:
`ws://127.0.0.1:8000/api/v1/realtime/ws?token=<JWT>`

Supported events:
- `message.new`
- `message.read`
- `notification.new`
- `presence.update`
- `typing`

Client may send:
- `heartbeat`
- `typing`

### 8) Browser layer

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/browser/connect \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Notion","domain":"notion.so"}'

curl -s -X POST http://127.0.0.1:8000/api/v1/browser/analyze \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

### 9) Growth

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/growth/subscribe \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

### 10) NeuroCloud

```bash
curl -s http://127.0.0.1:8000/api/v1/neurocloud/memory \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

### 11) Self-healing runtime operations

```bash
# Monitor report
curl -s http://127.0.0.1:8000/api/v1/self-heal/report \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Analyzer: generate optimization suggestions
curl -s -X POST http://127.0.0.1:8000/api/v1/self-heal/analyze \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Safe cache clear (guardrailed by allowed prefix)
curl -s -X POST http://127.0.0.1:8000/api/v1/self-heal/fix/clear-cache \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prefix":"lilith:"}'
```

### 12) Observability dashboard APIs

```bash
curl -s http://127.0.0.1:8000/api/v1/system/metrics \
  -H "Authorization: Bearer $ALICE_TOKEN"

curl -s http://127.0.0.1:8000/api/v1/system/logs \
  -H "Authorization: Bearer $ALICE_TOKEN"

curl -s http://127.0.0.1:8000/api/v1/system/alerts \
  -H "Authorization: Bearer $ALICE_TOKEN"

curl -s http://127.0.0.1:8000/api/v1/system/health \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

Live stream:
`ws://127.0.0.1:8000/api/v1/system/stream?token=<JWT>`

### 13) Admin Control Panel APIs

Use the seeded admin account:
- username: `lilith_admin`
- password: `123456`

Key endpoints:
- `GET /api/v1/admin/users`
- `POST /api/v1/admin/users/{id}/status`
- `GET /api/v1/admin/payments/transactions`
- `POST /api/v1/admin/payments/refund`
- `POST /api/v1/admin/payments/flag-fraud`
- `GET /api/v1/admin/tools`
- `POST /api/v1/admin/tools/control`
- `GET /api/v1/admin/moderation/reports`
- `POST /api/v1/admin/moderation/reports/{id}/action`
- `GET /api/v1/admin/system/metrics`
- `POST /api/v1/admin/system/fix/restart`
- `POST /api/v1/admin/system/fix/clear-cache`
- `GET /api/v1/admin/actions` (all admin actions are logged)

Moderation intake route:
- `POST /api/v1/moderation/report`

## SwiftUI Connection Layer

Created under:
`mobile/ios/LilithApp/`

Includes:
- Services: APIClient, AuthService, MessagingService, PaymentService, ToolService, WebSocketService
- Models: User, Message, Payment, ToolJob
- ViewModels: Auth, Chat, Wallet, Tool
- Views: Login, Chat, Wallet, ToolRunner

Expo browser module:
- `mobile/expo/app/connected-apps.tsx` with live `WebView` + AI overlay actions.
- Requires valid JWT token injection in `mobile/expo/app/_layout.tsx`.
- Observability dashboard screen:
  - `mobile/expo/app/system-dashboard.tsx`

## Fully working now

- Auth register/login/me
- Messaging send/thread/read
- Notifications list/read
- Presence heartbeat
- Realtime websocket with token auth
- Lilith Pay starter (create intent, confirm transfer, history, balance)
- Tool execution starter with persisted jobs/results
- Browser connect/analyze/send-to-chat/run-tool routes
- Growth subscribe/send-email/create-page/get-page routes
- NeuroCloud memory + execute routes
- Runtime monitoring for API errors, slow responses, failed jobs, websocket issues
- Self-heal operations: safe retry, restart realtime/redis health check, cache clear
- Optimization suggestions: caching/query/batching based on incident trends
- Observability endpoints + live metric stream for dashboard clients
- Role-based admin access (`user_roles`) and admin action audit logs (`admin_action_logs`)
- Global + per-domain rate limiting with Redis and in-memory fallback
- JWT hardening with issuer/audience/nbf/iat/jti claims
- Message safety policy enforcement + spam protection + optional content encryption at rest
- Payment hardening: fraud checks, idempotency key support, ledger invariant checks
- Tool/browser safety checks for payload and content policy
- Redis-backed fanout/presence/rate-limit when Redis is available
- In-memory fallback when Redis is unavailable

## Scaffolded for later

- Worker process queue is scaffolded (`apps/worker/worker.py`)
- Realtime split process entrypoint scaffolded (`apps/realtime/ws_server.py`)
- Subscription billing processors (Stripe/stablecoin rails) are future extension points
- `growth/send-email` is scaffolded for provider delivery (returns queued/delivered count)
- Self-heal `retry` action is guardrailed to safe route prefixes and GET/POST only
- Self-heal does not modify source code; runtime actions only
- `growth/send-email` and worker queue remain scaffolded integration points
