from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field


class RegisterPayload(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    name: Optional[str] = None
    device_name: Optional[str] = None
    platform: Optional[str] = None


class LoginPayload(BaseModel):
    email: EmailStr
    password: str
    device_name: Optional[str] = None
    platform: Optional[str] = None


class RefreshPayload(BaseModel):
    refresh_token: str


class ProfilePatchPayload(BaseModel):
    display_name: Optional[str] = None
    bio: Optional[str] = None
    discoverable: Optional[bool] = None
    is_private: Optional[bool] = None
    username: Optional[str] = None
    is_business: Optional[bool] = None
    service_description: Optional[str] = None
    is_verified_business: Optional[bool] = None


class PostCreatePayload(BaseModel):
    body: str
    visibility: Literal["public", "followers", "private"] = "public"
    media_asset_ids: list[str] = Field(default_factory=list)


class CommentPayload(BaseModel):
    body: str


class ReactionPayload(BaseModel):
    reaction: str = "like"


class MessageConversationCreatePayload(BaseModel):
    title: Optional[str] = None
    participant_user_ids: list[int]
    is_group: bool = False


class MessageSendPayload(BaseModel):
    content: str
    media_asset_ids: list[str] = Field(default_factory=list)
    encrypted_payload: Optional[str] = None
    key_envelope: Optional[str] = None
    nonce: Optional[str] = None


class MessageReadPayload(BaseModel):
    message_ids: list[str] = Field(default_factory=list)


class CallStartPayload(BaseModel):
    participant_user_ids: list[int]
    call_type: Literal["voice", "video"] = "voice"
    offer_sdp: Optional[str] = None
    ice_candidates: list[str] = Field(default_factory=list)


class CallStatePayload(BaseModel):
    answer_sdp: Optional[str] = None
    ice_candidates: list[str] = Field(default_factory=list)
    reason: Optional[str] = None


class CallIcePayload(BaseModel):
    candidates: list[str] = Field(default_factory=list)
    sdp_mid: Optional[str] = None
    sdp_mline_index: Optional[int] = None


class PushTokenPayload(BaseModel):
    token: str
    platform: str = "ios"
    device_id: Optional[str] = None


class ToolJobPayload(BaseModel):
    tool_id: str
    input: dict = Field(default_factory=dict)


class ShareToolResultPayload(BaseModel):
    caption: Optional[str] = None
    conversation_id: Optional[str] = None


class MediaUploadInitPayload(BaseModel):
    filename: str
    mime_type: str = "application/octet-stream"
    byte_size: int = 0
    kind: str = "generic"


class MediaUploadCompletePayload(BaseModel):
    asset_id: str
    base64_data: str


class PresenceHeartbeatPayload(BaseModel):
    active_now: bool = True
    status_text: Optional[str] = None


class ModerationReportPayload(BaseModel):
    target_type: str
    target_id: str
    reason: str
    detail: Optional[str] = None


class ExchangeRequestPayload(BaseModel):
    recipient_user_id: int
    request_type: str = "general"
    title: str
    body: Optional[str] = None
    source_tool_result_id: Optional[str] = None


class ExchangeRespondPayload(BaseModel):
    exchange_request_id: str
    response: Literal["accept", "decline", "update"] = "accept"
    message: Optional[str] = None
    transaction_status: Optional[str] = None


class PaymentIntentCreatePayload(BaseModel):
    amount: float = Field(gt=0)
    currency: str = "USD"
    intent_type: Literal[
        "tip",
        "subscription",
        "paid_post_unlock",
        "paid_tool_purchase",
        "invoice_payment",
        "business_quote_payment",
    ] = "tip"
    payee_user_id: Optional[int] = None
    rail: Literal["fiat", "stablecoin_usdc"] = "fiat"
    stablecoin: Optional[Literal["usdc"]] = None
    network: Optional[Literal["base", "ethereum", "solana"]] = None
    payment_method_id: Optional[str] = None
    idempotency_key: str
    metadata: dict = Field(default_factory=dict)


class PaymentConfirmPayload(BaseModel):
    payment_method_id: Optional[str] = None
    passkey_assertion: Optional[str] = None
    passkey_challenge_id: Optional[str] = None


class RefundCreatePayload(BaseModel):
    payment_intent_id: str
    amount: Optional[float] = Field(default=None, gt=0)
    reason: Optional[str] = None
    passkey_assertion: Optional[str] = None
    passkey_challenge_id: Optional[str] = None


class SubscriptionCreatePayload(BaseModel):
    creator_user_id: int
    plan_id: Optional[str] = None
    amount: float = Field(gt=0)
    currency: str = "USD"
    rail: Literal["fiat", "stablecoin_usdc"] = "fiat"
    payment_method_id: Optional[str] = None
    idempotency_key: str
    metadata: dict = Field(default_factory=dict)


class SubscriptionCancelPayload(BaseModel):
    cancel_at_period_end: bool = True
    reason: Optional[str] = None


class SubscriptionPlanPayload(BaseModel):
    name: str
    amount: float = Field(gt=0)
    currency: str = "USD"
    billing_interval: Literal["monthly", "yearly"] = "monthly"
    description: Optional[str] = None


class InvoiceCreatePayload(BaseModel):
    recipient_user_id: int
    title: str
    description: Optional[str] = None
    amount: float = Field(gt=0)
    currency: str = "USD"
    due_at: Optional[str] = None
    exchange_request_id: Optional[str] = None
    metadata: dict = Field(default_factory=dict)


class InvoicePayPayload(BaseModel):
    payment_method_id: Optional[str] = None
    rail: Literal["fiat", "stablecoin_usdc"] = "fiat"
    idempotency_key: str
    passkey_assertion: Optional[str] = None
    passkey_challenge_id: Optional[str] = None


class PayoutRequestPayload(BaseModel):
    amount: float = Field(gt=0)
    currency: str = "USD"
    rail: Literal["fiat", "stablecoin_usdc"] = "fiat"
    stablecoin: Optional[Literal["usdc"]] = None
    network: Optional[Literal["base", "ethereum", "solana"]] = None
    destination: Optional[str] = None
    passkey_assertion: Optional[str] = None
    passkey_challenge_id: Optional[str] = None
    metadata: dict = Field(default_factory=dict)


class WalletPreferencePayload(BaseModel):
    network: Literal["base", "ethereum", "solana"]
    address: str
    stablecoin: Literal["usdc"] = "usdc"
    preferred_rail: Literal["fiat", "stablecoin_usdc"] = "stablecoin_usdc"
    label: Optional[str] = None


class PaymentMethodCreatePayload(BaseModel):
    method_type: Literal["card", "bank", "wallet"] = "card"
    provider: str = "internal"
    provider_payment_method_id: Optional[str] = None
    last4: Optional[str] = None
    brand: Optional[str] = None
    exp_month: Optional[int] = None
    exp_year: Optional[int] = None
    billing_name: Optional[str] = None
    billing_email: Optional[EmailStr] = None
    encrypted_reference: Optional[str] = None
    make_default: bool = True
    metadata: dict = Field(default_factory=dict)


class WebhookEventPayload(BaseModel):
    provider: str
    event_id: str
    event_type: str
    signature: str
    payload: dict = Field(default_factory=dict)


class AIJobCreatePayload(BaseModel):
    action: Literal["improve", "summarize", "translate", "create_video", "analyze"]
    input_text: str
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None
    metadata: dict = Field(default_factory=dict)


class ToolListingCreatePayload(BaseModel):
    tool_id: str
    name: str
    description: str
    category: str
    pricing_model: Literal["free", "per_use", "subscription"] = "free"
    price_amount: float = 0.0
    currency: str = "USD"
    tags: list[str] = Field(default_factory=list)
    publish: bool = True


class ToolMarketplaceRunPayload(BaseModel):
    input: dict = Field(default_factory=dict)
    conversation_id: Optional[str] = None
    share_result_in_chat: bool = False


class ToolMarketplaceSubscribePayload(BaseModel):
    billing_interval: Literal["monthly", "yearly"] = "monthly"


class DeveloperAppCreatePayload(BaseModel):
    name: str
    redirect_uri: str
    scopes: list[str] = Field(default_factory=list)
    metadata: dict = Field(default_factory=dict)


class OAuthAuthorizePayload(BaseModel):
    client_id: str
    redirect_uri: str
    scopes: list[str] = Field(default_factory=list)
    state: Optional[str] = None


class OAuthTokenPayload(BaseModel):
    grant_type: Literal["authorization_code"] = "authorization_code"
    client_id: str
    client_secret: str
    code: str
    redirect_uri: str


class DeveloperToolCreatePayload(BaseModel):
    app_id: str
    tool_id: str
    name: str
    description: str
    category: str = "Automation"
    pricing_model: Literal["free", "per_use", "subscription"] = "free"
    price_amount: float = 0.0
    currency: str = "USD"
    tags: list[str] = Field(default_factory=list)
    runtime: str = "python"
    entrypoint: str
    version: str = "1.0.0"
    input_schema: dict = Field(default_factory=dict)
    output_schema: dict = Field(default_factory=dict)
    policy: dict = Field(default_factory=dict)
    publish: bool = True


class DeveloperToolRunPayload(BaseModel):
    input: dict = Field(default_factory=dict)
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None
    insert_message: bool = True
    insert_media: bool = False
    trigger_action: Optional[str] = None


class DeveloperContextPayload(BaseModel):
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None


class WorldSetupPayload(BaseModel):
    child_user_id: int
    theme: Literal["space", "jungle", "city", "ocean"] = "space"
    avatar_style: str = "explorer"
    interests: list[str] = Field(default_factory=list)
    pace: Literal["gentle", "adaptive", "accelerated"] = "adaptive"


class GuardianLinkPayload(BaseModel):
    child_user_id: int


class GuardianPolicyPayload(BaseModel):
    child_user_id: int
    allowed_subjects: list[str] = Field(default_factory=list)
    blocked_topics: list[str] = Field(default_factory=list)
    approved_games: list[str] = Field(default_factory=list)
    approved_content_ids: list[str] = Field(default_factory=list)
    communication_mode: Literal["friends_only", "guardian_only"] = "friends_only"
    allow_social: bool = True
    allow_ai: bool = True
    allow_creative_tools: bool = True
    daily_time_limit_minutes: int = 180
    safety_mode: Literal["strict", "balanced"] = "strict"


class LearningProfilePatchPayload(BaseModel):
    interests: list[str] = Field(default_factory=list)
    strengths: list[str] = Field(default_factory=list)
    weaknesses: list[str] = Field(default_factory=list)
    preferred_style: Literal["visual", "hands_on", "story"] = "visual"
    pace: Literal["gentle", "adaptive", "accelerated"] = "adaptive"


class LessonProgressPayload(BaseModel):
    subject_id: str
    lesson_id: Optional[str] = None
    status: Literal["started", "practiced", "completed"] = "started"
    score: float = 0.0
    feedback: Optional[str] = None


class WorldAIRequestPayload(BaseModel):
    child_user_id: int
    mode: Literal["suggest_activity", "teach", "recommend_content", "creativity_idea"] = "suggest_activity"
    prompt: Optional[str] = None
    subject: Optional[str] = None


class ContentAddPayload(BaseModel):
    title: str
    kind: Literal["movie", "show", "educational", "short"] = "show"
    provider: str = "curated"
    link: str
    age_rating: str = "kids"
    min_age: int = 5
    max_age: int = 18
    tags: list[str] = Field(default_factory=list)


class GameAddPayload(BaseModel):
    title: str
    description: Optional[str] = None
    genre: str = "educational"
    min_age: int = 5
    max_age: int = 18
    multiplayer_mode: Literal["off", "friends_only"] = "friends_only"
    supported_controls: list[str] = Field(default_factory=lambda: ["touch"])


class RewardGrantPayload(BaseModel):
    child_user_id: int
    reward_type: Literal["points", "streak", "achievement", "unlock"] = "points"
    points: int = 10
    title: str
    detail: Optional[str] = None
    source_type: Literal["lesson", "game", "creativity"] = "lesson"
    source_id: Optional[str] = None


class SubjectCreatePayload(BaseModel):
    key: str
    name: str
    description: Optional[str] = None


class LessonCreatePayload(BaseModel):
    subject_id: str
    title: str
    summary: str = ""
    difficulty: int = 1
    estimated_minutes: int = 10
    content: dict = Field(default_factory=dict)
    practice: dict = Field(default_factory=dict)
    quiz: dict = Field(default_factory=dict)
    is_published: bool = True


class GameSessionStartPayload(BaseModel):
    game_id: str
    mode: str = "solo"


class GameSessionEndPayload(BaseModel):
    duration_seconds: int = 0


class SkillTreeCreatePayload(BaseModel):
    subject_id: str
    name: str
    description: Optional[str] = None
    level_count: int = 5


class SkillNodeCreatePayload(BaseModel):
    tree_id: str
    subject_id: str
    code: str
    title: str
    description: Optional[str] = None
    level: int = 1
    mastery_threshold: float = 80.0
    prerequisite_ids: list[str] = Field(default_factory=list)
    assessment_weight: float = 1.0


class AssessmentCreatePayload(BaseModel):
    skill_node_id: str
    assessment_type: Literal["quiz", "interactive_task", "ai_evaluation"] = "quiz"
    title: str
    prompt: Optional[str] = None
    rubric: dict = Field(default_factory=dict)
    max_score: float = 100.0
    required_for_mastery: bool = True


class AssessmentSubmissionPayload(BaseModel):
    assessment_id: str
    child_user_id: int
    response: dict = Field(default_factory=dict)


class SkillMasteryValidatePayload(BaseModel):
    child_user_id: int
    skill_node_id: str
    strict: bool = True


class CertificateIssuePayload(BaseModel):
    child_user_id: int
    subject_group: str
    title: str
    skill_node_ids: list[str] = Field(default_factory=list)


class PortfolioItemPayload(BaseModel):
    child_user_id: int
    item_type: Literal["project", "creative_work", "certificate"] = "project"
    title: str
    description: Optional[str] = None
    artifact_type: Literal["text", "media", "link", "certificate_ref"] = "text"
    artifact_ref: Optional[str] = None
    certificate_id: Optional[str] = None
    skill_node_id: Optional[str] = None
    visibility: Literal["guardian", "private", "shared"] = "guardian"
    metadata: dict = Field(default_factory=dict)


class GrowthEmailIdentityPayload(BaseModel):
    sender_name: str
    sender_email: EmailStr
    reply_to_email: Optional[EmailStr] = None


class GrowthLandingGeneratePayload(BaseModel):
    title: str
    idea: str
    audience: str = "general"
    goal: Literal["waitlist", "signup", "preorder"] = "waitlist"
    cta_text: str = "Join waitlist"
    brand_tone: str = "calm-confident"
    sections: list[str] = Field(default_factory=lambda: ["hero", "social-proof", "faq", "cta"])


class GrowthWaitlistJoinPayload(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    source: str = "landing_form"
    tags: list[str] = Field(default_factory=list)
    metadata: dict = Field(default_factory=dict)


class GrowthCampaignCreatePayload(BaseModel):
    title: str
    subject: str
    body: str
    audience_segment: str = "all"
    schedule_at: Optional[str] = None
    metadata: dict = Field(default_factory=dict)


class GrowthWebsiteProjectPayload(BaseModel):
    title: str
    description: Optional[str] = None
    theme: str = "clean"
    slug: Optional[str] = None


class GrowthWebsitePagePayload(BaseModel):
    title: str
    slug: str
    sections: list[dict] = Field(default_factory=list)
    seo: dict = Field(default_factory=dict)
    published: bool = True


class GrowthAutomationPayload(BaseModel):
    name: str
    trigger_type: Literal["new_lead", "schedule", "campaign_sent"] = "new_lead"
    flow: dict = Field(default_factory=dict)
    active: bool = True


class GrowthCopyGeneratePayload(BaseModel):
    context: str
    channel: Literal["landing", "email", "social"] = "landing"
    goal: str = "conversion"
    audience: str = "general"
    tone: str = "calm-confident"


class GrowthOptimizePayload(BaseModel):
    landing_page_id: str
    focus: Literal["conversion", "clarity", "cta", "mobile"] = "conversion"


class CreatorMoneyFirstPayload(BaseModel):
    content_type: Literal["posts", "videos", "courses", "community", "newsletter"] = "posts"
    monetization_type: Literal["tips", "paid_post", "subscription", "one_time_offer"] = "subscription"
    first_post_text: str
    price_amount: float = Field(gt=0)
    currency: str = "USD"


class BusinessMoneyFirstPayload(BaseModel):
    business_type: Literal["agency", "consulting", "coaching", "commerce", "local_service"] = "consulting"
    service_or_product: str
    first_offer_title: str
    first_offer_description: str
    price_amount: float = Field(gt=0)
    currency: str = "USD"


class ToolBuilderMoneyFirstPayload(BaseModel):
    tool_name: str
    tool_description: str
    category: str = "Automation"
    input_schema: dict = Field(default_factory=dict)
    output_schema: dict = Field(default_factory=dict)
    pricing_model: Literal["free", "per_use", "subscription"] = "per_use"
    price_amount: float = 1.0
    currency: str = "USD"


class NeurocloudPasskeyRegisterBeginPayload(BaseModel):
    nickname: Optional[str] = None


class NeurocloudPasskeyRegisterCompletePayload(BaseModel):
    challenge_id: str
    credential_id: str
    public_key: str
    transports: list[str] = Field(default_factory=list)
    nickname: Optional[str] = None


class NeurocloudPasskeyAuthBeginPayload(BaseModel):
    credential_id: Optional[str] = None


class NeurocloudPasskeyAuthCompletePayload(BaseModel):
    challenge_id: str
    credential_id: str
    signature: str
    sign_count: int = 0


class NeurocloudDeviceTrustPayload(BaseModel):
    device_id: Optional[str] = None
    device_fingerprint: str
    trust_level: Literal["unverified", "verified", "high"] = "verified"
    metadata: dict = Field(default_factory=dict)


class NeurocloudScopedTokenIssuePayload(BaseModel):
    scopes: list[str] = Field(default_factory=list)
    ttl_seconds: int = 900
    issued_for: Optional[str] = None
    metadata: dict = Field(default_factory=dict)


class NeurocloudMemoryPatchPayload(BaseModel):
    preferences: dict = Field(default_factory=dict)
    behavior: dict = Field(default_factory=dict)
    learning_progress: dict = Field(default_factory=dict)


class NeurocloudExecutionPayload(BaseModel):
    action_type: str
    required_scope: Optional[str] = None
    input: dict = Field(default_factory=dict)
    metadata: dict = Field(default_factory=dict)


class NeurocloudCredentialValidatePayload(BaseModel):
    token: str
    required_scopes: list[str] = Field(default_factory=list)
