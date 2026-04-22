from __future__ import annotations

import json
import logging
import os
from typing import Any

_logger = logging.getLogger("lilith.platform")
_sentry_sdk = None


def configure_observability() -> None:
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    dsn = os.getenv("SENTRY_DSN", "").strip()
    if not dsn:
        return
    try:
        import sentry_sdk  # type: ignore
    except Exception:
        _logger.warning("SENTRY_DSN set but sentry-sdk is not installed")
        return
    sentry_sdk.init(
        dsn=dsn,
        traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.05")),
        environment=os.getenv("APP_ENV", "development"),
        release=os.getenv("APP_RELEASE", "local"),
    )
    globals()["_sentry_sdk"] = sentry_sdk


def audit_event(event: str, **fields: Any) -> None:
    payload = {"event": event, **fields}
    _logger.info(json.dumps(payload, default=str))


def capture_exception(exc: Exception, **context: Any) -> None:
    _logger.exception("platform_exception", extra={"context": context})
    if _sentry_sdk is not None:
        with _sentry_sdk.push_scope() as scope:
            for key, value in context.items():
                scope.set_extra(key, value)
            _sentry_sdk.capture_exception(exc)

