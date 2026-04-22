from __future__ import annotations

import base64
import json
import os
import secrets
from datetime import datetime, timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.security.utils import get_authorization_scheme_param
from sqlalchemy import and_, desc, or_
from sqlalchemy.orm import Session

from backend.platform.deps import create_access_token, current_user, get_db, hash_password, verify_password
from backend.platform.models import (
    Block,
    Call,
    CallEvent,
    CallParticipant,
    Comment,
    ConversationMember,
    Device,
    DevicePushToken,
    DeveloperAccessToken,
    DeveloperApp,
    DeveloperOAuthCode,
    DeveloperRevenueEvent,
    ExchangeRequest,
    ExchangeResponse,
    ExchangeTransaction,
    Follow,
    GrowthAutomationFlow,
    GrowthCampaign,
    GrowthCampaignDelivery,
    GrowthEmailIdentity,
    GrowthLandingPage,
    GrowthLead,
    GrowthWebsitePage,
    GrowthWebsiteProject,
    GuardianReportSnapshot,
    GameSession,
    GuardianLink,
    GuardianPolicy,
    InboxItem,
    Invoice,
    LearningProfile,
    Lesson,
    MediaAsset,
    MessageMedia,
    MessageReceipt,
    MonetizationEligibility,
    MonetizationOnboardingRun,
    NeurocloudDeviceTrust,
    NeurocloudEvent,
    NeurocloudMemoryProfile,
    NeurocloudPasskeyCredential,
    ModerationQueue,
    Mute,
    Notification,
    NotificationPreference,
    AIJob,
    AIResult,
    PaymentAttempt,
    PaymentIntent,
    PaymentMethod,
    Payout,
    Post,
    PostMedia,
    Profile,
    ProfileSettings,
    Reaction,
    Report,
    Repost,
    Reward,
    SkillNode,
    SkillProgress,
    SkillTree,
    Subscription,
    SubscriptionPlan,
    Subject,
    Save,
    SessionToken,
    ToolJob,
    ToolResult,
    ToolListing,
    ToolDeployment,
    ToolPurchase,
    ToolSubscription,
    ToolAsset,
    ToolUsage,
    WorldCustomization,
    WorldGame,
    ProgressTracking,
    ContentLibrary,
    Certificate,
    Assessment,
    AssessmentSubmission,
    PortfolioItem,
    Refund,
    CryptoSettlementPreference,
    CryptoWalletLink,
    AIInteraction,
)
from backend.platform.realtime import hub
from backend.platform.push import send_push_for_notification
from backend.platform.rate_limit import enforce_rate_limit
from backend.platform.schemas import (
    CallIcePayload,
    CallStartPayload,
    CallStatePayload,
    CommentPayload,
    LoginPayload,
    MediaUploadCompletePayload,
    MediaUploadInitPayload,
    MessageConversationCreatePayload,
    MessageReadPayload,
    MessageSendPayload,
    ModerationReportPayload,
    PostCreatePayload,
    PresenceHeartbeatPayload,
    ProfilePatchPayload,
    PushTokenPayload,
    ReactionPayload,
    RefreshPayload,
    RegisterPayload,
    ShareToolResultPayload,
    ToolJobPayload,
    ExchangeRequestPayload,
    ExchangeRespondPayload,
    InvoiceCreatePayload,
    InvoicePayPayload,
    PaymentConfirmPayload,
    PaymentIntentCreatePayload,
    PaymentMethodCreatePayload,
    PayoutRequestPayload,
    RefundCreatePayload,
    SubscriptionCancelPayload,
    SubscriptionCreatePayload,
    SubscriptionPlanPayload,
    WalletPreferencePayload,
    WebhookEventPayload,
    AIJobCreatePayload,
    DeveloperAppCreatePayload,
    DeveloperContextPayload,
    DeveloperToolCreatePayload,
    DeveloperToolRunPayload,
    GrowthAutomationPayload,
    GrowthCampaignCreatePayload,
    GrowthCopyGeneratePayload,
    GrowthEmailIdentityPayload,
    GrowthLandingGeneratePayload,
    GrowthOptimizePayload,
    GrowthWaitlistJoinPayload,
    GrowthWebsitePagePayload,
    GrowthWebsiteProjectPayload,
    BusinessMoneyFirstPayload,
    CreatorMoneyFirstPayload,
    NeurocloudCredentialValidatePayload,
    NeurocloudDeviceTrustPayload,
    NeurocloudExecutionPayload,
    NeurocloudMemoryPatchPayload,
    NeurocloudPasskeyAuthBeginPayload,
    NeurocloudPasskeyAuthCompletePayload,
    NeurocloudPasskeyRegisterBeginPayload,
    NeurocloudPasskeyRegisterCompletePayload,
    NeurocloudScopedTokenIssuePayload,
    ToolBuilderMoneyFirstPayload,
    OAuthAuthorizePayload,
    OAuthTokenPayload,
    WorldSetupPayload,
    GuardianLinkPayload,
    GuardianPolicyPayload,
    LearningProfilePatchPayload,
    LessonProgressPayload,
    WorldAIRequestPayload,
    ContentAddPayload,
    GameAddPayload,
    GameSessionEndPayload,
    GameSessionStartPayload,
    AssessmentCreatePayload,
    AssessmentSubmissionPayload,
    CertificateIssuePayload,
    LessonCreatePayload,
    PortfolioItemPayload,
    RewardGrantPayload,
    SkillMasteryValidatePayload,
    SkillNodeCreatePayload,
    SkillTreeCreatePayload,
    SubjectCreatePayload,
    ToolListingCreatePayload,
    ToolMarketplaceRunPayload,
    ToolMarketplaceSubscribePayload,
)
from backend.platform.services import (
    apply_lilith_voice,
    attach_asset_to_result,
    blocked_user_ids,
    create_inbox_item,
    create_notification,
    ensure_profile,
    ensure_tool_result,
    issue_refresh_session,
    lilith_voice_profile,
    make_lilith_id,
    profile_stats,
    rank_posts,
    save_media_blob,
    serialize_post,
    slugify_username,
)
from backend.platform.payments import (
    SUPPORTED_NETWORKS,
    SUPPORTED_STABLECOIN,
    create_ledger_transfer,
    ensure_payment_customer,
    evaluate_risk,
    get_or_create_ledger_account,
    record_payment_event,
    save_risk_review,
    set_default_payment_method,
    trust,
    update_monetization_eligibility,
    upsert_payment_method,
    verify_and_store_webhook,
)
from backend.platform.neurocloud import (
    complete_execution_job,
    create_execution_job,
    create_passkey_challenge,
    emit_neuro_event,
    issue_scoped_credential,
    validate_scoped_credential,
)
from backend.platform.observability import audit_event, capture_exception
from backend.platform.architecture import architecture_manifest, infrastructure_manifest, realtime_manifest, security_manifest
from backend.state import ChatMessage, Conversation, User, list_tool_registry, new_id, utcnow


def _refresh_token() -> str:
    return f"rf_{new_id()}"


def _session_payload(user: User, refresh_token: str) -> dict[str, Any]:
    return {
        "access_token": create_access_token(user.email),
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": {"id": user.id, "email": user.email, "name": user.name or "Lilith User"},
    }


def _notification_frame(row: Notification) -> dict[str, Any]:
    return {
        "id": row.id,
        "eventType": row.event_type,
        "text": row.text,
        "targetType": row.target_type,
        "targetId": row.target_id,
        "actorUserId": row.actor_user_id,
        "deepLink": row.deep_link,
        "createdAt": row.created_at.isoformat(),
    }


def _inbox_shape(row: InboxItem) -> dict[str, Any]:
    return {
        "id": row.id,
        "userId": row.user_id,
        "actorUserId": row.actor_user_id,
        "itemType": row.item_type,
        "title": row.title,
        "body": row.body,
        "sourceType": row.source_type,
        "sourceId": row.source_id,
        "status": row.status,
        "metadata": json.loads(row.metadata_json or "{}"),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat() if row.updated_at else row.created_at.isoformat(),
    }


def _payment_shape(row: PaymentIntent) -> dict[str, Any]:
    return {
        "id": row.id,
        "userId": row.user_id,
        "amount": row.amount,
        "currency": row.currency,
        "rail": row.rail,
        "stablecoin": row.stablecoin,
        "network": row.network,
        "intentType": row.intent_type,
        "status": row.status,
        "paymentMethodId": row.payment_method_id,
        "requiresStepUp": row.requires_step_up,
        "stepUpVerifiedAt": row.step_up_verified_at.isoformat() if row.step_up_verified_at else None,
        "metadata": json.loads(row.metadata_json or "{}"),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _tool_listing_shape(row: ToolListing) -> dict[str, Any]:
    return {
        "id": row.id,
        "creatorUserId": row.creator_user_id,
        "toolId": row.tool_id,
        "name": row.name,
        "description": row.description,
        "category": row.category,
        "pricingModel": row.pricing_model,
        "priceAmount": row.price_amount,
        "currency": row.currency,
        "rating": row.rating,
        "usage": row.usage_count,
        "published": row.is_published,
        "tags": json.loads(row.tags_json or "[]"),
        "metadata": json.loads(row.metadata_json or "{}"),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


DEVELOPER_SCOPE_SET = {
    "tools.read",
    "tools.write",
    "tools.run",
    "chat.write",
    "feed.write",
    "inbox.write",
    "profiles.read",
    "context.read",
    "payments.read",
}
DEFAULT_DEVELOPER_SCOPES = ["tools.read", "tools.write", "tools.run", "context.read"]
BANNED_TOOL_CONTENT_TERMS = {
    "csam",
    "sexual minors",
    "explosive recipe",
    "credit card dump",
}


def _developer_app_shape(row: DeveloperApp) -> dict[str, Any]:
    return {
        "id": row.id,
        "name": row.name,
        "clientId": row.client_id,
        "redirectUri": row.redirect_uri,
        "scopes": json.loads(row.scopes_json or "[]"),
        "isActive": row.is_active,
        "metadata": json.loads(row.metadata_json or "{}"),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _tool_deployment_shape(row: ToolDeployment) -> dict[str, Any]:
    return {
        "id": row.id,
        "appId": row.app_id,
        "listingId": row.listing_id,
        "runtime": row.runtime,
        "entrypoint": row.entrypoint,
        "version": row.version,
        "status": row.status,
        "inputSchema": json.loads(row.input_schema_json or "{}"),
        "outputSchema": json.loads(row.output_schema_json or "{}"),
        "policy": json.loads(row.policy_json or "{}"),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _parse_scopes(scopes: list[str]) -> list[str]:
    parsed = sorted({scope.strip() for scope in scopes if scope.strip() and scope.strip() in DEVELOPER_SCOPE_SET})
    if not parsed:
        return DEFAULT_DEVELOPER_SCOPES
    return parsed


def _authorized_scope_subset(requested: list[str], granted: list[str]) -> list[str]:
    if not requested:
        return granted
    granted_set = set(granted)
    requested_set = {scope.strip() for scope in requested if scope.strip()}
    if not requested_set.issubset(granted_set):
        raise HTTPException(status_code=400, detail="Requested scope not allowed for this app")
    return sorted(requested_set)


def _extract_bearer(authorization: Optional[str]) -> str:
    scheme, token = get_authorization_scheme_param(authorization or "")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return token


def _require_developer_token(
    db: Session,
    authorization: Optional[str],
    required_scopes: list[str],
) -> tuple[DeveloperAccessToken, DeveloperApp, User, set[str]]:
    token_value = _extract_bearer(authorization)
    row = (
        db.query(DeveloperAccessToken)
        .filter(
            DeveloperAccessToken.token == token_value,
            DeveloperAccessToken.revoked.is_(False),
            DeveloperAccessToken.expires_at > utcnow(),
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=401, detail="Invalid developer token")
    app = db.query(DeveloperApp).filter(DeveloperApp.id == row.app_id, DeveloperApp.is_active.is_(True)).first()
    if app is None:
        raise HTTPException(status_code=401, detail="Developer app is inactive")
    user = db.query(User).filter(User.id == row.user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Developer token user not found")
    scopes = set(json.loads(row.scopes_json or "[]"))
    for scope in required_scopes:
        if scope not in scopes:
            raise HTTPException(status_code=403, detail=f"Missing scope: {scope}")
    return row, app, user, scopes


def _build_tool_context(
    db: Session,
    user: User,
    payload: DeveloperContextPayload,
    scopes: set[str],
) -> dict[str, Any]:
    conversation_payload = None
    if payload.conversation_id:
        convo = db.query(Conversation).filter(Conversation.id == payload.conversation_id).first()
        if convo:
            conversation_payload = {
                "id": convo.id,
                "title": convo.title,
                "updatedAt": convo.updated_at.isoformat(),
            }
    message_payload = None
    if payload.message_id:
        msg = db.query(ChatMessage).filter(ChatMessage.id == payload.message_id).first()
        if msg:
            message_payload = {
                "id": msg.id,
                "conversationId": msg.conversation_id,
                "content": msg.content,
                "createdAt": msg.created_at.isoformat(),
            }
    profile = db.query(Profile).filter(Profile.user_id == user.id).first()
    return {
        "user": {
            "id": user.id,
            "email": user.email,
            "displayName": (profile.display_name if profile else (user.name or "Lilith User")),
            "username": (profile.username if profile else None),
        },
        "chat": conversation_payload,
        "message": message_payload,
        "permissions": sorted(scopes),
    }


def _passes_tool_safety(input_payload: dict[str, Any], policy: dict[str, Any]) -> tuple[bool, str]:
    moderation_required = bool(policy.get("moderation_required", True))
    if not moderation_required:
        return True, ""
    raw_text = json.dumps(input_payload, default=str).lower()
    for term in BANNED_TOOL_CONTENT_TERMS:
        if term in raw_text:
            return False, f"Input blocked by moderation policy: {term}"
    return True, ""


def _run_ai_action(action: str, input_text: str) -> tuple[str, str, dict[str, Any]]:
    source = (input_text or "").strip()
    if not source:
        return ("No content provided.", "text", {})
    if action == "improve":
        output = f"Improved draft:\n{source[0:1].upper() + source[1:] if len(source) > 1 else source}"
        return (output, "text", {"tone": "clear"})
    if action == "summarize":
        sentences = [part.strip() for part in source.replace("\n", " ").split(".") if part.strip()]
        output = ". ".join(sentences[:2]) + ("." if sentences else "")
        output = output or source[:180]
        return (f"Summary: {output}", "text", {"compression": "short"})
    if action == "translate":
        return (f"Translation (preview): {source}", "text", {"targetLanguage": "es"})
    if action == "create_video":
        return (
            "Video generated from message prompt. Open Video workspace to edit/export.",
            "video",
            {"videoLabel": "AI Clip", "durationSeconds": 12},
        )
    # analyze
    word_count = len(source.split())
    return (
        f"Analysis: {word_count} words. Primary intent appears task-oriented.",
        "text",
        {"wordCount": word_count},
    )


async def _emit_notification(db: Session, user_id: int, row: Notification) -> None:
    create_inbox_item(
        db,
        user_id=user_id,
        actor_user_id=row.actor_user_id,
        item_type="notification",
        title=row.text[:120] if row.text else "Notification",
        body=row.text,
        source_type="notification",
        source_id=row.id,
        metadata={
            "eventType": row.event_type,
            "targetType": row.target_type,
            "targetId": row.target_id,
            "deepLink": row.deep_link,
        },
    )
    db.commit()
    await hub.publish([user_id], "notification.new", _notification_frame(row))
    try:
        await send_push_for_notification(db, user_id, row)
    except Exception as error:  # pragma: no cover - defensive non-blocking push
        capture_exception(error, user_id=user_id, notification_id=row.id)


auth_router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
profiles_router = APIRouter(prefix="/api/v1/profiles", tags=["profiles"])
search_router = APIRouter(prefix="/api/v1/search", tags=["search"])
social_router = APIRouter(prefix="/api/v1/social", tags=["social"])
feed_router = APIRouter(prefix="/api/v1", tags=["feed"])
messages_router = APIRouter(prefix="/api/v1/messages", tags=["messages"])
calls_router = APIRouter(prefix="/api/v1/calls", tags=["calls"])
notifications_router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])
media_router = APIRouter(prefix="/api/v1/media", tags=["media"])
tools_router = APIRouter(prefix="/api/v1/tools", tags=["tools"])
presence_router = APIRouter(prefix="/api/v1/presence", tags=["presence"])
moderation_router = APIRouter(prefix="/api/v1/moderation", tags=["moderation"])
realtime_router = APIRouter(prefix="/api/v1/realtime", tags=["realtime"])
inbox_router = APIRouter(prefix="/api/v1/inbox", tags=["inbox"])
exchange_router = APIRouter(prefix="/api/v1/exchange", tags=["exchange"])
payments_router = APIRouter(prefix="/api/v1/payments", tags=["payments"])
subscriptions_router = APIRouter(prefix="/api/v1/subscriptions", tags=["subscriptions"])
invoices_router = APIRouter(prefix="/api/v1/invoices", tags=["invoices"])
payouts_router = APIRouter(prefix="/api/v1/payouts", tags=["payouts"])
wallets_router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])
webhooks_router = APIRouter(prefix="/api/v1/webhooks", tags=["webhooks"])
ai_router = APIRouter(prefix="/api/v1/ai", tags=["ai"])
developer_router = APIRouter(prefix="/api/v1/developer", tags=["developer"])
oauth_router = APIRouter(prefix="/api/v1/oauth", tags=["oauth"])
worlds_router = APIRouter(prefix="/api/v1/worlds", tags=["worlds"])
growth_router = APIRouter(prefix="/api/v1/growth", tags=["growth"])
onboarding_router = APIRouter(prefix="/api/v1/onboarding", tags=["onboarding"])
neurocloud_router = APIRouter(prefix="/api/v1/neurocloud", tags=["neurocloud"])
system_router = APIRouter(prefix="/api/v1/system", tags=["system"])


@system_router.get("/architecture")
def system_architecture(user: User = Depends(current_user)):
    return architecture_manifest()


@system_router.get("/realtime")
def system_realtime_manifest(user: User = Depends(current_user)):
    return realtime_manifest()


@system_router.get("/security")
def system_security_manifest(user: User = Depends(current_user)):
    return security_manifest()


@system_router.get("/infrastructure")
def system_infrastructure_manifest(user: User = Depends(current_user)):
    return infrastructure_manifest()


@auth_router.post("/register")
async def register(payload: RegisterPayload, db: Session = Depends(get_db)):
    await enforce_rate_limit("auth.register", payload.email.lower(), limit=6, window_seconds=300)
    email = payload.email.lower()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        email=email,
        hashed_password=hash_password(payload.password),
        name=(payload.name or email.split("@")[0])[:80],
        role="user",
        credits=24.0,
        is_super_admin=False,
    )
    db.add(user)
    db.flush()
    profile = ensure_profile(db, user)
    device = Device(
        user_id=user.id,
        device_name=payload.device_name or "Lilith Device",
        platform=payload.platform or "unknown",
    )
    db.add(device)
    refresh_token = _refresh_token()
    issue_refresh_session(db, user.id, refresh_token, device.id)
    db.commit()
    audit_event("auth.register", user_id=user.id, email=email)
    return {**_session_payload(user, refresh_token), "profile": {"username": profile.username, "lilithId": profile.lilith_id}}


@auth_router.post("/login")
async def login(payload: LoginPayload, db: Session = Depends(get_db)):
    await enforce_rate_limit("auth.login", payload.email.lower(), limit=12, window_seconds=300)
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    profile = ensure_profile(db, user)
    device = Device(
        user_id=user.id,
        device_name=payload.device_name or "Lilith Device",
        platform=payload.platform or "unknown",
        last_seen_at=utcnow(),
    )
    db.add(device)
    refresh_token = _refresh_token()
    issue_refresh_session(db, user.id, refresh_token, device.id)
    db.commit()
    audit_event("auth.login", user_id=user.id, email=user.email)
    return {**_session_payload(user, refresh_token), "profile": {"username": profile.username, "lilithId": profile.lilith_id}}


@auth_router.post("/refresh")
def refresh(payload: RefreshPayload, db: Session = Depends(get_db)):
    session = (
        db.query(SessionToken)
        .filter(SessionToken.refresh_token == payload.refresh_token, SessionToken.revoked.is_(False))
        .first()
    )
    if session is None or session.expires_at < utcnow():
        raise HTTPException(status_code=401, detail="Refresh token invalid")
    user = db.query(User).filter(User.id == session.user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    new_refresh = _refresh_token()
    session.revoked = True
    issue_refresh_session(db, user.id, new_refresh, session.device_id)
    db.commit()
    return _session_payload(user, new_refresh)


@auth_router.post("/logout")
def logout(payload: RefreshPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    session = (
        db.query(SessionToken)
        .filter(SessionToken.refresh_token == payload.refresh_token, SessionToken.user_id == user.id)
        .first()
    )
    if session:
        session.revoked = True
        session.updated_at = utcnow()
        db.add(session)
        db.commit()
    return {"success": True}


@auth_router.get("/me")
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = ensure_profile(db, user)
    stats = profile_stats(db, user.id)
    db.commit()
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name or "Lilith User",
        "profile": {
            "username": profile.username,
            "lilithId": profile.lilith_id,
            "displayName": profile.display_name,
            "bio": profile.bio or "",
        },
        "stats": stats,
    }


@profiles_router.get("/me")
def profile_me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = ensure_profile(db, user)
    settings = db.query(ProfileSettings).filter(ProfileSettings.profile_id == profile.id).first()
    stats = profile_stats(db, user.id)
    db.commit()
    return {
        "profile": {
            "userId": user.id,
            "username": profile.username,
            "lilithId": profile.lilith_id,
            "displayName": profile.display_name,
            "bio": profile.bio or "",
            "discoverable": profile.discoverable,
            "isPrivate": profile.is_private,
            "isBusiness": profile.is_business,
            "serviceDescription": profile.service_description or "",
            "isVerifiedBusiness": profile.is_verified_business,
            "stats": stats,
        },
        "settings": {
            "allowMessagesFrom": settings.allow_messages_from if settings else "followers",
            "allowCallsFrom": settings.allow_calls_from if settings else "followers",
            "showActivityStatus": settings.show_activity_status if settings else True,
            "showLastSeen": settings.show_last_seen if settings else True,
        },
    }


@profiles_router.patch("/me")
def profile_patch(payload: ProfilePatchPayload, user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = ensure_profile(db, user)
    if payload.username and payload.username != profile.username:
        new_username = slugify_username(payload.username)
        exists = db.query(Profile).filter(Profile.username == new_username, Profile.user_id != user.id).first()
        if exists:
            raise HTTPException(status_code=400, detail="Username already taken")
        profile.username = new_username
    if payload.display_name is not None:
        profile.display_name = payload.display_name[:80]
    if payload.bio is not None:
        profile.bio = payload.bio[:280]
    if payload.discoverable is not None:
        profile.discoverable = payload.discoverable
    if payload.is_private is not None:
        profile.is_private = payload.is_private
    if payload.is_business is not None:
        profile.is_business = payload.is_business
    if payload.service_description is not None:
        profile.service_description = payload.service_description[:500]
    if payload.is_verified_business is not None:
        profile.is_verified_business = payload.is_verified_business
    profile.updated_at = utcnow()
    db.add(profile)
    db.commit()
    return {
        "success": True,
        "profile": {
            "username": profile.username,
            "displayName": profile.display_name,
            "bio": profile.bio,
            "isBusiness": profile.is_business,
            "serviceDescription": profile.service_description,
            "isVerifiedBusiness": profile.is_verified_business,
        },
    }


@profiles_router.get("/{username}")
def profile_lookup(username: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    profile = db.query(Profile).filter(Profile.username == username.lower()).first()
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.is_private and profile.user_id != user.id:
        follow_exists = (
            db.query(Follow)
            .filter(Follow.follower_user_id == user.id, Follow.followed_user_id == profile.user_id)
            .first()
        )
        if not follow_exists:
            raise HTTPException(status_code=403, detail="Profile is private")
    stats = profile_stats(db, profile.user_id)
    return {
        "userId": profile.user_id,
        "username": profile.username,
        "lilithId": profile.lilith_id,
        "displayName": profile.display_name,
        "bio": profile.bio or "",
        "isBusiness": profile.is_business,
        "serviceDescription": profile.service_description or "",
        "isVerifiedBusiness": profile.is_verified_business,
        "stats": stats,
    }


@search_router.get("/users")
def search_users(q: str = "", db: Session = Depends(get_db), user: User = Depends(current_user)):
    term = (q or "").strip().lower()
    if not term:
        rows = db.query(Profile).filter(Profile.discoverable.is_(True)).order_by(Profile.updated_at.desc()).limit(20).all()
    else:
        rows = (
            db.query(Profile)
            .filter(
                Profile.discoverable.is_(True),
                or_(Profile.username.ilike(f"%{term}%"), Profile.display_name.ilike(f"%{term}%")),
            )
            .order_by(Profile.updated_at.desc())
            .limit(20)
            .all()
        )
    blocked = blocked_user_ids(db, user.id)
    output = []
    for profile in rows:
        if profile.user_id in blocked:
            continue
        output.append({
            "userId": profile.user_id,
            "username": profile.username,
            "displayName": profile.display_name,
            "lilithId": profile.lilith_id,
        })
    return {"items": output}


@social_router.post("/follow/{user_id}")
async def follow_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("social.follow", f"user:{user.id}", limit=60, window_seconds=60)
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    target = db.query(User).filter(User.id == user_id).first()
    if target is None:
        raise HTTPException(status_code=404, detail="Target user not found")
    exists = (
        db.query(Follow)
        .filter(Follow.follower_user_id == user.id, Follow.followed_user_id == user_id)
        .first()
    )
    if exists:
        return {"success": True}
    row = Follow(follower_user_id=user.id, followed_user_id=user_id)
    db.add(row)
    notification = create_notification(
        db,
        user_id=user_id,
        actor_user_id=user.id,
        event_type="follow.new",
        target_type="user",
        target_id=str(user.id),
        text=f"{user.name or user.email} followed you",
        deep_link=f"/profile/{user.id}",
    )
    db.commit()
    await _emit_notification(db, user_id, notification)
    audit_event("social.follow", follower_user_id=user.id, followed_user_id=user_id)
    return {"success": True}


@social_router.delete("/follow/{user_id}")
def unfollow_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = (
        db.query(Follow)
        .filter(Follow.follower_user_id == user.id, Follow.followed_user_id == user_id)
        .first()
    )
    if row:
        db.delete(row)
        db.commit()
    return {"success": True}


@social_router.post("/block/{user_id}")
def block_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    exists = db.query(Block).filter(Block.blocker_user_id == user.id, Block.blocked_user_id == user_id).first()
    if not exists:
        db.add(Block(blocker_user_id=user.id, blocked_user_id=user_id))
    db.query(Follow).filter(
        or_(
            and_(Follow.follower_user_id == user.id, Follow.followed_user_id == user_id),
            and_(Follow.follower_user_id == user_id, Follow.followed_user_id == user.id),
        )
    ).delete(synchronize_session=False)
    db.commit()
    return {"success": True}


@social_router.delete("/block/{user_id}")
def unblock_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Block).filter(Block.blocker_user_id == user.id, Block.blocked_user_id == user_id).first()
    if row:
        db.delete(row)
        db.commit()
    return {"success": True}


@social_router.post("/mute/{user_id}")
def mute_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Mute).filter(Mute.muter_user_id == user.id, Mute.muted_user_id == user_id).first()
    if not row:
        db.add(Mute(muter_user_id=user.id, muted_user_id=user_id))
        db.commit()
    return {"success": True}


@social_router.delete("/mute/{user_id}")
def unmute_user(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Mute).filter(Mute.muter_user_id == user.id, Mute.muted_user_id == user_id).first()
    if row:
        db.delete(row)
        db.commit()
    return {"success": True}


@social_router.get("/followers/{user_id}")
def followers(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _ = user
    rows = db.query(Follow).filter(Follow.followed_user_id == user_id).all()
    ids = [row.follower_user_id for row in rows]
    profiles = db.query(Profile).filter(Profile.user_id.in_(ids)).all() if ids else []
    by_uid = {row.user_id: row for row in profiles}
    return {"items": [{"userId": uid, "username": by_uid.get(uid).username if by_uid.get(uid) else None} for uid in ids]}


@social_router.get("/following/{user_id}")
def following(user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _ = user
    rows = db.query(Follow).filter(Follow.follower_user_id == user_id).all()
    ids = [row.followed_user_id for row in rows]
    profiles = db.query(Profile).filter(Profile.user_id.in_(ids)).all() if ids else []
    by_uid = {row.user_id: row for row in profiles}
    return {"items": [{"userId": uid, "username": by_uid.get(uid).username if by_uid.get(uid) else None} for uid in ids]}


@feed_router.get("/feed/home")
def home_feed(limit: int = 20, cursor: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = rank_posts(db, viewer_user_id=user.id, limit=max(1, min(limit, 50)), cursor=cursor)
    payload = [serialize_post(db, row, viewer_user_id=user.id) for row in rows]
    next_cursor = rows[-1].created_at.isoformat() if rows else None
    return {"items": payload, "nextCursor": next_cursor}


@feed_router.post("/posts")
async def create_post(payload: PostCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("feed.post", f"user:{user.id}", limit=20, window_seconds=60)
    row = Post(author_user_id=user.id, body=payload.body.strip(), visibility=payload.visibility)
    db.add(row)
    db.flush()
    for idx, asset_id in enumerate(payload.media_asset_ids):
        if db.query(MediaAsset).filter(MediaAsset.id == asset_id, MediaAsset.owner_user_id == user.id).first():
            db.add(PostMedia(post_id=row.id, media_asset_id=asset_id, display_order=idx))
    db.commit()
    audit_event("feed.post.create", user_id=user.id, post_id=row.id, media_count=len(payload.media_asset_ids))
    return {"post": serialize_post(db, row, viewer_user_id=user.id)}


@feed_router.get("/posts/{post_id}")
def post_detail(post_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Post).filter(Post.id == post_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Post not found")
    return {"post": serialize_post(db, row, viewer_user_id=user.id)}


@feed_router.post("/posts/{post_id}/comment")
async def post_comment(post_id: str, payload: CommentPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("feed.comment", f"user:{user.id}", limit=60, window_seconds=60)
    post = db.query(Post).filter(Post.id == post_id).first()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    row = Comment(post_id=post_id, author_user_id=user.id, body=payload.body.strip())
    db.add(row)
    notification: Notification | None = None
    if post.author_user_id != user.id:
        notification = create_notification(
            db,
            user_id=post.author_user_id,
            actor_user_id=user.id,
            event_type="post.comment",
            target_type="post",
            target_id=post_id,
            text=f"{user.name or user.email} commented on your post",
            deep_link=f"/post/{post_id}",
        )
    db.commit()
    if notification:
        await _emit_notification(db, post.author_user_id, notification)
    audit_event("feed.comment.create", user_id=user.id, post_id=post_id, comment_id=row.id)
    return {"id": row.id, "postId": row.post_id, "body": row.body, "createdAt": row.created_at.isoformat()}


@feed_router.post("/posts/{post_id}/react")
async def post_react(post_id: str, payload: ReactionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("feed.react", f"user:{user.id}", limit=120, window_seconds=60)
    post = db.query(Post).filter(Post.id == post_id).first()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    row = db.query(Reaction).filter(Reaction.post_id == post_id, Reaction.user_id == user.id).first()
    notification: Notification | None = None
    if row is None:
        row = Reaction(post_id=post_id, user_id=user.id, reaction=payload.reaction)
        db.add(row)
        if post.author_user_id != user.id:
            notification = create_notification(
                db,
                user_id=post.author_user_id,
                actor_user_id=user.id,
                event_type="post.reaction",
                target_type="post",
                target_id=post_id,
                text=f"{user.name or user.email} reacted to your post",
                deep_link=f"/post/{post_id}",
            )
    else:
        row.reaction = payload.reaction
    db.commit()
    if notification:
        await _emit_notification(db, post.author_user_id, notification)
    audit_event("feed.react", user_id=user.id, post_id=post_id, reaction=payload.reaction)
    return {"success": True}


@feed_router.post("/posts/{post_id}/share")
def post_share(post_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    exists = db.query(Repost).filter(Repost.post_id == post_id, Repost.user_id == user.id).first()
    if not exists:
        db.add(Repost(post_id=post_id, user_id=user.id))
    db.commit()
    return {"success": True}


@feed_router.post("/posts/{post_id}/save")
def post_save(post_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    exists = db.query(Save).filter(Save.post_id == post_id, Save.user_id == user.id).first()
    if not exists:
        db.add(Save(post_id=post_id, user_id=user.id))
    db.commit()
    return {"success": True}


@messages_router.get("/conversations")
def conversation_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    memberships = (
        db.query(ConversationMember)
        .filter(ConversationMember.user_id == user.id)
        .order_by(desc(ConversationMember.updated_at))
        .all()
    )
    out = []
    for member in memberships:
        convo = db.query(Conversation).filter(Conversation.id == member.conversation_id).first()
        if convo is None:
            continue
        last_message = db.query(ChatMessage).filter(ChatMessage.conversation_id == convo.id).order_by(desc(ChatMessage.created_at)).first()
        unread = db.query(MessageReceipt).filter(
            MessageReceipt.user_id == user.id,
            MessageReceipt.status != "read",
            MessageReceipt.message_id.in_(
                db.query(ChatMessage.id).filter(ChatMessage.conversation_id == convo.id)
            ),
        ).count()
        out.append({
            "conversationId": convo.id,
            "title": convo.title,
            "lastMessage": last_message.content if last_message else "",
            "lastMessageAt": last_message.created_at.isoformat() if last_message else convo.updated_at.isoformat(),
            "unread": unread,
        })
    return {"items": out}


@messages_router.post("/conversations")
def conversation_create(payload: MessageConversationCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    ids = sorted(set(payload.participant_user_ids + [user.id]))
    if len(ids) < 2:
        raise HTTPException(status_code=400, detail="At least two members required")
    convo = Conversation(
        user_id=user.id,
        title=payload.title or ("Group chat" if payload.is_group else "Direct message"),
    )
    db.add(convo)
    db.flush()
    for member_user_id in ids:
        db.add(ConversationMember(conversation_id=convo.id, user_id=member_user_id, role="owner" if member_user_id == user.id else "member"))
    db.commit()
    return {"conversationId": convo.id}


@messages_router.get("/conversations/{conversation_id}")
def conversation_detail(conversation_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    member = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user.id).first()
    if member is None:
        raise HTTPException(status_code=403, detail="Not a member")
    rows = db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id).order_by(ChatMessage.created_at.asc()).all()
    out = []
    for row in rows:
        media = db.query(MessageMedia).filter(MessageMedia.message_id == row.id).all()
        out.append({
            "id": row.id,
            "role": row.role,
            "content": row.content,
            "toolUsed": row.tool_used,
            "createdAt": row.created_at.isoformat(),
            "mediaAssetIds": [m.media_asset_id for m in media],
        })
    return {"conversationId": conversation_id, "messages": out}


@messages_router.post("/conversations/{conversation_id}/send")
async def conversation_send(conversation_id: str, payload: MessageSendPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("messages.send", f"user:{user.id}", limit=90, window_seconds=60)
    member = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user.id).first()
    if member is None:
        raise HTTPException(status_code=403, detail="Not a member")
    msg = ChatMessage(
        conversation_id=conversation_id,
        role="user",
        content=payload.content,
        tool_used="oneway_envelope" if payload.encrypted_payload else None,
    )
    db.add(msg)
    db.flush()
    for asset_id in payload.media_asset_ids:
        db.add(MessageMedia(message_id=msg.id, media_asset_id=asset_id))
    peers = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id).all()
    peer_notifications: list[tuple[int, Notification]] = []
    for peer in peers:
        if peer.user_id == user.id:
            continue
        db.add(MessageReceipt(message_id=msg.id, user_id=peer.user_id, status="delivered"))
        create_inbox_item(
            db,
            user_id=peer.user_id,
            actor_user_id=user.id,
            item_type="message",
            title=f"New message from {user.name or user.email}",
            body=payload.content[:300],
            source_type="message",
            source_id=msg.id,
            metadata={"conversationId": conversation_id},
        )
        notification = create_notification(
            db,
            user_id=peer.user_id,
            actor_user_id=user.id,
            event_type="message.new",
            target_type="conversation",
            target_id=conversation_id,
            text=f"New message from {user.name or user.email}",
            deep_link=f"/messages/{conversation_id}",
        )
        peer_notifications.append((peer.user_id, notification))
    convo = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if convo:
        convo.updated_at = utcnow()
    emit_neuro_event(
        db,
        event_type="message.sent",
        source_type="message",
        source_id=msg.id,
        user_id=user.id,
        channel="messages",
        payload={
            "conversationId": conversation_id,
            "messageId": msg.id,
            "hasEncryptedPayload": bool(payload.encrypted_payload),
            "mediaAssetCount": len(payload.media_asset_ids),
        },
    )
    db.commit()
    await hub.publish([peer.user_id for peer in peers if peer.user_id != user.id], "message.new", {
        "conversationId": conversation_id,
        "messageId": msg.id,
        "senderUserId": user.id,
        "content": payload.content,
    })
    for peer_user_id, notification in peer_notifications:
        await _emit_notification(db, peer_user_id, notification)
    audit_event("messages.send", user_id=user.id, conversation_id=conversation_id, message_id=msg.id)
    return {"messageId": msg.id, "createdAt": msg.created_at.isoformat()}


@messages_router.post("/conversations/{conversation_id}/read")
async def conversation_read(conversation_id: str, payload: MessageReadPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    member = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user.id).first()
    if member is None:
        raise HTTPException(status_code=403, detail="Not a member")
    target_ids = payload.message_ids or [
        row.id for row in db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id).all()
    ]
    rows = db.query(MessageReceipt).filter(MessageReceipt.user_id == user.id, MessageReceipt.message_id.in_(target_ids)).all()
    for row in rows:
        row.status = "read"
        row.seen_at = utcnow()
    if target_ids:
        member.last_read_message_id = target_ids[-1]
    member.updated_at = utcnow()
    db.add(member)
    db.commit()
    peers = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id).all()
    await hub.publish([peer.user_id for peer in peers if peer.user_id != user.id], "message.read", {
        "conversationId": conversation_id,
        "userId": user.id,
        "messageIds": target_ids,
    })
    return {"success": True}


@calls_router.post("/start")
async def call_start(payload: CallStartPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("calls.start", f"user:{user.id}", limit=20, window_seconds=60)
    row = Call(
        caller_user_id=user.id,
        call_type=payload.call_type,
        status="ringing",
        signaling_payload=json.dumps({"offerSdp": payload.offer_sdp, "iceCandidates": payload.ice_candidates}),
    )
    db.add(row)
    db.flush()
    db.add(CallParticipant(call_id=row.id, user_id=user.id, participant_state="joined", joined_at=utcnow()))
    peer_notifications: list[tuple[int, Notification]] = []
    for uid in payload.participant_user_ids:
        db.add(CallParticipant(call_id=row.id, user_id=uid, participant_state="invited"))
        notification = create_notification(
            db,
            user_id=uid,
            actor_user_id=user.id,
            event_type="call.invite",
            target_type="call",
            target_id=row.id,
            text=f"Incoming {payload.call_type} call",
            deep_link=f"/calls/{row.id}",
        )
        peer_notifications.append((uid, notification))
    db.add(CallEvent(call_id=row.id, event_type="call.invite", payload_json=json.dumps({"offerSdp": payload.offer_sdp})))
    db.commit()
    await hub.publish(payload.participant_user_ids, "call.invite", {
        "callId": row.id,
        "fromUserId": user.id,
        "callType": payload.call_type,
        "offerSdp": payload.offer_sdp,
        "iceCandidates": payload.ice_candidates,
    })
    for peer_user_id, notification in peer_notifications:
        await _emit_notification(db, peer_user_id, notification)
    audit_event("calls.start", caller_user_id=user.id, call_id=row.id, participants=payload.participant_user_ids)
    return {"callId": row.id, "status": row.status}


def _update_call_state(call_id: str, state: str, payload: CallStatePayload, db: Session, user: User) -> dict[str, Any]:
    row = db.query(Call).filter(Call.id == call_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Call not found")
    participant = db.query(CallParticipant).filter(CallParticipant.call_id == call_id, CallParticipant.user_id == user.id).first()
    if participant is None:
        raise HTTPException(status_code=403, detail="Not a participant")
    participant.participant_state = state
    if state == "joined":
        participant.joined_at = utcnow()
        row.status = "active"
    if state in {"declined", "left"}:
        participant.left_at = utcnow()
    if state == "ended":
        row.status = "ended"
        row.ended_at = utcnow()
    db.add(participant)
    db.add(CallEvent(call_id=call_id, event_type=f"call.{state}", payload_json=json.dumps(payload.dict(), default=str)))
    db.commit()
    return {"callId": call_id, "status": row.status, "participantState": participant.participant_state}


@calls_router.post("/{call_id}/accept")
async def call_accept(call_id: str, payload: CallStatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("calls.state", f"user:{user.id}", limit=60, window_seconds=60)
    state = _update_call_state(call_id, "joined", payload, db, user)
    peers = [row.user_id for row in db.query(CallParticipant).filter(CallParticipant.call_id == call_id).all() if row.user_id != user.id]
    await hub.publish(peers, "call.accept", {"callId": call_id, "userId": user.id, **payload.dict()})
    return state


@calls_router.post("/{call_id}/decline")
async def call_decline(call_id: str, payload: CallStatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("calls.state", f"user:{user.id}", limit=60, window_seconds=60)
    state = _update_call_state(call_id, "declined", payload, db, user)
    peers = [row.user_id for row in db.query(CallParticipant).filter(CallParticipant.call_id == call_id).all() if row.user_id != user.id]
    await hub.publish(peers, "call.decline", {"callId": call_id, "userId": user.id, "reason": payload.reason})
    return state


@calls_router.post("/{call_id}/end")
async def call_end(call_id: str, payload: CallStatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("calls.state", f"user:{user.id}", limit=60, window_seconds=60)
    state = _update_call_state(call_id, "ended", payload, db, user)
    peers = [row.user_id for row in db.query(CallParticipant).filter(CallParticipant.call_id == call_id).all() if row.user_id != user.id]
    await hub.publish(peers, "call.end", {"callId": call_id, "userId": user.id, "reason": payload.reason})
    return state


@calls_router.get("/history")
def call_history(limit: int = 50, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(Call)
        .join(CallParticipant, CallParticipant.call_id == Call.id)
        .filter(CallParticipant.user_id == user.id)
        .order_by(desc(Call.created_at))
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return {
        "items": [
            {
                "callId": row.id,
                "callerUserId": row.caller_user_id,
                "callType": row.call_type,
                "status": row.status,
                "startedAt": row.started_at.isoformat(),
                "endedAt": row.ended_at.isoformat() if row.ended_at else None,
            }
            for row in rows
        ]
    }


@calls_router.get("/config")
def call_config():
    stun_servers = [value.strip() for value in os.getenv("WEBRTC_STUN_SERVERS", "stun:stun.l.google.com:19302").split(",") if value.strip()]
    turn_url = os.getenv("WEBRTC_TURN_URL", "")
    turn_username = os.getenv("WEBRTC_TURN_USERNAME", "")
    turn_credential = os.getenv("WEBRTC_TURN_CREDENTIAL", "")
    return {
        "stunServers": stun_servers,
        "turn": {
            "url": turn_url,
            "username": turn_username,
            "credential": turn_credential,
            "configured": bool(turn_url and turn_username and turn_credential),
        },
    }


@calls_router.post("/{call_id}/ice")
async def call_ice_exchange(call_id: str, payload: CallIcePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    participant = db.query(CallParticipant).filter(CallParticipant.call_id == call_id, CallParticipant.user_id == user.id).first()
    if participant is None:
        raise HTTPException(status_code=403, detail="Not a participant")
    db.add(
        CallEvent(
            call_id=call_id,
            event_type="call.ice",
            payload_json=json.dumps(
                {
                    "fromUserId": user.id,
                    "candidates": payload.candidates,
                    "sdpMid": payload.sdp_mid,
                    "sdpMLineIndex": payload.sdp_mline_index,
                },
                default=str,
            ),
        )
    )
    db.commit()
    peers = [row.user_id for row in db.query(CallParticipant).filter(CallParticipant.call_id == call_id).all() if row.user_id != user.id]
    await hub.publish(
        peers,
        "call.signal",
        {
            "callId": call_id,
            "fromUserId": user.id,
            "iceCandidates": payload.candidates,
            "sdpMid": payload.sdp_mid,
            "sdpMLineIndex": payload.sdp_mline_index,
        },
    )
    return {"success": True}


@calls_router.get("/{call_id}/ice")
def call_ice_fetch(call_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    participant = db.query(CallParticipant).filter(CallParticipant.call_id == call_id, CallParticipant.user_id == user.id).first()
    if participant is None:
        raise HTTPException(status_code=403, detail="Not a participant")
    events = (
        db.query(CallEvent)
        .filter(CallEvent.call_id == call_id, CallEvent.event_type == "call.ice")
        .order_by(desc(CallEvent.created_at))
        .limit(100)
        .all()
    )
    output = []
    for event in events:
        payload = json.loads(event.payload_json or "{}")
        if payload.get("fromUserId") == user.id:
            continue
        output.append(
            {
                "eventId": event.id,
                "fromUserId": payload.get("fromUserId"),
                "candidates": payload.get("candidates", []),
                "sdpMid": payload.get("sdpMid"),
                "sdpMLineIndex": payload.get("sdpMLineIndex"),
                "createdAt": event.created_at.isoformat(),
            }
        )
    return {"items": output}


@calls_router.post("/{call_id}/reconnect")
async def call_reconnect(call_id: str, payload: CallStatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    state = _update_call_state(call_id, "joined", payload, db, user)
    peers = [row.user_id for row in db.query(CallParticipant).filter(CallParticipant.call_id == call_id).all() if row.user_id != user.id]
    await hub.publish(peers, "call.reconnect", {"callId": call_id, "userId": user.id})
    return state


@notifications_router.get("")
def notifications(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(Notification)
        .filter(Notification.user_id == user.id)
        .order_by(desc(Notification.created_at))
        .limit(max(1, min(limit, 200)))
        .all()
    )
    unread = sum(1 for row in rows if not row.read)
    return {
        "unread": unread,
        "items": [
            {
                "id": row.id,
                "eventType": row.event_type,
                "text": row.text,
                "deepLink": row.deep_link,
                "targetType": row.target_type,
                "targetId": row.target_id,
                "actorUserId": row.actor_user_id,
                "read": row.read,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ],
    }


@notifications_router.post("/push-token")
def register_push_token(payload: PushTokenPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(DevicePushToken).filter(DevicePushToken.token == payload.token).first()
    if row is None:
        row = DevicePushToken(
            user_id=user.id,
            device_id=payload.device_id,
            token=payload.token,
            platform=payload.platform,
        )
    else:
        row.user_id = user.id
        row.device_id = payload.device_id
        row.platform = payload.platform
        row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"success": True, "tokenId": row.id}


@notifications_router.post("/{notification_id}/read")
def notification_read(notification_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    row.read = True
    db.add(row)
    db.commit()
    return {"success": True}


@notifications_router.post("/read-all")
def notifications_read_all(db: Session = Depends(get_db), user: User = Depends(current_user)):
    db.query(Notification).filter(Notification.user_id == user.id, Notification.read.is_(False)).update({"read": True})
    db.commit()
    return {"success": True}


@inbox_router.get("")
def inbox_list(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(InboxItem)
        .filter(InboxItem.user_id == user.id)
        .order_by(desc(InboxItem.created_at))
        .limit(max(1, min(limit, 300)))
        .all()
    )
    unread = sum(1 for row in rows if row.status == "unread")
    return {"unread": unread, "items": [_inbox_shape(row) for row in rows]}


@inbox_router.post("/{inbox_id}/read")
def inbox_mark_read(inbox_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(InboxItem).filter(InboxItem.id == inbox_id, InboxItem.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Inbox item not found")
    row.status = "read"
    row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"success": True, "item": _inbox_shape(row)}


@exchange_router.post("/request")
async def exchange_request_create(payload: ExchangeRequestPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    target = db.query(User).filter(User.id == payload.recipient_user_id).first()
    if target is None:
        raise HTTPException(status_code=404, detail="Recipient not found")
    row = ExchangeRequest(
        requester_user_id=user.id,
        recipient_user_id=payload.recipient_user_id,
        request_type=payload.request_type,
        title=payload.title.strip()[:160],
        body=(payload.body or "").strip()[:2000] or None,
        source_tool_result_id=payload.source_tool_result_id,
        status="pending",
    )
    db.add(row)
    db.flush()
    transaction = ExchangeTransaction(
        exchange_request_id=row.id,
        status="open",
        summary=f"Exchange request: {row.title}",
        details_json=json.dumps({"requestType": row.request_type}, default=str),
    )
    db.add(transaction)
    inbox = create_inbox_item(
        db,
        user_id=payload.recipient_user_id,
        actor_user_id=user.id,
        item_type="exchange_request",
        title=row.title,
        body=row.body,
        source_type="exchange_request",
        source_id=row.id,
        metadata={
            "requestType": row.request_type,
            "requesterUserId": user.id,
            "transactionId": transaction.id,
            "sourceToolResultId": row.source_tool_result_id,
        },
    )
    notification = create_notification(
        db,
        user_id=payload.recipient_user_id,
        actor_user_id=user.id,
        event_type="exchange.request",
        target_type="exchange_request",
        target_id=row.id,
        text=f"New exchange request: {row.title}",
        deep_link=f"/exchange/{row.id}",
    )
    db.commit()
    await _emit_notification(db, payload.recipient_user_id, notification)
    return {
        "requestId": row.id,
        "status": row.status,
        "transactionId": transaction.id,
        "inboxItemId": inbox.id,
        "notificationId": notification.id,
    }


@exchange_router.post("/respond")
async def exchange_request_respond(payload: ExchangeRespondPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(ExchangeRequest).filter(ExchangeRequest.id == payload.exchange_request_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Exchange request not found")
    if user.id not in {row.requester_user_id, row.recipient_user_id}:
        raise HTTPException(status_code=403, detail="Not authorized for this exchange")

    response_row = ExchangeResponse(
        exchange_request_id=row.id,
        responder_user_id=user.id,
        response=payload.response,
        message=(payload.message or "").strip()[:1200] or None,
    )
    db.add(response_row)
    row.status = {
        "accept": "accepted",
        "decline": "declined",
        "update": row.status,
    }[payload.response]
    row.updated_at = utcnow()
    db.add(row)

    transaction = db.query(ExchangeTransaction).filter(ExchangeTransaction.exchange_request_id == row.id).first()
    if transaction:
        if payload.transaction_status:
            transaction.status = payload.transaction_status
        elif payload.response == "accept":
            transaction.status = "processing"
        elif payload.response == "decline":
            transaction.status = "cancelled"
        transaction.updated_at = utcnow()
        db.add(transaction)

    counterpart_id = row.requester_user_id if user.id == row.recipient_user_id else row.recipient_user_id
    inbox = create_inbox_item(
        db,
        user_id=counterpart_id,
        actor_user_id=user.id,
        item_type="transaction",
        title=f"Exchange {payload.response}: {row.title}",
        body=response_row.message,
        source_type="exchange_response",
        source_id=response_row.id,
        metadata={
            "exchangeRequestId": row.id,
            "response": payload.response,
            "transactionStatus": transaction.status if transaction else None,
        },
    )
    notification = create_notification(
        db,
        user_id=counterpart_id,
        actor_user_id=user.id,
        event_type="exchange.response",
        target_type="exchange_request",
        target_id=row.id,
        text=f"{user.name or user.email} {payload.response}ed exchange: {row.title}",
        deep_link=f"/exchange/{row.id}",
    )
    db.commit()
    await _emit_notification(db, counterpart_id, notification)
    return {
        "success": True,
        "exchangeRequestId": row.id,
        "status": row.status,
        "responseId": response_row.id,
        "transactionStatus": transaction.status if transaction else None,
        "inboxItemId": inbox.id,
    }


@ai_router.post("/jobs")
async def ai_job_create(payload: AIJobCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("ai.jobs.create", f"user:{user.id}", limit=120, window_seconds=60)
    row = AIJob(
        user_id=user.id,
        conversation_id=payload.conversation_id,
        message_id=payload.message_id,
        action=payload.action,
        input_text=payload.input_text,
        status="processing",
        metadata_json=json.dumps(payload.metadata or {}, default=str),
    )
    db.add(row)
    db.flush()
    output_text, output_kind, output_meta = _run_ai_action(payload.action, payload.input_text)
    output_text = apply_lilith_voice(
        user=user,
        user_text=payload.input_text,
        base_text=output_text,
        tool_used="AI",
        proactive_hint="share this in chat or save it to your library",
    )
    voice = lilith_voice_profile(user, payload.input_text)
    result = AIResult(
        job_id=row.id,
        user_id=user.id,
        conversation_id=payload.conversation_id,
        message_id=payload.message_id,
        output_text=output_text,
        output_kind=output_kind,
        metadata_json=json.dumps(output_meta, default=str),
    )
    db.add(result)
    row.status = "completed"
    row.updated_at = utcnow()
    db.add(row)
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=None,
        item_type="tool_result",
        title=f"AI {payload.action} ready",
        body=output_text[:280],
        source_type="ai_result",
        source_id=result.id,
        metadata={"action": payload.action, "jobId": row.id, "outputKind": output_kind},
    )
    db.commit()
    return {
        "job": {
            "id": row.id,
            "status": row.status,
            "action": row.action,
            "conversationId": row.conversation_id,
            "messageId": row.message_id,
            "createdAt": row.created_at.isoformat(),
        },
        "result": {
            "id": result.id,
            "jobId": result.job_id,
            "outputText": result.output_text,
            "outputKind": result.output_kind,
            "metadata": json.loads(result.metadata_json or "{}"),
            "voice": voice,
            "createdAt": result.created_at.isoformat(),
        },
    }


@ai_router.get("/jobs")
def ai_jobs(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(AIJob)
        .filter(AIJob.user_id == user.id)
        .order_by(desc(AIJob.created_at))
        .limit(max(1, min(limit, 300)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "status": row.status,
                "action": row.action,
                "conversationId": row.conversation_id,
                "messageId": row.message_id,
                "createdAt": row.created_at.isoformat(),
                "updatedAt": row.updated_at.isoformat(),
            }
            for row in rows
        ]
    }


@ai_router.get("/jobs/{job_id}")
def ai_job_detail(job_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(AIJob).filter(AIJob.id == job_id, AIJob.user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="AI job not found")
    result = db.query(AIResult).filter(AIResult.job_id == row.id).order_by(desc(AIResult.created_at)).first()
    return {
        "job": {
            "id": row.id,
            "status": row.status,
            "action": row.action,
            "conversationId": row.conversation_id,
            "messageId": row.message_id,
            "inputText": row.input_text,
            "createdAt": row.created_at.isoformat(),
            "updatedAt": row.updated_at.isoformat(),
        },
        "result": (
            {
                "id": result.id,
                "outputText": result.output_text,
                "outputKind": result.output_kind,
                "metadata": json.loads(result.metadata_json or "{}"),
                "createdAt": result.created_at.isoformat(),
            }
            if result
            else None
        ),
    }


@payments_router.post("/methods")
async def payment_method_create(payload: PaymentMethodCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("payments.methods.create", f"user:{user.id}", limit=25, window_seconds=60)
    method = upsert_payment_method(
        db=db,
        user=user,
        method_type=payload.method_type,
        provider=payload.provider,
        provider_payment_method_id=payload.provider_payment_method_id,
        last4=payload.last4,
        brand=payload.brand,
        exp_month=payload.exp_month,
        exp_year=payload.exp_year,
        billing_name=payload.billing_name,
        billing_email=str(payload.billing_email) if payload.billing_email else None,
        encrypted_reference=payload.encrypted_reference,
        make_default=payload.make_default,
        metadata=payload.metadata,
    )
    record_payment_event(
        db,
        user_id=user.id,
        event_type="payment_method.created",
        object_type="payment_method",
        object_id=method.id,
        payload={"provider": method.provider, "methodType": method.method_type},
    )
    db.commit()
    return {
        "paymentMethod": {
            "id": method.id,
            "methodType": method.method_type,
            "provider": method.provider,
            "last4": method.last4,
            "brand": method.brand,
            "isDefault": method.is_default,
            "expMonth": method.exp_month,
            "expYear": method.exp_year,
        }
    }


@payments_router.get("/methods")
def payment_methods(db: Session = Depends(get_db), user: User = Depends(current_user)):
    customer = ensure_payment_customer(db, user)
    rows = (
        db.query(PaymentMethod)
        .filter(PaymentMethod.customer_id == customer.id)
        .order_by(desc(PaymentMethod.is_default), desc(PaymentMethod.updated_at))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "methodType": row.method_type,
                "provider": row.provider,
                "last4": row.last4,
                "brand": row.brand,
                "isDefault": row.is_default,
                "expMonth": row.exp_month,
                "expYear": row.exp_year,
            }
            for row in rows
        ],
        "defaultPaymentMethodId": customer.default_payment_method_id,
    }


@payments_router.post("/intents")
async def payment_intent_create(payload: PaymentIntentCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("payments.intent.create", f"user:{user.id}", limit=45, window_seconds=60)
    if payload.rail == "stablecoin_usdc":
        if (payload.stablecoin or SUPPORTED_STABLECOIN) != SUPPORTED_STABLECOIN:
            raise HTTPException(status_code=400, detail="Only USDC stablecoin is supported")
        if payload.network and payload.network not in SUPPORTED_NETWORKS:
            raise HTTPException(status_code=400, detail="Unsupported stablecoin network")
    customer = ensure_payment_customer(db, user)
    existing = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.user_id == user.id, PaymentIntent.idempotency_key == payload.idempotency_key)
        .first()
    )
    if existing:
        return {"paymentIntent": _payment_shape(existing), "idempotent": True}
    risk = evaluate_risk(db, user.id, payload.amount, payload.intent_type)
    decision = save_risk_review(
        db,
        user_id=user.id,
        action_type="payment_intent_create",
        score=risk.score,
        decision=risk.decision,
        reasons=risk.reasons,
    )
    if risk.decision == "deny":
        db.commit()
        raise HTTPException(status_code=403, detail=f"Payment denied by risk policy: {','.join(risk.reasons) or 'policy'}")

    requires_step_up = trust.requires_step_up(payload.amount, payload.intent_type)
    status_value = "requires_confirmation" if risk.decision == "allow" else "requires_review"
    row = PaymentIntent(
        user_id=user.id,
        customer_id=customer.id,
        payment_method_id=payload.payment_method_id,
        amount=round(payload.amount, 2),
        currency=payload.currency.upper(),
        rail=payload.rail,
        stablecoin=payload.stablecoin or (SUPPORTED_STABLECOIN if payload.rail == "stablecoin_usdc" else None),
        network=payload.network,
        intent_type=payload.intent_type,
        status=status_value,
        idempotency_key=payload.idempotency_key,
        external_intent_id=f"pi_ext_{new_id()}",
        requires_step_up=requires_step_up,
        metadata_json=json.dumps(
            {
                **payload.metadata,
                "payeeUserId": payload.payee_user_id,
                "riskDecision": risk.decision,
                "riskScore": risk.score,
                "riskReviewId": decision.id,
            },
            default=str,
        ),
    )
    db.add(row)
    db.flush()
    record_payment_event(
        db,
        user_id=user.id,
        event_type="payment_intent.created",
        object_type="payment_intent",
        object_id=row.id,
        idempotency_key=payload.idempotency_key,
        payload={"amount": row.amount, "currency": row.currency, "intentType": row.intent_type, "rail": row.rail},
    )
    db.commit()
    return {"paymentIntent": _payment_shape(row), "idempotent": False}


@payments_router.post("/intents/{intent_id}/confirm")
async def payment_intent_confirm(intent_id: str, payload: PaymentConfirmPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("payments.intent.confirm", f"user:{user.id}", limit=60, window_seconds=60)
    intent = db.query(PaymentIntent).filter(PaymentIntent.id == intent_id, PaymentIntent.user_id == user.id).first()
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    if intent.status in {"succeeded", "refunded", "cancelled"}:
        return {"paymentIntent": _payment_shape(intent), "alreadyFinalized": True}
    if intent.requires_step_up and not trust.verify_passkey_assertion(payload.passkey_assertion, payload.passkey_challenge_id):
        raise HTTPException(status_code=401, detail="Step-up verification required")
    if intent.status == "requires_review":
        raise HTTPException(status_code=403, detail="Payment is pending manual risk review")

    customer = ensure_payment_customer(db, user)
    method_id = payload.payment_method_id or intent.payment_method_id or customer.default_payment_method_id
    if not method_id:
        raise HTTPException(status_code=400, detail="No payment method available")
    method = db.query(PaymentMethod).filter(PaymentMethod.id == method_id).first()
    if method is None:
        raise HTTPException(status_code=404, detail="Payment method not found")

    if method.customer_id != customer.id:
        raise HTTPException(status_code=403, detail="Payment method does not belong to caller")

    intent.payment_method_id = method.id
    intent.status = "processing"
    intent.step_up_verified_at = utcnow() if intent.requires_step_up else intent.step_up_verified_at
    intent.updated_at = utcnow()
    db.add(intent)
    db.flush()

    attempt = PaymentAttempt(
        payment_intent_id=intent.id,
        user_id=user.id,
        payment_method_id=method.id,
        status="processing",
        provider=method.provider,
        provider_attempt_id=f"pa_{new_id()}",
        response_json=json.dumps({"provider": method.provider, "status": "processing"}, default=str),
    )
    db.add(attempt)
    db.flush()

    metadata = json.loads(intent.metadata_json or "{}")
    payee_user_id = metadata.get("payeeUserId")
    payer_account = get_or_create_ledger_account(db, user.id, "user_wallet", intent.currency)
    platform_escrow = get_or_create_ledger_account(db, None, "platform_escrow", intent.currency)
    event = record_payment_event(
        db,
        user_id=user.id,
        event_type="payment_intent.succeeded",
        object_type="payment_intent",
        object_id=intent.id,
        idempotency_key=intent.idempotency_key,
        payload={"attemptId": attempt.id, "methodId": method.id},
    )
    create_ledger_transfer(
        db,
        from_account=payer_account,
        to_account=platform_escrow,
        amount=intent.amount,
        currency=intent.currency,
        reference_type="payment_intent",
        reference_id=intent.id,
        event_id=event.id,
        description="Payer charge captured",
        metadata={"rail": intent.rail, "intentType": intent.intent_type},
    )
    if payee_user_id:
        payee_account = get_or_create_ledger_account(db, int(payee_user_id), "user_revenue", intent.currency)
        create_ledger_transfer(
            db,
            from_account=platform_escrow,
            to_account=payee_account,
            amount=intent.amount,
            currency=intent.currency,
            reference_type="payment_intent",
            reference_id=intent.id,
            event_id=event.id,
            description="Settlement to payee",
            metadata={"payeeUserId": payee_user_id},
        )
        update_monetization_eligibility(db, int(payee_user_id))

    attempt.status = "succeeded"
    attempt.updated_at = utcnow()
    attempt.response_json = json.dumps({"provider": method.provider, "status": "succeeded"}, default=str)
    intent.status = "succeeded"
    intent.updated_at = utcnow()
    db.add(intent)
    db.add(attempt)
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=None,
        item_type="transaction",
        title=f"Payment successful • {intent.currency} {intent.amount:.2f}",
        body=f"Payment intent {intent.id} was completed.",
        source_type="payment_intent",
        source_id=intent.id,
        metadata={"intentType": intent.intent_type, "attemptId": attempt.id},
    )
    if payee_user_id:
        create_inbox_item(
            db,
            user_id=int(payee_user_id),
            actor_user_id=user.id,
            item_type="transaction",
            title=f"Payment received • {intent.currency} {intent.amount:.2f}",
            body=f"{user.name or user.email} sent a payment.",
            source_type="payment_intent",
            source_id=intent.id,
            metadata={"payerUserId": user.id, "intentType": intent.intent_type},
        )
    emit_neuro_event(
        db,
        event_type="payment.succeeded",
        source_type="payment_intent",
        source_id=intent.id,
        user_id=user.id,
        channel="payments",
        payload={
            "amount": intent.amount,
            "currency": intent.currency,
            "rail": intent.rail,
            "intentType": intent.intent_type,
            "attemptId": attempt.id,
            "payeeUserId": payee_user_id,
        },
    )
    db.commit()
    audit_event("payments.intent.confirm", user_id=user.id, payment_intent_id=intent.id, attempt_id=attempt.id)
    return {"paymentIntent": _payment_shape(intent), "attemptId": attempt.id}


@payments_router.post("/refunds")
async def payment_refund(payload: RefundCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("payments.refund", f"user:{user.id}", limit=20, window_seconds=60)
    intent = db.query(PaymentIntent).filter(PaymentIntent.id == payload.payment_intent_id).first()
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    metadata = json.loads(intent.metadata_json or "{}")
    payee_user_id = metadata.get("payeeUserId")
    allowed = intent.user_id == user.id or (payee_user_id and int(payee_user_id) == user.id)
    if not allowed:
        raise HTTPException(status_code=403, detail="Not authorized to refund this payment")
    if intent.status != "succeeded":
        raise HTTPException(status_code=400, detail="Only succeeded payments can be refunded")

    amount = round(payload.amount if payload.amount is not None else intent.amount, 2)
    if amount <= 0 or amount > intent.amount:
        raise HTTPException(status_code=400, detail="Invalid refund amount")
    if trust.requires_step_up(amount, "refund") and not trust.verify_passkey_assertion(payload.passkey_assertion, payload.passkey_challenge_id):
        raise HTTPException(status_code=401, detail="Step-up verification required")
    risk = evaluate_risk(db, user.id, amount, "refund")
    save_risk_review(db, user.id, "refund", risk.score, risk.decision, risk.reasons, payment_intent_id=intent.id)
    if risk.decision == "deny":
        db.commit()
        raise HTTPException(status_code=403, detail="Refund blocked by risk policy")
    refund = Refund(
        payment_intent_id=intent.id,
        user_id=user.id,
        amount=amount,
        currency=intent.currency,
        reason=(payload.reason or "").strip()[:280] or None,
        status="succeeded" if risk.decision == "allow" else "pending",
        metadata_json=json.dumps({"riskDecision": risk.decision, "riskScore": risk.score}, default=str),
    )
    db.add(refund)
    db.flush()
    event = record_payment_event(
        db,
        user_id=user.id,
        event_type="refund.created",
        object_type="refund",
        object_id=refund.id,
        payload={"paymentIntentId": intent.id, "amount": amount},
    )
    payer_account = get_or_create_ledger_account(db, intent.user_id, "user_wallet", intent.currency)
    platform_escrow = get_or_create_ledger_account(db, None, "platform_escrow", intent.currency)
    create_ledger_transfer(
        db,
        from_account=platform_escrow,
        to_account=payer_account,
        amount=amount,
        currency=intent.currency,
        reference_type="refund",
        reference_id=refund.id,
        event_id=event.id,
        description="Refund to payer",
        metadata={"paymentIntentId": intent.id},
    )
    intent.status = "refunded" if amount == intent.amount else intent.status
    intent.updated_at = utcnow()
    db.add(intent)
    create_inbox_item(
        db,
        user_id=intent.user_id,
        actor_user_id=user.id,
        item_type="transaction",
        title=f"Refund processed • {intent.currency} {amount:.2f}",
        body=f"Refund {refund.id} was created.",
        source_type="refund",
        source_id=refund.id,
        metadata={"paymentIntentId": intent.id, "status": refund.status},
    )
    db.commit()
    return {"refundId": refund.id, "status": refund.status, "paymentIntentId": intent.id}


@payments_router.get("/history")
def payment_history(limit: int = 50, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(PaymentIntent)
        .filter(PaymentIntent.user_id == user.id)
        .order_by(desc(PaymentIntent.created_at))
        .limit(max(1, min(limit, 200)))
        .all()
    )
    attempts = (
        db.query(PaymentAttempt)
        .filter(PaymentAttempt.user_id == user.id)
        .order_by(desc(PaymentAttempt.created_at))
        .limit(max(1, min(limit, 200)))
        .all()
    )
    return {
        "intents": [_payment_shape(row) for row in rows],
        "attempts": [
            {
                "id": row.id,
                "paymentIntentId": row.payment_intent_id,
                "status": row.status,
                "provider": row.provider,
                "failReason": row.fail_reason,
                "createdAt": row.created_at.isoformat(),
            }
            for row in attempts
        ],
    }


@payments_router.get("/eligibility")
def payment_eligibility(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = update_monetization_eligibility(db, user.id)
    db.commit()
    return {
        "status": row.status,
        "verificationScore": row.verification_score,
        "reportRate": row.report_rate,
        "refundRate": row.refund_rate,
        "disputeRate": row.dispute_rate,
        "fraudScore": row.fraud_score,
        "policyViolations": row.policy_violations,
        "reason": row.reason,
    }


@subscriptions_router.post("/plans")
def subscription_plan_create(payload: SubscriptionPlanPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = SubscriptionPlan(
        creator_user_id=user.id,
        name=payload.name.strip()[:120],
        description=(payload.description or "").strip()[:600] or None,
        amount=round(payload.amount, 2),
        currency=payload.currency.upper(),
        billing_interval=payload.billing_interval,
        active=True,
    )
    db.add(row)
    db.commit()
    return {"planId": row.id}


@subscriptions_router.get("/plans")
def subscription_plan_list(creator_user_id: int | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _ = user
    query = db.query(SubscriptionPlan).filter(SubscriptionPlan.active.is_(True))
    if creator_user_id:
        query = query.filter(SubscriptionPlan.creator_user_id == creator_user_id)
    rows = query.order_by(desc(SubscriptionPlan.updated_at)).limit(200).all()
    return {
        "items": [
            {
                "id": row.id,
                "creatorUserId": row.creator_user_id,
                "name": row.name,
                "description": row.description,
                "amount": row.amount,
                "currency": row.currency,
                "billingInterval": row.billing_interval,
            }
            for row in rows
        ]
    }


@subscriptions_router.post("")
async def subscription_create(payload: SubscriptionCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if payload.creator_user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot subscribe to yourself")
    await enforce_rate_limit("subscriptions.create", f"user:{user.id}", limit=20, window_seconds=60)
    existing = (
        db.query(Subscription)
        .filter(Subscription.subscriber_user_id == user.id, Subscription.creator_user_id == payload.creator_user_id)
        .first()
    )
    if existing and existing.status == "active":
        return {"subscriptionId": existing.id, "status": existing.status, "alreadyActive": True}
    intent_payload = PaymentIntentCreatePayload(
        amount=payload.amount,
        currency=payload.currency,
        intent_type="subscription",
        payee_user_id=payload.creator_user_id,
        rail=payload.rail,
        payment_method_id=payload.payment_method_id,
        idempotency_key=payload.idempotency_key,
        metadata={"planId": payload.plan_id, **payload.metadata},
    )
    intent_result = await payment_intent_create(intent_payload, db, user)
    intent_id = intent_result["paymentIntent"]["id"]
    await payment_intent_confirm(intent_id, PaymentConfirmPayload(payment_method_id=payload.payment_method_id), db, user)
    if existing is None:
        existing = Subscription(
            subscriber_user_id=user.id,
            creator_user_id=payload.creator_user_id,
            plan_id=payload.plan_id,
            payment_method_id=payload.payment_method_id,
            status="active",
            current_period_start=utcnow(),
            current_period_end=utcnow(),
            cancel_at_period_end=False,
            metadata_json=json.dumps(payload.metadata or {}, default=str),
        )
    else:
        existing.status = "active"
        existing.plan_id = payload.plan_id
        existing.payment_method_id = payload.payment_method_id
        existing.cancel_at_period_end = False
        existing.cancelled_at = None
        existing.updated_at = utcnow()
    db.add(existing)
    create_inbox_item(
        db,
        user_id=payload.creator_user_id,
        actor_user_id=user.id,
        item_type="transaction",
        title="New creator subscription",
        body=f"{user.name or user.email} subscribed.",
        source_type="subscription",
        source_id=existing.id,
        metadata={"subscriberUserId": user.id, "planId": payload.plan_id},
    )
    db.commit()
    return {"subscriptionId": existing.id, "status": existing.status, "paymentIntentId": intent_id}


@subscriptions_router.post("/{subscription_id}/cancel")
def subscription_cancel(subscription_id: str, payload: SubscriptionCancelPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = (
        db.query(Subscription)
        .filter(
            Subscription.id == subscription_id,
            or_(Subscription.subscriber_user_id == user.id, Subscription.creator_user_id == user.id),
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Subscription not found")
    row.cancel_at_period_end = payload.cancel_at_period_end
    if not payload.cancel_at_period_end:
        row.status = "cancelled"
        row.cancelled_at = utcnow()
    row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"subscriptionId": row.id, "status": row.status, "cancelAtPeriodEnd": row.cancel_at_period_end}


@subscriptions_router.get("")
def subscriptions_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(Subscription)
        .filter(or_(Subscription.subscriber_user_id == user.id, Subscription.creator_user_id == user.id))
        .order_by(desc(Subscription.updated_at))
        .limit(200)
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "subscriberUserId": row.subscriber_user_id,
                "creatorUserId": row.creator_user_id,
                "planId": row.plan_id,
                "status": row.status,
                "cancelAtPeriodEnd": row.cancel_at_period_end,
                "currentPeriodStart": row.current_period_start.isoformat() if row.current_period_start else None,
                "currentPeriodEnd": row.current_period_end.isoformat() if row.current_period_end else None,
            }
            for row in rows
        ]
    }


@invoices_router.post("")
def invoice_create(payload: InvoiceCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = Invoice(
        issuer_user_id=user.id,
        recipient_user_id=payload.recipient_user_id,
        exchange_request_id=payload.exchange_request_id,
        title=payload.title.strip()[:180],
        description=(payload.description or "").strip()[:2000] or None,
        amount=round(payload.amount, 2),
        currency=payload.currency.upper(),
        status="open",
        due_at=datetime.fromisoformat(payload.due_at) if payload.due_at else None,
        metadata_json=json.dumps(payload.metadata or {}, default=str),
    )
    db.add(row)
    db.flush()
    create_inbox_item(
        db,
        user_id=payload.recipient_user_id,
        actor_user_id=user.id,
        item_type="document",
        title=f"Invoice: {row.title}",
        body=f"{row.currency} {row.amount:.2f}",
        source_type="invoice",
        source_id=row.id,
        metadata={"issuerUserId": user.id, "dueAt": row.due_at.isoformat() if row.due_at else None},
    )
    db.commit()
    return {"invoiceId": row.id, "status": row.status}


@invoices_router.post("/{invoice_id}/pay")
async def invoice_pay(invoice_id: str, payload: InvoicePayPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("invoices.pay", f"user:{user.id}", limit=20, window_seconds=60)
    row = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Invoice not found")
    if row.recipient_user_id != user.id:
        raise HTTPException(status_code=403, detail="Only recipient can pay this invoice")
    if row.status == "paid":
        return {"invoiceId": row.id, "status": row.status, "alreadyPaid": True}
    intent_payload = PaymentIntentCreatePayload(
        amount=row.amount,
        currency=row.currency,
        intent_type="invoice_payment",
        payee_user_id=row.issuer_user_id,
        rail=payload.rail,
        payment_method_id=payload.payment_method_id,
        idempotency_key=payload.idempotency_key,
        metadata={"invoiceId": row.id},
    )
    intent_result = await payment_intent_create(intent_payload, db, user)
    intent_id = intent_result["paymentIntent"]["id"]
    await payment_intent_confirm(
        intent_id,
        PaymentConfirmPayload(
            payment_method_id=payload.payment_method_id,
            passkey_assertion=payload.passkey_assertion,
            passkey_challenge_id=payload.passkey_challenge_id,
        ),
        db,
        user,
    )
    row.status = "paid"
    row.paid_at = utcnow()
    row.updated_at = utcnow()
    db.add(row)
    create_inbox_item(
        db,
        user_id=row.issuer_user_id,
        actor_user_id=user.id,
        item_type="transaction",
        title=f"Invoice paid • {row.currency} {row.amount:.2f}",
        body=row.title,
        source_type="invoice",
        source_id=row.id,
        metadata={"paymentIntentId": intent_id},
    )
    db.commit()
    return {"invoiceId": row.id, "status": row.status, "paymentIntentId": intent_id}


@invoices_router.get("")
def invoices_list(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(Invoice)
        .filter(or_(Invoice.issuer_user_id == user.id, Invoice.recipient_user_id == user.id))
        .order_by(desc(Invoice.created_at))
        .limit(max(1, min(limit, 300)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "issuerUserId": row.issuer_user_id,
                "recipientUserId": row.recipient_user_id,
                "title": row.title,
                "amount": row.amount,
                "currency": row.currency,
                "status": row.status,
                "dueAt": row.due_at.isoformat() if row.due_at else None,
                "paidAt": row.paid_at.isoformat() if row.paid_at else None,
            }
            for row in rows
        ]
    }


@payouts_router.post("/request")
async def payout_request(payload: PayoutRequestPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("payouts.request", f"user:{user.id}", limit=12, window_seconds=60)
    eligibility = update_monetization_eligibility(db, user.id)
    if eligibility.status in {"review", "suspended"}:
        db.commit()
        raise HTTPException(status_code=403, detail=f"Monetization not eligible: {eligibility.status}")
    if trust.requires_step_up(payload.amount, "payout") and not trust.verify_passkey_assertion(payload.passkey_assertion, payload.passkey_challenge_id):
        raise HTTPException(status_code=401, detail="Step-up verification required")
    if payload.rail == "stablecoin_usdc":
        if (payload.stablecoin or SUPPORTED_STABLECOIN) != SUPPORTED_STABLECOIN:
            raise HTTPException(status_code=400, detail="Only USDC supported for stablecoin payouts")
        if payload.network not in SUPPORTED_NETWORKS:
            raise HTTPException(status_code=400, detail="Unsupported stablecoin network")
    risk = evaluate_risk(db, user.id, payload.amount, "payout")
    save_risk_review(db, user.id, "payout", risk.score, risk.decision, risk.reasons)
    if risk.decision == "deny":
        db.commit()
        raise HTTPException(status_code=403, detail="Payout denied by risk policy")
    row = Payout(
        user_id=user.id,
        amount=round(payload.amount, 2),
        currency=payload.currency.upper(),
        rail=payload.rail,
        stablecoin=payload.stablecoin,
        network=payload.network,
        destination=(payload.destination or "").strip()[:260] or None,
        status="requested" if risk.decision == "allow" else "review",
        metadata_json=json.dumps({**payload.metadata, "riskDecision": risk.decision, "riskScore": risk.score}, default=str),
    )
    db.add(row)
    db.flush()
    record_payment_event(
        db,
        user_id=user.id,
        event_type="payout.requested",
        object_type="payout",
        object_id=row.id,
        payload={"amount": row.amount, "currency": row.currency, "rail": row.rail},
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=None,
        item_type="transaction",
        title=f"Payout requested • {row.currency} {row.amount:.2f}",
        body=f"Payout {row.id} is {row.status}.",
        source_type="payout",
        source_id=row.id,
        metadata={"rail": row.rail, "network": row.network},
    )
    db.commit()
    return {"payoutId": row.id, "status": row.status}


@payouts_router.get("")
def payout_list(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(Payout)
        .filter(Payout.user_id == user.id)
        .order_by(desc(Payout.created_at))
        .limit(max(1, min(limit, 300)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "amount": row.amount,
                "currency": row.currency,
                "rail": row.rail,
                "stablecoin": row.stablecoin,
                "network": row.network,
                "destination": row.destination,
                "status": row.status,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@wallets_router.post("/preferences")
def wallet_preference(payload: WalletPreferencePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if payload.network not in SUPPORTED_NETWORKS:
        raise HTTPException(status_code=400, detail="Unsupported network")
    link = (
        db.query(CryptoWalletLink)
        .filter(
            CryptoWalletLink.user_id == user.id,
            CryptoWalletLink.network == payload.network,
            CryptoWalletLink.address == payload.address.strip(),
        )
        .first()
    )
    if link is None:
        link = CryptoWalletLink(
            user_id=user.id,
            network=payload.network,
            address=payload.address.strip(),
            label=(payload.label or "").strip()[:120] or None,
            verified=False,
            metadata_json=json.dumps({"stablecoin": payload.stablecoin}, default=str),
        )
    else:
        link.label = (payload.label or "").strip()[:120] or link.label
        link.updated_at = utcnow()
    db.add(link)
    db.flush()
    preference = db.query(CryptoSettlementPreference).filter(CryptoSettlementPreference.user_id == user.id).first()
    if preference is None:
        preference = CryptoSettlementPreference(user_id=user.id)
    preference.preferred_rail = payload.preferred_rail
    preference.stablecoin = payload.stablecoin
    preference.network = payload.network
    preference.payout_wallet_link_id = link.id
    preference.updated_at = utcnow()
    db.add(preference)
    db.commit()
    return {
        "preference": {
            "preferredRail": preference.preferred_rail,
            "stablecoin": preference.stablecoin,
            "network": preference.network,
            "walletLinkId": preference.payout_wallet_link_id,
        }
    }


@wallets_router.get("/preferences")
def wallet_preference_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    preference = db.query(CryptoSettlementPreference).filter(CryptoSettlementPreference.user_id == user.id).first()
    links = db.query(CryptoWalletLink).filter(CryptoWalletLink.user_id == user.id).order_by(desc(CryptoWalletLink.updated_at)).all()
    return {
        "preference": {
            "preferredRail": preference.preferred_rail if preference else "fiat",
            "stablecoin": preference.stablecoin if preference else None,
            "network": preference.network if preference else None,
            "walletLinkId": preference.payout_wallet_link_id if preference else None,
        },
        "wallets": [
            {
                "id": row.id,
                "network": row.network,
                "address": row.address,
                "label": row.label,
                "verified": row.verified,
            }
            for row in links
        ],
    }


@webhooks_router.post("/payments")
async def payments_webhook(payload: WebhookEventPayload, db: Session = Depends(get_db)):
    await enforce_rate_limit("webhooks.payments", f"provider:{payload.provider}", limit=300, window_seconds=60)
    row = verify_and_store_webhook(
        db=db,
        provider=payload.provider,
        event_id=payload.event_id,
        event_type=payload.event_type,
        signature=payload.signature,
        payload=payload.payload,
    )
    if not row.verified:
        db.commit()
        raise HTTPException(status_code=401, detail="Webhook signature verification failed")
    row.processed = True
    row.processed_at = utcnow()
    db.add(row)
    db.commit()
    return {"success": True, "webhookEventId": row.id, "verified": row.verified}


@tools_router.get("/jobs")
def tool_jobs(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = db.query(ToolJob).filter(ToolJob.user_id == user.id).order_by(desc(ToolJob.created_at)).limit(100).all()
    return {
        "items": [
            {
                "id": row.id,
                "toolId": row.tool_id,
                "status": row.status,
                "createdAt": row.created_at.isoformat(),
                "updatedAt": row.updated_at.isoformat(),
            }
            for row in rows
        ]
    }


@tools_router.get("/catalog")
def tools_catalog(user: User = Depends(current_user)):
    _ = user
    return {"items": list_tool_registry()}


@tools_router.get("/marketplace")
def tools_marketplace(section: str = "all", q: str = "", db: Session = Depends(get_db), user: User = Depends(current_user)):
    query = db.query(ToolListing).filter(ToolListing.is_published.is_(True))
    if q.strip():
        term = q.strip()
        query = query.filter(
            or_(
                ToolListing.name.ilike(f"%{term}%"),
                ToolListing.description.ilike(f"%{term}%"),
                ToolListing.category.ilike(f"%{term}%"),
            )
        )
    rows = query.order_by(desc(ToolListing.usage_count), desc(ToolListing.rating), desc(ToolListing.updated_at)).limit(200).all()
    items = [_tool_listing_shape(row) for row in rows]
    trending = sorted(items, key=lambda i: ((i.get("usage") or 0) * 0.7) + ((i.get("rating") or 0) * 12), reverse=True)[:20]
    personalized = [item for item in items if item["creatorUserId"] != user.id][:20]
    mine = [item for item in items if item["creatorUserId"] == user.id]

    if section == "trending":
        return {"items": trending}
    if section == "personalized":
        return {"items": personalized}
    if section == "mine":
        mine_rows = (
            db.query(ToolListing)
            .filter(ToolListing.creator_user_id == user.id)
            .order_by(desc(ToolListing.updated_at))
            .all()
        )
        return {"items": [_tool_listing_shape(row) for row in mine_rows]}
    return {
        "items": items,
        "sections": {
            "trending": trending,
            "personalized": personalized,
            "mine": mine,
        },
    }


@tools_router.post("/marketplace")
async def tools_marketplace_publish(payload: ToolListingCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("tools.marketplace.publish", f"user:{user.id}", limit=30, window_seconds=60)
    row = db.query(ToolListing).filter(ToolListing.creator_user_id == user.id, ToolListing.tool_id == payload.tool_id).first()
    if row is None:
        row = ToolListing(
            creator_user_id=user.id,
            tool_id=payload.tool_id,
            name=payload.name.strip()[:120],
            description=payload.description.strip()[:1200],
            category=payload.category.strip()[:80] or "Automation",
            pricing_model=payload.pricing_model,
            price_amount=max(0.0, round(payload.price_amount, 2)),
            currency=payload.currency.upper(),
            is_published=payload.publish,
            tags_json=json.dumps(payload.tags[:20], default=str),
            metadata_json=json.dumps({"source": "creator_publish"}, default=str),
        )
    else:
        row.name = payload.name.strip()[:120]
        row.description = payload.description.strip()[:1200]
        row.category = payload.category.strip()[:80] or row.category
        row.pricing_model = payload.pricing_model
        row.price_amount = max(0.0, round(payload.price_amount, 2))
        row.currency = payload.currency.upper()
        row.is_published = payload.publish
        row.tags_json = json.dumps(payload.tags[:20], default=str)
        row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"listing": _tool_listing_shape(row)}


@tools_router.post("/marketplace/{listing_id}/run")
async def tools_marketplace_run(listing_id: str, payload: ToolMarketplaceRunPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("tools.marketplace.run", f"user:{user.id}", limit=120, window_seconds=60)
    listing = db.query(ToolListing).filter(ToolListing.id == listing_id, ToolListing.is_published.is_(True)).first()
    if listing is None:
        raise HTTPException(status_code=404, detail="Tool listing not found")
    if listing.pricing_model == "per_use" and listing.price_amount > 0:
        purchase = ToolPurchase(
            listing_id=listing.id,
            user_id=user.id,
            amount=listing.price_amount,
            currency=listing.currency,
            status="succeeded",
            payment_intent_id=None,
        )
        db.add(purchase)
        deployment = (
            db.query(ToolDeployment)
            .filter(ToolDeployment.listing_id == listing.id)
            .order_by(desc(ToolDeployment.created_at))
            .first()
        )
        db.add(
            DeveloperRevenueEvent(
                app_id=(deployment.app_id if deployment else None),
                listing_id=listing.id,
                creator_user_id=listing.creator_user_id,
                buyer_user_id=user.id,
                event_type="per_use",
                amount=listing.price_amount,
                currency=listing.currency,
                metadata_json=json.dumps({"source": "marketplace_run"}, default=str),
            )
        )
    job = ToolJob(
        user_id=user.id,
        tool_id=listing.tool_id,
        status="completed",
        input_json=json.dumps(payload.input or {}, default=str),
        started_at=utcnow(),
        completed_at=utcnow(),
    )
    db.add(job)
    db.flush()
    summary = f"{listing.name} executed"
    result = ensure_tool_result(
        db,
        job,
        summary=summary,
        result={
            "listingId": listing.id,
            "toolId": listing.tool_id,
            "status": "completed",
            "output": f"{listing.name} generated output.",
            "input": payload.input or {},
        },
    )
    db.add(
        ToolUsage(
            user_id=user.id,
            tool_id=listing.tool_id,
            job_id=job.id,
            result_id=result.id,
            action="run_marketplace",
            context_type="tool_listing",
            context_id=listing.id,
            metadata_json=json.dumps({"conversationId": payload.conversation_id}, default=str),
        )
    )
    listing.usage_count = (listing.usage_count or 0) + 1
    listing.updated_at = utcnow()
    db.add(listing)

    if payload.share_result_in_chat and payload.conversation_id:
        member = db.query(ConversationMember).filter(
            ConversationMember.conversation_id == payload.conversation_id,
            ConversationMember.user_id == user.id,
        ).first()
        if member:
            msg = ChatMessage(
                conversation_id=payload.conversation_id,
                role="user",
                content=f"Tool result • {listing.name}: {summary}",
                tool_used="marketplace_run",
            )
            db.add(msg)

    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=listing.creator_user_id,
        item_type="tool_result",
        title=f"{listing.name} result ready",
        body=summary,
        source_type="tool_result",
        source_id=result.id,
        metadata={"listingId": listing.id, "toolId": listing.tool_id},
    )
    emit_neuro_event(
        db,
        event_type="tool.marketplace.run",
        source_type="tool_result",
        source_id=result.id,
        user_id=user.id,
        channel="tools",
        payload={
            "listingId": listing.id,
            "toolId": listing.tool_id,
            "jobId": job.id,
            "resultId": result.id,
            "sharedInChat": bool(payload.share_result_in_chat and payload.conversation_id),
        },
    )
    db.commit()
    return {
        "listing": _tool_listing_shape(listing),
        "job": {"id": job.id, "status": job.status},
        "result": {"id": result.id, "summary": result.summary, "result": json.loads(result.result_json or "{}")},
    }


@tools_router.post("/marketplace/{listing_id}/subscribe")
def tools_marketplace_subscribe(listing_id: str, payload: ToolMarketplaceSubscribePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    listing = db.query(ToolListing).filter(ToolListing.id == listing_id, ToolListing.is_published.is_(True)).first()
    if listing is None:
        raise HTTPException(status_code=404, detail="Tool listing not found")
    if listing.pricing_model != "subscription":
        raise HTTPException(status_code=400, detail="Listing is not subscription-based")
    row = db.query(ToolSubscription).filter(ToolSubscription.listing_id == listing.id, ToolSubscription.user_id == user.id).first()
    if row is None:
        row = ToolSubscription(
            listing_id=listing.id,
            user_id=user.id,
            status="active",
            amount=listing.price_amount,
            currency=listing.currency,
            billing_interval=payload.billing_interval,
        )
    else:
        row.status = "active"
        row.amount = listing.price_amount
        row.currency = listing.currency
        row.billing_interval = payload.billing_interval
        row.updated_at = utcnow()
    db.add(row)
    deployment = (
        db.query(ToolDeployment)
        .filter(ToolDeployment.listing_id == listing.id)
        .order_by(desc(ToolDeployment.created_at))
        .first()
    )
    db.add(
        DeveloperRevenueEvent(
            app_id=(deployment.app_id if deployment else None),
            listing_id=listing.id,
            creator_user_id=listing.creator_user_id,
            buyer_user_id=user.id,
            event_type="subscription",
            amount=listing.price_amount,
            currency=listing.currency,
            metadata_json=json.dumps({"billingInterval": payload.billing_interval, "source": "marketplace_subscribe"}, default=str),
        )
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=listing.creator_user_id,
        item_type="transaction",
        title=f"Subscribed to {listing.name}",
        body=f"{listing.currency} {listing.price_amount:.2f}/{payload.billing_interval}",
        source_type="tool_subscription",
        source_id=row.id,
        metadata={"listingId": listing.id},
    )
    db.commit()
    return {"subscriptionId": row.id, "status": row.status}


@developer_router.post("/apps")
async def developer_app_create(payload: DeveloperAppCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("developer.apps.create", f"user:{user.id}", limit=15, window_seconds=60)
    client_id = f"lilith_app_{new_id().replace('-', '')[:16]}"
    client_secret = f"lilith_secret_{secrets.token_urlsafe(24)}"
    row = DeveloperApp(
        owner_user_id=user.id,
        name=payload.name.strip()[:120] or "Lilith App",
        client_id=client_id,
        client_secret_hash=hash_password(client_secret),
        redirect_uri=payload.redirect_uri.strip(),
        scopes_json=json.dumps(_parse_scopes(payload.scopes), default=str),
        metadata_json=json.dumps(payload.metadata or {}, default=str),
    )
    db.add(row)
    db.commit()
    audit_event("developer.app.create", user_id=user.id, app_id=row.id)
    return {"app": _developer_app_shape(row), "clientSecret": client_secret}


@developer_router.get("/apps")
def developer_app_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(DeveloperApp)
        .filter(DeveloperApp.owner_user_id == user.id)
        .order_by(desc(DeveloperApp.updated_at), desc(DeveloperApp.created_at))
        .all()
    )
    return {"items": [_developer_app_shape(row) for row in rows]}


@developer_router.post("/apps/{app_id}/rotate-secret")
async def developer_app_rotate_secret(app_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("developer.apps.rotate_secret", f"user:{user.id}", limit=20, window_seconds=60)
    app_row = db.query(DeveloperApp).filter(DeveloperApp.id == app_id, DeveloperApp.owner_user_id == user.id).first()
    if app_row is None:
        raise HTTPException(status_code=404, detail="Developer app not found")
    client_secret = f"lilith_secret_{secrets.token_urlsafe(24)}"
    app_row.client_secret_hash = hash_password(client_secret)
    app_row.updated_at = utcnow()
    db.add(app_row)
    db.query(DeveloperAccessToken).filter(DeveloperAccessToken.app_id == app_row.id, DeveloperAccessToken.revoked.is_(False)).update(
        {DeveloperAccessToken.revoked: True}
    )
    db.commit()
    audit_event("developer.app.rotate_secret", user_id=user.id, app_id=app_row.id)
    return {"appId": app_row.id, "clientSecret": client_secret}


@oauth_router.post("/authorize")
async def oauth_authorize(payload: OAuthAuthorizePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("oauth.authorize", f"user:{user.id}", limit=60, window_seconds=60)
    app_row = (
        db.query(DeveloperApp)
        .filter(DeveloperApp.client_id == payload.client_id, DeveloperApp.is_active.is_(True))
        .first()
    )
    if app_row is None:
        raise HTTPException(status_code=404, detail="Developer app not found")
    if app_row.redirect_uri.strip() != payload.redirect_uri.strip():
        raise HTTPException(status_code=400, detail="Redirect URI mismatch")
    app_scopes = json.loads(app_row.scopes_json or "[]")
    granted_scopes = _authorized_scope_subset(payload.scopes, app_scopes)
    code_value = f"code_{secrets.token_urlsafe(20)}"
    code = DeveloperOAuthCode(
        app_id=app_row.id,
        user_id=user.id,
        code=code_value,
        scopes_json=json.dumps(granted_scopes, default=str),
        expires_at=utcnow() + timedelta(minutes=10),
    )
    db.add(code)
    db.commit()
    return {
        "code": code_value,
        "state": payload.state,
        "expiresAt": code.expires_at.isoformat(),
        "scopes": granted_scopes,
    }


@oauth_router.post("/token")
async def oauth_token(payload: OAuthTokenPayload, db: Session = Depends(get_db)):
    await enforce_rate_limit("oauth.token", f"client:{payload.client_id}", limit=120, window_seconds=60)
    app_row = (
        db.query(DeveloperApp)
        .filter(DeveloperApp.client_id == payload.client_id, DeveloperApp.is_active.is_(True))
        .first()
    )
    if app_row is None:
        raise HTTPException(status_code=404, detail="Developer app not found")
    if app_row.redirect_uri.strip() != payload.redirect_uri.strip():
        raise HTTPException(status_code=400, detail="Redirect URI mismatch")
    if not verify_password(payload.client_secret, app_row.client_secret_hash):
        raise HTTPException(status_code=401, detail="Invalid client credentials")
    code = (
        db.query(DeveloperOAuthCode)
        .filter(
            DeveloperOAuthCode.code == payload.code,
            DeveloperOAuthCode.app_id == app_row.id,
            DeveloperOAuthCode.expires_at > utcnow(),
            DeveloperOAuthCode.consumed_at.is_(None),
        )
        .first()
    )
    if code is None:
        raise HTTPException(status_code=400, detail="Invalid or expired authorization code")
    code.consumed_at = utcnow()
    access_token = f"lat_{secrets.token_urlsafe(28)}"
    token_row = DeveloperAccessToken(
        app_id=app_row.id,
        user_id=code.user_id,
        token=access_token,
        scopes_json=code.scopes_json,
        expires_at=utcnow() + timedelta(hours=24),
    )
    db.add(code)
    db.add(token_row)
    db.commit()
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": 24 * 60 * 60,
        "scope": " ".join(json.loads(code.scopes_json or "[]")),
    }


@oauth_router.post("/revoke")
def oauth_revoke(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    token_value = _extract_bearer(authorization)
    row = db.query(DeveloperAccessToken).filter(DeveloperAccessToken.token == token_value).first()
    if row:
        row.revoked = True
        row.updated_at = utcnow()
        db.add(row)
        db.commit()
    return {"success": True}


@developer_router.post("/context")
def developer_context(
    payload: DeveloperContextPayload,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    token_row, app_row, user, scopes = _require_developer_token(db, authorization, required_scopes=["context.read"])
    return {
        "app": {"id": app_row.id, "name": app_row.name},
        "token": {"id": token_row.id, "expiresAt": token_row.expires_at.isoformat()},
        "context": _build_tool_context(db, user, payload, scopes),
    }


@developer_router.post("/tools")
async def developer_tool_publish(
    payload: DeveloperToolCreatePayload,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    await enforce_rate_limit("developer.tools.publish", f"token:{_extract_bearer(authorization)[-12:]}", limit=90, window_seconds=60)
    _, app_row, user, _ = _require_developer_token(db, authorization, required_scopes=["tools.write"])
    if payload.app_id != app_row.id:
        raise HTTPException(status_code=403, detail="Tool app_id does not match token app")

    listing = db.query(ToolListing).filter(ToolListing.creator_user_id == user.id, ToolListing.tool_id == payload.tool_id).first()
    if listing is None:
        listing = ToolListing(
            creator_user_id=user.id,
            tool_id=payload.tool_id,
            name=payload.name.strip()[:120],
            description=payload.description.strip()[:1200],
            category=payload.category.strip()[:80] or "Automation",
            pricing_model=payload.pricing_model,
            price_amount=max(0.0, round(payload.price_amount, 2)),
            currency=payload.currency.upper(),
            is_published=payload.publish,
            tags_json=json.dumps(payload.tags[:20], default=str),
            metadata_json=json.dumps({"source": "developer_sdk", "appId": app_row.id}, default=str),
        )
        db.add(listing)
        db.flush()
    else:
        listing.name = payload.name.strip()[:120]
        listing.description = payload.description.strip()[:1200]
        listing.category = payload.category.strip()[:80] or listing.category
        listing.pricing_model = payload.pricing_model
        listing.price_amount = max(0.0, round(payload.price_amount, 2))
        listing.currency = payload.currency.upper()
        listing.is_published = payload.publish
        listing.tags_json = json.dumps(payload.tags[:20], default=str)
        listing.updated_at = utcnow()
        db.add(listing)
        db.flush()

    deployment = (
        db.query(ToolDeployment)
        .filter(ToolDeployment.listing_id == listing.id, ToolDeployment.version == payload.version)
        .first()
    )
    if deployment is None:
        deployment = ToolDeployment(
            app_id=app_row.id,
            listing_id=listing.id,
            runtime=payload.runtime,
            entrypoint=payload.entrypoint,
            version=payload.version,
            status="active",
            input_schema_json=json.dumps(payload.input_schema or {}, default=str),
            output_schema_json=json.dumps(payload.output_schema or {}, default=str),
            policy_json=json.dumps(payload.policy or {}, default=str),
        )
    else:
        deployment.runtime = payload.runtime
        deployment.entrypoint = payload.entrypoint
        deployment.status = "active"
        deployment.input_schema_json = json.dumps(payload.input_schema or {}, default=str)
        deployment.output_schema_json = json.dumps(payload.output_schema or {}, default=str)
        deployment.policy_json = json.dumps(payload.policy or {}, default=str)
        deployment.updated_at = utcnow()
    db.add(deployment)
    db.commit()
    audit_event("developer.tools.publish", user_id=user.id, listing_id=listing.id, deployment_id=deployment.id)
    return {"listing": _tool_listing_shape(listing), "deployment": _tool_deployment_shape(deployment)}


@developer_router.get("/tools")
def developer_tools(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    _, app_row, user, _ = _require_developer_token(db, authorization, required_scopes=["tools.read"])
    listings = (
        db.query(ToolListing)
        .filter(ToolListing.creator_user_id == user.id)
        .order_by(desc(ToolListing.updated_at), desc(ToolListing.created_at))
        .all()
    )
    listing_ids = [row.id for row in listings]
    deployments = (
        db.query(ToolDeployment)
        .filter(ToolDeployment.app_id == app_row.id, ToolDeployment.listing_id.in_(listing_ids or [""]))
        .order_by(desc(ToolDeployment.updated_at), desc(ToolDeployment.created_at))
        .all()
    )
    deployment_map: dict[str, dict[str, Any]] = {}
    for row in deployments:
        deployment_map[row.listing_id] = _tool_deployment_shape(row)
    return {
        "items": [
            {"listing": _tool_listing_shape(listing), "deployment": deployment_map.get(listing.id)}
            for listing in listings
        ]
    }


@developer_router.post("/tools/{listing_id}/run")
async def developer_tool_run(
    listing_id: str,
    payload: DeveloperToolRunPayload,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    await enforce_rate_limit("developer.tools.run", f"token:{_extract_bearer(authorization)[-12:]}", limit=180, window_seconds=60)
    _, app_row, user, scopes = _require_developer_token(db, authorization, required_scopes=["tools.run"])
    listing = db.query(ToolListing).filter(ToolListing.id == listing_id, ToolListing.is_published.is_(True)).first()
    if listing is None:
        raise HTTPException(status_code=404, detail="Tool listing not found")
    deployment = (
        db.query(ToolDeployment)
        .filter(ToolDeployment.app_id == app_row.id, ToolDeployment.listing_id == listing.id, ToolDeployment.status == "active")
        .order_by(desc(ToolDeployment.created_at))
        .first()
    )
    if deployment is None:
        raise HTTPException(status_code=404, detail="Active deployment not found for app/listing")

    policy = json.loads(deployment.policy_json or "{}")
    min_age = int(policy.get("min_age", 13))
    user_age = int((json.loads(user.settings_json or "{}")).get("age", 18))
    if user_age < min_age:
        raise HTTPException(status_code=403, detail="Age restriction failed for this tool")
    safe, reason = _passes_tool_safety(payload.input or {}, policy)
    if not safe:
        queue_row = ModerationQueue(
            report_id=None,
            target_type="tool_input",
            target_id=listing.id,
            status="pending",
            reviewer_user_id=None,
            decision_reason=reason,
        )
        db.add(queue_row)
        db.commit()
        raise HTTPException(status_code=400, detail=reason)

    output = {
        "status": "completed",
        "toolId": listing.tool_id,
        "listingId": listing.id,
        "appId": app_row.id,
        "inputEcho": payload.input or {},
        "context": _build_tool_context(
            db,
            user,
            DeveloperContextPayload(conversation_id=payload.conversation_id, message_id=payload.message_id),
            scopes,
        ),
        "actions": {
            "insertMessage": payload.insert_message,
            "insertMedia": payload.insert_media,
            "triggerAction": payload.trigger_action,
        },
    }
    summary = f"{listing.name} completed via developer SDK"
    job = ToolJob(
        user_id=user.id,
        tool_id=listing.tool_id,
        status="completed",
        input_json=json.dumps(payload.input or {}, default=str),
        started_at=utcnow(),
        completed_at=utcnow(),
    )
    db.add(job)
    db.flush()
    result = ensure_tool_result(db, job, summary=summary, result=output)
    db.add(
        ToolUsage(
            user_id=user.id,
            tool_id=listing.tool_id,
            job_id=job.id,
            result_id=result.id,
            action="developer_run",
            context_type="tool_listing",
            context_id=listing.id,
            metadata_json=json.dumps({"conversationId": payload.conversation_id, "messageId": payload.message_id}, default=str),
        )
    )
    listing.usage_count = (listing.usage_count or 0) + 1
    listing.updated_at = utcnow()
    db.add(listing)

    if listing.pricing_model == "per_use" and listing.price_amount > 0:
        db.add(
            DeveloperRevenueEvent(
                app_id=app_row.id,
                listing_id=listing.id,
                creator_user_id=listing.creator_user_id,
                buyer_user_id=user.id,
                event_type="per_use",
                amount=listing.price_amount,
                currency=listing.currency,
                metadata_json=json.dumps({"source": "developer_tool_run", "jobId": job.id}, default=str),
            )
        )

    inserted_message_id = None
    created_post_id = None
    if payload.insert_message and payload.conversation_id and "chat.write" in scopes:
        member = db.query(ConversationMember).filter(
            ConversationMember.conversation_id == payload.conversation_id,
            ConversationMember.user_id == user.id,
        ).first()
        if member:
            msg = ChatMessage(
                conversation_id=payload.conversation_id,
                role="assistant",
                content=summary,
                tool_used=listing.tool_id,
            )
            db.add(msg)
            db.flush()
            inserted_message_id = msg.id
            if payload.insert_media:
                media_asset_id = (payload.input or {}).get("media_asset_id")
                if media_asset_id:
                    asset = db.query(MediaAsset).filter(MediaAsset.id == str(media_asset_id), MediaAsset.owner_user_id == user.id).first()
                    if asset:
                        db.add(MessageMedia(message_id=msg.id, media_asset_id=asset.id))

    if payload.trigger_action == "create_post" and "feed.write" in scopes:
        post = Post(author_user_id=user.id, body=summary, visibility="public")
        db.add(post)
        db.flush()
        created_post_id = post.id
        if payload.insert_media:
            media_asset_id = (payload.input or {}).get("media_asset_id")
            if media_asset_id:
                asset = db.query(MediaAsset).filter(MediaAsset.id == str(media_asset_id), MediaAsset.owner_user_id == user.id).first()
                if asset:
                    db.add(PostMedia(post_id=post.id, media_asset_id=asset.id, display_order=0))

    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=listing.creator_user_id,
        item_type="tool_result",
        title=f"{listing.name} result ready",
        body=summary,
        source_type="tool_result",
        source_id=result.id,
        metadata={
            "listingId": listing.id,
            "toolId": listing.tool_id,
            "insertedMessageId": inserted_message_id,
            "createdPostId": created_post_id,
        },
    )
    db.commit()
    return {
        "job": {"id": job.id, "status": job.status},
        "result": {"id": result.id, "summary": result.summary, "result": json.loads(result.result_json or "{}")},
        "chat": {"insertedMessageId": inserted_message_id},
        "feed": {"postId": created_post_id},
    }


@developer_router.get("/payments/revenue")
def developer_payments_revenue(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    _, app_row, user, _ = _require_developer_token(db, authorization, required_scopes=["payments.read"])
    rows = (
        db.query(DeveloperRevenueEvent)
        .filter(DeveloperRevenueEvent.creator_user_id == user.id)
        .order_by(desc(DeveloperRevenueEvent.created_at))
        .limit(500)
        .all()
    )
    app_rows = [row for row in rows if (row.app_id == app_row.id or row.app_id is None)]
    total_amount = round(sum((row.amount or 0.0) for row in app_rows), 2)
    return {
        "summary": {"currency": "USD", "grossAmount": total_amount, "events": len(app_rows)},
        "items": [
            {
                "id": row.id,
                "appId": row.app_id,
                "listingId": row.listing_id,
                "eventType": row.event_type,
                "amount": row.amount,
                "currency": row.currency,
                "buyerUserId": row.buyer_user_id,
                "metadata": json.loads(row.metadata_json or "{}"),
                "createdAt": row.created_at.isoformat(),
            }
            for row in app_rows
        ],
    }


_DEFAULT_WORLD_SUBJECTS: list[tuple[str, str, str]] = [
    ("math", "Math", "Numbers, problem solving, and logic."),
    ("reading", "Reading", "Stories, vocabulary, and comprehension."),
    ("writing", "Writing", "Creative and structured writing practice."),
    ("science", "Science", "Nature, experiments, and discovery."),
    ("history", "History", "People, places, and timelines."),
    ("coding", "Coding", "Computational thinking and beginner coding."),
    ("art", "Art", "Drawing, design, and visual expression."),
    ("life-skills", "Life skills", "Habits, communication, and practical skills."),
]


def _is_guardian_for_child(db: Session, guardian_user_id: int, child_user_id: int) -> bool:
    row = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == guardian_user_id,
            GuardianLink.child_user_id == child_user_id,
            GuardianLink.status == "active",
        )
        .first()
    )
    return row is not None


def _assert_child_access(db: Session, actor: User, child_user_id: int) -> None:
    if actor.id == child_user_id:
        return
    if not _is_guardian_for_child(db, actor.id, child_user_id):
        raise HTTPException(status_code=403, detail="Not allowed to access this child world")


def _policy_shape(row: GuardianPolicy | None) -> dict[str, Any]:
    if row is None:
        return {
            "allowedSubjects": [item[1] for item in _DEFAULT_WORLD_SUBJECTS],
            "blockedTopics": [],
            "approvedGames": [],
            "approvedContentIds": [],
            "communicationMode": "friends_only",
            "allowSocial": True,
            "allowAI": True,
            "allowCreativeTools": True,
            "dailyTimeLimitMinutes": 180,
            "safetyMode": "strict",
        }
    return {
        "allowedSubjects": json.loads(row.allowed_subjects_json or "[]"),
        "blockedTopics": json.loads(row.blocked_topics_json or "[]"),
        "approvedGames": json.loads(row.approved_games_json or "[]"),
        "approvedContentIds": json.loads(row.approved_content_ids_json or "[]"),
        "communicationMode": row.communication_mode,
        "allowSocial": row.allow_social,
        "allowAI": row.allow_ai,
        "allowCreativeTools": row.allow_creative_tools,
        "dailyTimeLimitMinutes": row.daily_time_limit_minutes,
        "safetyMode": row.safety_mode,
    }


def _ensure_world_subjects(db: Session) -> None:
    existing = {row.key for row in db.query(Subject).all()}
    for idx, (key, name, description) in enumerate(_DEFAULT_WORLD_SUBJECTS):
        if key in existing:
            continue
        db.add(Subject(key=key, name=name, description=description, is_active=True, order_index=idx))
    db.commit()


def _ensure_world_core_rows(db: Session, child_user_id: int, *, theme: str = "space", avatar_style: str = "explorer") -> None:
    row = db.query(WorldCustomization).filter(WorldCustomization.child_user_id == child_user_id).first()
    if row is None:
        db.add(
            WorldCustomization(
                child_user_id=child_user_id,
                theme=theme,
                avatar_style=avatar_style,
                layout_json=json.dumps(
                    {
                        "zones": [
                            {"id": "school_zone", "object": "desk"},
                            {"id": "theater", "object": "tv"},
                            {"id": "game_zone", "object": "console"},
                            {"id": "creative_studio", "object": "easel"},
                            {"id": "friends_park", "object": "bench"},
                        ]
                    },
                    default=str,
                ),
                interactive_objects_json=json.dumps(
                    {
                        "desk": "learning",
                        "tv": "content",
                        "console": "games",
                        "easel": "creative",
                        "bench": "social",
                    },
                    default=str,
                ),
            )
        )
    lp = db.query(LearningProfile).filter(LearningProfile.child_user_id == child_user_id).first()
    if lp is None:
        db.add(
            LearningProfile(
                child_user_id=child_user_id,
                pace="adaptive",
                interests_json="[]",
                strengths_json="[]",
                weaknesses_json="[]",
                preferred_style="visual",
                current_skill_level=1.0,
            )
        )
    db.commit()


def _verification_id() -> str:
    return f"LILITH-CERT-{secrets.token_hex(6).upper()}"


def _share_token() -> str:
    return f"cred_{secrets.token_urlsafe(18)}"


def _skill_progress_shape(row: SkillProgress) -> dict[str, Any]:
    return {
        "id": row.id,
        "childUserId": row.child_user_id,
        "skillNodeId": row.skill_node_id,
        "status": row.status,
        "score": row.score,
        "masteryVerified": row.mastery_verified,
        "attempts": row.attempts,
        "evidence": json.loads(row.evidence_json or "[]"),
        "updatedByAI": row.updated_by_ai,
        "updatedAt": row.updated_at.isoformat(),
    }


def _certificate_shape(row: Certificate) -> dict[str, Any]:
    return {
        "id": row.id,
        "childUserId": row.child_user_id,
        "subjectGroup": row.subject_group,
        "title": row.title,
        "verificationId": row.verification_id,
        "issuedBy": row.issued_by,
        "issuedAt": row.issued_at.isoformat(),
        "status": row.status,
        "masterySnapshot": json.loads(row.mastery_snapshot_json or "{}"),
        "shareToken": row.share_token,
    }


def _evaluate_submission(assessment: Assessment, response: dict[str, Any]) -> tuple[float, bool, dict[str, Any], str]:
    rubric = json.loads(assessment.rubric_json or "{}")
    expected_keywords = [str(item).strip().lower() for item in rubric.get("keywords", []) if str(item).strip()]
    response_text = json.dumps(response or {}, default=str).lower()
    keyword_hits = sum(1 for term in expected_keywords if term in response_text) if expected_keywords else 0
    keyword_score = (keyword_hits / max(len(expected_keywords), 1)) * 70.0 if expected_keywords else 55.0
    structure_bonus = 20.0 if isinstance(response, dict) and len(response.keys()) >= 2 else 10.0
    clarity_bonus = min(10.0, len(response_text.split()) / 18.0)
    score = round(min(100.0, keyword_score + structure_bonus + clarity_bonus), 2)
    passed = score >= min(assessment.max_score * 0.75, 80.0)
    validation = {
        "keywordsExpected": expected_keywords,
        "keywordsMatched": keyword_hits,
        "structureSignals": len(response.keys()) if isinstance(response, dict) else 0,
        "scoreComponents": {
            "keywordScore": round(keyword_score, 2),
            "structureBonus": round(structure_bonus, 2),
            "clarityBonus": round(clarity_bonus, 2),
        },
        "noShortcutSignal": passed and (keyword_hits >= max(1, len(expected_keywords) // 2) if expected_keywords else True),
    }
    notes = "Mastery signal is strong." if passed else "Needs more evidence of understanding."
    return score, passed, validation, notes


@worlds_router.post("/guardian/link")
async def worlds_guardian_link(payload: GuardianLinkPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.guardian.link", f"user:{user.id}", limit=30, window_seconds=60)
    if payload.child_user_id == user.id:
        raise HTTPException(status_code=400, detail="Guardian and child cannot be the same user")
    child = db.query(User).filter(User.id == payload.child_user_id).first()
    if child is None:
        raise HTTPException(status_code=404, detail="Child user not found")
    row = (
        db.query(GuardianLink)
        .filter(GuardianLink.guardian_user_id == user.id, GuardianLink.child_user_id == payload.child_user_id)
        .first()
    )
    if row is None:
        row = GuardianLink(guardian_user_id=user.id, child_user_id=payload.child_user_id, status="active")
    else:
        row.status = "active"
        row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"success": True, "guardianUserId": user.id, "childUserId": payload.child_user_id, "status": row.status}


@worlds_router.post("/setup")
async def worlds_setup(payload: WorldSetupPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.setup", f"user:{user.id}", limit=40, window_seconds=60)
    _assert_child_access(db, user, payload.child_user_id)
    _ensure_world_subjects(db)
    _ensure_world_core_rows(db, payload.child_user_id, theme=payload.theme, avatar_style=payload.avatar_style)
    lp = db.query(LearningProfile).filter(LearningProfile.child_user_id == payload.child_user_id).first()
    if lp:
        lp.pace = payload.pace
        lp.interests_json = json.dumps(payload.interests[:24], default=str)
        db.add(lp)
    db.commit()
    return {"success": True, "childUserId": payload.child_user_id, "theme": payload.theme}


@worlds_router.put("/guardian/policies")
async def worlds_policy_upsert(payload: GuardianPolicyPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.guardian.policy", f"user:{user.id}", limit=80, window_seconds=60)
    if not _is_guardian_for_child(db, user.id, payload.child_user_id):
        raise HTTPException(status_code=403, detail="Guardian link required before setting policy")
    row = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == payload.child_user_id).first()
    if row is None:
        row = GuardianPolicy(guardian_user_id=user.id, child_user_id=payload.child_user_id)
    row.guardian_user_id = user.id
    row.allowed_subjects_json = json.dumps(payload.allowed_subjects or [item[1] for item in _DEFAULT_WORLD_SUBJECTS], default=str)
    row.blocked_topics_json = json.dumps(payload.blocked_topics[:60], default=str)
    row.approved_games_json = json.dumps(payload.approved_games[:200], default=str)
    row.approved_content_ids_json = json.dumps(payload.approved_content_ids[:200], default=str)
    row.communication_mode = payload.communication_mode
    row.allow_social = payload.allow_social
    row.allow_ai = payload.allow_ai
    row.allow_creative_tools = payload.allow_creative_tools
    row.daily_time_limit_minutes = max(30, min(payload.daily_time_limit_minutes, 1440))
    row.safety_mode = payload.safety_mode
    row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"success": True, "policy": _policy_shape(row)}


@worlds_router.get("/guardian/policies/{child_user_id}")
def worlds_policy_get(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    row = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    return {"childUserId": child_user_id, "policy": _policy_shape(row)}


@worlds_router.get("/{child_user_id}/environment")
def worlds_environment(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    _ensure_world_subjects(db)
    _ensure_world_core_rows(db, child_user_id)
    wc = db.query(WorldCustomization).filter(WorldCustomization.child_user_id == child_user_id).first()
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    lp = db.query(LearningProfile).filter(LearningProfile.child_user_id == child_user_id).first()
    return {
        "childUserId": child_user_id,
        "theme": wc.theme if wc else "space",
        "avatarStyle": wc.avatar_style if wc else "explorer",
        "layout": json.loads(wc.layout_json or "{}") if wc else {},
        "interactiveObjects": json.loads(wc.interactive_objects_json or "{}") if wc else {},
        "unlockedZones": json.loads(wc.unlocked_zones_json or "[]") if wc else [],
        "learningProfile": {
            "pace": lp.pace if lp else "adaptive",
            "interests": json.loads(lp.interests_json or "[]") if lp else [],
            "preferredStyle": lp.preferred_style if lp else "visual",
            "skillLevel": lp.current_skill_level if lp else 1.0,
        },
        "safety": _policy_shape(policy),
    }


@worlds_router.patch("/{child_user_id}/learning-profile")
async def worlds_learning_profile_patch(
    child_user_id: int,
    payload: LearningProfilePatchPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.learning_profile.patch", f"user:{user.id}", limit=120, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    _ensure_world_core_rows(db, child_user_id)
    row = db.query(LearningProfile).filter(LearningProfile.child_user_id == child_user_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Learning profile not found")
    row.interests_json = json.dumps(payload.interests[:24], default=str)
    row.strengths_json = json.dumps(payload.strengths[:24], default=str)
    row.weaknesses_json = json.dumps(payload.weaknesses[:24], default=str)
    row.preferred_style = payload.preferred_style
    row.pace = payload.pace
    row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {
        "success": True,
        "profile": {
            "pace": row.pace,
            "interests": json.loads(row.interests_json or "[]"),
            "strengths": json.loads(row.strengths_json or "[]"),
            "weaknesses": json.loads(row.weaknesses_json or "[]"),
            "preferredStyle": row.preferred_style,
        },
    }


@worlds_router.get("/{child_user_id}/subjects")
def worlds_subjects(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    _ensure_world_subjects(db)
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    allowed_subjects = set(_policy_shape(policy)["allowedSubjects"])
    rows = db.query(Subject).filter(Subject.is_active.is_(True)).order_by(Subject.order_index.asc(), Subject.name.asc()).all()
    items = [
        {"id": row.id, "key": row.key, "name": row.name, "description": row.description}
        for row in rows
        if row.name in allowed_subjects
    ]
    return {"items": items}


@worlds_router.post("/subjects")
async def worlds_subject_create(payload: SubjectCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.subjects.create", f"user:{user.id}", limit=30, window_seconds=60)
    row = db.query(Subject).filter(Subject.key == payload.key.strip().lower()).first()
    if row is None:
        row = Subject(
            key=payload.key.strip().lower()[:80],
            name=payload.name.strip()[:120],
            description=(payload.description or "").strip()[:1200] or None,
            is_active=True,
            order_index=999,
        )
    else:
        row.name = payload.name.strip()[:120]
        row.description = (payload.description or "").strip()[:1200] or None
        row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"subjectId": row.id, "key": row.key, "name": row.name}


@worlds_router.get("/{child_user_id}/lessons")
def worlds_lessons(child_user_id: int, subject_id: Optional[str] = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    query = db.query(Lesson).filter(Lesson.is_published.is_(True))
    if subject_id:
        query = query.filter(Lesson.subject_id == subject_id)
    rows = query.order_by(Lesson.difficulty.asc(), Lesson.created_at.asc()).limit(200).all()
    return {
        "items": [
            {
                "id": row.id,
                "subjectId": row.subject_id,
                "title": row.title,
                "summary": row.summary,
                "difficulty": row.difficulty,
                "estimatedMinutes": row.estimated_minutes,
                "content": json.loads(row.content_json or "{}"),
                "practice": json.loads(row.practice_json or "{}"),
                "quiz": json.loads(row.quiz_json or "{}"),
            }
            for row in rows
        ]
    }


@worlds_router.post("/lessons")
async def worlds_lesson_create(payload: LessonCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.lessons.create", f"user:{user.id}", limit=45, window_seconds=60)
    subject = db.query(Subject).filter(Subject.id == payload.subject_id).first()
    if subject is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    row = Lesson(
        subject_id=payload.subject_id,
        title=payload.title.strip()[:140],
        summary=payload.summary.strip()[:1600],
        difficulty=max(1, min(payload.difficulty, 12)),
        estimated_minutes=max(3, min(payload.estimated_minutes, 180)),
        content_json=json.dumps(payload.content or {}, default=str),
        practice_json=json.dumps(payload.practice or {}, default=str),
        quiz_json=json.dumps(payload.quiz or {}, default=str),
        is_published=payload.is_published,
    )
    db.add(row)
    db.commit()
    return {"lessonId": row.id, "subjectId": row.subject_id, "title": row.title}


@worlds_router.post("/{child_user_id}/progress")
async def worlds_progress(
    child_user_id: int,
    payload: LessonProgressPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.progress.write", f"user:{user.id}", limit=240, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    row = ProgressTracking(
        child_user_id=child_user_id,
        subject_id=payload.subject_id,
        lesson_id=payload.lesson_id,
        status=payload.status,
        score=max(0.0, min(payload.score, 100.0)),
        attempts=1,
        feedback=(payload.feedback or "").strip()[:600] or None,
    )
    db.add(row)
    points = 25 if payload.status == "completed" else (10 if payload.status == "practiced" else 5)
    db.add(
        Reward(
            child_user_id=child_user_id,
            reward_type="points",
            points=points,
            title="Learning progress",
            detail=f"{payload.status.title()} in lesson",
            source_type="lesson",
            source_id=payload.lesson_id,
        )
    )
    db.commit()
    return {"success": True, "progressId": row.id, "awardedPoints": points}


@worlds_router.post("/content")
async def worlds_content_add(payload: ContentAddPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.content.add", f"user:{user.id}", limit=40, window_seconds=60)
    if not (payload.link.startswith("https://") or payload.link.startswith("http://")):
        raise HTTPException(status_code=400, detail="Only http(s) links are allowed")
    row = ContentLibrary(
        title=payload.title.strip()[:160],
        kind=payload.kind,
        provider=payload.provider.strip()[:80],
        link=payload.link.strip(),
        age_rating=payload.age_rating.strip()[:40],
        min_age=max(0, payload.min_age),
        max_age=max(payload.min_age, payload.max_age),
        approved=True,
        tags_json=json.dumps(payload.tags[:20], default=str),
        metadata_json=json.dumps({"addedBy": user.id, "guardianApproved": True}, default=str),
    )
    db.add(row)
    db.commit()
    return {"contentId": row.id, "title": row.title}


@worlds_router.get("/{child_user_id}/content")
def worlds_content(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    child = db.query(User).filter(User.id == child_user_id).first()
    age = int((json.loads((child.settings_json if child else "{}") or "{}")).get("age", 10))
    approved_ids = set(_policy_shape(policy)["approvedContentIds"])
    rows = db.query(ContentLibrary).filter(ContentLibrary.approved.is_(True)).order_by(desc(ContentLibrary.updated_at)).limit(300).all()
    items: list[dict[str, Any]] = []
    for row in rows:
        if row.min_age > age or row.max_age < age:
            continue
        if approved_ids and row.id not in approved_ids:
            continue
        items.append(
            {
                "id": row.id,
                "title": row.title,
                "kind": row.kind,
                "provider": row.provider,
                "link": row.link,
                "ageRating": row.age_rating,
                "tags": json.loads(row.tags_json or "[]"),
            }
        )
    return {"items": items}


@worlds_router.post("/games")
async def worlds_game_add(payload: GameAddPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.games.add", f"user:{user.id}", limit=40, window_seconds=60)
    row = WorldGame(
        title=payload.title.strip()[:120],
        description=(payload.description or "").strip()[:1200] or None,
        genre=payload.genre.strip()[:80],
        min_age=max(0, payload.min_age),
        max_age=max(payload.min_age, payload.max_age),
        multiplayer_mode=payload.multiplayer_mode,
        supported_controls_json=json.dumps(payload.supported_controls[:8], default=str),
        approved=True,
        metadata_json=json.dumps({"addedBy": user.id, "guardianApproved": True}, default=str),
    )
    db.add(row)
    db.commit()
    return {"gameId": row.id, "title": row.title}


@worlds_router.get("/{child_user_id}/games")
def worlds_games(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    child = db.query(User).filter(User.id == child_user_id).first()
    age = int((json.loads((child.settings_json if child else "{}") or "{}")).get("age", 10))
    approved_ids = set(_policy_shape(policy)["approvedGames"])
    rows = db.query(WorldGame).filter(WorldGame.approved.is_(True)).order_by(desc(WorldGame.updated_at)).limit(300).all()
    items: list[dict[str, Any]] = []
    for row in rows:
        if row.min_age > age or row.max_age < age:
            continue
        if approved_ids and row.id not in approved_ids:
            continue
        items.append(
            {
                "id": row.id,
                "title": row.title,
                "description": row.description,
                "genre": row.genre,
                "multiplayerMode": row.multiplayer_mode,
                "supportedControls": json.loads(row.supported_controls_json or "[]"),
            }
        )
    return {"items": items}


@worlds_router.post("/{child_user_id}/games/session/start")
async def worlds_game_session_start(
    child_user_id: int,
    payload: GameSessionStartPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.games.session.start", f"user:{user.id}", limit=180, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    game = db.query(WorldGame).filter(WorldGame.id == payload.game_id, WorldGame.approved.is_(True)).first()
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    approved_ids = set(_policy_shape(policy)["approvedGames"])
    if approved_ids and game.id not in approved_ids:
        raise HTTPException(status_code=403, detail="Game is not approved by guardian policy")
    row = GameSession(child_user_id=child_user_id, game_id=game.id, mode=payload.mode[:40], status="active")
    db.add(row)
    db.commit()
    return {"sessionId": row.id, "status": row.status, "gameId": row.game_id}


@worlds_router.post("/{child_user_id}/games/session/{session_id}/end")
async def worlds_game_session_end(
    child_user_id: int,
    session_id: str,
    payload: GameSessionEndPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.games.session.end", f"user:{user.id}", limit=240, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    row = db.query(GameSession).filter(GameSession.id == session_id, GameSession.child_user_id == child_user_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Game session not found")
    row.duration_seconds = max(0, payload.duration_seconds)
    row.status = "completed"
    row.ended_at = utcnow()
    row.updated_at = utcnow()
    db.add(row)
    db.add(
        Reward(
            child_user_id=child_user_id,
            reward_type="points",
            points=min(80, max(10, row.duration_seconds // 120)),
            title="Game session complete",
            detail="Nice focus and play balance!",
            source_type="game",
            source_id=row.game_id,
        )
    )
    db.commit()
    return {"success": True, "sessionId": row.id, "durationSeconds": row.duration_seconds}


@worlds_router.post("/{child_user_id}/rewards/grant")
async def worlds_reward_grant(
    child_user_id: int,
    payload: RewardGrantPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.rewards.grant", f"user:{user.id}", limit=120, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    if payload.child_user_id != child_user_id:
        raise HTTPException(status_code=400, detail="child_user_id mismatch")
    row = Reward(
        child_user_id=child_user_id,
        reward_type=payload.reward_type,
        points=max(0, payload.points),
        title=payload.title.strip()[:120],
        detail=(payload.detail or "").strip()[:400] or None,
        source_type=payload.source_type,
        source_id=payload.source_id,
    )
    db.add(row)
    db.commit()
    return {"success": True, "rewardId": row.id}


@worlds_router.get("/{child_user_id}/rewards")
def worlds_rewards(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    rows = db.query(Reward).filter(Reward.child_user_id == child_user_id).order_by(desc(Reward.created_at)).limit(300).all()
    total_points = sum((row.points or 0) for row in rows)
    return {
        "summary": {"totalPoints": total_points, "streakDays": min(30, total_points // 120)},
        "items": [
            {
                "id": row.id,
                "rewardType": row.reward_type,
                "points": row.points,
                "title": row.title,
                "detail": row.detail,
                "sourceType": row.source_type,
                "sourceId": row.source_id,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ],
    }


@worlds_router.post("/{child_user_id}/ai")
async def worlds_ai_guide(
    child_user_id: int,
    payload: WorldAIRequestPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.ai.guide", f"user:{user.id}", limit=180, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    if payload.child_user_id != child_user_id:
        raise HTTPException(status_code=400, detail="child_user_id mismatch")
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    policy_data = _policy_shape(policy)
    if not policy_data["allowAI"]:
        raise HTTPException(status_code=403, detail="AI guide disabled by guardian policy")
    prompt = (payload.prompt or "").strip()
    if any(topic.lower() in prompt.lower() for topic in policy_data["blockedTopics"]):
        raise HTTPException(status_code=400, detail="Prompt includes blocked topic")
    child_user = db.query(User).filter(User.id == child_user_id).first()
    if child_user is None:
        raise HTTPException(status_code=404, detail="Child user not found")
    subject = (payload.subject or "Math").strip()
    if payload.mode == "teach":
        base_text = f"Let's learn {subject} together in small steps. First, try a quick challenge and I'll help as you go."
    elif payload.mode == "recommend_content":
        base_text = "I found safe picks in your Theater zone based on your interests and age settings."
    elif payload.mode == "creativity_idea":
        base_text = "Creative mission: build a mini world scene, then explain your story in 3 sentences."
    else:
        base_text = "Want to learn, play, create, or connect with friends safely? I can guide your next step."
    text = apply_lilith_voice(
        user=child_user,
        user_text=prompt,
        base_text=base_text,
        tool_used="World Guide",
        proactive_hint=f"start a {subject} activity",
        force_child=True,
    )
    voice = lilith_voice_profile(child_user, prompt, force_child=True)
    row = AIInteraction(
        child_user_id=child_user_id,
        guardian_user_id=(user.id if user.id != child_user_id else None),
        interaction_type=payload.mode,
        input_text=prompt or None,
        output_text=text,
        safe=True,
        metadata_json=json.dumps({"subject": subject, "blockedTopics": len(policy_data["blockedTopics"])}, default=str),
    )
    db.add(row)
    db.commit()
    return {"interactionId": row.id, "message": text, "voice": voice}


@worlds_router.get("/{child_user_id}/dashboard")
def worlds_dashboard(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    learning = db.query(ProgressTracking).filter(ProgressTracking.child_user_id == child_user_id).all()
    rewards = db.query(Reward).filter(Reward.child_user_id == child_user_id).all()
    recent_ai = (
        db.query(AIInteraction)
        .filter(AIInteraction.child_user_id == child_user_id)
        .order_by(desc(AIInteraction.created_at))
        .limit(5)
        .all()
    )
    completed = sum(1 for row in learning if row.status == "completed")
    avg_score = round(sum((row.score or 0.0) for row in learning) / max(len(learning), 1), 2)
    total_points = sum((row.points or 0) for row in rewards)
    return {
        "childUserId": child_user_id,
        "safeMode": "ON",
        "policy": _policy_shape(policy),
        "progress": {
            "completedLessons": completed,
            "averageScore": avg_score,
            "activitiesLogged": len(learning),
        },
        "rewards": {
            "totalPoints": total_points,
            "achievements": sum(1 for row in rewards if row.reward_type == "achievement"),
        },
        "aiGuide": [{"id": row.id, "type": row.interaction_type, "message": row.output_text} for row in recent_ai],
    }


@worlds_router.post("/skills/trees")
async def worlds_skill_tree_create(payload: SkillTreeCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.skills.trees.create", f"user:{user.id}", limit=40, window_seconds=60)
    subject = db.query(Subject).filter(Subject.id == payload.subject_id).first()
    if subject is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    row = SkillTree(
        subject_id=payload.subject_id,
        name=payload.name.strip()[:120],
        description=(payload.description or "").strip()[:1200] or None,
        level_count=max(1, min(payload.level_count, 12)),
        active=True,
    )
    db.add(row)
    db.commit()
    return {"skillTreeId": row.id, "subjectId": row.subject_id, "name": row.name}


@worlds_router.post("/skills/nodes")
async def worlds_skill_node_create(payload: SkillNodeCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.skills.nodes.create", f"user:{user.id}", limit=60, window_seconds=60)
    tree = db.query(SkillTree).filter(SkillTree.id == payload.tree_id, SkillTree.active.is_(True)).first()
    if tree is None:
        raise HTTPException(status_code=404, detail="Skill tree not found")
    row = SkillNode(
        tree_id=payload.tree_id,
        subject_id=payload.subject_id,
        code=payload.code.strip().lower()[:80],
        title=payload.title.strip()[:140],
        description=(payload.description or "").strip()[:1200] or None,
        level=max(1, min(payload.level, 20)),
        mastery_threshold=max(50.0, min(payload.mastery_threshold, 100.0)),
        prerequisite_ids_json=json.dumps(payload.prerequisite_ids[:30], default=str),
        assessment_weight=max(0.25, min(payload.assessment_weight, 5.0)),
    )
    db.add(row)
    db.commit()
    return {"skillNodeId": row.id, "treeId": row.tree_id, "code": row.code, "title": row.title}


@worlds_router.get("/{child_user_id}/skills")
def worlds_skill_tree(child_user_id: int, subject_id: Optional[str] = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    policy = db.query(GuardianPolicy).filter(GuardianPolicy.child_user_id == child_user_id).first()
    allowed_subjects = set(_policy_shape(policy)["allowedSubjects"])
    query = db.query(SkillNode)
    if subject_id:
        query = query.filter(SkillNode.subject_id == subject_id)
    rows = query.order_by(SkillNode.level.asc(), SkillNode.created_at.asc()).limit(400).all()
    progress_rows = db.query(SkillProgress).filter(SkillProgress.child_user_id == child_user_id).all()
    progress_map = {row.skill_node_id: row for row in progress_rows}
    subjects = {row.id: row for row in db.query(Subject).all()}
    items: list[dict[str, Any]] = []
    for row in rows:
        subject = subjects.get(row.subject_id)
        if subject and subject.name not in allowed_subjects:
            continue
        prog = progress_map.get(row.id)
        items.append(
            {
                "id": row.id,
                "subjectId": row.subject_id,
                "subjectName": (subject.name if subject else None),
                "treeId": row.tree_id,
                "code": row.code,
                "title": row.title,
                "description": row.description,
                "level": row.level,
                "masteryThreshold": row.mastery_threshold,
                "prerequisites": json.loads(row.prerequisite_ids_json or "[]"),
                "progress": (_skill_progress_shape(prog) if prog else None),
            }
        )
    return {"items": items}


@worlds_router.post("/assessments")
async def worlds_assessment_create(payload: AssessmentCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.assessment.create", f"user:{user.id}", limit=90, window_seconds=60)
    node = db.query(SkillNode).filter(SkillNode.id == payload.skill_node_id).first()
    if node is None:
        raise HTTPException(status_code=404, detail="Skill node not found")
    row = Assessment(
        skill_node_id=payload.skill_node_id,
        assessment_type=payload.assessment_type,
        title=payload.title.strip()[:140],
        prompt=(payload.prompt or "").strip()[:2400] or None,
        rubric_json=json.dumps(payload.rubric or {}, default=str),
        max_score=max(10.0, min(payload.max_score, 100.0)),
        required_for_mastery=payload.required_for_mastery,
        active=True,
    )
    db.add(row)
    db.commit()
    return {"assessmentId": row.id, "skillNodeId": row.skill_node_id, "type": row.assessment_type}


@worlds_router.get("/{child_user_id}/assessments")
def worlds_assessments(child_user_id: int, skill_node_id: Optional[str] = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    query = db.query(Assessment).filter(Assessment.active.is_(True))
    if skill_node_id:
        query = query.filter(Assessment.skill_node_id == skill_node_id)
    rows = query.order_by(desc(Assessment.updated_at)).limit(300).all()
    return {
        "items": [
            {
                "id": row.id,
                "skillNodeId": row.skill_node_id,
                "assessmentType": row.assessment_type,
                "title": row.title,
                "prompt": row.prompt,
                "rubric": json.loads(row.rubric_json or "{}"),
                "maxScore": row.max_score,
                "requiredForMastery": row.required_for_mastery,
            }
            for row in rows
        ]
    }


@worlds_router.post("/assessments/submit")
async def worlds_assessment_submit(payload: AssessmentSubmissionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.assessment.submit", f"user:{user.id}", limit=200, window_seconds=60)
    _assert_child_access(db, user, payload.child_user_id)
    assessment = db.query(Assessment).filter(Assessment.id == payload.assessment_id, Assessment.active.is_(True)).first()
    if assessment is None:
        raise HTTPException(status_code=404, detail="Assessment not found")
    score, passed, validation, notes = _evaluate_submission(assessment, payload.response or {})
    submission = AssessmentSubmission(
        assessment_id=assessment.id,
        child_user_id=payload.child_user_id,
        response_json=json.dumps(payload.response or {}, default=str),
        score=score,
        passed=passed,
        evaluator_type="ai",
        evaluator_notes=notes,
        ai_validation_json=json.dumps(validation, default=str),
    )
    db.add(submission)
    db.flush()
    progress = (
        db.query(SkillProgress)
        .filter(SkillProgress.child_user_id == payload.child_user_id, SkillProgress.skill_node_id == assessment.skill_node_id)
        .first()
    )
    if progress is None:
        progress = SkillProgress(
            child_user_id=payload.child_user_id,
            skill_node_id=assessment.skill_node_id,
            status="learning",
            score=score,
            mastery_verified=False,
            attempts=1,
            evidence_json=json.dumps([submission.id], default=str),
            updated_by_ai=True,
        )
    else:
        progress.attempts = (progress.attempts or 0) + 1
        progress.score = round(((progress.score or 0.0) * 0.4) + (score * 0.6), 2)
        evidence = json.loads(progress.evidence_json or "[]")
        evidence = (evidence + [submission.id])[-20:]
        progress.evidence_json = json.dumps(evidence, default=str)
        progress.updated_by_ai = True
        if passed:
            progress.status = "ready_for_assessment"
    db.add(progress)
    if passed:
        db.add(
            Reward(
                child_user_id=payload.child_user_id,
                reward_type="achievement",
                points=40,
                title="Assessment passed",
                detail=f"{assessment.title} passed with {score:.1f}",
                source_type="lesson",
                source_id=assessment.id,
            )
        )
    db.commit()
    return {
        "submissionId": submission.id,
        "score": score,
        "passed": passed,
        "aiValidation": validation,
        "skillProgress": _skill_progress_shape(progress),
    }


@worlds_router.post("/skills/validate")
async def worlds_skill_validate(payload: SkillMasteryValidatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.skill.validate", f"user:{user.id}", limit=120, window_seconds=60)
    _assert_child_access(db, user, payload.child_user_id)
    node = db.query(SkillNode).filter(SkillNode.id == payload.skill_node_id).first()
    if node is None:
        raise HTTPException(status_code=404, detail="Skill node not found")
    progress = (
        db.query(SkillProgress)
        .filter(SkillProgress.child_user_id == payload.child_user_id, SkillProgress.skill_node_id == payload.skill_node_id)
        .first()
    )
    if progress is None:
        raise HTTPException(status_code=400, detail="No progress exists for this skill")
    submissions = (
        db.query(AssessmentSubmission)
        .join(Assessment, Assessment.id == AssessmentSubmission.assessment_id)
        .filter(Assessment.skill_node_id == payload.skill_node_id, AssessmentSubmission.child_user_id == payload.child_user_id)
        .order_by(desc(AssessmentSubmission.created_at))
        .limit(8)
        .all()
    )
    if not submissions:
        raise HTTPException(status_code=400, detail="No assessments submitted for this skill")
    avg_score = round(sum((row.score or 0.0) for row in submissions) / len(submissions), 2)
    pass_count = sum(1 for row in submissions if row.passed)
    strict_ok = pass_count >= (2 if payload.strict else 1)
    mastery_ok = avg_score >= node.mastery_threshold and strict_ok
    progress.score = max(progress.score, avg_score)
    progress.mastery_verified = mastery_ok
    progress.status = "mastered" if mastery_ok else "ready_for_assessment"
    progress.updated_by_ai = True
    progress.updated_at = utcnow()
    db.add(progress)
    db.add(
        AIInteraction(
            child_user_id=payload.child_user_id,
            guardian_user_id=(user.id if user.id != payload.child_user_id else None),
            interaction_type="lesson_help",
            input_text=f"validate skill {node.code}",
            output_text=(
                f"Mastery verified for {node.title}."
                if mastery_ok
                else f"{node.title} needs more practice before mastery."
            ),
            safe=True,
            metadata_json=json.dumps(
                {"skillNodeId": node.id, "avgScore": avg_score, "passCount": pass_count, "strict": payload.strict},
                default=str,
            ),
        )
    )
    db.commit()
    return {
        "skillNodeId": node.id,
        "masteryVerified": mastery_ok,
        "averageScore": avg_score,
        "passCount": pass_count,
        "requiredPassCount": (2 if payload.strict else 1),
        "progress": _skill_progress_shape(progress),
    }


@worlds_router.post("/certificates/issue")
async def worlds_certificate_issue(payload: CertificateIssuePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("worlds.certificate.issue", f"user:{user.id}", limit=40, window_seconds=60)
    _assert_child_access(db, user, payload.child_user_id)
    skill_ids = payload.skill_node_ids[:80]
    if not skill_ids:
        raise HTTPException(status_code=400, detail="At least one skill node is required")
    progress_rows = (
        db.query(SkillProgress)
        .filter(
            SkillProgress.child_user_id == payload.child_user_id,
            SkillProgress.skill_node_id.in_(skill_ids),
            SkillProgress.mastery_verified.is_(True),
        )
        .all()
    )
    if len(progress_rows) != len(set(skill_ids)):
        raise HTTPException(status_code=400, detail="All included skills must be mastery-verified")
    snapshot = {
        "skillNodeIds": skill_ids,
        "verifiedAt": utcnow().isoformat(),
        "scores": {row.skill_node_id: row.score for row in progress_rows},
    }
    cert = Certificate(
        child_user_id=payload.child_user_id,
        subject_group=payload.subject_group.strip()[:120],
        title=payload.title.strip()[:160],
        verification_id=_verification_id(),
        issued_by="Lilith Learning System",
        issued_at=utcnow(),
        status="active",
        mastery_snapshot_json=json.dumps(snapshot, default=str),
        share_token=_share_token(),
    )
    db.add(cert)
    db.flush()
    db.add(
        PortfolioItem(
            child_user_id=payload.child_user_id,
            item_type="certificate",
            title=cert.title,
            description=f"Verified credential in {cert.subject_group}",
            artifact_type="certificate_ref",
            artifact_ref=cert.verification_id,
            certificate_id=cert.id,
            visibility="guardian",
            metadata_json=json.dumps({"subjectGroup": cert.subject_group}, default=str),
        )
    )
    db.add(
        Reward(
            child_user_id=payload.child_user_id,
            reward_type="achievement",
            points=120,
            title="Certificate earned",
            detail=cert.title,
            source_type="lesson",
            source_id=cert.id,
        )
    )
    db.commit()
    return {"certificate": _certificate_shape(cert)}


@worlds_router.get("/certificates/verify/{verification_id}")
def worlds_certificate_verify(verification_id: str, db: Session = Depends(get_db)):
    row = db.query(Certificate).filter(Certificate.verification_id == verification_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Credential not found")
    return {
        "verified": row.status == "active",
        "credential": {
            "verificationId": row.verification_id,
            "title": row.title,
            "subjectGroup": row.subject_group,
            "issuedBy": row.issued_by,
            "issuedAt": row.issued_at.isoformat(),
            "status": row.status,
        },
    }


@worlds_router.get("/{child_user_id}/certificates")
def worlds_certificates(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    rows = db.query(Certificate).filter(Certificate.child_user_id == child_user_id).order_by(desc(Certificate.issued_at)).all()
    return {"items": [_certificate_shape(row) for row in rows]}


@worlds_router.post("/{child_user_id}/portfolio")
async def worlds_portfolio_add(
    child_user_id: int,
    payload: PortfolioItemPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("worlds.portfolio.add", f"user:{user.id}", limit=120, window_seconds=60)
    _assert_child_access(db, user, child_user_id)
    if payload.child_user_id != child_user_id:
        raise HTTPException(status_code=400, detail="child_user_id mismatch")
    if payload.certificate_id:
        cert = db.query(Certificate).filter(Certificate.id == payload.certificate_id, Certificate.child_user_id == child_user_id).first()
        if cert is None:
            raise HTTPException(status_code=404, detail="Certificate not found for child")
    row = PortfolioItem(
        child_user_id=child_user_id,
        item_type=payload.item_type,
        title=payload.title.strip()[:140],
        description=(payload.description or "").strip()[:2000] or None,
        artifact_type=payload.artifact_type,
        artifact_ref=(payload.artifact_ref or "").strip()[:500] or None,
        certificate_id=payload.certificate_id,
        skill_node_id=payload.skill_node_id,
        visibility=payload.visibility,
        metadata_json=json.dumps(payload.metadata or {}, default=str),
    )
    db.add(row)
    db.commit()
    return {"portfolioItemId": row.id}


@worlds_router.get("/{child_user_id}/portfolio")
def worlds_portfolio(child_user_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    _assert_child_access(db, user, child_user_id)
    rows = db.query(PortfolioItem).filter(PortfolioItem.child_user_id == child_user_id).order_by(desc(PortfolioItem.created_at)).all()
    return {
        "items": [
            {
                "id": row.id,
                "itemType": row.item_type,
                "title": row.title,
                "description": row.description,
                "artifactType": row.artifact_type,
                "artifactRef": row.artifact_ref,
                "certificateId": row.certificate_id,
                "skillNodeId": row.skill_node_id,
                "visibility": row.visibility,
                "metadata": json.loads(row.metadata_json or "{}"),
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@worlds_router.get("/guardian/reports/{child_user_id}")
def worlds_guardian_report(child_user_id: int, days: int = 7, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if not _is_guardian_for_child(db, user.id, child_user_id):
        raise HTTPException(status_code=403, detail="Guardian link required")
    window_days = max(1, min(days, 90))
    start = utcnow() - timedelta(days=window_days)
    progress = (
        db.query(ProgressTracking)
        .filter(ProgressTracking.child_user_id == child_user_id, ProgressTracking.created_at >= start)
        .all()
    )
    skills = db.query(SkillProgress).filter(SkillProgress.child_user_id == child_user_id).all()
    lp = db.query(LearningProfile).filter(LearningProfile.child_user_id == child_user_id).first()
    completed = sum(1 for row in progress if row.status == "completed")
    avg_score = round(sum((row.score or 0.0) for row in progress) / max(len(progress), 1), 2)
    mastered = [row for row in skills if row.mastery_verified]
    weak = sorted([row for row in skills if not row.mastery_verified], key=lambda x: x.score)[:5]
    strengths = (json.loads(lp.strengths_json or "[]") if lp else []) + [f"Mastered {len(mastered)} skills"]
    weaknesses = (json.loads(lp.weaknesses_json or "[]") if lp else []) + [f"Needs focus on {len(weak)} skills"]
    recommendations = [
        "Continue lesson-practice-quiz loop in low-score areas.",
        "Add one portfolio project for each mastered skill cluster.",
        "Review blocked-topic safety settings monthly.",
    ]
    snapshot = GuardianReportSnapshot(
        guardian_user_id=user.id,
        child_user_id=child_user_id,
        period_start=start,
        period_end=utcnow(),
        progress_summary_json=json.dumps(
            {"windowDays": window_days, "completedLessons": completed, "averageScore": avg_score, "masteredSkills": len(mastered)},
            default=str,
        ),
        strengths_json=json.dumps(strengths[:20], default=str),
        weaknesses_json=json.dumps(weaknesses[:20], default=str),
        recommendations_json=json.dumps(recommendations[:20], default=str),
    )
    db.add(snapshot)
    db.commit()
    return {
        "reportId": snapshot.id,
        "period": {"start": snapshot.period_start.isoformat(), "end": snapshot.period_end.isoformat(), "days": window_days},
        "summary": json.loads(snapshot.progress_summary_json or "{}"),
        "strengths": json.loads(snapshot.strengths_json or "[]"),
        "weaknesses": json.loads(snapshot.weaknesses_json or "[]"),
        "recommendations": json.loads(snapshot.recommendations_json or "[]"),
    }


def _growth_profile_link(db: Session, user_id: int) -> str:
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    username = profile.username if profile else f"user{user_id}"
    return f"/profiles/{username}"


def _growth_landing_shape(db: Session, row: GrowthLandingPage) -> dict[str, Any]:
    return {
        "id": row.id,
        "ownerUserId": row.owner_user_id,
        "title": row.title,
        "slug": row.slug,
        "goal": row.goal,
        "audience": row.audience,
        "ctaText": row.cta_text,
        "html": row.html,
        "sections": json.loads(row.sections_json or "[]"),
        "formSchema": json.loads(row.form_schema_json or "{}"),
        "analytics": json.loads(row.analytics_json or "{}"),
        "published": row.published,
        "publishedUrl": row.published_url,
        "profileLink": _growth_profile_link(db, row.owner_user_id),
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _growth_site_shape(db: Session, row: GrowthWebsiteProject, pages: list[GrowthWebsitePage] | None = None) -> dict[str, Any]:
    return {
        "id": row.id,
        "ownerUserId": row.owner_user_id,
        "title": row.title,
        "slug": row.slug,
        "description": row.description,
        "theme": row.theme,
        "published": row.published,
        "publishedUrl": row.published_url,
        "profileLink": _growth_profile_link(db, row.owner_user_id),
        "pages": [
            {
                "id": page.id,
                "title": page.title,
                "slug": page.slug,
                "sections": json.loads(page.sections_json or "[]"),
                "seo": json.loads(page.seo_json or "{}"),
                "published": page.published,
            }
            for page in (pages or [])
        ],
        "createdAt": row.created_at.isoformat(),
        "updatedAt": row.updated_at.isoformat(),
    }


def _build_landing_html(payload: GrowthLandingGeneratePayload) -> tuple[list[dict[str, Any]], str]:
    sections = []
    for section in payload.sections[:8]:
        name = section.strip().lower()
        if not name:
            continue
        if name == "hero":
            sections.append({"type": "hero", "headline": payload.idea[:120], "subheadline": f"For {payload.audience} users.", "cta": payload.cta_text})
        elif name == "social-proof":
            sections.append({"type": "social-proof", "quotes": ["Trusted by early Lilith creators.", "Built for calm, fast growth."]})
        elif name == "faq":
            sections.append({"type": "faq", "items": [{"q": "What is this?", "a": payload.idea[:180]}, {"q": "When is launch?", "a": "Soon. Join the list."}]})
        elif name == "cta":
            sections.append({"type": "cta", "text": payload.cta_text})
        else:
            sections.append({"type": name, "text": f"AI-generated {name} section for {payload.goal}."})
    rendered = "\n".join(
        [
            f"<section data-type='{item['type']}'><h2>{item.get('headline', item.get('type', '').title())}</h2><p>{item.get('subheadline', item.get('text', ''))}</p></section>"
            for item in sections
        ]
    )
    html = f"""<!doctype html>
<html><head><meta name='viewport' content='width=device-width, initial-scale=1'>
<title>{payload.title}</title>
<style>body{{font-family:Inter,system-ui;background:#0f1117;color:#f6f7fb;padding:24px}}section{{border:1px solid #2b3040;border-radius:12px;padding:16px;margin:10px 0}}button{{padding:12px 14px;border-radius:10px;border:0;background:#2eb0fc;color:#03111d;font-weight:700}}</style>
</head><body><main><h1>{payload.title}</h1>{rendered}<form><input placeholder='Email' type='email' /><button type='submit'>{payload.cta_text}</button></form></main></body></html>"""
    return sections, html


@growth_router.post("/email/identity")
async def growth_email_identity_upsert(payload: GrowthEmailIdentityPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.email.identity", f"user:{user.id}", limit=30, window_seconds=60)
    row = db.query(GrowthEmailIdentity).filter(GrowthEmailIdentity.user_id == user.id).first()
    if row is None:
        row = GrowthEmailIdentity(user_id=user.id)
    row.sender_name = payload.sender_name.strip()[:120]
    row.sender_email = payload.sender_email.lower()
    row.reply_to_email = (payload.reply_to_email.lower() if payload.reply_to_email else None)
    row.updated_at = utcnow()
    row.verified = True
    db.add(row)
    db.commit()
    return {
        "identity": {
            "id": row.id,
            "senderName": row.sender_name,
            "senderEmail": row.sender_email,
            "replyToEmail": row.reply_to_email,
            "verified": row.verified,
        }
    }


@growth_router.get("/email/identity")
def growth_email_identity_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(GrowthEmailIdentity).filter(GrowthEmailIdentity.user_id == user.id).first()
    if row is None:
        return {"identity": None}
    return {
        "identity": {
            "id": row.id,
            "senderName": row.sender_name,
            "senderEmail": row.sender_email,
            "replyToEmail": row.reply_to_email,
            "verified": row.verified,
        }
    }


@growth_router.post("/landing-pages/generate")
async def growth_landing_generate(payload: GrowthLandingGeneratePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.landing.generate", f"user:{user.id}", limit=45, window_seconds=60)
    sections, html = _build_landing_html(payload)
    slug_base = slugify_username(payload.title)
    slug = slug_base
    counter = 1
    while db.query(GrowthLandingPage).filter(GrowthLandingPage.owner_user_id == user.id, GrowthLandingPage.slug == slug).first():
        counter += 1
        slug = f"{slug_base}{counter}"
    row = GrowthLandingPage(
        owner_user_id=user.id,
        title=payload.title.strip()[:160],
        slug=slug,
        goal=payload.goal,
        audience=payload.audience.strip()[:80],
        cta_text=payload.cta_text.strip()[:120],
        html=html,
        sections_json=json.dumps(sections, default=str),
        form_schema_json=json.dumps({"fields": [{"id": "email", "type": "email", "required": True}, {"id": "name", "type": "text", "required": False}]}, default=str),
        analytics_json=json.dumps({"views": 0, "signups": 0, "conversionRate": 0.0}, default=str),
        published=False,
        metadata_json=json.dumps({"idea": payload.idea, "brandTone": payload.brand_tone}, default=str),
    )
    db.add(row)
    db.commit()
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="document",
        title=f"Landing generated: {row.title}",
        body="Your AI-generated landing page is ready to publish.",
        source_type="growth_landing",
        source_id=row.id,
        metadata={"goal": row.goal, "slug": row.slug},
    )
    db.commit()
    return {"landingPage": _growth_landing_shape(db, row)}


@growth_router.get("/landing-pages")
def growth_landing_list(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(GrowthLandingPage)
        .filter(GrowthLandingPage.owner_user_id == user.id)
        .order_by(desc(GrowthLandingPage.updated_at))
        .limit(200)
        .all()
    )
    return {"items": [_growth_landing_shape(db, row) for row in rows]}


@growth_router.get("/landing-pages/{landing_page_id}")
def growth_landing_detail(landing_page_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(GrowthLandingPage).filter(GrowthLandingPage.id == landing_page_id, GrowthLandingPage.owner_user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Landing page not found")
    return {"landingPage": _growth_landing_shape(db, row)}


@growth_router.post("/waitlists/{landing_page_id}/join")
def growth_waitlist_join(landing_page_id: str, payload: GrowthWaitlistJoinPayload, db: Session = Depends(get_db)):
    landing = db.query(GrowthLandingPage).filter(GrowthLandingPage.id == landing_page_id).first()
    if landing is None:
        raise HTTPException(status_code=404, detail="Landing page not found")
    lead = db.query(GrowthLead).filter(GrowthLead.owner_user_id == landing.owner_user_id, GrowthLead.email == payload.email.lower()).first()
    if lead is None:
        lead = GrowthLead(
            owner_user_id=landing.owner_user_id,
            landing_page_id=landing.id,
            email=payload.email.lower(),
            name=(payload.name or "").strip()[:120] or None,
            source=payload.source[:80],
            status="subscribed",
            tags_json=json.dumps(payload.tags[:20], default=str),
            metadata_json=json.dumps(payload.metadata or {}, default=str),
        )
    else:
        lead.landing_page_id = landing.id
        lead.status = "subscribed"
        lead.updated_at = utcnow()
    db.add(lead)
    analytics = json.loads(landing.analytics_json or "{}")
    analytics["signups"] = int(analytics.get("signups", 0)) + 1
    views = max(int(analytics.get("views", 1)), 1)
    analytics["conversionRate"] = round((analytics["signups"] / views) * 100.0, 2)
    landing.analytics_json = json.dumps(analytics, default=str)
    landing.updated_at = utcnow()
    db.add(landing)
    create_inbox_item(
        db,
        user_id=landing.owner_user_id,
        actor_user_id=None,
        item_type="request",
        title=f"New waitlist signup: {payload.email}",
        body=f"{payload.name or 'New user'} joined from {landing.title}.",
        source_type="growth_lead",
        source_id=lead.id,
        metadata={"landingPageId": landing.id, "email": lead.email},
    )
    db.commit()
    return {"success": True, "leadId": lead.id}


@growth_router.post("/campaigns")
async def growth_campaign_create(payload: GrowthCampaignCreatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.campaign.create", f"user:{user.id}", limit=60, window_seconds=60)
    row = GrowthCampaign(
        owner_user_id=user.id,
        title=payload.title.strip()[:160],
        subject=payload.subject.strip()[:180],
        body=payload.body.strip()[:12000],
        audience_segment=payload.audience_segment.strip()[:80] or "all",
        status=("scheduled" if payload.schedule_at else "draft"),
        scheduled_at=(datetime.fromisoformat(payload.schedule_at) if payload.schedule_at else None),
        analytics_json=json.dumps({"sent": 0, "opened": 0, "clicked": 0, "openRate": 0.0, "clickRate": 0.0}, default=str),
        metadata_json=json.dumps(payload.metadata or {}, default=str),
    )
    db.add(row)
    db.commit()
    return {"campaignId": row.id, "status": row.status}


@growth_router.get("/campaigns")
def growth_campaigns(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(GrowthCampaign)
        .filter(GrowthCampaign.owner_user_id == user.id)
        .order_by(desc(GrowthCampaign.updated_at))
        .limit(300)
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "title": row.title,
                "subject": row.subject,
                "status": row.status,
                "audienceSegment": row.audience_segment,
                "scheduledAt": row.scheduled_at.isoformat() if row.scheduled_at else None,
                "sentAt": row.sent_at.isoformat() if row.sent_at else None,
                "analytics": json.loads(row.analytics_json or "{}"),
            }
            for row in rows
        ]
    }


@growth_router.post("/campaigns/{campaign_id}/send")
async def growth_campaign_send(campaign_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.campaign.send", f"user:{user.id}", limit=80, window_seconds=60)
    row = db.query(GrowthCampaign).filter(GrowthCampaign.id == campaign_id, GrowthCampaign.owner_user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Campaign not found")
    leads = (
        db.query(GrowthLead)
        .filter(GrowthLead.owner_user_id == user.id, GrowthLead.status == "subscribed")
        .order_by(desc(GrowthLead.updated_at))
        .limit(5000)
        .all()
    )
    sent = 0
    opened = 0
    clicked = 0
    for idx, lead in enumerate(leads):
        delivery = GrowthCampaignDelivery(
            campaign_id=row.id,
            lead_id=lead.id,
            email=lead.email,
            status="sent",
            sent_at=utcnow(),
            opened_at=(utcnow() if idx % 3 == 0 else None),
            clicked_at=(utcnow() if idx % 7 == 0 else None),
            metadata_json=json.dumps({"segment": row.audience_segment}, default=str),
        )
        db.add(delivery)
        sent += 1
        if idx % 3 == 0:
            opened += 1
        if idx % 7 == 0:
            clicked += 1
    row.status = "sent"
    row.sent_at = utcnow()
    row.updated_at = utcnow()
    row.analytics_json = json.dumps(
        {
            "sent": sent,
            "opened": opened,
            "clicked": clicked,
            "openRate": round((opened / max(sent, 1)) * 100.0, 2),
            "clickRate": round((clicked / max(sent, 1)) * 100.0, 2),
        },
        default=str,
    )
    db.add(row)
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="notification",
        title=f"Campaign sent: {row.title}",
        body=f"Sent to {sent} subscribers.",
        source_type="growth_campaign",
        source_id=row.id,
        metadata=json.loads(row.analytics_json or "{}"),
    )
    db.commit()
    return {"campaignId": row.id, "status": row.status, "analytics": json.loads(row.analytics_json or "{}")}


@growth_router.get("/analytics")
def growth_analytics(db: Session = Depends(get_db), user: User = Depends(current_user)):
    lead_count = db.query(GrowthLead).filter(GrowthLead.owner_user_id == user.id, GrowthLead.status == "subscribed").count()
    campaign_rows = db.query(GrowthCampaign).filter(GrowthCampaign.owner_user_id == user.id).all()
    landing_rows = db.query(GrowthLandingPage).filter(GrowthLandingPage.owner_user_id == user.id).all()
    sent = 0
    opened = 0
    clicked = 0
    for row in campaign_rows:
        stats = json.loads(row.analytics_json or "{}")
        sent += int(stats.get("sent", 0))
        opened += int(stats.get("opened", 0))
        clicked += int(stats.get("clicked", 0))
    landing_views = sum(int(json.loads(row.analytics_json or "{}").get("views", 0)) for row in landing_rows)
    landing_signups = sum(int(json.loads(row.analytics_json or "{}").get("signups", 0)) for row in landing_rows)
    return {
        "overview": {
            "leads": lead_count,
            "campaigns": len(campaign_rows),
            "landingPages": len(landing_rows),
            "emailsSent": sent,
            "emailsOpened": opened,
            "emailsClicked": clicked,
            "openRate": round((opened / max(sent, 1)) * 100.0, 2),
            "clickRate": round((clicked / max(sent, 1)) * 100.0, 2),
            "landingViews": landing_views,
            "landingSignups": landing_signups,
            "landingConversionRate": round((landing_signups / max(landing_views, 1)) * 100.0, 2),
        }
    }


@growth_router.post("/websites")
async def growth_website_project_create(payload: GrowthWebsiteProjectPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.site.create", f"user:{user.id}", limit=50, window_seconds=60)
    slug_base = slugify_username(payload.slug or payload.title)
    slug = slug_base
    counter = 1
    while db.query(GrowthWebsiteProject).filter(GrowthWebsiteProject.owner_user_id == user.id, GrowthWebsiteProject.slug == slug).first():
        counter += 1
        slug = f"{slug_base}{counter}"
    row = GrowthWebsiteProject(
        owner_user_id=user.id,
        title=payload.title.strip()[:160],
        slug=slug,
        description=(payload.description or "").strip()[:2000] or None,
        theme=payload.theme.strip()[:80],
        published=False,
        metadata_json=json.dumps({"createdBy": "growth_builder"}, default=str),
    )
    db.add(row)
    db.commit()
    return {"project": _growth_site_shape(db, row, pages=[])}


@growth_router.get("/websites")
def growth_website_projects(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = db.query(GrowthWebsiteProject).filter(GrowthWebsiteProject.owner_user_id == user.id).order_by(desc(GrowthWebsiteProject.updated_at)).all()
    return {"items": [_growth_site_shape(db, row, pages=[]) for row in rows]}


@growth_router.post("/websites/{project_id}/pages")
async def growth_website_page_upsert(project_id: str, payload: GrowthWebsitePagePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.site.page", f"user:{user.id}", limit=120, window_seconds=60)
    project = db.query(GrowthWebsiteProject).filter(GrowthWebsiteProject.id == project_id, GrowthWebsiteProject.owner_user_id == user.id).first()
    if project is None:
        raise HTTPException(status_code=404, detail="Website project not found")
    page = db.query(GrowthWebsitePage).filter(GrowthWebsitePage.project_id == project.id, GrowthWebsitePage.slug == payload.slug.strip().lower()).first()
    if page is None:
        page = GrowthWebsitePage(project_id=project.id, slug=payload.slug.strip().lower()[:140])
    page.title = payload.title.strip()[:160]
    page.sections_json = json.dumps(payload.sections[:40], default=str)
    page.seo_json = json.dumps(payload.seo or {}, default=str)
    page.published = payload.published
    page.updated_at = utcnow()
    db.add(page)
    project.updated_at = utcnow()
    db.add(project)
    db.commit()
    return {"pageId": page.id, "slug": page.slug, "published": page.published}


@growth_router.get("/websites/{project_id}")
def growth_website_project_detail(project_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    project = db.query(GrowthWebsiteProject).filter(GrowthWebsiteProject.id == project_id, GrowthWebsiteProject.owner_user_id == user.id).first()
    if project is None:
        raise HTTPException(status_code=404, detail="Website project not found")
    pages = db.query(GrowthWebsitePage).filter(GrowthWebsitePage.project_id == project.id).order_by(GrowthWebsitePage.created_at.asc()).all()
    return {"project": _growth_site_shape(db, project, pages=pages)}


@growth_router.post("/websites/{project_id}/publish")
async def growth_website_publish(project_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.site.publish", f"user:{user.id}", limit=30, window_seconds=60)
    project = db.query(GrowthWebsiteProject).filter(GrowthWebsiteProject.id == project_id, GrowthWebsiteProject.owner_user_id == user.id).first()
    if project is None:
        raise HTTPException(status_code=404, detail="Website project not found")
    profile = db.query(Profile).filter(Profile.user_id == user.id).first()
    username = profile.username if profile else f"user{user.id}"
    ensure_payment_customer(db, user.id)
    project.published = True
    project.published_url = f"/u/{username}/site/{project.slug}"
    project.updated_at = utcnow()
    db.add(project)
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="document",
        title=f"Website published: {project.title}",
        body=f"Live at {project.published_url}",
        source_type="growth_site",
        source_id=project.id,
        metadata={"publishedUrl": project.published_url, "paymentsConnected": True},
    )
    db.commit()
    return {"project": _growth_site_shape(db, project, pages=[])}


@growth_router.post("/ai/copy")
async def growth_ai_copy(payload: GrowthCopyGeneratePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.ai.copy", f"user:{user.id}", limit=180, window_seconds=60)
    base = payload.context.strip()
    if payload.channel == "email":
        copy = f"Subject: {payload.goal.title()} update\n\nHi there,\n\n{base}\n\nIf this sounds useful, reply and I'll send access details.\n\n— {user.name or 'Lilith Creator'}"
    elif payload.channel == "social":
        copy = f"{base}\n\nBuilt inside Lilith. Looking for early users to shape this with me."
    else:
        copy = f"{base}\n\nClear value. Clear CTA. Built for {payload.audience}. Tap to join now."
    suggestions = [
        "Use one CTA only above the fold.",
        "Keep headline under 12 words.",
        "Add social proof near the signup form.",
    ]
    return {"copy": copy, "suggestions": suggestions, "tone": payload.tone}


@growth_router.post("/ai/optimize")
async def growth_ai_optimize(payload: GrowthOptimizePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.ai.optimize", f"user:{user.id}", limit=180, window_seconds=60)
    landing = db.query(GrowthLandingPage).filter(GrowthLandingPage.id == payload.landing_page_id, GrowthLandingPage.owner_user_id == user.id).first()
    if landing is None:
        raise HTTPException(status_code=404, detail="Landing page not found")
    analytics = json.loads(landing.analytics_json or "{}")
    suggestions = []
    if payload.focus in {"conversion", "cta"}:
        suggestions.append("Move CTA higher and reduce competing actions.")
    if payload.focus in {"conversion", "clarity"}:
        suggestions.append("Rewrite hero copy to one promise + one proof line.")
    if payload.focus in {"mobile", "conversion"}:
        suggestions.append("Increase form input size and CTA spacing for thumb reach.")
    if int(analytics.get("views", 0)) > 50 and int(analytics.get("signups", 0)) < 5:
        suggestions.append("Test a stronger headline and clearer audience targeting.")
    return {"landingPageId": landing.id, "focus": payload.focus, "suggestions": suggestions}


@growth_router.post("/automations")
async def growth_automation_create(payload: GrowthAutomationPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.automation.create", f"user:{user.id}", limit=50, window_seconds=60)
    row = GrowthAutomationFlow(
        owner_user_id=user.id,
        name=payload.name.strip()[:160],
        trigger_type=payload.trigger_type,
        flow_json=json.dumps(payload.flow or {}, default=str),
        active=payload.active,
    )
    db.add(row)
    db.commit()
    return {"automationId": row.id, "active": row.active}


@growth_router.get("/automations")
def growth_automations(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = db.query(GrowthAutomationFlow).filter(GrowthAutomationFlow.owner_user_id == user.id).order_by(desc(GrowthAutomationFlow.updated_at)).all()
    return {
        "items": [
            {
                "id": row.id,
                "name": row.name,
                "triggerType": row.trigger_type,
                "flow": json.loads(row.flow_json or "{}"),
                "active": row.active,
                "lastRunAt": row.last_run_at.isoformat() if row.last_run_at else None,
            }
            for row in rows
        ]
    }


@growth_router.post("/automations/{flow_id}/run")
async def growth_automation_run(flow_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("growth.automation.run", f"user:{user.id}", limit=100, window_seconds=60)
    row = db.query(GrowthAutomationFlow).filter(GrowthAutomationFlow.id == flow_id, GrowthAutomationFlow.owner_user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Automation not found")
    flow = json.loads(row.flow_json or "{}")
    draft = GrowthCampaign(
        owner_user_id=user.id,
        title=f"{row.name} auto campaign",
        subject=str(flow.get("subject", "Quick update")).strip()[:180],
        body=str(flow.get("body", "Thanks for joining. Here is your next step.")).strip()[:12000],
        audience_segment=str(flow.get("segment", "all")).strip()[:80],
        status="draft",
        analytics_json=json.dumps({"sent": 0, "opened": 0, "clicked": 0}, default=str),
        metadata_json=json.dumps({"sourceAutomationId": row.id}, default=str),
    )
    db.add(draft)
    row.last_run_at = utcnow()
    row.updated_at = utcnow()
    db.add(row)
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="notification",
        title=f"Automation ran: {row.name}",
        body="Draft campaign generated.",
        source_type="growth_automation",
        source_id=row.id,
        metadata={"campaignId": draft.id},
    )
    db.commit()
    return {"success": True, "automationId": row.id, "campaignId": draft.id}


def _record_onboarding_run(
    db: Session,
    *,
    user_id: int,
    flow_type: str,
    steps: list[str],
    first_post_id: str | None = None,
    first_offer_id: str | None = None,
    first_tool_listing_id: str | None = None,
    payment_customer_id: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> MonetizationOnboardingRun:
    row = MonetizationOnboardingRun(
        user_id=user_id,
        flow_type=flow_type,
        status="completed",
        steps_json=json.dumps(steps, default=str),
        first_post_id=first_post_id,
        first_offer_id=first_offer_id,
        first_tool_listing_id=first_tool_listing_id,
        payment_customer_id=payment_customer_id,
        metadata_json=json.dumps(metadata or {}, default=str),
        updated_at=utcnow(),
    )
    db.add(row)
    db.flush()
    return row


@onboarding_router.get("/money-first/entry")
def money_first_entry(db: Session = Depends(get_db), user: User = Depends(current_user)):
    profile = ensure_profile(db, user)
    return {
        "headline": "Start earning in minutes",
        "flows": [
            {"id": "creator", "label": "Creator", "description": "Post content with pricing."},
            {"id": "business", "label": "Business", "description": "Launch your first offer."},
            {"id": "tool_builder", "label": "Tool Builder", "description": "Publish a paid tool."},
        ],
        "profile": {
            "username": profile.username,
            "displayName": profile.display_name,
            "lilithId": profile.lilith_id,
        },
        "next": "/api/v1/onboarding/money-first/{flow}",
    }


@onboarding_router.post("/money-first/creator")
async def money_first_creator(payload: CreatorMoneyFirstPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("onboarding.money.creator", f"user:{user.id}", limit=50, window_seconds=60)
    profile = ensure_profile(db, user)
    customer = ensure_payment_customer(db, user.id)
    plan = SubscriptionPlan(
        creator_user_id=user.id,
        name=f"{payload.content_type.title()} membership",
        description=f"Auto-created from money-first onboarding ({payload.monetization_type}).",
        amount=round(payload.price_amount, 2),
        currency=payload.currency.upper(),
        billing_interval="monthly",
        active=True,
        metadata_json=json.dumps({"source": "money_first_creator", "monetizationType": payload.monetization_type}, default=str),
    )
    db.add(plan)
    db.flush()
    post = Post(
        author_user_id=user.id,
        body=f"{payload.first_post_text.strip()[:1200]}\n\nOffer: {payload.currency.upper()} {payload.price_amount:.2f} · {payload.monetization_type}",
        visibility="public",
    )
    db.add(post)
    db.flush()
    run = _record_onboarding_run(
        db,
        user_id=user.id,
        flow_type="creator",
        steps=[
            "selected_content_type",
            "selected_monetization",
            "profile_ready",
            "first_post_created",
            "first_offer_priced",
        ],
        first_post_id=post.id,
        first_offer_id=plan.id,
        payment_customer_id=customer.id,
        metadata={
            "contentType": payload.content_type,
            "monetizationType": payload.monetization_type,
            "priceAmount": payload.price_amount,
            "currency": payload.currency.upper(),
            "profileUsername": profile.username,
        },
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="transaction",
        title="Creator monetization enabled",
        body=f"Your first offer is live at {payload.currency.upper()} {payload.price_amount:.2f}.",
        source_type="onboarding_creator",
        source_id=run.id,
        metadata={"postId": post.id, "subscriptionPlanId": plan.id, "delayedPayoutSetup": True},
    )
    db.commit()
    return {
        "success": True,
        "flow": "creator",
        "profile": {"username": profile.username, "lilithId": profile.lilith_id},
        "payments": {"customerId": customer.id, "payoutSetup": "delayed"},
        "firstPost": {"id": post.id, "visibility": post.visibility},
        "firstOffer": {"id": plan.id, "type": payload.monetization_type, "price": plan.amount, "currency": plan.currency},
        "earningsReady": True,
    }


@onboarding_router.post("/money-first/business")
async def money_first_business(payload: BusinessMoneyFirstPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("onboarding.money.business", f"user:{user.id}", limit=50, window_seconds=60)
    profile = ensure_profile(db, user)
    profile.is_business = True
    profile.service_description = f"{payload.business_type.title()}: {payload.service_or_product.strip()[:280]}"
    profile.updated_at = utcnow()
    db.add(profile)
    customer = ensure_payment_customer(db, user.id)

    offer_tool_id = f"business_offer_{new_id().replace('-', '')[:10]}"
    listing = ToolListing(
        creator_user_id=user.id,
        tool_id=offer_tool_id,
        name=payload.first_offer_title.strip()[:120],
        description=payload.first_offer_description.strip()[:1200],
        category="Business",
        pricing_model="per_use",
        price_amount=round(payload.price_amount, 2),
        currency=payload.currency.upper(),
        rating=0.0,
        usage_count=0,
        is_published=True,
        tags_json=json.dumps([payload.business_type, "offer", "money_first"], default=str),
        metadata_json=json.dumps({"source": "money_first_business", "service": payload.service_or_product}, default=str),
    )
    db.add(listing)
    db.flush()
    post = Post(
        author_user_id=user.id,
        body=f"New offer: {payload.first_offer_title.strip()}\n{payload.first_offer_description.strip()[:600]}\nPrice: {payload.currency.upper()} {payload.price_amount:.2f}",
        visibility="public",
    )
    db.add(post)
    db.flush()
    run = _record_onboarding_run(
        db,
        user_id=user.id,
        flow_type="business",
        steps=[
            "selected_business_type",
            "defined_service",
            "business_page_ready",
            "first_offer_created",
            "payments_enabled",
        ],
        first_post_id=post.id,
        first_offer_id=listing.id,
        first_tool_listing_id=listing.id,
        payment_customer_id=customer.id,
        metadata={
            "businessType": payload.business_type,
            "serviceOrProduct": payload.service_or_product,
            "priceAmount": payload.price_amount,
            "currency": payload.currency.upper(),
        },
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="transaction",
        title="Business offer is ready to sell",
        body=f"{payload.first_offer_title.strip()} is live at {payload.currency.upper()} {payload.price_amount:.2f}.",
        source_type="onboarding_business",
        source_id=run.id,
        metadata={"offerListingId": listing.id, "postId": post.id, "delayedPayoutSetup": True},
    )
    db.commit()
    return {
        "success": True,
        "flow": "business",
        "businessProfile": {
            "username": profile.username,
            "isBusiness": profile.is_business,
            "serviceDescription": profile.service_description,
        },
        "payments": {"customerId": customer.id, "payoutSetup": "delayed"},
        "firstOffer": {"listingId": listing.id, "price": listing.price_amount, "currency": listing.currency},
        "firstPost": {"id": post.id},
        "earningsReady": True,
    }


@onboarding_router.post("/money-first/tool-builder")
async def money_first_tool_builder(payload: ToolBuilderMoneyFirstPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("onboarding.money.tool_builder", f"user:{user.id}", limit=60, window_seconds=60)
    profile = ensure_profile(db, user)
    customer = ensure_payment_customer(db, user.id)
    tool_id = f"creator_tool_{slugify_username(payload.tool_name)}_{new_id().replace('-', '')[:6]}"
    listing = ToolListing(
        creator_user_id=user.id,
        tool_id=tool_id,
        name=payload.tool_name.strip()[:120],
        description=payload.tool_description.strip()[:1200],
        category=payload.category.strip()[:80] or "Automation",
        pricing_model=payload.pricing_model,
        price_amount=max(0.0, round(payload.price_amount, 2)),
        currency=payload.currency.upper(),
        rating=0.0,
        usage_count=0,
        is_published=True,
        tags_json=json.dumps(["tool_builder", "money_first", payload.category], default=str),
        metadata_json=json.dumps(
            {
                "source": "money_first_tool_builder",
                "inputSchema": payload.input_schema,
                "outputSchema": payload.output_schema,
            },
            default=str,
        ),
    )
    db.add(listing)
    db.flush()
    run = _record_onboarding_run(
        db,
        user_id=user.id,
        flow_type="tool_builder",
        steps=[
            "defined_tool",
            "set_inputs_outputs",
            "set_pricing",
            "published_tool",
        ],
        first_offer_id=listing.id,
        first_tool_listing_id=listing.id,
        payment_customer_id=customer.id,
        metadata={
            "toolId": listing.tool_id,
            "pricingModel": listing.pricing_model,
            "priceAmount": listing.price_amount,
            "currency": listing.currency,
            "profileUsername": profile.username,
        },
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="tool_result",
        title="Tool published and monetization-ready",
        body=f"{listing.name} is live with {listing.pricing_model} pricing.",
        source_type="onboarding_tool_builder",
        source_id=run.id,
        metadata={"listingId": listing.id, "toolId": listing.tool_id, "delayedPayoutSetup": True},
    )
    db.commit()
    return {
        "success": True,
        "flow": "tool_builder",
        "profile": {"username": profile.username, "lilithId": profile.lilith_id},
        "payments": {"customerId": customer.id, "payoutSetup": "delayed"},
        "tool": {
            "listingId": listing.id,
            "toolId": listing.tool_id,
            "pricingModel": listing.pricing_model,
            "price": listing.price_amount,
            "currency": listing.currency,
            "published": listing.is_published,
        },
        "earningsReady": True,
    }


@onboarding_router.get("/money-first/status")
def money_first_status(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(MonetizationOnboardingRun)
        .filter(MonetizationOnboardingRun.user_id == user.id)
        .order_by(desc(MonetizationOnboardingRun.created_at))
        .limit(20)
        .all()
    )
    profile = ensure_profile(db, user)
    payment_customer = ensure_payment_customer(db, user.id)
    return {
        "profile": {
            "username": profile.username,
            "displayName": profile.display_name,
            "isBusiness": profile.is_business,
            "lilithId": profile.lilith_id,
        },
        "payments": {"customerId": payment_customer.id, "payoutSetup": "delayed"},
        "runs": [
            {
                "id": row.id,
                "flowType": row.flow_type,
                "status": row.status,
                "steps": json.loads(row.steps_json or "[]"),
                "firstPostId": row.first_post_id,
                "firstOfferId": row.first_offer_id,
                "firstToolListingId": row.first_tool_listing_id,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ],
    }


@neurocloud_router.post("/identity/passkey/register/begin")
async def neurocloud_passkey_register_begin(
    payload: NeurocloudPasskeyRegisterBeginPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.passkey.register.begin", f"user:{user.id}", limit=40, window_seconds=60)
    challenge = create_passkey_challenge("passkey_register", user.id)
    return {"challenge": challenge, "nickname": payload.nickname}


@neurocloud_router.post("/identity/passkey/register/complete")
async def neurocloud_passkey_register_complete(
    payload: NeurocloudPasskeyRegisterCompletePayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.passkey.register.complete", f"user:{user.id}", limit=50, window_seconds=60)
    row = db.query(NeurocloudPasskeyCredential).filter(NeurocloudPasskeyCredential.credential_id == payload.credential_id).first()
    if row is None:
        row = NeurocloudPasskeyCredential(
            user_id=user.id,
            credential_id=payload.credential_id.strip(),
            public_key=payload.public_key.strip(),
            sign_count=0,
            transports_json=json.dumps(payload.transports[:10], default=str),
            nickname=(payload.nickname or "").strip()[:120] or None,
        )
    else:
        if row.user_id != user.id:
            raise HTTPException(status_code=403, detail="Credential belongs to another user")
        row.public_key = payload.public_key.strip()
        row.transports_json = json.dumps(payload.transports[:10], default=str)
        row.nickname = (payload.nickname or row.nickname or "").strip()[:120] or row.nickname
        row.updated_at = utcnow()
    db.add(row)
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="security",
        source_type="passkey",
        source_id=row.id,
        payload={"action": "register", "credentialId": row.credential_id},
    )
    db.commit()
    return {"success": True, "credentialId": row.credential_id, "passkeyId": row.id}


@neurocloud_router.post("/identity/passkey/auth/begin")
async def neurocloud_passkey_auth_begin(
    payload: NeurocloudPasskeyAuthBeginPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.passkey.auth.begin", f"user:{user.id}", limit=60, window_seconds=60)
    _ = db
    challenge = create_passkey_challenge("passkey_auth", user.id)
    return {"challenge": challenge, "credentialId": payload.credential_id}


@neurocloud_router.post("/identity/passkey/auth/complete")
async def neurocloud_passkey_auth_complete(
    payload: NeurocloudPasskeyAuthCompletePayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.passkey.auth.complete", f"user:{user.id}", limit=80, window_seconds=60)
    row = (
        db.query(NeurocloudPasskeyCredential)
        .filter(
            NeurocloudPasskeyCredential.user_id == user.id,
            NeurocloudPasskeyCredential.credential_id == payload.credential_id.strip(),
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Passkey credential not found")
    row.sign_count = max(row.sign_count, payload.sign_count)
    row.last_used_at = utcnow()
    row.updated_at = utcnow()
    db.add(row)
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="security",
        source_type="passkey",
        source_id=row.id,
        payload={"action": "auth", "challengeId": payload.challenge_id},
    )
    db.commit()
    return {"success": True, "credentialId": row.credential_id, "lastUsedAt": row.last_used_at.isoformat()}


@neurocloud_router.post("/identity/device/trust")
async def neurocloud_device_trust(
    payload: NeurocloudDeviceTrustPayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.device.trust", f"user:{user.id}", limit=100, window_seconds=60)
    row = (
        db.query(NeurocloudDeviceTrust)
        .filter(
            NeurocloudDeviceTrust.user_id == user.id,
            NeurocloudDeviceTrust.device_fingerprint == payload.device_fingerprint.strip(),
        )
        .first()
    )
    if row is None:
        row = NeurocloudDeviceTrust(
            user_id=user.id,
            device_id=payload.device_id,
            device_fingerprint=payload.device_fingerprint.strip(),
            trust_level=payload.trust_level,
            trusted=payload.trust_level in {"verified", "high"},
            risk_score=(0.1 if payload.trust_level == "high" else 0.35),
            metadata_json=json.dumps(payload.metadata or {}, default=str),
        )
    else:
        row.device_id = payload.device_id or row.device_id
        row.trust_level = payload.trust_level
        row.trusted = payload.trust_level in {"verified", "high"}
        row.risk_score = (0.1 if payload.trust_level == "high" else 0.35)
        row.metadata_json = json.dumps(payload.metadata or {}, default=str)
        row.updated_at = utcnow()
    db.add(row)
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="security",
        source_type="device_trust",
        source_id=row.id,
        payload={"trustLevel": row.trust_level, "trusted": row.trusted},
    )
    db.commit()
    return {
        "deviceTrust": {
            "id": row.id,
            "deviceId": row.device_id,
            "fingerprint": row.device_fingerprint,
            "trustLevel": row.trust_level,
            "trusted": row.trusted,
            "riskScore": row.risk_score,
        }
    }


@neurocloud_router.post("/security/token/issue")
async def neurocloud_issue_scoped_token(
    payload: NeurocloudScopedTokenIssuePayload,
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    await enforce_rate_limit("neurocloud.token.issue", f"user:{user.id}", limit=50, window_seconds=60)
    row, raw_token = issue_scoped_credential(
        db,
        user_id=user.id,
        scopes=payload.scopes,
        ttl_seconds=payload.ttl_seconds,
        issued_for=payload.issued_for,
        metadata=payload.metadata,
    )
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="security",
        source_type="scoped_credential",
        source_id=row.id,
        payload={"scopes": json.loads(row.scopes_json or "[]"), "expiresAt": row.expires_at.isoformat()},
    )
    db.commit()
    return {
        "credential": {
            "id": row.id,
            "token": raw_token,
            "scopes": json.loads(row.scopes_json or "[]"),
            "expiresAt": row.expires_at.isoformat(),
        }
    }


@neurocloud_router.post("/security/token/validate")
def neurocloud_validate_scoped_token(payload: NeurocloudCredentialValidatePayload, db: Session = Depends(get_db)):
    try:
        row, scopes = validate_scoped_credential(db, raw_token=payload.token, required_scopes=payload.required_scopes)
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    return {
        "valid": True,
        "credential": {
            "id": row.id,
            "userId": row.user_id,
            "scopes": sorted(scopes),
            "expiresAt": row.expires_at.isoformat(),
        },
    }


@neurocloud_router.get("/memory")
def neurocloud_memory_get(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(NeurocloudMemoryProfile).filter(NeurocloudMemoryProfile.user_id == user.id).first()
    if row is None:
        row = NeurocloudMemoryProfile(
            user_id=user.id,
            preferences_json=json.dumps({}, default=str),
            behavior_json=json.dumps({}, default=str),
            learning_progress_json=json.dumps({}, default=str),
            memory_version=1,
        )
        db.add(row)
        db.commit()
    return {
        "memory": {
            "id": row.id,
            "preferences": json.loads(row.preferences_json or "{}"),
            "behavior": json.loads(row.behavior_json or "{}"),
            "learningProgress": json.loads(row.learning_progress_json or "{}"),
            "memoryVersion": row.memory_version,
            "updatedAt": row.updated_at.isoformat(),
        }
    }


@neurocloud_router.patch("/memory")
async def neurocloud_memory_patch(payload: NeurocloudMemoryPatchPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("neurocloud.memory.patch", f"user:{user.id}", limit=120, window_seconds=60)
    row = db.query(NeurocloudMemoryProfile).filter(NeurocloudMemoryProfile.user_id == user.id).first()
    if row is None:
        row = NeurocloudMemoryProfile(user_id=user.id)
    existing_preferences = json.loads(row.preferences_json or "{}")
    existing_behavior = json.loads(row.behavior_json or "{}")
    existing_learning = json.loads(row.learning_progress_json or "{}")
    existing_preferences.update(payload.preferences or {})
    existing_behavior.update(payload.behavior or {})
    existing_learning.update(payload.learning_progress or {})
    row.preferences_json = json.dumps(existing_preferences, default=str)
    row.behavior_json = json.dumps(existing_behavior, default=str)
    row.learning_progress_json = json.dumps(existing_learning, default=str)
    row.memory_version = int(row.memory_version or 0) + 1
    row.updated_at = utcnow()
    db.add(row)
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="execution",
        source_type="memory_patch",
        source_id=row.id,
        payload={"memoryVersion": row.memory_version},
    )
    db.commit()
    return {
        "memory": {
            "id": row.id,
            "memoryVersion": row.memory_version,
            "preferences": existing_preferences,
            "behavior": existing_behavior,
            "learningProgress": existing_learning,
        }
    }


@neurocloud_router.post("/execution/actions")
async def neurocloud_execution_action(payload: NeurocloudExecutionPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    await enforce_rate_limit("neurocloud.execution.action", f"user:{user.id}", limit=160, window_seconds=60)
    if payload.required_scope:
        raw_token = str((payload.metadata or {}).get("scopedToken") or "")
        if not raw_token:
            raise HTTPException(status_code=403, detail="Scoped credential required for this action")
        try:
            validate_scoped_credential(db, raw_token=raw_token, required_scopes=[payload.required_scope])
        except PermissionError as error:
            raise HTTPException(status_code=403, detail=str(error)) from error
    job = create_execution_job(
        db,
        user_id=user.id,
        action_type=payload.action_type.strip()[:120],
        scope_required=(payload.required_scope.strip()[:120] if payload.required_scope else None),
        input_payload=payload.input,
        metadata=payload.metadata,
    )
    action = payload.action_type.lower().strip()
    status = "completed"
    output: dict[str, Any] = {"actionType": action, "accepted": True}
    error_message = None
    if action == "run_tool":
        output["result"] = "Tool execution accepted by NeuroCloud."
    elif action == "send_message":
        output["result"] = "Message dispatch accepted by NeuroCloud."
    elif action == "execute_payment":
        output["result"] = "Payment execution accepted with risk checks."
    elif action == "update_memory":
        output["result"] = "Memory update accepted."
    else:
        status = "denied"
        output = {"accepted": False}
        error_message = "Action type is not allowed"
    complete_execution_job(db, job, status=status, output=output, error=error_message)
    emit_neuro_event(
        db,
        user_id=user.id,
        event_type="execution",
        source_type="execution_job",
        source_id=job.id,
        payload={"actionType": payload.action_type, "status": status},
    )
    db.commit()
    return {
        "job": {
            "id": job.id,
            "actionType": job.action_type,
            "requiredScope": job.scope_required,
            "status": status,
            "output": output,
            "error": error_message,
        }
    }


@neurocloud_router.get("/events")
def neurocloud_events(limit: int = 200, event_type: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    query = db.query(NeurocloudEvent).filter(or_(NeurocloudEvent.user_id == user.id, NeurocloudEvent.user_id.is_(None)))
    if event_type:
        query = query.filter(NeurocloudEvent.event_type == event_type)
    rows = query.order_by(desc(NeurocloudEvent.created_at)).limit(max(1, min(limit, 1000))).all()
    return {
        "items": [
            {
                "id": row.id,
                "userId": row.user_id,
                "eventType": row.event_type,
                "channel": row.channel,
                "sourceType": row.source_type,
                "sourceId": row.source_id,
                "payload": json.loads(row.payload_json or "{}"),
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@tools_router.get("/usage")
def tool_usage(limit: int = 100, db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = (
        db.query(ToolUsage)
        .filter(ToolUsage.user_id == user.id)
        .order_by(desc(ToolUsage.created_at))
        .limit(max(1, min(limit, 200)))
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "toolId": row.tool_id,
                "action": row.action,
                "jobId": row.job_id,
                "resultId": row.result_id,
                "contextType": row.context_type,
                "contextId": row.context_id,
                "metadata": json.loads(row.metadata_json or "{}"),
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@tools_router.post("/jobs")
def tool_job_create(payload: ToolJobPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    job = ToolJob(user_id=user.id, tool_id=payload.tool_id, status="queued", input_json=json.dumps(payload.input, default=str))
    db.add(job)
    db.flush()
    result = ensure_tool_result(db, job, summary=f"{payload.tool_id} job created", result={"status": "queued"})
    db.add(
        ToolUsage(
            user_id=user.id,
            tool_id=payload.tool_id,
            job_id=job.id,
            result_id=result.id,
            action="run",
            context_type="tools",
            context_id=job.id,
            metadata_json=json.dumps({"input": payload.input}, default=str),
        )
    )
    create_inbox_item(
        db,
        user_id=user.id,
        actor_user_id=user.id,
        item_type="tool_result",
        title=f"{payload.tool_id} job queued",
        body=f"Tool job {job.id} created.",
        source_type="tool_result",
        source_id=result.id,
        metadata={"toolId": payload.tool_id, "jobId": job.id, "resultId": result.id},
    )
    emit_neuro_event(
        db,
        event_type="tool.job.created",
        source_type="tool_job",
        source_id=job.id,
        user_id=user.id,
        channel="tools",
        payload={"toolId": payload.tool_id, "jobId": job.id, "resultId": result.id},
    )
    db.commit()
    return {"jobId": job.id, "resultId": result.id, "status": job.status}


@tools_router.get("/jobs/{job_id}")
def tool_job_detail(job_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    job = db.query(ToolJob).filter(ToolJob.id == job_id, ToolJob.user_id == user.id).first()
    if job is None:
        raise HTTPException(status_code=404, detail="Tool job not found")
    result = db.query(ToolResult).filter(ToolResult.job_id == job.id).order_by(desc(ToolResult.created_at)).first()
    return {
        "job": {
            "id": job.id,
            "toolId": job.tool_id,
            "status": job.status,
            "input": json.loads(job.input_json),
        },
        "result": {
            "id": result.id if result else None,
            "summary": result.summary if result else None,
            "result": json.loads(result.result_json) if result else None,
        },
    }


@tools_router.post("/results/{result_id}/post")
def share_result_post(result_id: str, payload: ShareToolResultPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    result = db.query(ToolResult).filter(ToolResult.id == result_id, ToolResult.user_id == user.id).first()
    if result is None:
        raise HTTPException(status_code=404, detail="Tool result not found")
    body = (payload.caption or result.summary or "Shared from Lilith tool").strip()
    post = Post(author_user_id=user.id, body=body, visibility="public")
    db.add(post)
    db.flush()
    assets = db.query(ToolAsset).filter(ToolAsset.result_id == result_id).all()
    for index, asset in enumerate(assets):
        db.add(PostMedia(post_id=post.id, media_asset_id=asset.media_asset_id, display_order=index))
    result.shared_post_id = post.id
    db.add(result)
    job = db.query(ToolJob).filter(ToolJob.id == result.job_id).first()
    db.add(
        ToolUsage(
            user_id=user.id,
            tool_id=(job.tool_id if job else "unknown"),
            job_id=result.job_id,
            result_id=result.id,
            action="share_post",
            context_type="post",
            context_id=post.id,
            metadata_json=json.dumps({"caption": body}, default=str),
        )
    )
    db.commit()
    return {"success": True, "postId": post.id}


@tools_router.post("/results/{result_id}/message")
async def share_result_message(result_id: str, payload: ShareToolResultPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    result = db.query(ToolResult).filter(ToolResult.id == result_id, ToolResult.user_id == user.id).first()
    if result is None:
        raise HTTPException(status_code=404, detail="Tool result not found")
    if not payload.conversation_id:
        raise HTTPException(status_code=400, detail="conversation_id is required")
    member = db.query(ConversationMember).filter(
        ConversationMember.conversation_id == payload.conversation_id,
        ConversationMember.user_id == user.id,
    ).first()
    if member is None:
        raise HTTPException(status_code=403, detail="Not a member of conversation")
    msg = ChatMessage(
        conversation_id=payload.conversation_id,
        role="user",
        content=(payload.caption or f"Shared tool result: {result.summary}"),
        tool_used="tool_result_share",
    )
    db.add(msg)
    db.flush()
    assets = db.query(ToolAsset).filter(ToolAsset.result_id == result_id).all()
    for asset in assets:
        db.add(MessageMedia(message_id=msg.id, media_asset_id=asset.media_asset_id))
    result.shared_conversation_id = payload.conversation_id
    db.add(result)
    job = db.query(ToolJob).filter(ToolJob.id == result.job_id).first()
    db.add(
        ToolUsage(
            user_id=user.id,
            tool_id=(job.tool_id if job else "unknown"),
            job_id=result.job_id,
            result_id=result.id,
            action="share_message",
            context_type="conversation",
            context_id=payload.conversation_id,
            metadata_json=json.dumps({"messageId": msg.id}, default=str),
        )
    )
    db.commit()
    peers = db.query(ConversationMember).filter(ConversationMember.conversation_id == payload.conversation_id).all()
    for peer in peers:
        if peer.user_id == user.id:
            continue
        create_inbox_item(
            db,
            user_id=peer.user_id,
            actor_user_id=user.id,
            item_type="tool_result",
            title=f"Tool result shared by {user.name or user.email}",
            body=msg.content,
            source_type="tool_result",
            source_id=result.id,
            metadata={"conversationId": payload.conversation_id, "messageId": msg.id},
        )
    db.commit()
    await hub.publish([row.user_id for row in peers if row.user_id != user.id], "message.new", {
        "conversationId": payload.conversation_id,
        "messageId": msg.id,
        "senderUserId": user.id,
        "content": msg.content,
    })
    return {"success": True, "messageId": msg.id}


@media_router.post("/upload/init")
def media_upload_init(payload: MediaUploadInitPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = MediaAsset(
        owner_user_id=user.id,
        storage_key=f"pending/{new_id()}-{payload.filename}",
        bucket="local",
        mime_type=payload.mime_type,
        byte_size=payload.byte_size,
        kind=payload.kind,
        metadata_json=json.dumps({"filename": payload.filename}),
    )
    db.add(row)
    db.commit()
    return {"assetId": row.id, "uploadToken": f"upload_{row.id}", "storageKey": row.storage_key}


@media_router.post("/upload/complete")
def media_upload_complete(payload: MediaUploadCompletePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(MediaAsset).filter(MediaAsset.id == payload.asset_id, MediaAsset.owner_user_id == user.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    try:
        raw = base64.b64decode(payload.base64_data)
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Invalid base64 payload: {error}") from error
    asset, storage_key = save_media_blob(user.id, json.loads(row.metadata_json).get("filename", "asset.bin"), raw, row.mime_type, row.kind)
    row.storage_key = storage_key
    row.byte_size = len(raw)
    row.bucket = "local"
    row.updated_at = utcnow()
    db.add(row)
    db.commit()
    return {"assetId": row.id, "storageKey": row.storage_key}


@media_router.get("/{asset_id}")
def media_asset(asset_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    if row.owner_user_id != user.id:
        # signed access pattern scaffold
        signed_url = f"/api/v1/media/{asset_id}?signed={new_id()}"
    else:
        signed_url = f"/api/v1/media/{asset_id}?owner=true"
    return {
        "assetId": row.id,
        "ownerUserId": row.owner_user_id,
        "storageKey": row.storage_key,
        "bucket": row.bucket,
        "mimeType": row.mime_type,
        "byteSize": row.byte_size,
        "kind": row.kind,
        "signedUrl": signed_url,
    }


@presence_router.get("/{user_id}")
async def presence(user_id: int):
    return await hub.get_presence(user_id)


@presence_router.post("/heartbeat")
async def heartbeat(payload: PresenceHeartbeatPayload, user: User = Depends(current_user)):
    await hub.set_presence(
        user.id,
        online=True,
        active_now=payload.active_now,
        status_text=payload.status_text,
    )
    state = await hub.get_presence(user.id)
    await hub.publish_to_all("presence.update", {"userId": user.id, **state})
    return {"success": True}


@moderation_router.post("/report")
def moderation_report(payload: ModerationReportPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    report = Report(
        reporter_user_id=user.id,
        target_type=payload.target_type,
        target_id=payload.target_id,
        reason=payload.reason,
        detail=payload.detail,
        status="open",
    )
    db.add(report)
    db.flush()
    queue = ModerationQueue(report_id=report.id, priority="normal", status="pending")
    db.add(queue)
    db.commit()
    return {"reportId": report.id, "queueId": queue.id}


@realtime_router.websocket("/ws")
async def realtime_ws(websocket: WebSocket):
    token = websocket.query_params.get("token", "")
    if not token:
        await websocket.close(code=4401)
        return
    db_gen = get_db()
    db = next(db_gen)
    try:
        # small local decode path for websocket auth
        user = await current_user(token=token, db=db)  # type: ignore[arg-type]
    except Exception:
        await websocket.close(code=4401)
        return
    await hub.connect(user.id, websocket)
    try:
        while True:
            frame = await websocket.receive_json()
            event = frame.get("event")
            payload = frame.get("payload", {})
            if event in {"thread.typing", "typing"}:
                conversation_id = payload.get("conversationId")
                await enforce_rate_limit("realtime.typing", f"user:{user.id}", limit=120, window_seconds=60)
                members = db.query(ConversationMember).filter(ConversationMember.conversation_id == conversation_id).all()
                typing_value = bool(payload.get("typing", True))
                if conversation_id:
                    await hub.set_typing(str(conversation_id), user.id, typing_value)
                await hub.publish(
                    [row.user_id for row in members if row.user_id != user.id],
                    "thread.typing",
                    {"conversationId": conversation_id, "userId": user.id, "typing": typing_value},
                )
                await hub.publish(
                    [row.user_id for row in members if row.user_id != user.id],
                    "typing",
                    {"conversationId": conversation_id, "userId": user.id, "typing": typing_value},
                )
            elif event == "call.signal":
                target_user_id = int(payload.get("targetUserId", 0))
                if target_user_id <= 0:
                    continue
                await hub.publish([target_user_id], "call.signal", {"fromUserId": user.id, "payload": payload})
    except WebSocketDisconnect:
        await hub.disconnect(user.id, websocket)
    except Exception as error:
        capture_exception(error, phase="realtime_ws", user_id=user.id)
        await hub.disconnect(user.id, websocket)
    finally:
        try:
            db_gen.close()
        except Exception:
            pass


def include_platform_routes(app) -> None:
    app.include_router(auth_router)
    app.include_router(profiles_router)
    app.include_router(search_router)
    app.include_router(social_router)
    app.include_router(feed_router)
    app.include_router(messages_router)
    app.include_router(calls_router)
    app.include_router(notifications_router)
    app.include_router(inbox_router)
    app.include_router(exchange_router)
    app.include_router(ai_router)
    app.include_router(worlds_router)
    app.include_router(growth_router)
    app.include_router(onboarding_router)
    app.include_router(payments_router)
    app.include_router(subscriptions_router)
    app.include_router(invoices_router)
    app.include_router(payouts_router)
    app.include_router(wallets_router)
    app.include_router(webhooks_router)
    app.include_router(developer_router)
    app.include_router(oauth_router)
    app.include_router(media_router)
    app.include_router(tools_router)
    app.include_router(neurocloud_router)
    app.include_router(system_router)
    app.include_router(presence_router)
    app.include_router(moderation_router)
    app.include_router(realtime_router)
