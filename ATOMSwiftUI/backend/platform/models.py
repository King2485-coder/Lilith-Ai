from __future__ import annotations

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import relationship

from backend.state import Base, new_id, utcnow


class Device(Base):
    __tablename__ = "devices"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_name = Column(String, nullable=False, default="Unknown Device")
    platform = Column(String, nullable=True)
    app_version = Column(String, nullable=True)
    last_seen_at = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class SessionToken(Base):
    __tablename__ = "sessions"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=True, index=True)
    refresh_token = Column(String, nullable=False, index=True)
    revoked = Column(Boolean, nullable=False, default=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class Profile(Base):
    __tablename__ = "profiles"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    username = Column(String, nullable=False, unique=True, index=True)
    lilith_id = Column(String, nullable=False, unique=True, index=True)
    display_name = Column(String, nullable=False)
    avatar_asset_id = Column(String, ForeignKey("media_assets.id"), nullable=True)
    bio = Column(Text, nullable=True)
    discoverable = Column(Boolean, nullable=False, default=True)
    is_private = Column(Boolean, nullable=False, default=False)
    is_business = Column(Boolean, nullable=False, default=False, index=True)
    service_description = Column(Text, nullable=True)
    is_verified_business = Column(Boolean, nullable=False, default=False, index=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class ProfileSettings(Base):
    __tablename__ = "profile_settings"

    id = Column(String, primary_key=True, default=new_id)
    profile_id = Column(String, ForeignKey("profiles.id"), nullable=False, unique=True, index=True)
    allow_messages_from = Column(String, nullable=False, default="followers")
    allow_calls_from = Column(String, nullable=False, default="followers")
    show_activity_status = Column(Boolean, nullable=False, default=True)
    show_last_seen = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class UsernameHistory(Base):
    __tablename__ = "username_history"

    id = Column(String, primary_key=True, default=new_id)
    profile_id = Column(String, ForeignKey("profiles.id"), nullable=False, index=True)
    username = Column(String, nullable=False, index=True)
    changed_at = Column(DateTime, default=utcnow)


class Follow(Base):
    __tablename__ = "follows"

    id = Column(String, primary_key=True, default=new_id)
    follower_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    followed_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_follows_unique_edge", "follower_user_id", "followed_user_id", unique=True),
    )


class Block(Base):
    __tablename__ = "blocks"

    id = Column(String, primary_key=True, default=new_id)
    blocker_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    blocked_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_blocks_unique_edge", "blocker_user_id", "blocked_user_id", unique=True),
    )


class Mute(Base):
    __tablename__ = "mutes"

    id = Column(String, primary_key=True, default=new_id)
    muter_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    muted_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_mutes_unique_edge", "muter_user_id", "muted_user_id", unique=True),
    )


class Post(Base):
    __tablename__ = "posts"

    id = Column(String, primary_key=True, default=new_id)
    author_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    body = Column(Text, nullable=False)
    visibility = Column(String, nullable=False, default="public")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    media = relationship("PostMedia", cascade="all, delete-orphan")


class PostMedia(Base):
    __tablename__ = "post_media"

    id = Column(String, primary_key=True, default=new_id)
    post_id = Column(String, ForeignKey("posts.id"), nullable=False, index=True)
    media_asset_id = Column(String, ForeignKey("media_assets.id"), nullable=False, index=True)
    display_order = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=utcnow)


class Comment(Base):
    __tablename__ = "comments"

    id = Column(String, primary_key=True, default=new_id)
    post_id = Column(String, ForeignKey("posts.id"), nullable=False, index=True)
    author_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class Reaction(Base):
    __tablename__ = "reactions"

    id = Column(String, primary_key=True, default=new_id)
    post_id = Column(String, ForeignKey("posts.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    reaction = Column(String, nullable=False, default="like")
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_reactions_unique_user_post", "post_id", "user_id", unique=True),
    )


class Repost(Base):
    __tablename__ = "reposts"

    id = Column(String, primary_key=True, default=new_id)
    post_id = Column(String, ForeignKey("posts.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_reposts_unique_user_post", "post_id", "user_id", unique=True),
    )


class Save(Base):
    __tablename__ = "saves"

    id = Column(String, primary_key=True, default=new_id)
    post_id = Column(String, ForeignKey("posts.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_saves_unique_user_post", "post_id", "user_id", unique=True),
    )


class ConversationMember(Base):
    __tablename__ = "conversation_members"

    id = Column(String, primary_key=True, default=new_id)
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    role = Column(String, nullable=False, default="member")
    last_read_message_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_conv_member_unique", "conversation_id", "user_id", unique=True),
    )


class MessageMedia(Base):
    __tablename__ = "message_media"

    id = Column(String, primary_key=True, default=new_id)
    message_id = Column(String, ForeignKey("messages.id"), nullable=False, index=True)
    media_asset_id = Column(String, ForeignKey("media_assets.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)


class MessageReceipt(Base):
    __tablename__ = "message_receipts"

    id = Column(String, primary_key=True, default=new_id)
    message_id = Column(String, ForeignKey("messages.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="delivered")
    seen_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_message_receipt_unique", "message_id", "user_id", unique=True),
    )


class Call(Base):
    __tablename__ = "calls"

    id = Column(String, primary_key=True, default=new_id)
    caller_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    call_type = Column(String, nullable=False, default="voice")
    status = Column(String, nullable=False, default="ringing")
    signaling_payload = Column(Text, nullable=True, default="{}")
    started_at = Column(DateTime, default=utcnow)
    ended_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class CallParticipant(Base):
    __tablename__ = "call_participants"

    id = Column(String, primary_key=True, default=new_id)
    call_id = Column(String, ForeignKey("calls.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    participant_state = Column(String, nullable=False, default="invited")
    joined_at = Column(DateTime, nullable=True)
    left_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)


class CallEvent(Base):
    __tablename__ = "call_events"

    id = Column(String, primary_key=True, default=new_id)
    call_id = Column(String, ForeignKey("calls.id"), nullable=False, index=True)
    event_type = Column(String, nullable=False)
    payload_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    actor_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    event_type = Column(String, nullable=False, index=True)
    target_type = Column(String, nullable=True)
    target_id = Column(String, nullable=True)
    text = Column(Text, nullable=False)
    deep_link = Column(String, nullable=True)
    read = Column(Boolean, nullable=False, default=False, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class NotificationPreference(Base):
    __tablename__ = "notification_preferences"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    likes = Column(Boolean, nullable=False, default=True)
    comments = Column(Boolean, nullable=False, default=True)
    follows = Column(Boolean, nullable=False, default=True)
    messages = Column(Boolean, nullable=False, default=True)
    calls = Column(Boolean, nullable=False, default=True)
    mentions = Column(Boolean, nullable=False, default=True)
    tool_shares = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class DevicePushToken(Base):
    __tablename__ = "device_push_tokens"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=True, index=True)
    token = Column(String, nullable=False, unique=True)
    platform = Column(String, nullable=False, default="ios")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class MediaAsset(Base):
    __tablename__ = "media_assets"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    storage_key = Column(String, nullable=False, unique=True, index=True)
    bucket = Column(String, nullable=False, default="local")
    mime_type = Column(String, nullable=False, default="application/octet-stream")
    byte_size = Column(Integer, nullable=False, default=0)
    kind = Column(String, nullable=False, default="generic")
    thumbnail_asset_id = Column(String, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class ToolJob(Base):
    __tablename__ = "tool_jobs"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    tool_id = Column(String, nullable=False, index=True)
    status = Column(String, nullable=False, default="queued", index=True)
    input_json = Column(Text, nullable=False, default="{}")
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class ToolResult(Base):
    __tablename__ = "tool_results"

    id = Column(String, primary_key=True, default=new_id)
    job_id = Column(String, ForeignKey("tool_jobs.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    summary = Column(Text, nullable=False)
    result_json = Column(Text, nullable=False, default="{}")
    shared_post_id = Column(String, ForeignKey("posts.id"), nullable=True, index=True)
    shared_conversation_id = Column(String, ForeignKey("conversations.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class ToolAsset(Base):
    __tablename__ = "tool_assets"

    id = Column(String, primary_key=True, default=new_id)
    result_id = Column(String, ForeignKey("tool_results.id"), nullable=False, index=True)
    media_asset_id = Column(String, ForeignKey("media_assets.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow)


class ToolUsage(Base):
    __tablename__ = "tool_usage"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    tool_id = Column(String, nullable=False, index=True)
    job_id = Column(String, ForeignKey("tool_jobs.id"), nullable=True, index=True)
    result_id = Column(String, ForeignKey("tool_results.id"), nullable=True, index=True)
    action = Column(String, nullable=False, default="run", index=True)
    context_type = Column(String, nullable=True, index=True)
    context_id = Column(String, nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)


class ToolListing(Base):
    __tablename__ = "tool_listings"

    id = Column(String, primary_key=True, default=new_id)
    creator_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    tool_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=False, default="")
    category = Column(String, nullable=False, default="Automation", index=True)
    pricing_model = Column(String, nullable=False, default="free", index=True)  # free, per_use, subscription
    price_amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    rating = Column(Float, nullable=False, default=0.0)
    usage_count = Column(Integer, nullable=False, default=0, index=True)
    is_published = Column(Boolean, nullable=False, default=False, index=True)
    tags_json = Column(Text, nullable=False, default="[]")
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_tool_listings_unique_creator_tool", "creator_user_id", "tool_id", unique=True),
    )


class ToolPurchase(Base):
    __tablename__ = "tool_purchases"

    id = Column(String, primary_key=True, default=new_id)
    listing_id = Column(String, ForeignKey("tool_listings.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    status = Column(String, nullable=False, default="succeeded", index=True)
    payment_intent_id = Column(String, ForeignKey("payment_intents.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class ToolSubscription(Base):
    __tablename__ = "tool_subscriptions"

    id = Column(String, primary_key=True, default=new_id)
    listing_id = Column(String, ForeignKey("tool_listings.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="active", index=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    billing_interval = Column(String, nullable=False, default="monthly")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_tool_subscriptions_unique_listing_user", "listing_id", "user_id", unique=True),
    )


class DeveloperApp(Base):
    __tablename__ = "developer_apps"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    client_id = Column(String, nullable=False, unique=True, index=True)
    client_secret_hash = Column(String, nullable=False)
    redirect_uri = Column(String, nullable=False)
    scopes_json = Column(Text, nullable=False, default="[]")
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class DeveloperOAuthCode(Base):
    __tablename__ = "developer_oauth_codes"

    id = Column(String, primary_key=True, default=new_id)
    app_id = Column(String, ForeignKey("developer_apps.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    code = Column(String, nullable=False, unique=True, index=True)
    scopes_json = Column(Text, nullable=False, default="[]")
    expires_at = Column(DateTime, nullable=False, index=True)
    consumed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class DeveloperAccessToken(Base):
    __tablename__ = "developer_access_tokens"

    id = Column(String, primary_key=True, default=new_id)
    app_id = Column(String, ForeignKey("developer_apps.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String, nullable=False, unique=True, index=True)
    scopes_json = Column(Text, nullable=False, default="[]")
    expires_at = Column(DateTime, nullable=False, index=True)
    revoked = Column(Boolean, nullable=False, default=False, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class ToolDeployment(Base):
    __tablename__ = "tool_deployments"

    id = Column(String, primary_key=True, default=new_id)
    app_id = Column(String, ForeignKey("developer_apps.id"), nullable=False, index=True)
    listing_id = Column(String, ForeignKey("tool_listings.id"), nullable=False, index=True)
    runtime = Column(String, nullable=False, default="python", index=True)
    entrypoint = Column(String, nullable=False)
    version = Column(String, nullable=False, default="1.0.0")
    status = Column(String, nullable=False, default="active", index=True)
    input_schema_json = Column(Text, nullable=False, default="{}")
    output_schema_json = Column(Text, nullable=False, default="{}")
    policy_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_tool_deployments_unique_listing_version", "listing_id", "version", unique=True),
    )


class DeveloperRevenueEvent(Base):
    __tablename__ = "developer_revenue_events"

    id = Column(String, primary_key=True, default=new_id)
    app_id = Column(String, ForeignKey("developer_apps.id"), nullable=True, index=True)
    listing_id = Column(String, ForeignKey("tool_listings.id"), nullable=False, index=True)
    creator_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    buyer_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    event_type = Column(String, nullable=False, index=True)  # per_use, subscription
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)


class AIJob(Base):
    __tablename__ = "ai_jobs"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=True, index=True)
    message_id = Column(String, ForeignKey("messages.id"), nullable=True, index=True)
    action = Column(String, nullable=False, index=True)  # improve, summarize, translate, create_video, analyze
    input_text = Column(Text, nullable=False)
    status = Column(String, nullable=False, default="queued", index=True)
    error_message = Column(Text, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class AIResult(Base):
    __tablename__ = "ai_results"

    id = Column(String, primary_key=True, default=new_id)
    job_id = Column(String, ForeignKey("ai_jobs.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=True, index=True)
    message_id = Column(String, ForeignKey("messages.id"), nullable=True, index=True)
    output_text = Column(Text, nullable=False)
    output_kind = Column(String, nullable=False, default="text", index=True)  # text, video
    media_asset_id = Column(String, ForeignKey("media_assets.id"), nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class InboxItem(Base):
    __tablename__ = "inbox_items"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    actor_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    item_type = Column(String, nullable=False, index=True)  # message, notification, exchange_request, transaction, document, tool_result
    title = Column(String, nullable=False)
    body = Column(Text, nullable=True)
    source_type = Column(String, nullable=True, index=True)
    source_id = Column(String, nullable=True, index=True)
    status = Column(String, nullable=False, default="unread", index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class ExchangeRequest(Base):
    __tablename__ = "exchange_requests"

    id = Column(String, primary_key=True, default=new_id)
    requester_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    recipient_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    request_type = Column(String, nullable=False, default="general", index=True)
    title = Column(String, nullable=False)
    body = Column(Text, nullable=True)
    source_tool_result_id = Column(String, ForeignKey("tool_results.id"), nullable=True, index=True)
    status = Column(String, nullable=False, default="pending", index=True)  # pending, accepted, declined, completed, cancelled
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class ExchangeResponse(Base):
    __tablename__ = "exchange_responses"

    id = Column(String, primary_key=True, default=new_id)
    exchange_request_id = Column(String, ForeignKey("exchange_requests.id"), nullable=False, index=True)
    responder_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    response = Column(String, nullable=False, index=True)  # accept, decline, update
    message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class ExchangeTransaction(Base):
    __tablename__ = "exchange_transactions"

    id = Column(String, primary_key=True, default=new_id)
    exchange_request_id = Column(String, ForeignKey("exchange_requests.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="open", index=True)  # open, processing, completed, failed, cancelled
    summary = Column(Text, nullable=True)
    details_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class PaymentCustomer(Base):
    __tablename__ = "payment_customers"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    provider_customer_id = Column(String, nullable=True, index=True)
    default_payment_method_id = Column(String, ForeignKey("payment_methods.id"), nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    id = Column(String, primary_key=True, default=new_id)
    customer_id = Column(String, ForeignKey("payment_customers.id"), nullable=False, index=True)
    method_type = Column(String, nullable=False, default="card", index=True)
    provider = Column(String, nullable=False, default="internal", index=True)
    provider_payment_method_id = Column(String, nullable=True, index=True)
    last4 = Column(String, nullable=True)
    brand = Column(String, nullable=True)
    exp_month = Column(Integer, nullable=True)
    exp_year = Column(Integer, nullable=True)
    billing_name = Column(String, nullable=True)
    billing_email = Column(String, nullable=True)
    is_default = Column(Boolean, nullable=False, default=False, index=True)
    encrypted_reference = Column(String, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class PaymentIntent(Base):
    __tablename__ = "payment_intents"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    customer_id = Column(String, ForeignKey("payment_customers.id"), nullable=True, index=True)
    payment_method_id = Column(String, ForeignKey("payment_methods.id"), nullable=True, index=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD", index=True)
    rail = Column(String, nullable=False, default="fiat", index=True)  # fiat, stablecoin_usdc
    stablecoin = Column(String, nullable=True, index=True)  # usdc
    network = Column(String, nullable=True, index=True)  # base, solana, ethereum
    intent_type = Column(String, nullable=False, default="purchase", index=True)
    status = Column(String, nullable=False, default="requires_confirmation", index=True)
    idempotency_key = Column(String, nullable=True)
    external_intent_id = Column(String, nullable=True, index=True)
    requires_step_up = Column(Boolean, nullable=False, default=False)
    step_up_verified_at = Column(DateTime, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_payment_intents_user_idempotency", "user_id", "idempotency_key", unique=True),
    )


class PaymentAttempt(Base):
    __tablename__ = "payment_attempts"

    id = Column(String, primary_key=True, default=new_id)
    payment_intent_id = Column(String, ForeignKey("payment_intents.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    payment_method_id = Column(String, ForeignKey("payment_methods.id"), nullable=True, index=True)
    status = Column(String, nullable=False, default="pending", index=True)
    provider = Column(String, nullable=False, default="internal", index=True)
    provider_attempt_id = Column(String, nullable=True, index=True)
    fail_reason = Column(String, nullable=True)
    risk_score = Column(Float, nullable=True)
    response_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Refund(Base):
    __tablename__ = "refunds"

    id = Column(String, primary_key=True, default=new_id)
    payment_intent_id = Column(String, ForeignKey("payment_intents.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    reason = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending", index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(String, primary_key=True, default=new_id)
    creator_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    billing_interval = Column(String, nullable=False, default="monthly", index=True)
    active = Column(Boolean, nullable=False, default=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(String, primary_key=True, default=new_id)
    subscriber_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    creator_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    plan_id = Column(String, ForeignKey("subscription_plans.id"), nullable=True, index=True)
    payment_method_id = Column(String, ForeignKey("payment_methods.id"), nullable=True, index=True)
    status = Column(String, nullable=False, default="active", index=True)
    current_period_start = Column(DateTime, default=utcnow)
    current_period_end = Column(DateTime, nullable=True)
    cancel_at_period_end = Column(Boolean, nullable=False, default=False)
    cancelled_at = Column(DateTime, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_subscriptions_unique_pair", "subscriber_user_id", "creator_user_id", unique=True),
    )


class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(String, primary_key=True, default=new_id)
    issuer_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    recipient_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    exchange_request_id = Column(String, ForeignKey("exchange_requests.id"), nullable=True, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    status = Column(String, nullable=False, default="open", index=True)
    due_at = Column(DateTime, nullable=True, index=True)
    paid_at = Column(DateTime, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Payout(Base):
    __tablename__ = "payouts"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    rail = Column(String, nullable=False, default="fiat", index=True)
    stablecoin = Column(String, nullable=True)
    network = Column(String, nullable=True)
    destination = Column(String, nullable=True)
    status = Column(String, nullable=False, default="requested", index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Dispute(Base):
    __tablename__ = "disputes"

    id = Column(String, primary_key=True, default=new_id)
    payment_intent_id = Column(String, ForeignKey("payment_intents.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    reason = Column(String, nullable=False)
    status = Column(String, nullable=False, default="open", index=True)
    details_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class WebhookEvent(Base):
    __tablename__ = "webhook_events"

    id = Column(String, primary_key=True, default=new_id)
    provider = Column(String, nullable=False, index=True)
    event_id = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False, index=True)
    signature = Column(String, nullable=True)
    payload_json = Column(Text, nullable=False, default="{}")
    verified = Column(Boolean, nullable=False, default=False, index=True)
    processed = Column(Boolean, nullable=False, default=False, index=True)
    processed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_webhook_events_provider_event", "provider", "event_id", unique=True),
    )


class RiskReview(Base):
    __tablename__ = "risk_reviews"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    payment_intent_id = Column(String, ForeignKey("payment_intents.id"), nullable=True, index=True)
    action_type = Column(String, nullable=False, index=True)
    score = Column(Float, nullable=False, default=0.0)
    decision = Column(String, nullable=False, default="allow", index=True)  # allow, review, deny
    reasons_json = Column(Text, nullable=False, default="[]")
    resolved_by = Column(String, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class CryptoWalletLink(Base):
    __tablename__ = "crypto_wallet_links"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    network = Column(String, nullable=False, index=True)
    address = Column(String, nullable=False, index=True)
    label = Column(String, nullable=True)
    verified = Column(Boolean, nullable=False, default=False)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_wallet_unique_per_user_network", "user_id", "network", "address", unique=True),
    )


class CryptoSettlementPreference(Base):
    __tablename__ = "crypto_settlement_preferences"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    preferred_rail = Column(String, nullable=False, default="fiat", index=True)  # fiat, stablecoin_usdc
    stablecoin = Column(String, nullable=True, default="usdc")
    network = Column(String, nullable=True, default="base")
    payout_wallet_link_id = Column(String, ForeignKey("crypto_wallet_links.id"), nullable=True, index=True)
    updated_at = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow)


class LedgerAccount(Base):
    __tablename__ = "ledger_accounts"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    account_type = Column(String, nullable=False, index=True)  # platform_cash, user_wallet, user_revenue, platform_liability
    currency = Column(String, nullable=False, default="USD", index=True)
    status = Column(String, nullable=False, default="active", index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_ledger_account_unique_key", "user_id", "account_type", "currency", unique=True),
    )


class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id = Column(String, primary_key=True, default=new_id)
    account_id = Column(String, ForeignKey("ledger_accounts.id"), nullable=False, index=True)
    related_account_id = Column(String, ForeignKey("ledger_accounts.id"), nullable=True, index=True)
    event_id = Column(String, ForeignKey("payment_events.id"), nullable=True, index=True)
    direction = Column(String, nullable=False, index=True)  # debit, credit
    amount = Column(Float, nullable=False, default=0.0)
    currency = Column(String, nullable=False, default="USD")
    reference_type = Column(String, nullable=False, index=True)
    reference_id = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)


class PaymentEvent(Base):
    __tablename__ = "payment_events"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    event_type = Column(String, nullable=False, index=True)
    object_type = Column(String, nullable=False, index=True)
    object_id = Column(String, nullable=False, index=True)
    idempotency_key = Column(String, nullable=True, index=True)
    payload_json = Column(Text, nullable=False, default="{}")
    prev_hash = Column(String, nullable=True, index=True)
    event_hash = Column(String, nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)


class MonetizationEligibility(Base):
    __tablename__ = "monetization_eligibility"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    status = Column(String, nullable=False, default="pending", index=True)  # pending, active, review, suspended
    verification_score = Column(Float, nullable=False, default=0.0)
    report_rate = Column(Float, nullable=False, default=0.0)
    refund_rate = Column(Float, nullable=False, default=0.0)
    dispute_rate = Column(Float, nullable=False, default=0.0)
    fraud_score = Column(Float, nullable=False, default=0.0)
    policy_violations = Column(Integer, nullable=False, default=0)
    reason = Column(String, nullable=True)
    updated_at = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow)


class Report(Base):
    __tablename__ = "reports"

    id = Column(String, primary_key=True, default=new_id)
    reporter_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    target_type = Column(String, nullable=False, index=True)
    target_id = Column(String, nullable=False, index=True)
    reason = Column(String, nullable=False)
    detail = Column(Text, nullable=True)
    status = Column(String, nullable=False, default="open", index=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class ModerationQueue(Base):
    __tablename__ = "moderation_queue"

    id = Column(String, primary_key=True, default=new_id)
    report_id = Column(String, ForeignKey("reports.id"), nullable=False, index=True)
    priority = Column(String, nullable=False, default="normal")
    assigned_to = Column(String, nullable=True)
    action = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending", index=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class WorldCustomization(Base):
    __tablename__ = "world_customizations"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    theme = Column(String, nullable=False, default="space", index=True)
    avatar_style = Column(String, nullable=False, default="explorer")
    layout_json = Column(Text, nullable=False, default="{}")
    unlocked_zones_json = Column(Text, nullable=False, default='["school_zone","theater","game_zone","creative_studio","friends_park"]')
    interactive_objects_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GuardianLink(Base):
    __tablename__ = "guardian_links"

    id = Column(String, primary_key=True, default=new_id)
    guardian_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="active", index=True)  # active, pending, revoked
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_guardian_links_unique_pair", "guardian_user_id", "child_user_id", unique=True),
    )


class GuardianPolicy(Base):
    __tablename__ = "guardian_policies"

    id = Column(String, primary_key=True, default=new_id)
    guardian_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    allowed_subjects_json = Column(Text, nullable=False, default='["Math","Reading","Writing","Science","History","Coding","Art","Life skills"]')
    blocked_topics_json = Column(Text, nullable=False, default="[]")
    approved_games_json = Column(Text, nullable=False, default="[]")
    approved_content_ids_json = Column(Text, nullable=False, default="[]")
    communication_mode = Column(String, nullable=False, default="friends_only")  # friends_only, guardian_only
    allow_social = Column(Boolean, nullable=False, default=True)
    allow_ai = Column(Boolean, nullable=False, default=True)
    allow_creative_tools = Column(Boolean, nullable=False, default=True)
    daily_time_limit_minutes = Column(Integer, nullable=False, default=180)
    safety_mode = Column(String, nullable=False, default="strict", index=True)  # strict, balanced
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class LearningProfile(Base):
    __tablename__ = "learning_profiles"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    pace = Column(String, nullable=False, default="adaptive", index=True)  # gentle, adaptive, accelerated
    interests_json = Column(Text, nullable=False, default="[]")
    strengths_json = Column(Text, nullable=False, default="[]")
    weaknesses_json = Column(Text, nullable=False, default="[]")
    preferred_style = Column(String, nullable=False, default="visual")  # visual, hands_on, story
    current_skill_level = Column(Float, nullable=False, default=1.0)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(String, primary_key=True, default=new_id)
    key = Column(String, nullable=False, unique=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    order_index = Column(Integer, nullable=False, default=0, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(String, primary_key=True, default=new_id)
    subject_id = Column(String, ForeignKey("subjects.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    summary = Column(Text, nullable=False, default="")
    difficulty = Column(Integer, nullable=False, default=1, index=True)
    estimated_minutes = Column(Integer, nullable=False, default=10)
    content_json = Column(Text, nullable=False, default="{}")
    practice_json = Column(Text, nullable=False, default="{}")
    quiz_json = Column(Text, nullable=False, default="{}")
    is_published = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class ProgressTracking(Base):
    __tablename__ = "progress_tracking"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    subject_id = Column(String, ForeignKey("subjects.id"), nullable=False, index=True)
    lesson_id = Column(String, ForeignKey("lessons.id"), nullable=True, index=True)
    status = Column(String, nullable=False, default="started", index=True)  # started, practiced, completed
    score = Column(Float, nullable=False, default=0.0)
    attempts = Column(Integer, nullable=False, default=1)
    feedback = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class WorldGame(Base):
    __tablename__ = "games"

    id = Column(String, primary_key=True, default=new_id)
    title = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    genre = Column(String, nullable=False, default="educational", index=True)
    min_age = Column(Integer, nullable=False, default=5)
    max_age = Column(Integer, nullable=False, default=18)
    multiplayer_mode = Column(String, nullable=False, default="friends_only")  # off, friends_only
    supported_controls_json = Column(Text, nullable=False, default='["touch"]')
    approved = Column(Boolean, nullable=False, default=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GameSession(Base):
    __tablename__ = "game_sessions"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    game_id = Column(String, ForeignKey("games.id"), nullable=False, index=True)
    duration_seconds = Column(Integer, nullable=False, default=0)
    mode = Column(String, nullable=False, default="solo")
    status = Column(String, nullable=False, default="active", index=True)  # active, completed
    metadata_json = Column(Text, nullable=False, default="{}")
    started_at = Column(DateTime, default=utcnow, index=True)
    ended_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class ContentLibrary(Base):
    __tablename__ = "content_library"

    id = Column(String, primary_key=True, default=new_id)
    title = Column(String, nullable=False, index=True)
    kind = Column(String, nullable=False, default="show", index=True)  # movie, show, educational, short
    provider = Column(String, nullable=False, default="curated", index=True)
    link = Column(String, nullable=False)
    age_rating = Column(String, nullable=False, default="kids")
    min_age = Column(Integer, nullable=False, default=5)
    max_age = Column(Integer, nullable=False, default=18)
    approved = Column(Boolean, nullable=False, default=True, index=True)
    tags_json = Column(Text, nullable=False, default="[]")
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Reward(Base):
    __tablename__ = "rewards"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    reward_type = Column(String, nullable=False, index=True)  # points, streak, achievement, unlock
    points = Column(Integer, nullable=False, default=0)
    title = Column(String, nullable=False)
    detail = Column(Text, nullable=True)
    source_type = Column(String, nullable=False, index=True)  # lesson, game, creativity
    source_id = Column(String, nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class AIInteraction(Base):
    __tablename__ = "ai_interactions"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    guardian_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    interaction_type = Column(String, nullable=False, index=True)  # suggestion, lesson_help, creativity_idea, safety_intervention
    input_text = Column(Text, nullable=True)
    output_text = Column(Text, nullable=False)
    safe = Column(Boolean, nullable=False, default=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class SkillTree(Base):
    __tablename__ = "skill_trees"

    id = Column(String, primary_key=True, default=new_id)
    subject_id = Column(String, ForeignKey("subjects.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    level_count = Column(Integer, nullable=False, default=5)
    active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class SkillNode(Base):
    __tablename__ = "skill_nodes"

    id = Column(String, primary_key=True, default=new_id)
    tree_id = Column(String, ForeignKey("skill_trees.id"), nullable=False, index=True)
    subject_id = Column(String, ForeignKey("subjects.id"), nullable=False, index=True)
    code = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    level = Column(Integer, nullable=False, default=1, index=True)
    mastery_threshold = Column(Float, nullable=False, default=80.0)
    prerequisite_ids_json = Column(Text, nullable=False, default="[]")
    assessment_weight = Column(Float, nullable=False, default=1.0)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_skill_nodes_unique_tree_code", "tree_id", "code", unique=True),
    )


class SkillProgress(Base):
    __tablename__ = "skill_progress"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    skill_node_id = Column(String, ForeignKey("skill_nodes.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="learning", index=True)  # learning, ready_for_assessment, mastered
    score = Column(Float, nullable=False, default=0.0)
    mastery_verified = Column(Boolean, nullable=False, default=False, index=True)
    attempts = Column(Integer, nullable=False, default=0)
    evidence_json = Column(Text, nullable=False, default="[]")
    updated_by_ai = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_skill_progress_unique_child_skill", "child_user_id", "skill_node_id", unique=True),
    )


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(String, primary_key=True, default=new_id)
    skill_node_id = Column(String, ForeignKey("skill_nodes.id"), nullable=False, index=True)
    assessment_type = Column(String, nullable=False, default="quiz", index=True)  # quiz, interactive_task, ai_evaluation
    title = Column(String, nullable=False)
    prompt = Column(Text, nullable=True)
    rubric_json = Column(Text, nullable=False, default="{}")
    max_score = Column(Float, nullable=False, default=100.0)
    required_for_mastery = Column(Boolean, nullable=False, default=True, index=True)
    active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class AssessmentSubmission(Base):
    __tablename__ = "assessment_submissions"

    id = Column(String, primary_key=True, default=new_id)
    assessment_id = Column(String, ForeignKey("assessments.id"), nullable=False, index=True)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    response_json = Column(Text, nullable=False, default="{}")
    score = Column(Float, nullable=False, default=0.0)
    passed = Column(Boolean, nullable=False, default=False, index=True)
    evaluator_type = Column(String, nullable=False, default="ai", index=True)  # ai, guardian, teacher
    evaluator_notes = Column(Text, nullable=True)
    ai_validation_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class Certificate(Base):
    __tablename__ = "certificates"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    subject_group = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False)
    verification_id = Column(String, nullable=False, unique=True, index=True)
    issued_by = Column(String, nullable=False, default="Lilith Learning System")
    issued_at = Column(DateTime, default=utcnow, index=True)
    status = Column(String, nullable=False, default="active", index=True)  # active, revoked
    mastery_snapshot_json = Column(Text, nullable=False, default="{}")
    share_token = Column(String, nullable=True, unique=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class PortfolioItem(Base):
    __tablename__ = "portfolio_items"

    id = Column(String, primary_key=True, default=new_id)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    item_type = Column(String, nullable=False, index=True)  # project, creative_work, certificate
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    artifact_type = Column(String, nullable=False, default="text", index=True)  # text, media, link, certificate_ref
    artifact_ref = Column(String, nullable=True)
    certificate_id = Column(String, ForeignKey("certificates.id"), nullable=True, index=True)
    skill_node_id = Column(String, ForeignKey("skill_nodes.id"), nullable=True, index=True)
    visibility = Column(String, nullable=False, default="guardian", index=True)  # guardian, private, shared
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GuardianReportSnapshot(Base):
    __tablename__ = "guardian_report_snapshots"

    id = Column(String, primary_key=True, default=new_id)
    guardian_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    child_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    period_start = Column(DateTime, nullable=False, index=True)
    period_end = Column(DateTime, nullable=False, index=True)
    progress_summary_json = Column(Text, nullable=False, default="{}")
    strengths_json = Column(Text, nullable=False, default="[]")
    weaknesses_json = Column(Text, nullable=False, default="[]")
    recommendations_json = Column(Text, nullable=False, default="[]")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GrowthEmailIdentity(Base):
    __tablename__ = "growth_email_identities"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    sender_name = Column(String, nullable=False, default="Lilith Creator")
    sender_email = Column(String, nullable=False, unique=True, index=True)
    reply_to_email = Column(String, nullable=True)
    verified = Column(Boolean, nullable=False, default=False, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GrowthLandingPage(Base):
    __tablename__ = "growth_landing_pages"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False, index=True)
    slug = Column(String, nullable=False, index=True)
    goal = Column(String, nullable=False, default="waitlist", index=True)
    audience = Column(String, nullable=False, default="general", index=True)
    cta_text = Column(String, nullable=False, default="Join waitlist")
    html = Column(Text, nullable=False, default="")
    sections_json = Column(Text, nullable=False, default="[]")
    form_schema_json = Column(Text, nullable=False, default="{}")
    analytics_json = Column(Text, nullable=False, default="{}")
    published = Column(Boolean, nullable=False, default=False, index=True)
    published_url = Column(String, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_growth_landing_owner_slug", "owner_user_id", "slug", unique=True),
    )


class GrowthLead(Base):
    __tablename__ = "growth_leads"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    landing_page_id = Column(String, ForeignKey("growth_landing_pages.id"), nullable=True, index=True)
    email = Column(String, nullable=False, index=True)
    name = Column(String, nullable=True)
    source = Column(String, nullable=False, default="waitlist", index=True)
    status = Column(String, nullable=False, default="subscribed", index=True)  # subscribed, unsubscribed, bounced
    tags_json = Column(Text, nullable=False, default="[]")
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_growth_leads_unique_owner_email", "owner_user_id", "email", unique=True),
    )


class GrowthCampaign(Base):
    __tablename__ = "growth_campaigns"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False, index=True)
    subject = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    audience_segment = Column(String, nullable=False, default="all", index=True)
    status = Column(String, nullable=False, default="draft", index=True)  # draft, scheduled, sent
    scheduled_at = Column(DateTime, nullable=True, index=True)
    sent_at = Column(DateTime, nullable=True, index=True)
    analytics_json = Column(Text, nullable=False, default="{}")
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class GrowthCampaignDelivery(Base):
    __tablename__ = "growth_campaign_deliveries"

    id = Column(String, primary_key=True, default=new_id)
    campaign_id = Column(String, ForeignKey("growth_campaigns.id"), nullable=False, index=True)
    lead_id = Column(String, ForeignKey("growth_leads.id"), nullable=False, index=True)
    email = Column(String, nullable=False, index=True)
    status = Column(String, nullable=False, default="queued", index=True)  # queued, sent, opened, clicked, bounced
    sent_at = Column(DateTime, nullable=True, index=True)
    opened_at = Column(DateTime, nullable=True, index=True)
    clicked_at = Column(DateTime, nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_growth_delivery_campaign_lead_unique", "campaign_id", "lead_id", unique=True),
    )


class GrowthWebsiteProject(Base):
    __tablename__ = "growth_website_projects"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False, index=True)
    slug = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    theme = Column(String, nullable=False, default="clean", index=True)
    published = Column(Boolean, nullable=False, default=False, index=True)
    published_url = Column(String, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_growth_site_owner_slug", "owner_user_id", "slug", unique=True),
    )


class GrowthWebsitePage(Base):
    __tablename__ = "growth_website_pages"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("growth_website_projects.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    slug = Column(String, nullable=False)
    sections_json = Column(Text, nullable=False, default="[]")
    seo_json = Column(Text, nullable=False, default="{}")
    published = Column(Boolean, nullable=False, default=False, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_growth_page_project_slug", "project_id", "slug", unique=True),
    )


class GrowthAutomationFlow(Base):
    __tablename__ = "growth_automation_flows"

    id = Column(String, primary_key=True, default=new_id)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    trigger_type = Column(String, nullable=False, default="new_lead", index=True)  # new_lead, schedule, campaign_sent
    flow_json = Column(Text, nullable=False, default="{}")
    active = Column(Boolean, nullable=False, default=True, index=True)
    last_run_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class MonetizationOnboardingRun(Base):
    __tablename__ = "monetization_onboarding_runs"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    flow_type = Column(String, nullable=False, index=True)  # creator, business, tool_builder
    status = Column(String, nullable=False, default="completed", index=True)  # started, completed
    steps_json = Column(Text, nullable=False, default="[]")
    first_post_id = Column(String, ForeignKey("posts.id"), nullable=True, index=True)
    first_offer_id = Column(String, nullable=True, index=True)
    first_tool_listing_id = Column(String, ForeignKey("tool_listings.id"), nullable=True, index=True)
    payment_customer_id = Column(String, ForeignKey("payment_customers.id"), nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class NeurocloudPasskeyCredential(Base):
    __tablename__ = "neurocloud_passkey_credentials"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    credential_id = Column(String, nullable=False, unique=True, index=True)
    public_key = Column(Text, nullable=False)
    sign_count = Column(Integer, nullable=False, default=0)
    transports_json = Column(Text, nullable=False, default="[]")
    nickname = Column(String, nullable=True)
    last_used_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class NeurocloudDeviceTrust(Base):
    __tablename__ = "neurocloud_device_trust"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=True, index=True)
    device_fingerprint = Column(String, nullable=False, index=True)
    trust_level = Column(String, nullable=False, default="unverified", index=True)  # unverified, verified, high
    trusted = Column(Boolean, nullable=False, default=False, index=True)
    risk_score = Column(Float, nullable=False, default=0.0)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_neurocloud_trust_user_fingerprint", "user_id", "device_fingerprint", unique=True),
    )


class NeurocloudScopedCredential(Base):
    __tablename__ = "neurocloud_scoped_credentials"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token_hash = Column(String, nullable=False, unique=True, index=True)
    scopes_json = Column(Text, nullable=False, default="[]")
    expires_at = Column(DateTime, nullable=False, index=True)
    revoked = Column(Boolean, nullable=False, default=False, index=True)
    issued_for = Column(String, nullable=True, index=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class NeurocloudMemoryProfile(Base):
    __tablename__ = "neurocloud_memory_profiles"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    preferences_json = Column(Text, nullable=False, default="{}")
    behavior_json = Column(Text, nullable=False, default="{}")
    learning_progress_json = Column(Text, nullable=False, default="{}")
    memory_version = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class NeurocloudExecutionJob(Base):
    __tablename__ = "neurocloud_execution_jobs"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    action_type = Column(String, nullable=False, index=True)
    scope_required = Column(String, nullable=True, index=True)
    status = Column(String, nullable=False, default="queued", index=True)  # queued, completed, denied, failed
    input_json = Column(Text, nullable=False, default="{}")
    output_json = Column(Text, nullable=False, default="{}")
    error = Column(Text, nullable=True)
    metadata_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
    updated_at = Column(DateTime, default=utcnow)


class NeurocloudEvent(Base):
    __tablename__ = "neurocloud_events"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    event_type = Column(String, nullable=False, index=True)  # message, payment, tool_usage, execution, security
    channel = Column(String, nullable=False, default="core", index=True)
    source_type = Column(String, nullable=False, index=True)
    source_id = Column(String, nullable=True, index=True)
    payload_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow, index=True)
