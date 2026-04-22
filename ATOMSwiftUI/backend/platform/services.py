from __future__ import annotations

import json
import os
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from sqlalchemy import and_, desc
from sqlalchemy.orm import Session

from backend.platform.models import (
    Block,
    Comment,
    Follow,
    InboxItem,
    MediaAsset,
    Notification,
    NotificationPreference,
    Post,
    PostMedia,
    Profile,
    ProfileSettings,
    Reaction,
    Save,
    SessionToken,
    ToolAsset,
    ToolJob,
    ToolResult,
)
from backend.state import User, new_id, utcnow


MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", "./media_store")).resolve()

_EMOTION_PATTERNS: dict[str, tuple[str, ...]] = {
    "overwhelmed": ("overwhelmed", "stressed", "anxious", "panic", "too much", "burned out"),
    "frustrated": ("frustrated", "annoyed", "stuck", "angry", "mad", "upset"),
    "sad": ("sad", "down", "lonely", "hurt", "depressed"),
    "excited": ("excited", "awesome", "great", "amazing", "love this", "happy"),
    "confused": ("confused", "not sure", "don't understand", "what?", "unclear"),
}


def _safe_user_settings(user: User) -> dict[str, Any]:
    try:
        return json.loads(user.settings_json or "{}")
    except Exception:
        return {}


def detect_user_audience(user: User, *, force_child: bool = False) -> str:
    if force_child:
        return "child"
    settings = _safe_user_settings(user)
    age_value = settings.get("age")
    try:
        age = int(age_value)
    except Exception:
        age = None
    if age is not None:
        if age <= 12:
            return "child"
        if age <= 17:
            return "teen"
    return "adult"


def detect_user_emotion(text: str) -> str:
    lower = (text or "").lower()
    for emotion, terms in _EMOTION_PATTERNS.items():
        if any(term in lower for term in terms):
            return emotion
    return "neutral"


def _trim_sentences(text: str, limit: int = 3) -> str:
    chunks = [part.strip() for part in re.split(r"(?<=[.!?])\s+", text.strip()) if part.strip()]
    if not chunks:
        return text.strip()
    return " ".join(chunks[:limit]).strip()


def _tone_prefix(emotion: str, audience: str) -> str:
    if emotion in {"overwhelmed", "frustrated", "sad"}:
        if audience == "child":
            return "You're safe here. We can do this one small step at a time."
        return "I hear you. We can keep this simple and steady."
    if emotion == "excited":
        return "Nice momentum. Let's use it well."
    if emotion == "confused":
        if audience == "child":
            return "No problem. I can explain it in a simpler way."
        return "Good call. I'll make this clearer."
    return ""


def _audience_rewrite(base_text: str, audience: str) -> str:
    text = _trim_sentences(base_text, limit=3)
    if audience == "child":
        text = text.replace("execute", "do").replace("configure", "set up").replace("preview", "look at")
        return _trim_sentences(text, limit=2)
    if audience == "teen":
        return _trim_sentences(text, limit=3)
    return _trim_sentences(text, limit=3)


def apply_lilith_voice(
    *,
    user: User,
    user_text: str,
    base_text: str,
    tool_used: str,
    proactive_hint: str | None = None,
    force_child: bool = False,
) -> str:
    audience = detect_user_audience(user, force_child=force_child)
    emotion = detect_user_emotion(user_text)
    prefix = _tone_prefix(emotion, audience)
    body = _audience_rewrite(base_text, audience)

    if proactive_hint:
        if audience == "child":
            suggestion = f"Next: {proactive_hint}."
        elif audience == "teen":
            suggestion = f"Next step: {proactive_hint}."
        else:
            suggestion = f"Recommended next step: {proactive_hint}."
    else:
        if audience == "child":
            suggestion = f"Want me to open the {tool_used} area for you?"
        elif audience == "teen":
            suggestion = f"I can open {tool_used} if you want."
        else:
            suggestion = f"I can open {tool_used} when you're ready."

    parts = [segment for segment in [prefix, body, suggestion] if segment]
    return " ".join(parts).strip()


def lilith_voice_profile(user: User, user_text: str, *, force_child: bool = False) -> dict[str, Any]:
    audience = detect_user_audience(user, force_child=force_child)
    emotion = detect_user_emotion(user_text)
    return {
        "audience": audience,
        "emotion": emotion,
        "traits": ["calm", "confident", "helpful", "slightly_playful", "emotionally_aware"],
        "style": {
            "sentenceLength": "short_clear",
            "tone": "warm_supportive",
            "interruptions": "minimal",
            "guidance": "proactive",
        },
    }


def slugify_username(source: str) -> str:
    candidate = re.sub(r"[^a-zA-Z0-9_]", "", source or "").lower()
    if not candidate:
        candidate = f"user{int(datetime.utcnow().timestamp())}"
    return candidate[:28]


def make_lilith_id(user: User) -> str:
    return f"LIL-{user.id:06d}"


def ensure_profile(db: Session, user: User) -> Profile:
    profile = db.query(Profile).filter(Profile.user_id == user.id).first()
    if profile:
        return profile
    base = slugify_username(user.name or user.email.split("@")[0])
    username = base
    counter = 1
    while db.query(Profile).filter(Profile.username == username).first():
        counter += 1
        username = f"{base}{counter}"
    profile = Profile(
        user_id=user.id,
        username=username,
        lilith_id=make_lilith_id(user),
        display_name=user.name or username,
        bio="",
    )
    db.add(profile)
    db.flush()
    db.add(ProfileSettings(profile_id=profile.id))
    db.add(NotificationPreference(user_id=user.id))
    db.flush()
    return profile


def profile_stats(db: Session, user_id: int) -> dict[str, int]:
    return {
        "posts": db.query(Post).filter(Post.author_user_id == user_id).count(),
        "followers": db.query(Follow).filter(Follow.followed_user_id == user_id).count(),
        "following": db.query(Follow).filter(Follow.follower_user_id == user_id).count(),
    }


def create_notification(
    db: Session,
    user_id: int,
    event_type: str,
    text: str,
    actor_user_id: int | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    deep_link: str | None = None,
) -> Notification:
    notification = Notification(
        user_id=user_id,
        actor_user_id=actor_user_id,
        event_type=event_type,
        text=text,
        target_type=target_type,
        target_id=target_id,
        deep_link=deep_link,
    )
    db.add(notification)
    db.flush()
    return notification


def create_inbox_item(
    db: Session,
    user_id: int,
    item_type: str,
    title: str,
    body: str | None = None,
    actor_user_id: int | None = None,
    source_type: str | None = None,
    source_id: str | None = None,
    status: str = "unread",
    metadata: dict[str, Any] | None = None,
) -> InboxItem:
    row = InboxItem(
        user_id=user_id,
        actor_user_id=actor_user_id,
        item_type=item_type,
        title=title,
        body=body,
        source_type=source_type,
        source_id=source_id,
        status=status,
        metadata_json=json.dumps(metadata or {}, default=str),
    )
    db.add(row)
    db.flush()
    return row


def blocked_user_ids(db: Session, user_id: int) -> set[int]:
    ids = set()
    for row in db.query(Block).filter(Block.blocker_user_id == user_id).all():
        ids.add(row.blocked_user_id)
    for row in db.query(Block).filter(Block.blocked_user_id == user_id).all():
        ids.add(row.blocker_user_id)
    return ids


def rank_posts(db: Session, viewer_user_id: int, limit: int = 25, cursor: str | None = None) -> list[Post]:
    followed_ids = [
        row.followed_user_id
        for row in db.query(Follow).filter(Follow.follower_user_id == viewer_user_id).all()
    ]
    candidate_ids = set(followed_ids + [viewer_user_id])
    if not candidate_ids:
        candidate_ids = {viewer_user_id}
    blocked = blocked_user_ids(db, viewer_user_id)

    query = db.query(Post).filter(Post.author_user_id.in_(candidate_ids))
    if blocked:
        query = query.filter(~Post.author_user_id.in_(blocked))
    if cursor:
        query = query.filter(Post.created_at < datetime.fromisoformat(cursor))

    rows = query.order_by(desc(Post.created_at)).limit(limit * 3).all()
    scored: list[tuple[float, Post]] = []
    now = utcnow()
    for post in rows:
        age_hours = max((now - post.created_at).total_seconds() / 3600.0, 0.05)
        reaction_count = db.query(Reaction).filter(Reaction.post_id == post.id).count()
        comment_count = db.query(Comment).filter(Comment.post_id == post.id).count()
        share_count = db.query(Save).filter(Save.post_id == post.id).count()
        follows_boost = 1.2 if post.author_user_id in followed_ids else 1.0
        score = follows_boost * ((reaction_count * 0.8) + (comment_count * 1.2) + (share_count * 0.6) + 1) / age_hours
        scored.append((score, post))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [post for _, post in scored[:limit]]


def serialize_post(db: Session, post: Post, viewer_user_id: int | None = None) -> dict[str, Any]:
    profile = db.query(Profile).filter(Profile.user_id == post.author_user_id).first()
    comments = db.query(Comment).filter(Comment.post_id == post.id).order_by(Comment.created_at.asc()).all()
    reactions = db.query(Reaction).filter(Reaction.post_id == post.id).all()
    saves = db.query(Save).filter(Save.post_id == post.id).count()
    media_links = []
    post_media = db.query(PostMedia).filter(PostMedia.post_id == post.id).order_by(PostMedia.display_order.asc()).all()
    for item in post_media:
        asset = db.query(MediaAsset).filter(MediaAsset.id == item.media_asset_id).first()
        if asset:
            media_links.append({"assetId": asset.id, "kind": asset.kind, "storageKey": asset.storage_key})
    viewer_reacted = False
    if viewer_user_id is not None:
        viewer_reacted = any(row.user_id == viewer_user_id for row in reactions)
    return {
        "id": post.id,
        "authorUserId": post.author_user_id,
        "author": {
            "username": profile.username if profile else f"user{post.author_user_id}",
            "displayName": profile.display_name if profile else "Lilith User",
            "lilithId": profile.lilith_id if profile else None,
        },
        "body": post.body,
        "visibility": post.visibility,
        "createdAt": post.created_at.isoformat(),
        "updatedAt": post.updated_at.isoformat(),
        "media": media_links,
        "engagement": {
            "reactions": len(reactions),
            "comments": len(comments),
            "saves": saves,
            "viewerReacted": viewer_reacted,
        },
        "commentsPreview": [
            {"id": row.id, "authorUserId": row.author_user_id, "body": row.body, "createdAt": row.created_at.isoformat()}
            for row in comments[:3]
        ],
    }


def issue_refresh_session(db: Session, user_id: int, refresh_token: str, device_id: str | None = None) -> SessionToken:
    session = SessionToken(
        user_id=user_id,
        device_id=device_id,
        refresh_token=refresh_token,
        expires_at=utcnow() + timedelta(days=30),
    )
    db.add(session)
    db.flush()
    return session


def media_storage_path(user_id: int, filename: str) -> Path:
    safe_name = filename.replace("/", "_")
    return MEDIA_ROOT / str(user_id) / f"{new_id()}-{safe_name}"


def save_media_blob(user_id: int, filename: str, raw: bytes, mime_type: str, kind: str = "generic") -> tuple[MediaAsset, str]:
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    path = media_storage_path(user_id, filename)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    storage_key = str(path.relative_to(MEDIA_ROOT))
    asset = MediaAsset(
        owner_user_id=user_id,
        storage_key=storage_key,
        bucket="local",
        mime_type=mime_type,
        byte_size=len(raw),
        kind=kind,
        metadata_json=json.dumps({"filename": filename}),
    )
    return asset, storage_key


def ensure_tool_result(db: Session, job: ToolJob, summary: str, result: dict[str, Any]) -> ToolResult:
    output = ToolResult(
        job_id=job.id,
        user_id=job.user_id,
        summary=summary,
        result_json=json.dumps(result, default=str),
    )
    db.add(output)
    db.flush()
    return output


def attach_asset_to_result(db: Session, result: ToolResult, media_asset_id: str) -> ToolAsset:
    row = ToolAsset(result_id=result.id, media_asset_id=media_asset_id)
    db.add(row)
    db.flush()
    return row
