from __future__ import annotations

import os
from typing import Any

from sqlalchemy.orm import Session

from backend.platform.models import DevicePushToken, Notification
from backend.platform.observability import audit_event


class PushProvider:
    def __init__(self) -> None:
        self.provider = os.getenv("PUSH_PROVIDER", "stub").strip().lower()

    async def send(self, token: str, title: str, body: str, data: dict[str, Any]) -> None:
        # Provider adapter scaffold. Replace with APNs/FCM integration in production.
        audit_event(
            "push.send",
            provider=self.provider,
            token_suffix=token[-8:] if token else "",
            title=title,
            body=body,
            data=data,
        )


push_provider = PushProvider()


async def send_push_for_notification(db: Session, user_id: int, notification: Notification) -> int:
    tokens = db.query(DevicePushToken).filter(DevicePushToken.user_id == user_id).all()
    sent = 0
    for token in tokens:
        await push_provider.send(
            token=token.token,
            title="Lilith",
            body=notification.text,
            data={
                "eventType": notification.event_type,
                "targetType": notification.target_type,
                "targetId": notification.target_id,
                "deepLink": notification.deep_link,
            },
        )
        sent += 1
    return sent

