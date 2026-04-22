# Lilith System Architecture

This backend follows a modular monolith pattern with NeuroCloud as the core trust and execution layer.

## Layers

1. Client Layer
- Mobile/web clients authenticate, persist session state, and subscribe to realtime updates.

2. UI Layer (Lilith OS)
- Environment-first shell with integrated social, messaging, wallet, inbox, and tools surfaces.

3. AI Layer
- Intent handling, reasoning, and async AI job orchestration.
- Produces structured actions routed through tool and service domains.

4. NeuroCloud Core
- Identity trust (passkey challenge scaffolding, device trust).
- Scoped token issuance/validation.
- Memory and preference profile storage.
- Execution jobs for permissioned AI-driven actions.
- Cross-domain event stream (`neurocloud_events`).

5. Service Layer
- Messaging/calls, social graph/feed, notifications, inbox/exchange, payments/wallet, tools, guardian/world domains.

6. Data + Infrastructure Layer
- PostgreSQL (production target) for source-of-truth entities.
- Redis for presence, typing, fanout, and rate-limit buckets.
- Media/object storage abstraction for assets and signed URL workflows.

## Realtime

WebSocket endpoint: `/api/v1/realtime/ws`

Core events:
- `message.new`
- `message.read`
- `thread.typing`
- `typing`
- `notification.new`
- `presence.update`
- `call.invite`
- `call.accept`
- `call.decline`
- `call.end`
- `call.signal`

Redis pub/sub is used for multi-instance fanout when configured.

## Security

- JWT session auth and refresh flow.
- NeuroCloud scoped credentials for short-lived permissioned execution.
- Passkey verification hooks for step-up and payment-sensitive actions.
- Rate limiting on auth, social, messaging, calls, payments, and realtime typing.
- Payment risk review and event auditing.
- Guardian and moderation policy hooks.

## System Inspection Endpoints

- `GET /api/v1/system/architecture`
- `GET /api/v1/system/realtime`
- `GET /api/v1/system/security`
- `GET /api/v1/system/infrastructure`

These endpoints expose the active architecture contract for frontend and ops alignment.
