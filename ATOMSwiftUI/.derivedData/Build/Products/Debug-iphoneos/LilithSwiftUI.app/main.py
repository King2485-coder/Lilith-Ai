import io
import os
import re
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from typing import Any, Optional

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from backend.integrations.legal_ease_adapter import draft_document, extract_clauses, summarize_text
from backend.integrations.wealthwizard_adapter import analyze_spending, approve_transfer, get_balance, get_transactions, simulate_purchase, transfer_funds
from backend.integrations.wealthwizard_api import register_finance_routes
from backend.platform.observability import configure_observability
from backend.platform.realtime import hub as realtime_hub
from backend.platform.routers import include_platform_routes
from backend.platform.seed import seed_platform_data
import backend.platform.models  # noqa: F401 - ensure platform tables register on Base metadata
from backend.state import ActivityEvent, ApprovalRequest, ChatMessage, CloneArtifact, Conversation, MemoryItem, Project, ProjectFile, SessionLocal, User, ensure_conversation, init_db, iso, json_dumps, json_loads, list_tool_registry, message_to_dict, record_activity, seed_all_users, seed_user_workspace, serialize_activity, serialize_conversation_list_item, serialize_memory, serialize_project, serialize_user, utcnow
from backend.tool_engines import analyze_html_structure, build_prompt_from_html, export_pdf_bytes, inspect_pdf_bytes


JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "antoniohoshaw6@gmail.com").lower()
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "123456")
MASTER_TOKEN = os.getenv("MASTER_TOKEN", "LILITH_MASTER_TOKEN")

DEFAULT_ALLOWED_ORIGINS = [
    "http://localhost:4173",
    "http://127.0.0.1:4173",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "https://lilithai.one",
    "https://www.lilithai.one",
    "https://whimsical-dieffenbachia-d116b9.netlify.app",
]
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv("ALLOWED_ORIGINS", ",".join(DEFAULT_ALLOWED_ORIGINS)).split(",")
    if origin.strip()
]

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
ALGORITHM = "HS256"
TINY_PNG_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA"
    "ASsJTYQAAAAASUVORK5CYII="
)
SAMPLE_VIDEO_URL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class CreateProjectPayload(BaseModel):
    name: str
    description: Optional[str] = None


class AddFilePayload(BaseModel):
    name: str
    content: str = ""
    language: Optional[str] = None


class UpdateFilePayload(BaseModel):
    content: str


class CodeExecutePayload(BaseModel):
    code: str
    language: str
    project_id: Optional[str] = None


class CodeReviewPayload(BaseModel):
    code: str
    language: str
    project_id: Optional[str] = None


class AutoFixLoopPayload(BaseModel):
    code: str
    language: str
    project_id: Optional[str] = None


class ImageGenerationPayload(BaseModel):
    prompt: str


class VideoGenerationPayload(BaseModel):
    prompt: str
    size: Optional[str] = None
    duration: Optional[int] = None


class BrowserSearchRequest(BaseModel):
    query: str


class CloneSitePayload(BaseModel):
    url: str


class LinkPromptPayload(BaseModel):
    url: str


app = FastAPI(title="Lilith Backend", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
include_platform_routes(app)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    payload = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=JWT_EXPIRE_MINUTES))
    payload.update({"exp": expire})
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email.lower()).first()


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    user = get_user_by_email(db, email)
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user


def ensure_admin_user() -> None:
    db = SessionLocal()
    try:
        user = get_user_by_email(db, ADMIN_EMAIL)
        if user is None:
            user = User(
                email=ADMIN_EMAIL,
                hashed_password=hash_password(ADMIN_PASSWORD),
                name="Lilith Owner",
                role="super_admin",
                credits=9999999,
                is_super_admin=True,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            user.hashed_password = hash_password(ADMIN_PASSWORD)
            user.name = user.name or "Lilith Owner"
            user.role = "super_admin"
            user.credits = 9999999
            user.is_super_admin = True
            db.commit()
        seed_user_workspace(db, user)
    finally:
        db.close()


async def get_bearer_token(authorization: Optional[str] = Header(None)) -> str:
    from fastapi.security.utils import get_authorization_scheme_param

    scheme, token = get_authorization_scheme_param(authorization or "")
    if not authorization or scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token


async def get_current_user_dep(
    token: str = Depends(get_bearer_token),
    db: Session = Depends(get_db),
) -> User:
    if token == MASTER_TOKEN:
        user = get_user_by_email(db, ADMIN_EMAIL)
        if user is None:
            raise HTTPException(status_code=401, detail="Master user not available")
        return user

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if not email:
            raise credentials_exception
    except JWTError as error:
        raise credentials_exception from error

    user = get_user_by_email(db, email)
    if user is None:
        raise credentials_exception
    return user


@app.on_event("startup")
def startup_event():
    configure_observability()
    init_db()
    ensure_admin_user()
    db = SessionLocal()
    try:
        seed_all_users(db)
        seed_platform_data(db, hash_password)
    finally:
        db.close()


@app.on_event("shutdown")
async def shutdown_event():
    await realtime_hub.shutdown()


@app.get("/")
def root():
    return {"status": "Lilith backend running", "product": "Lilith"}


@app.get("/api/health")
def health():
    return {"status": "ok", "timestamp": utcnow().isoformat()}


def auth_response(user: User) -> dict[str, Any]:
    access_token = create_access_token({"sub": user.email})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": serialize_user(user),
        "success": True,
    }


@app.post("/auth/register")
@app.post("/api/auth/register")
async def register(payload: UserCreate, db: Session = Depends(get_db)):
    email = payload.email.lower()
    if get_user_by_email(db, email):
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        email=email,
        hashed_password=hash_password(payload.password),
        name=(payload.name or email.split("@")[0]).strip() or "Lilith User",
        role="user",
        credits=24.0,
        is_super_admin=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    seed_user_workspace(db, user)
    return auth_response(user)


@app.post("/auth/login")
@app.post("/api/auth/login")
async def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = authenticate_user(db, payload.email.lower(), payload.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    seed_user_workspace(db, user)
    return auth_response(user)


@app.get("/auth/me")
@app.get("/api/auth/me")
async def me(current_user: User = Depends(get_current_user_dep)):
    return serialize_user(current_user)


@app.post("/auth/logout")
@app.post("/api/auth/logout")
async def logout():
    return {"success": True, "message": "Logged out"}


def make_subscription(user: User) -> dict[str, Any]:
    if user.is_super_admin:
        plan = "owner"
        status_value = "active"
    else:
        plan = "pro" if (user.credits or 0) > 100 else "free"
        status_value = "active"
    return {
        "subscription": {
            "plan": plan,
            "status": status_value,
            "currentPeriodStart": (utcnow() - timedelta(days=3)).isoformat(),
            "currentPeriodEnd": (utcnow() + timedelta(days=27)).isoformat(),
        },
        "credits": None if user.is_super_admin else float(user.credits or 0.0),
        "isSuperAdmin": bool(user.is_super_admin),
    }


@app.get("/api/user/credits")
async def user_credits(current_user: User = Depends(get_current_user_dep)):
    return {
        "credits": None if current_user.is_super_admin else float(current_user.credits or 0.0),
        "isSuperAdmin": bool(current_user.is_super_admin),
        "unlimited": bool(current_user.is_super_admin),
    }


@app.get("/api/subscription")
async def subscription(current_user: User = Depends(get_current_user_dep)):
    return make_subscription(current_user)


@app.get("/api/admin/stats")
async def admin_stats(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    if not current_user.is_super_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return {
        "users": {
            "total": db.query(User).count(),
            "active": db.query(User).count(),
            "premium": db.query(User).filter(User.credits > 100).count(),
            "free": db.query(User).filter((User.credits <= 100) | (User.credits.is_(None))).count(),
        },
        "content": {
            "conversations": db.query(Conversation).count(),
            "projects": db.query(Project).count(),
            "videos": 0,
            "images": 0,
        },
    }


def _conversation_or_404(db: Session, user: User, conversation_id: str) -> Conversation:
    conversation = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id, Conversation.user_id == user.id)
        .first()
    )
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation


@app.get("/api/conversations")
async def conversations(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Conversation)
        .filter(Conversation.user_id == current_user.id)
        .order_by(Conversation.updated_at.desc())
        .all()
    )
    return [serialize_conversation_list_item(row) for row in rows]


@app.get("/api/conversations/{conversation_id}")
async def conversation_detail(
    conversation_id: str,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    conversation = _conversation_or_404(db, current_user, conversation_id)
    return {
        "id": conversation.id,
        "title": conversation.title,
        "messages": [message_to_dict(message) for message in conversation.messages],
    }


@app.delete("/api/conversations/{conversation_id}")
async def conversation_delete(
    conversation_id: str,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    conversation = _conversation_or_404(db, current_user, conversation_id)
    db.delete(conversation)
    record_activity(
        db,
        current_user.id,
        kind="activity",
        title="Conversation deleted",
        detail=conversation.title,
    )
    db.commit()
    return {}


def _extract_amount(text: str) -> Optional[float]:
    match = re.search(r"\$?\s*([0-9]+(?:\.[0-9]{1,2})?)", text)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _parse_transfer_accounts(text: str) -> tuple[str, str]:
    lower = text.lower()
    source = "Checking"
    destination = "Savings"
    if "from savings" in lower:
        source = "Savings"
    if "to checking" in lower:
        destination = "Checking"
    if "to savings" in lower:
        destination = "Savings"
    return source, destination


def _detect_intent(text: str) -> str:
    lower = text.lower()
    if lower.startswith("/plan"):
        return "planner"
    if lower.startswith("/approve"):
        return "approval"
    if lower.startswith("/memory") or lower.startswith("remember that"):
        return "memory"
    if lower.startswith("/device"):
        return "device"
    if any(keyword in lower for keyword in ["balance", "transaction", "spend", "spent", "afford", "budget", "transfer", "finance", "purchase"]):
        return "finance"
    if any(keyword in lower for keyword in ["contract", "legal", "agreement", "clause", "nda", "summary", "document", "terms"]):
        return "legal"
    if any(keyword in lower for keyword in ["image", "photo", "render", "picture"]):
        return "image"
    if any(keyword in lower for keyword in ["video", "animate", "clip"]):
        return "video"
    if any(keyword in lower for keyword in ["clone", "website", "landing page", "site"]):
        return "clone"
    if any(keyword in lower for keyword in ["code", "bug", "fix", "function", "python", "swift", "html"]):
        return "code"
    if any(keyword in lower for keyword in ["history", "activity", "what happened"]):
        return "activity"
    if any(keyword in lower for keyword in ["tool", "capability", "what can you do"]):
        return "tools"
    return "chat"


def _respond_finance(db: Session, user: User, text: str) -> tuple[str, str, dict[str, Any]]:
    lower = text.lower()
    if "transfer" in lower:
        amount = _extract_amount(text)
        if amount is None:
            return (
                "I used Finance and need an amount before I can prepare the transfer preview.",
                "Finance",
                {},
            )
        source, destination = _parse_transfer_accounts(text)
        result = transfer_funds(db, user, amount=amount, source_account=source, destination_account=destination, require_approval=True)
        assistant = (
            f"I used Finance to prepare that transfer. Approval is required before Lilith executes it.\n\n"
            f"Preview: {result['preview']}\nApproval ID: {result['approvalId']}"
        )
        return assistant, "Finance", {"approvalRequest": result, "preview": result.get("preview")}

    if "approve" in lower:
        approval_match = re.search(r"(?:approve|approval)\s+([a-f0-9\-]{8,})", lower)
        if approval_match:
            result = approve_transfer(db, user, approval_match.group(1))
            transfer = result["transfer"]
            assistant = (
                f"I used Finance to execute the approved transfer. "
                f"${transfer['amount']:,.2f} moved from {transfer['source']} to {transfer['destination']}."
            )
            return assistant, "Finance", {"execution": result}

    if "afford" in lower or "simulate" in lower:
        amount = _extract_amount(text) or 0.0
        simulation = simulate_purchase(db, user, amount=amount, merchant="Purchase")
        assistant = f"I used Finance to simulate that purchase. {simulation['message']}"
        return assistant, "Finance", {"simulation": simulation}

    if "spend" in lower or "analyze" in lower:
        days = 30 if "month" in lower else 7
        analysis = analyze_spending(db, user, days=days)
        top_categories = ", ".join(
            f"{item['category']} ${item['amount']:,.2f}" for item in analysis["topCategories"]
        ) or "no major categories yet"
        assistant = (
            f"I used Finance to analyze your spending over the last {days} days. "
            f"You spent ${analysis['spent']:,.2f}, {analysis['percentChange']}% versus the prior window. "
            f"Top categories: {top_categories}."
        )
        return assistant, "Finance", {"analysis": analysis}

    if "transaction" in lower:
        transactions = get_transactions(db, user, days=30, limit=5)["transactions"]
        lines = "\n".join(
            f"- {item['merchant']}: ${abs(item['amount']):,.2f} on {item['occurredAt'][:10]}"
            for item in transactions
        )
        assistant = f"I used Finance to pull your recent transactions.\n{lines or '- No recent transactions found.'}"
        return assistant, "Finance", {"transactions": transactions}

    balance = get_balance(db, user)
    checking = next((account for account in balance["accounts"] if account["kind"] == "checking"), None)
    assistant = (
        f"I used Finance to check your balances. "
        f"Total available cash is ${balance['totalBalance']:,.2f}."
    )
    if checking:
        assistant += f" Checking currently holds ${checking['balance']:,.2f}."
    return assistant, "Finance", {"balance": balance}


def _respond_legal(db: Session, user: User, text: str) -> tuple[str, str, dict[str, Any]]:
    lower = text.lower()
    if "clause" in lower or "extract" in lower:
        result = extract_clauses(db, user, text, title="Clause extraction")
        labels = ", ".join(clause["label"] for clause in result["clauses"])
        assistant = f"I used Legal to extract likely clauses from that text. I found: {labels}."
        return assistant, "Legal", result

    if any(keyword in lower for keyword in ["draft", "agreement", "nda", "document", "contract"]):
        doc_type = "NDA" if "nda" in lower else "General Agreement"
        result = draft_document(db, user, prompt=text, document_type=doc_type)
        assistant = (
            f"I used Legal to draft a {doc_type}. "
            "Open the Legal tab if you want to keep editing the generated document."
        )
        return assistant, "Legal", result

    result = summarize_text(db, user, text, title="Legal summary")
    assistant = f"I used Legal to summarize that material. Summary: {result['summary']}"
    return assistant, "Legal", result


def _respond_memory(db: Session, user: User, text: str) -> tuple[str, str, dict[str, Any]]:
    value = text.split("remember", 1)[-1].strip(" :.-")
    if not value:
        memories = db.query(MemoryItem).filter(MemoryItem.user_id == user.id).order_by(MemoryItem.updated_at.desc()).limit(5).all()
        memory_lines = "\n".join(f"- {memory.label}: {memory.value}" for memory in memories)
        assistant = f"I checked Memory. Current learned context:\n{memory_lines or '- No memories stored yet.'}"
        return assistant, "Memory", {"memories": [serialize_memory(memory) for memory in memories]}

    memory = MemoryItem(user_id=user.id, label=f"preference-{utcnow().strftime('%H%M%S')}", value=value, source="chat")
    db.add(memory)
    record_activity(db, user.id, kind="memory", title="Memory updated", detail=value)
    db.commit()
    assistant = f"I added that to Memory so Lilith can reuse it later: {value}"
    return assistant, "Memory", {"memory": serialize_memory(memory)}


def _respond_planner(text: str) -> tuple[str, str, dict[str, Any]]:
    body = text.split("/plan", 1)[-1].strip() or "your request"
    plan = [
        {"step": f"Understand the goal for {body}", "status": "completed"},
        {"step": "Preview the safest route and required tools", "status": "completed"},
        {"step": "Execute after confirmations for sensitive actions", "status": "pending"},
    ]
    assistant = (
        "I used Planner to frame the work. "
        "Lilith will preview the route first, then ask for approval before sensitive execution."
    )
    return assistant, "Planner", {"plan": plan}


def _respond_device(db: Session, user: User, text: str) -> tuple[str, str, dict[str, Any]]:
    lower = text.lower()
    if "finance" in lower:
        detail = "Open Finance tab"
    elif "legal" in lower:
        detail = "Open Legal tab"
    elif "memory" in lower or "settings" in lower:
        detail = "Open Memory & Settings tab"
    else:
        detail = "Open Tools tab"
    record_activity(db, user.id, kind="device", title="Device control preview", detail=detail)
    db.commit()
    assistant = (
        f"I used Device Control to prepare a safe navigation action: {detail}. "
        "Execute it from the Lilith interface if you want to switch context."
    )
    return assistant, "Device Control", {"preview": detail}


def _respond_tools() -> tuple[str, str, dict[str, Any]]:
    tools = list_tool_registry()
    categories = ", ".join(tool["title"] for tool in tools[:6])
    assistant = f"Lilith keeps these capabilities available behind the chat surface: {categories}, and more in the Tools tab."
    return assistant, "Tools", {"tools": tools}


def _respond_general(text: str) -> tuple[str, str, dict[str, Any]]:
    assistant = (
        "Lilith is ready. "
        "Ask naturally and I’ll route through Finance, Legal, Builder, Memory, or other tools as needed."
    )
    if text.strip():
        assistant += f" You said: {text.strip()}"
    return assistant, "Assistant", {}


def build_chat_response(db: Session, user: User, text: str) -> tuple[str, str, dict[str, Any]]:
    intent = _detect_intent(text)
    if intent == "finance":
        return _respond_finance(db, user, text)
    if intent == "approval":
        return _respond_finance(db, user, text)
    if intent == "legal":
        return _respond_legal(db, user, text)
    if intent == "memory":
        return _respond_memory(db, user, text)
    if intent == "planner":
        return _respond_planner(text)
    if intent == "device":
        return _respond_device(db, user, text)
    if intent == "tools":
        return _respond_tools()
    if intent == "image":
        return (
            "I used Media framing to route that request. Open the Image tool if you want Lilith to render it.",
            "Image",
            {"tabHint": "tools.image"},
        )
    if intent == "video":
        return (
            "I used Media framing to route that request. Open the Video tool if you want Lilith to generate it.",
            "Video",
            {"tabHint": "tools.video"},
        )
    if intent == "clone":
        return (
            "I used Builder routing to identify that as a site-clone task. Open the Clone tool to fetch and preview the page.",
            "Clone",
            {"tabHint": "tools.clone"},
        )
    if intent == "code":
        return (
            "I used Builder routing to classify that as a code task. Open the Code Workspace if you want to edit, review, or execute files.",
            "Builder",
            {"tabHint": "tools.code"},
        )
    if intent == "activity":
        return (
            "I used Activity routing for that request. Open the Activity tab to inspect prior tasks, approvals, and results.",
            "Activity",
            {"tabHint": "activity"},
        )
    return _respond_general(text)


@app.post("/api/chat")
async def chat(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    user_message = body.get("message") or body.get("prompt") or body.get("content") or "Hello"
    conversation = ensure_conversation(db, current_user, body.get("conversationId"), user_message)

    user_msg = ChatMessage(conversation_id=conversation.id, role="user", content=user_message)
    db.add(user_msg)
    db.flush()

    assistant_text, tool_used, payload = build_chat_response(db, current_user, user_message)
    assistant_msg = ChatMessage(
        conversation_id=conversation.id,
        role="assistant",
        content=assistant_text,
        tool_used=tool_used,
    )
    db.add(assistant_msg)
    conversation.updated_at = utcnow()
    record_activity(
        db,
        current_user.id,
        kind="chat",
        title=f"{tool_used} reply",
        detail=user_message[:160],
        metadata={"toolUsed": tool_used, "conversationId": conversation.id},
    )
    db.commit()
    db.refresh(assistant_msg)
    return {
        "success": True,
        "conversationId": conversation.id,
        "messageId": assistant_msg.id,
        "response": assistant_text,
        "message": assistant_text,
        "reply": assistant_text,
        "content": assistant_text,
        "text": assistant_text,
        "toolUsed": tool_used,
        "data": {
            "message": assistant_text,
            "reply": assistant_text,
            "content": assistant_text,
            "text": assistant_text,
        },
        "chat": {
            "id": assistant_msg.id,
            "role": "assistant",
            "message": assistant_text,
            "content": assistant_text,
        },
        "messages": [
            {
                "id": assistant_msg.id,
                "role": "assistant",
                "content": assistant_text,
            }
        ],
        **payload,
    }


@app.get("/api/activity")
async def activity_feed(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    events = (
        db.query(ActivityEvent)
        .filter(ActivityEvent.user_id == current_user.id)
        .order_by(ActivityEvent.created_at.desc())
        .limit(100)
        .all()
    )
    return {"items": [serialize_activity(event) for event in events]}


@app.get("/api/history")
async def history_list(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    conversations = (
        db.query(Conversation)
        .filter(Conversation.user_id == current_user.id)
        .order_by(Conversation.updated_at.desc())
        .limit(20)
        .all()
    )
    return {
        "success": True,
        "items": [
            {
                "id": conversation.id,
                "title": conversation.title,
                "timestamp": iso(conversation.updated_at),
            }
            for conversation in conversations
        ],
    }


@app.get("/api/tools")
async def tools_registry(current_user: User = Depends(get_current_user_dep)):
    _ = current_user
    return {"tools": list_tool_registry()}


@app.get("/api/memory")
async def memory_list(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    items = (
        db.query(MemoryItem)
        .filter(MemoryItem.user_id == current_user.id)
        .order_by(MemoryItem.updated_at.desc())
        .all()
    )
    return {"items": [serialize_memory(item) for item in items]}


@app.post("/api/memory")
async def memory_create(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    label = body.get("label") or f"memory-{utcnow().strftime('%H%M%S')}"
    value = (body.get("value") or "").strip()
    if not value:
        raise HTTPException(status_code=400, detail="Memory value is required")
    item = MemoryItem(user_id=current_user.id, label=label, value=value, source=body.get("source", "manual"))
    db.add(item)
    record_activity(db, current_user.id, kind="memory", title="Memory saved", detail=value)
    db.commit()
    db.refresh(item)
    return serialize_memory(item)


@app.get("/api/settings")
async def settings_get(current_user: User = Depends(get_current_user_dep)):
    return json_loads(current_user.settings_json)


@app.put("/api/settings")
async def settings_update(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    incoming = await _safe_json(request)
    current = json_loads(current_user.settings_json)
    current.update(incoming)
    current_user.settings_json = json_dumps(current)
    record_activity(db, current_user.id, kind="settings", title="Settings updated", detail=None)
    db.add(current_user)
    db.commit()
    return current


@app.get("/api/device/actions")
async def device_actions(current_user: User = Depends(get_current_user_dep)):
    _ = current_user
    return {
        "actions": [
            {"id": "open_finance", "title": "Open Finance", "safe": True},
            {"id": "open_legal", "title": "Open Legal", "safe": True},
            {"id": "open_memory", "title": "Open Memory & Settings", "safe": True},
            {"id": "review_approvals", "title": "Review Pending Approvals", "safe": True},
        ]
    }


@app.post("/api/device/actions")
async def device_action_preview(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    action_id = body.get("actionId", "open_tools")
    mapping = {
        "open_finance": "Open Finance tab",
        "open_legal": "Open Legal tab",
        "open_memory": "Open Memory & Settings tab",
        "review_approvals": "Open Activity and focus approvals",
    }
    preview = mapping.get(action_id, "Open Tools tab")
    record_activity(db, current_user.id, kind="device", title="Device action previewed", detail=preview)
    db.commit()
    return {"actionId": action_id, "preview": preview, "status": "ready"}


@app.post("/api/legal/summary")
async def legal_summary_route(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    text = body.get("text") or body.get("content") or body.get("prompt") or ""
    if not text.strip():
        raise HTTPException(status_code=400, detail="Text is required")
    return summarize_text(db, current_user, text, title=body.get("title", "Legal summary"))


@app.post("/api/legal/draft")
async def legal_draft_route(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    prompt = body.get("prompt") or body.get("text") or ""
    document_type = body.get("documentType", "General Agreement")
    parties = body.get("parties") or []
    return draft_document(db, current_user, prompt=prompt, document_type=document_type, parties=parties)


@app.post("/api/legal/clauses")
async def legal_clause_route(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    text = body.get("text") or body.get("content") or body.get("prompt") or ""
    if not text.strip():
        raise HTTPException(status_code=400, detail="Text is required")
    return extract_clauses(db, current_user, text, title=body.get("title", "Clause extraction"))


register_finance_routes(app, get_db, get_current_user_dep)


@app.get("/api/projects")
async def projects_list(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    projects = (
        db.query(Project)
        .filter(Project.user_id == current_user.id)
        .order_by(Project.updated_at.desc())
        .all()
    )
    return [serialize_project(project) for project in projects]


def _project_or_404(db: Session, user: User, project_id: str) -> Project:
    project = db.query(Project).filter(Project.id == project_id, Project.user_id == user.id).first()
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


@app.post("/api/projects")
async def project_create(
    payload: CreateProjectPayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = Project(user_id=current_user.id, name=payload.name.strip(), description=payload.description)
    db.add(project)
    db.flush()
    starter_file = ProjectFile(
        project_id=project.id,
        name="notes.md",
        path="notes.md",
        content="# New project\n",
        language="markdown",
    )
    db.add(starter_file)
    record_activity(db, current_user.id, kind="builder", title="Project created", detail=project.name)
    db.commit()
    db.refresh(project)
    return serialize_project(project)


@app.get("/api/projects/{project_id}")
async def project_detail(
    project_id: str,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = _project_or_404(db, current_user, project_id)
    return serialize_project(project)


@app.delete("/api/projects/{project_id}")
async def project_delete(
    project_id: str,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = _project_or_404(db, current_user, project_id)
    db.delete(project)
    record_activity(db, current_user.id, kind="builder", title="Project deleted", detail=project.name)
    db.commit()
    return {}


@app.post("/api/projects/{project_id}/files")
async def project_add_file(
    project_id: str,
    payload: AddFilePayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = _project_or_404(db, current_user, project_id)
    existing = next((file for file in project.files if file.name == payload.name), None)
    if existing:
        raise HTTPException(status_code=400, detail="File already exists")
    file = ProjectFile(
        project_id=project.id,
        name=payload.name,
        path=payload.name,
        content=payload.content,
        language=payload.language or _infer_language(payload.name),
    )
    project.updated_at = utcnow()
    db.add(file)
    db.add(project)
    db.commit()
    db.refresh(project)
    return serialize_project(project)


@app.put("/api/projects/{project_id}/files/{file_name}")
async def project_update_file(
    project_id: str,
    file_name: str,
    payload: UpdateFilePayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = _project_or_404(db, current_user, project_id)
    file = next((row for row in project.files if row.name == file_name), None)
    if file is None:
        raise HTTPException(status_code=404, detail="File not found")
    file.content = payload.content
    file.updated_at = utcnow()
    project.updated_at = utcnow()
    db.add_all([file, project])
    db.commit()
    return serialize_project(project)


@app.delete("/api/projects/{project_id}/files/{file_name}")
async def project_delete_file(
    project_id: str,
    file_name: str,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    project = _project_or_404(db, current_user, project_id)
    file = next((row for row in project.files if row.name == file_name), None)
    if file is None:
        raise HTTPException(status_code=404, detail="File not found")
    db.delete(file)
    project.updated_at = utcnow()
    db.add(project)
    db.commit()
    return {}


def _infer_language(name: str) -> str:
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else "text"
    mapping = {
        "py": "python",
        "js": "javascript",
        "ts": "typescript",
        "html": "html",
        "css": "css",
        "json": "json",
        "md": "markdown",
        "swift": "swift",
    }
    return mapping.get(ext, "text")


def _run_python(code: str) -> tuple[bool, str]:
    buffer = io.StringIO()
    allowed_builtins = {
        "print": print,
        "range": range,
        "len": len,
        "str": str,
        "int": int,
        "float": float,
        "dict": dict,
        "list": list,
        "set": set,
        "sum": sum,
        "min": min,
        "max": max,
        "enumerate": enumerate,
    }
    scope = {"__builtins__": allowed_builtins}
    try:
        compiled = compile(code, "<lilith>", "exec")
        with redirect_stdout(buffer):
            exec(compiled, scope, {})
        output = buffer.getvalue().strip() or "Executed successfully with no output."
        return True, output
    except Exception as error:
        return False, str(error)


@app.post("/api/code/execute")
async def code_execute(
    payload: CodeExecutePayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    language = payload.language.lower()
    if language == "python":
        success, output = _run_python(payload.code)
        record_activity(db, current_user.id, kind="builder", title="Code executed", detail=language, status="completed" if success else "failed")
        db.commit()
        return {"success": success, "output": output if success else None, "error": None if success else output}
    if language == "json":
        try:
            import json as _json

            parsed = _json.loads(payload.code)
            pretty = _json.dumps(parsed, indent=2)
            return {"success": True, "output": pretty, "error": None}
        except Exception as error:
            return {"success": False, "output": None, "error": str(error)}
    if language == "html":
        return {"success": True, "output": "HTML preview ready.", "error": None}
    return {
        "success": True,
        "output": f"Execution guard kept this as a preview for {language}. Review in the IDE before running externally.",
        "error": None,
    }


@app.post("/api/code/review")
async def code_review(
    payload: CodeReviewPayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    suggestions = []
    code = payload.code
    if "TODO" in code:
        suggestions.append({"title": "Resolve TODO markers", "detail": "The file still contains TODO markers that look user-visible.", "severity": "medium"})
    if payload.language.lower() == "python" and "except:" in code:
        suggestions.append({"title": "Use explicit exceptions", "detail": "A bare except will hide actionable failures. Catch specific exceptions instead.", "severity": "high"})
    if len(code.splitlines()) > 150:
        suggestions.append({"title": "Split large file", "detail": "The file is long enough that extracting smaller units would improve readability.", "severity": "low"})
    if not suggestions:
        suggestions.append({"title": "No critical review findings", "detail": "The file looks coherent for a quick pass. Consider adding tests around edge cases.", "severity": "low"})
    record_activity(db, current_user.id, kind="builder", title="Code reviewed", detail=payload.language)
    db.commit()
    return {"summary": "Lilith reviewed the current file.", "suggestions": suggestions}


@app.post("/api/code/autofix-loop")
async def code_autofix_loop(payload: AutoFixLoopPayload):
    code = payload.code
    if payload.language.lower() == "json":
        try:
            import json as _json

            final_code = _json.dumps(_json.loads(code), indent=2)
            return {"success": True, "finalCode": final_code, "output": "Formatted JSON successfully.", "totalAttempts": 1}
        except Exception as error:
            return {"success": False, "finalCode": code, "output": str(error), "totalAttempts": 1}
    return {
        "success": True,
        "finalCode": code,
        "output": "Lilith kept the current code unchanged after previewing fixes.",
        "totalAttempts": 1,
    }


@app.post("/api/image/generate")
async def image_generate(payload: ImageGenerationPayload):
    return {
        "imageId": "img-1",
        "imageData": TINY_PNG_BASE64,
        "textResponse": f"Generated image preview for: {payload.prompt}",
    }


@app.post("/api/video/generate")
async def video_generate(payload: VideoGenerationPayload):
    return {
        "videoId": "video-demo",
        "status": "processing",
        "videoUrl": SAMPLE_VIDEO_URL,
        "textResponse": f"Prepared a video job for: {payload.prompt}",
    }


@app.post("/api/video/from-media")
@app.post("/api/video/from-upload")
async def video_from_media(request: Request):
    prompt = request.query_params.get("prompt", "")
    return {
        "videoId": "video-upload-demo",
        "status": "processing",
        "videoUrl": SAMPLE_VIDEO_URL,
        "textResponse": f"Prepared a video remix upload for: {prompt or 'your prompt'}",
    }


@app.get("/api/video/status/{video_id}")
async def video_status(video_id: str):
    return {"videoId": video_id, "status": "completed", "videoUrl": SAMPLE_VIDEO_URL}


@app.post("/api/browser/search")
async def browser_search(payload: BrowserSearchRequest):
    query = payload.query.strip() or "latest AI news"
    results = [
        {
            "title": "Lilith capability guide",
            "url": "https://example.com/lilith",
            "snippet": "Overview of Lilith chat, planner, finance, legal, and activity flows.",
        },
        {
            "title": "WealthWizard finance notes",
            "url": "https://example.com/wealthwizard",
            "snippet": "Balance, transfer approvals, and transaction analysis patterns.",
        },
        {
            "title": "Legal Ease drafting checklist",
            "url": "https://example.com/legal-ease",
            "snippet": "Draft, summarize, and extract clause flows for legal review.",
        },
    ]
    return {"success": True, "engine": "Lilith", "query": query, "results": results}


@app.post("/api/clone")
@app.post("/api/clone/site")
async def clone_site(
    payload: CloneSitePayload,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    html = ""
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
            response = await client.get(payload.url)
            response.raise_for_status()
            html = response.text
    except Exception:
        html = f"<!doctype html><html><body><h1>Clone preview for {payload.url}</h1><p>Remote fetch failed, so Lilith prepared a local scaffold preview instead.</p></body></html>"

    artifact = CloneArtifact(user_id=current_user.id, url=payload.url, html=html)
    db.add(artifact)
    record_activity(db, current_user.id, kind="builder", title="Site cloned", detail=payload.url)
    db.commit()
    db.refresh(artifact)
    structure = analyze_html_structure(html)
    return {
        "id": artifact.id,
        "url": payload.url,
        "code": html,
        "previewUrl": f"/api/clone/preview/{artifact.id}",
        "structure": structure,
    }


@app.get("/api/clone/preview/{clone_id}", response_class=HTMLResponse)
async def clone_preview(
    clone_id: str,
    db: Session = Depends(get_db),
):
    artifact = (
        db.query(CloneArtifact)
        .filter(CloneArtifact.id == clone_id)
        .first()
    )
    if artifact is None:
        raise HTTPException(status_code=404, detail="Clone preview not found")
    return HTMLResponse(content=artifact.html)


@app.post("/api/clone/structure")
async def clone_structure(
    payload: CloneSitePayload,
    current_user: User = Depends(get_current_user_dep),
):
    _ = current_user
    html = ""
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=12.0) as client:
            response = await client.get(payload.url)
            response.raise_for_status()
            html = response.text
    except Exception:
        html = (
            f"<!doctype html><html><body><header><h1>Clone fallback for {payload.url}</h1></header>"
            "<section><p>Remote fetch unavailable. Showing structural fallback.</p></section>"
            "<footer>Generated by Lilith</footer></body></html>"
        )
    return {
        "url": payload.url,
        "structure": analyze_html_structure(html),
        "fallback": "Remote fetch unavailable, returned structural fallback." if "Clone fallback" in html else None,
    }


@app.post("/api/link/prompt")
async def link_prompt(
    payload: LinkPromptPayload,
    current_user: User = Depends(get_current_user_dep),
):
    _ = current_user
    html = ""
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=12.0) as client:
            response = await client.get(payload.url)
            response.raise_for_status()
            html = response.text
        result = build_prompt_from_html(payload.url, html)
        result["fallback"] = None
        return result
    except Exception:
        fallback_html = (
            f"<!doctype html><html><body><h1>Link analysis fallback for {payload.url}</h1>"
            "<section><p>Remote content unavailable.</p></section></body></html>"
        )
        result = build_prompt_from_html(payload.url, fallback_html)
        result["fallback"] = "Remote fetch unavailable, generated prompt from fallback structure."
        return result


@app.post("/api/pdf/inspect")
async def pdf_inspect(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
):
    _ = current_user
    body = await _safe_json(request)
    filename = str(body.get("filename") or "document.pdf")
    base64_data = str(body.get("base64") or "")
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Upload a PDF file.")
    if not base64_data:
        raise HTTPException(status_code=400, detail="Missing PDF payload.")
    try:
        import base64

        data = base64.b64decode(base64_data)
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Invalid PDF payload: {error}") from error
    if not data:
        raise HTTPException(status_code=400, detail="PDF file is empty.")
    inspection = inspect_pdf_bytes(data)
    return {"filename": filename, **inspection}


@app.post("/api/pdf/export")
async def pdf_export(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
):
    _ = current_user
    body = await _safe_json(request)
    filename = str(body.get("filename") or "document.pdf")
    base64_data = str(body.get("base64") or "")
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Upload a PDF file.")
    if not base64_data:
        raise HTTPException(status_code=400, detail="Missing PDF payload.")
    try:
        import base64

        source_bytes = base64.b64decode(base64_data)
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Invalid PDF payload: {error}") from error
    if not source_bytes:
        raise HTTPException(status_code=400, detail="PDF file is empty.")

    try:
        annotation_items = body.get("annotations", [])
        removed_page_items = body.get("removedPages", [])
        added_pages_value = int(body.get("addedPages", 0))
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=400, detail=f"Invalid annotation payload: {error}") from error

    exported_bytes = export_pdf_bytes(
        source_pdf_bytes=source_bytes,
        annotations=annotation_items if isinstance(annotation_items, list) else [],
        removed_pages=removed_page_items if isinstance(removed_page_items, list) else [],
        added_pages=added_pages_value,
    )
    filename_base = (filename.rsplit(".", 1)[0] if filename else "lilith-pdf").strip() or "lilith-pdf"
    export_name = f"{filename_base}-edited.pdf"
    import base64

    return {
        "filename": export_name,
        "base64": base64.b64encode(exported_bytes).decode("ascii"),
    }


@app.post("/api/subscription/checkout")
async def subscription_checkout(
    current_user: User = Depends(get_current_user_dep),
):
    return {
        "success": True,
        "checkoutUrl": "https://billing.example.com/checkout/session",
        "plan": "Pro" if not current_user.is_super_admin else "Owner",
    }


@app.post("/api/credits/buy")
async def credits_buy(
    request: Request,
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    body = await _safe_json(request)
    package_id = str(body.get("package", "100"))
    package_amount = float(re.sub(r"[^0-9.]", "", package_id) or 100)
    if not current_user.is_super_admin:
        current_user.credits = float(current_user.credits or 0.0) + package_amount
        db.add(current_user)
    record_activity(db, current_user.id, kind="billing", title="Credits purchased", detail=package_id)
    db.commit()
    return {
        "success": True,
        "creditsAdded": package_amount,
        "totalCredits": "unlimited" if current_user.is_super_admin else float(current_user.credits or 0.0),
    }


@app.get("/api/agents")
async def agents():
    return {
        "agents": [
            {"id": "nova", "name": "Nova"},
            {"id": "forge", "name": "Forge"},
            {"id": "sentinel", "name": "Sentinel"},
            {"id": "atlas", "name": "Atlas"},
            {"id": "pulse", "name": "Pulse"},
        ],
        "modes": ["e1", "e2", "prototype", "mobile"],
        "default": {"agent": "nova", "mode": "e1"},
    }


@app.get("/api/finance")
async def finance_overview(
    current_user: User = Depends(get_current_user_dep),
    db: Session = Depends(get_db),
):
    return {
        "balance": get_balance(db, current_user),
        "analysis": analyze_spending(db, current_user, days=7),
        "approvals": db.query(ApprovalRequest).filter(ApprovalRequest.user_id == current_user.id, ApprovalRequest.domain == "finance", ApprovalRequest.status == "pending").count(),
    }


async def _safe_json(request: Request) -> dict[str, Any]:
    try:
        return await request.json()
    except Exception:
        return {}
