from __future__ import annotations

from backend.core.events import event_frame
from backend.realtime.manager import realtime_manager


async def broadcast_message_new(receiver_id: str, message_id: str, sender_id: str, content: str) -> None:
    await realtime_manager.publish_to_users(
        [receiver_id],
        event_frame(
            "message.new",
            {"message_id": message_id, "sender_id": sender_id, "content": content},
        ),
    )


async def broadcast_message_read(sender_id: str, message_id: str) -> None:
    await realtime_manager.publish_to_users([sender_id], event_frame("message.read", {"message_id": message_id}))


async def broadcast_notification(user_id: str, notification_id: str, title: str, body: str) -> None:
    await realtime_manager.publish_to_users(
        [user_id],
        event_frame("notification.new", {"notification_id": notification_id, "title": title, "body": body}),
    )

