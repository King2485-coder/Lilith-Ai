from __future__ import annotations

from backend.core.auth import create_access_token, decode_access_token


def issue_identity_token(username: str) -> str:
    return create_access_token(username)


def verify_identity_token(token: str) -> str:
    return decode_access_token(token)

