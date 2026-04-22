# Lilith Modular Monolith Architecture

## Folder Tree

```text
ATOMSwiftUI/
├── apps/
│   └── api/
│       ├── main.py
│       └── README.md
├── backend/
│   ├── core/
│   │   └── neurocloud/
│   │       ├── __init__.py
│   │       └── README.md
│   ├── ai/
│   │   ├── __init__.py
│   │   ├── README.md
│   │   ├── intent/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── reasoning/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   └── orchestration/
│   │       ├── __init__.py
│   │       └── README.md
│   ├── services/
│   │   ├── __init__.py
│   │   ├── README.md
│   │   ├── messaging/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── calls/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── payments/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── tools/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── learning/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── social/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── notifications/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   └── inbox/
│   │       ├── __init__.py
│   │       └── README.md
│   ├── shared/
│   │   ├── __init__.py
│   │   ├── README.md
│   │   ├── auth/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── security/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   ├── events/
│   │   │   ├── __init__.py
│   │   │   └── README.md
│   │   └── storage/
│   │       ├── __init__.py
│   │       └── README.md
│   ├── platform/            # existing active API/domain implementation
│   ├── integrations/        # existing external adapters
│   └── state.py             # existing persistence bootstrap
├── frontend/
│   └── README.md
├── mobile/
│   └── README.md
├── web/                     # existing web client
└── Lilith/                  # existing iOS SwiftUI client
```

## Module Purpose

- `apps/api`: API gateway entrypoint, app startup, middleware, router composition.
- `backend/core/neurocloud`: trust core for identity, memory, scoped credentials, secure execution.
- `backend/ai/intent`: intent parsing and command classification.
- `backend/ai/reasoning`: policy-aware reasoning and action plan shaping.
- `backend/ai/orchestration`: async job orchestration and AI-to-tool execution bridging.
- `backend/services/*`: product domains (messaging, calls, payments, tools, learning, social, notifications, inbox).
- `backend/shared/auth`: common auth/session helpers.
- `backend/shared/security`: permission checks, risk controls, guardrails.
- `backend/shared/events`: domain event contracts and publish/subscribe abstractions.
- `backend/shared/storage`: database/redis/object storage adapters.
- `frontend`: web client architecture notes and contracts with backend APIs.
- `mobile`: iOS/mobile app architecture notes and contracts with backend APIs.

## Recommended Build Order

1. Core contracts
- Finalize `backend/shared` interfaces for auth, security, events, storage.

2. NeuroCloud core
- Consolidate passkeys, device trust, scoped credentials, memory profile, execution jobs.

3. API gateway wiring
- Keep `apps/api/main.py` as single runtime entrypoint and register module routers.

4. Service modules
- Messaging + notifications + social first.
- Payments + tools second.
- Learning/worlds third.

5. AI layer
- Implement intent -> reasoning -> orchestration pipeline on top of service contracts.

6. Realtime/eventing
- Standardize websocket event envelope and domain event fanout.

7. Frontend + mobile integration
- Bind web and iOS clients to unified API contracts and realtime events.

8. Hardening
- Observability, rate limiting, abuse controls, rollout flags, load testing.
