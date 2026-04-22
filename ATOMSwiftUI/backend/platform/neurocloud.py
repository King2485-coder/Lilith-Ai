from __future__ import annotations

import hashlib
import json
import os
import secrets
from datetime import timedelta
from typing import Any

from sqlalchemy.orm import Session

from backend.platform.models import NeurocloudEvent, NeurocloudExecutionJob, NeurocloudScopedCredential
from backend.state import new_id, utcnow


DEFAULT_SCOPE_SET = {
    "identity:read",
    "memory:read",
    "memory:write",
    "execution:run",
    "payments:execute",
    "tools:run",
    "messages:send",
    "safety:enforce",
}


def _secret_key() -> str:
    return os.getenv("NEUROCLOUD_SCOPED_TOKEN_SECRET", "neurocloud-dev-secret")


def hash_scoped_token(raw_token: str) -> str:
    return hashlib.sha256(f"{_secret_key()}::{raw_token}".encode("utf-8")).hexdigest()


def normalize_scopes(scopes: list[str]) -> list[str]:
    parsed = sorted({scope.strip() for scope in scopes if scope.strip() in DEFAULT_SCOPE_SET})
    return parsed or ["identity:read"]


def issue_scoped_credential(
    db: Session,
    *,
    user_id: int,
    scopes: list[str],
    ttl_seconds: int = 900,
    issued_for: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> tuple[NeurocloudScopedCredential, str]:
    raw_token = f"nc_{secrets.token_urlsafe(28)}"
    row = NeurocloudScopedCredential(
        user_id=user_id,
        token_hash=hash_scoped_token(raw_token),
        scopes_json=json.dumps(normalize_scopes(scopes), default=str),
        expires_at=utcnow() + timedelta(seconds=max(60, min(ttl_seconds, 3600))),
        revoked=False,
        issued_for=issued_for,
        metadata_json=json.dumps(metadata or {}, default=str),
    )
    db.add(row)
    db.flush()
    return row, raw_token


def validate_scoped_credential(
    db: Session,
    *,
    raw_token: str,
    required_scopes: list[str],
) -> tuple[NeurocloudScopedCredential, set[str]]:
    row = (
        db.query(NeurocloudScopedCredential)
        .filter(
            NeurocloudScopedCredential.token_hash == hash_scoped_token(raw_token),
            NeurocloudScopedCredential.revoked.is_(False),
            NeurocloudScopedCredential.expires_at > utcnow(),
        )
        .first()
    )
    if row is None:
        raise PermissionError("Invalid or expired NeuroCloud scoped credential")
    granted = set(json.loads(row.scopes_json or "[]"))
    for scope in required_scopes:
        if scope not in granted:
            raise PermissionError(f"Missing NeuroCloud scope: {scope}")
    return row, granted


def create_passkey_challenge(action: str, user_id: int) -> dict[str, Any]:
    # WebAuthn wiring point: challenge + relying party metadata.
    return {
        "challengeId": new_id(),
        "challenge": secrets.token_urlsafe(24),
        "action": action,
        "userId": user_id,
        "expiresAt": (utcnow() + timedelta(minutes=5)).isoformat(),
        "rpId": os.getenv("NEUROCLOUD_RP_ID", "lilith.local"),
    }


def create_execution_job(
    db: Session,
    *,
    user_id: int,
    action_type: str,
    scope_required: str | None,
    input_payload: dict[str, Any],
    metadata: dict[str, Any] | None = None,
) -> NeurocloudExecutionJob:
    row = NeurocloudExecutionJob(
        user_id=user_id,
        action_type=action_type,
        scope_required=scope_required,
        status="queued",
        input_json=json.dumps(input_payload or {}, default=str),
        output_json="{}",
        metadata_json=json.dumps(metadata or {}, default=str),
    )
    db.add(row)
    db.flush()
    return row


def complete_execution_job(
    db: Session,
    row: NeurocloudExecutionJob,
    *,
    status: str,
    output: dict[str, Any] | None = None,
    error: str | None = None,
) -> NeurocloudExecutionJob:
    row.status = status
    row.output_json = json.dumps(output or {}, default=str)
    row.error = error
    row.updated_at = utcnow()
    db.add(row)
    db.flush()
    return row


def emit_neuro_event(
    db: Session,
    *,
    event_type: str,
    source_type: str,
    source_id: str | None = None,
    user_id: int | None = None,
    channel: str = "core",
    payload: dict[str, Any] | None = None,
) -> NeurocloudEvent:
    row = NeurocloudEvent(
        user_id=user_id,
        event_type=event_type,
        channel=channel,
        source_type=source_type,
        source_id=source_id,
        payload_json=json.dumps(payload or {}, default=str),
    )
    db.add(row)
    db.flush()
    return row

