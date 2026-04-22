from __future__ import annotations

import os
from typing import Any


def _storage_mode() -> str:
    database_url = os.getenv("DATABASE_URL", "sqlite:///./lilith.db").lower()
    if database_url.startswith("postgresql"):
        return "postgresql"
    if database_url.startswith("sqlite"):
        return "sqlite"
    return "custom"


def architecture_manifest() -> dict[str, Any]:
    return {
        "system": "Lilith",
        "version": "v1",
        "pattern": "modular_monolith",
        "core": "NeuroCloud",
        "layers": [
            {
                "id": "client",
                "name": "Client Layer",
                "responsibilities": [
                    "Mobile and web application clients",
                    "Session persistence and token attachment",
                    "Realtime websocket session setup",
                ],
                "entrypoints": ["iOS SwiftUI app", "web client"],
            },
            {
                "id": "ui_os",
                "name": "Lilith OS UI Layer",
                "responsibilities": [
                    "Unified environment-first interface",
                    "Context-aware surfaces for chat, social, wallet, inbox, tools",
                    "Action launch and state rendering",
                ],
                "entrypoints": ["workspace shell", "tools workspaces", "social + messaging surfaces"],
            },
            {
                "id": "ai",
                "name": "AI Intent + Reasoning Layer",
                "responsibilities": [
                    "Intent detection and structured tool routing",
                    "Prompt orchestration and response shaping",
                    "AI job lifecycle for async generation and analysis",
                ],
                "entrypoints": ["/api/v1/ai/jobs", "/api/v1/tools/*", "/api/v1/chat/*"],
            },
            {
                "id": "neurocloud",
                "name": "NeuroCloud Core",
                "responsibilities": [
                    "Identity trust (passkey challenge scaffolding, device trust)",
                    "Scoped credential issuance and validation",
                    "Memory profile and preference persistence",
                    "Execution job lifecycle and secured action dispatch",
                    "Neuro event stream for cross-domain observability",
                ],
                "entrypoints": ["/api/v1/neurocloud/*"],
            },
            {
                "id": "services",
                "name": "Service Layer",
                "responsibilities": [
                    "Messaging and call signaling",
                    "Social feed, profiles, follows, notifications, inbox/exchange",
                    "Payments, wallet, subscriptions, payouts",
                    "Tools marketplace, jobs, results, sharing",
                    "Education/guardian/world systems",
                ],
                "entrypoints": ["/api/v1/messages/*", "/api/v1/feed/*", "/api/v1/payments/*", "/api/v1/tools/*"],
            },
            {
                "id": "data",
                "name": "Data + Infrastructure Layer",
                "responsibilities": [
                    "Relational data persistence",
                    "Ephemeral state and fanout via Redis",
                    "Object/media asset metadata and retrieval references",
                    "Rate limits and trust telemetry",
                ],
                "entrypoints": ["SQLAlchemy models", "Redis realtime hub", "media asset APIs"],
            },
        ],
    }


def realtime_manifest() -> dict[str, Any]:
    return {
        "transport": "websocket",
        "channel": "/api/v1/realtime/ws",
        "events": [
            "message.new",
            "message.read",
            "thread.typing",
            "typing",
            "notification.new",
            "presence.update",
            "call.invite",
            "call.accept",
            "call.decline",
            "call.end",
            "call.signal",
        ],
        "fanout": "redis_pubsub_when_enabled_else_local",
        "presence": "redis_ttl_presence_keys_with_inmemory_fallback",
    }


def security_manifest() -> dict[str, Any]:
    return {
        "identity": {
            "jwt_sessions": True,
            "passkey_hooks": True,
            "device_trust": True,
            "scoped_credentials": True,
        },
        "controls": {
            "rate_limiting": True,
            "server_side_authorization": True,
            "idempotency_payments": True,
            "risk_reviews": True,
            "audit_events": True,
            "child_guardian_policies": True,
            "moderation_scaffold": True,
        },
        "secrets": {
            "raw_frontend_api_keys_exposed": False,
            "neurocloud_scoped_token_secret_configured": bool(os.getenv("NEUROCLOUD_SCOPED_TOKEN_SECRET")),
        },
    }


def infrastructure_manifest() -> dict[str, Any]:
    redis_url = os.getenv("REDIS_URL", "").strip()
    return {
        "database": {
            "mode": _storage_mode(),
            "url_configured": bool(os.getenv("DATABASE_URL")),
            "target": "postgresql_preferred_for_production",
        },
        "cache_and_realtime": {
            "redis_configured": bool(redis_url),
            "redis_prefix": os.getenv("REDIS_PREFIX", "lilith"),
        },
        "object_storage": {
            "mode": "metadata_plus_url_reference",
            "signed_url_pattern_supported": True,
        },
        "deployment": {
            "api_gateway_entrypoint": "apps/api/main.py",
            "observability": "sentry_hooks_plus_structured_audit_events",
        },
    }

