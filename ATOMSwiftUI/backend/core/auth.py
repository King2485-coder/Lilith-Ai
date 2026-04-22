from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from jose import JWTError, jwt

from backend.core.settings import settings


def create_access_token(subject: str) -> str:
    expires_at = datetime.utcnow() + timedelta(minutes=settings.token_expire_minutes)
    payload = {
        "sub": subject,
        "exp": expires_at,
        "iat": datetime.utcnow(),
        "nbf": datetime.utcnow(),
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> str:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
            options={"verify_aud": True, "verify_iss": True},
        )
        subject = payload.get("sub")
        if not subject:
            raise ValueError("Invalid token subject")
        return str(subject)
    except JWTError as exc:
        raise ValueError("Invalid access token") from exc
