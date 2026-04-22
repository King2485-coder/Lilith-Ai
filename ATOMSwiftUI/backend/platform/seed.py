from __future__ import annotations

import os

from sqlalchemy.orm import Session

from backend.platform.models import ConversationMember, Follow, Notification, Post, Reaction
from backend.platform.services import ensure_profile
from backend.state import ChatMessage, Conversation, User


def _create_user(db: Session, email: str, password_hash: str, name: str) -> User:
    row = db.query(User).filter(User.email == email).first()
    if row:
        return row
    row = User(
        email=email,
        hashed_password=password_hash,
        name=name,
        role="user",
        credits=200.0,
        is_super_admin=False,
    )
    db.add(row)
    db.flush()
    ensure_profile(db, row)
    return row


def seed_platform_data(db: Session, hash_password_fn) -> None:
    if os.getenv("LILITH_SEED_ON_START", "true").lower() not in {"1", "true", "yes"}:
        return

    users = [
        _create_user(db, "maya@lilith.local", hash_password_fn("Pass1234!"), "Maya Rivers"),
        _create_user(db, "jordan@lilith.local", hash_password_fn("Pass1234!"), "Jordan Hale"),
        _create_user(db, "noah@lilith.local", hash_password_fn("Pass1234!"), "Noah Avery"),
        _create_user(db, "aria@lilith.local", hash_password_fn("Pass1234!"), "Aria Stone"),
    ]
    db.flush()

    existing_posts = db.query(Post).count()
    if existing_posts < 8:
        for idx, user in enumerate(users):
            for post_num in range(2):
                post = Post(
                    author_user_id=user.id,
                    body=f"Lilith beta update {idx + 1}.{post_num + 1}: shipping faster social loops.",
                    visibility="public",
                )
                db.add(post)
                db.flush()
                if users[(idx + 1) % len(users)].id != user.id:
                    db.add(
                        Reaction(
                            post_id=post.id,
                            user_id=users[(idx + 1) % len(users)].id,
                            reaction="like",
                        )
                    )

    for idx, user in enumerate(users):
        target = users[(idx + 1) % len(users)]
        edge = db.query(Follow).filter(Follow.follower_user_id == user.id, Follow.followed_user_id == target.id).first()
        if not edge:
            db.add(Follow(follower_user_id=user.id, followed_user_id=target.id))

    conversation = db.query(Conversation).filter(Conversation.title == "Lilith Beta Lounge").first()
    if conversation is None:
        owner = users[0]
        conversation = Conversation(user_id=owner.id, title="Lilith Beta Lounge")
        db.add(conversation)
        db.flush()
        for user in users:
            db.add(ConversationMember(conversation_id=conversation.id, user_id=user.id))
        db.flush()
        db.add(ChatMessage(conversation_id=conversation.id, role="user", content="Welcome to Lilith beta chat."))
        db.add(ChatMessage(conversation_id=conversation.id, role="assistant", content="Realtime stack is live and ready."))

    for user in users:
        exists = db.query(Notification).filter(
            Notification.user_id == user.id,
            Notification.event_type == "system.beta",
        ).first()
        if not exists:
            db.add(
                Notification(
                    user_id=user.id,
                    actor_user_id=None,
                    event_type="system.beta",
                    target_type="system",
                    target_id="beta",
                    text="Welcome to Lilith beta. Explore feed, messages, calls, and tools.",
                    deep_link="/home",
                    read=False,
                )
            )

    db.commit()

