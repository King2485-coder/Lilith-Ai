from __future__ import annotations

import base64
import hashlib

from backend.core.settings import settings

try:
    from cryptography.fernet import Fernet, InvalidToken
except Exception:  # pragma: no cover
    Fernet = None  # type: ignore
    InvalidToken = Exception  # type: ignore


def _fernet() -> "Fernet | None":
    if Fernet is None:
        return None
    key = settings.data_encryption_key.strip()
    if not key:
        return None
    try:
        if len(key) != 44:
            derived = base64.urlsafe_b64encode(hashlib.sha256(key.encode("utf-8")).digest())
            return Fernet(derived)
        return Fernet(key.encode("utf-8"))
    except Exception:
        return None


def encrypt_text(value: str) -> str:
    value = value or ""
    f = _fernet()
    if f is None:
        return value
    token = f.encrypt(value.encode("utf-8")).decode("utf-8")
    return f"enc:{token}"


def decrypt_text(value: str) -> str:
    value = value or ""
    if not value.startswith("enc:"):
        return value
    f = _fernet()
    if f is None:
        return "[encrypted]"
    token = value[4:]
    try:
        return f.decrypt(token.encode("utf-8")).decode("utf-8")
    except InvalidToken:
        return "[encrypted]"
    except Exception:
        return "[encrypted]"

