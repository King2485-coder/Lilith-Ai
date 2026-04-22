from __future__ import annotations


DEFAULT_PERMISSIONS = {
    "messages.send",
    "payments.create",
    "payments.confirm",
    "tools.run",
    "browser.analyze",
    "growth.send_email",
}


def can_execute(permission: str) -> bool:
    return permission in DEFAULT_PERMISSIONS

