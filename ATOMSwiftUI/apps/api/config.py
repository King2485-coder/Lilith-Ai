from __future__ import annotations

from backend.core.settings import settings


def cors_origins() -> list[str]:
    return [item.strip() for item in settings.cors_origins.split(",") if item.strip()]

