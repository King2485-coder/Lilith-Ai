import json
import os
import uuid
from datetime import datetime, timedelta
from typing import Any, Iterable

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text, create_engine, inspect
from sqlalchemy.orm import Session, declarative_base, relationship, sessionmaker


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./lilith.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def utcnow() -> datetime:
    return datetime.utcnow()


def new_id() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=True)
    role = Column(String, nullable=True, default="user")
    credits = Column(Float, nullable=True, default=24.0)
    is_super_admin = Column(Boolean, nullable=True, default=False)
    settings_json = Column(Text, nullable=True, default="{}")
    created_at = Column(DateTime, default=utcnow)

    conversations = relationship("Conversation", back_populates="user", cascade="all, delete-orphan")
    projects = relationship("Project", back_populates="user", cascade="all, delete-orphan")
    activities = relationship("ActivityEvent", back_populates="user", cascade="all, delete-orphan")
    approvals = relationship("ApprovalRequest", back_populates="user", cascade="all, delete-orphan")
    memories = relationship("MemoryItem", back_populates="user", cascade="all, delete-orphan")
    finance_accounts = relationship("FinanceAccount", back_populates="user", cascade="all, delete-orphan")


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    user = relationship("User", back_populates="conversations")
    messages = relationship("ChatMessage", back_populates="conversation", cascade="all, delete-orphan", order_by="ChatMessage.created_at")


class ChatMessage(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, default=new_id)
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=False, index=True)
    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    tool_used = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

    conversation = relationship("Conversation", back_populates="messages")


class Project(Base):
    __tablename__ = "projects"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    user = relationship("User", back_populates="projects")
    files = relationship("ProjectFile", back_populates="project", cascade="all, delete-orphan", order_by="ProjectFile.name")


class ProjectFile(Base):
    __tablename__ = "project_files"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    path = Column(String, nullable=True)
    content = Column(Text, nullable=False, default="")
    language = Column(String, nullable=False, default="text")
    updated_at = Column(DateTime, default=utcnow)

    project = relationship("Project", back_populates="files")


class ActivityEvent(Base):
    __tablename__ = "activity_events"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    kind = Column(String, nullable=False)
    title = Column(String, nullable=False)
    detail = Column(Text, nullable=True)
    status = Column(String, nullable=False, default="completed")
    details_json = Column(Text, nullable=True, default="{}")
    created_at = Column(DateTime, default=utcnow)

    user = relationship("User", back_populates="activities")


class ApprovalRequest(Base):
    __tablename__ = "approval_requests"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    domain = Column(String, nullable=False)
    title = Column(String, nullable=False)
    preview = Column(Text, nullable=False)
    status = Column(String, nullable=False, default="pending")
    payload_json = Column(Text, nullable=False, default="{}")
    created_at = Column(DateTime, default=utcnow)
    resolved_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="approvals")


class MemoryItem(Base):
    __tablename__ = "memory_items"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    label = Column(String, nullable=False)
    value = Column(Text, nullable=False)
    source = Column(String, nullable=False, default="chat")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)

    user = relationship("User", back_populates="memories")


class FinanceAccount(Base):
    __tablename__ = "finance_accounts"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    kind = Column(String, nullable=False, default="checking")
    currency = Column(String, nullable=False, default="USD")
    balance = Column(Float, nullable=False, default=0.0)
    updated_at = Column(DateTime, default=utcnow)

    user = relationship("User", back_populates="finance_accounts")
    transactions = relationship("FinanceTransaction", back_populates="account", cascade="all, delete-orphan", order_by="FinanceTransaction.occurred_at.desc()")


class FinanceTransaction(Base):
    __tablename__ = "finance_transactions"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    account_id = Column(String, ForeignKey("finance_accounts.id"), nullable=False, index=True)
    direction = Column(String, nullable=False, default="debit")
    merchant = Column(String, nullable=False)
    category = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    note = Column(Text, nullable=True)
    occurred_at = Column(DateTime, default=utcnow)

    account = relationship("FinanceAccount", back_populates="transactions")


class LegalArtifact(Base):
    __tablename__ = "legal_artifacts"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    kind = Column(String, nullable=False)
    title = Column(String, nullable=False)
    source_text = Column(Text, nullable=False)
    output_text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utcnow)


class CloneArtifact(Base):
    __tablename__ = "clone_artifacts"

    id = Column(String, primary_key=True, default=new_id)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    url = Column(String, nullable=False)
    html = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utcnow)


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    _ensure_legacy_columns()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _ensure_legacy_columns() -> None:
    if not DATABASE_URL.startswith("sqlite"):
        return

    inspector = inspect(engine)
    table_names = set(inspector.get_table_names())
    if "users" not in table_names:
        return

    users_existing = {column["name"] for column in inspector.get_columns("users")}
    user_additions = {
        "name": "VARCHAR",
        "role": "VARCHAR DEFAULT 'user'",
        "credits": "FLOAT DEFAULT 24.0",
        "is_super_admin": "BOOLEAN DEFAULT 0",
        "settings_json": "TEXT DEFAULT '{}'",
    }

    profile_additions = {}
    if "profiles" in table_names:
        profile_existing = {column["name"] for column in inspector.get_columns("profiles")}
        if "is_business" not in profile_existing:
            profile_additions["is_business"] = "BOOLEAN DEFAULT 0"
        if "service_description" not in profile_existing:
            profile_additions["service_description"] = "TEXT"
        if "is_verified_business" not in profile_existing:
            profile_additions["is_verified_business"] = "BOOLEAN DEFAULT 0"

    with engine.begin() as connection:
        for column_name, definition in user_additions.items():
            if column_name not in users_existing:
                connection.exec_driver_sql(f"ALTER TABLE users ADD COLUMN {column_name} {definition}")
        for column_name, definition in profile_additions.items():
            connection.exec_driver_sql(f"ALTER TABLE profiles ADD COLUMN {column_name} {definition}")


def json_dumps(value: Any) -> str:
    return json.dumps(value or {}, default=str)


def json_loads(value: str | None) -> Any:
    if not value:
        return {}
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return {}


def serialize_user(user: User) -> dict[str, Any]:
    is_super_admin = bool(user.is_super_admin or (user.role or "").lower() == "super_admin")
    return {
        "id": str(user.id),
        "email": user.email,
        "name": user.name or "Lilith User",
        "createdAt": (user.created_at or utcnow()).isoformat(),
        "role": "super_admin" if is_super_admin else (user.role or "user"),
        "credits": None if is_super_admin else float(user.credits or 0.0),
        "isSuperAdmin": is_super_admin,
    }


def default_settings() -> dict[str, Any]:
    return {
        "defaultAgent": "nova",
        "defaultMode": "e1",
        "approvalMode": "confirm_sensitive",
        "memoryEnabled": True,
        "toolHints": True,
    }


def ensure_user_settings(user: User) -> dict[str, Any]:
    settings = json_loads(user.settings_json)
    merged = {**default_settings(), **settings}
    user.settings_json = json_dumps(merged)
    return merged


def record_activity(
    db: Session,
    user_id: int,
    kind: str,
    title: str,
    detail: str | None = None,
    status: str = "completed",
    metadata: dict[str, Any] | None = None,
) -> ActivityEvent:
    event = ActivityEvent(
        user_id=user_id,
        kind=kind,
        title=title,
        detail=detail,
        status=status,
        details_json=json_dumps(metadata),
    )
    db.add(event)
    db.flush()
    return event


def serialize_activity(event: ActivityEvent) -> dict[str, Any]:
    return {
        "id": event.id,
        "kind": event.kind,
        "title": event.title,
        "detail": event.detail or "",
        "status": event.status,
        "metadata": json_loads(event.details_json),
        "createdAt": (event.created_at or utcnow()).isoformat(),
    }


def serialize_memory(memory: MemoryItem) -> dict[str, Any]:
    return {
        "id": memory.id,
        "label": memory.label,
        "value": memory.value,
        "source": memory.source,
        "createdAt": (memory.created_at or utcnow()).isoformat(),
        "updatedAt": (memory.updated_at or utcnow()).isoformat(),
    }


def serialize_project(project: Project) -> dict[str, Any]:
    return {
        "id": project.id,
        "name": project.name,
        "description": project.description,
        "files": [
            {
                "name": file.name,
                "path": file.path or file.name,
                "content": file.content,
                "language": file.language,
            }
            for file in project.files
        ],
        "createdAt": (project.created_at or utcnow()).isoformat(),
        "updatedAt": (project.updated_at or utcnow()).isoformat(),
    }


def serialize_conversation_list_item(conversation: Conversation) -> dict[str, Any]:
    return {
        "id": conversation.id,
        "title": conversation.title,
        "messages": len(conversation.messages),
        "updatedAt": (conversation.updated_at or utcnow()).isoformat(),
    }


def list_tool_registry() -> list[dict[str, Any]]:
    return [
        {"id": "assistant", "title": "Lilith Assistant", "category": "assistant", "status": "active", "summary": "Primary chat interface with translator, planner, guard, approvals, and memory."},
        {"id": "finance", "title": "WealthWizard", "category": "finance", "status": "active", "summary": "Balance, transactions, spending analysis, simulations, and approval-gated transfers."},
        {"id": "legal", "title": "Legal Ease", "category": "legal", "status": "active", "summary": "Drafting, summaries, clause extraction, and document framing."},
        {"id": "builder", "title": "Code Workspace", "category": "builder", "status": "active", "summary": "Project files, code execution, and review flows."},
        {"id": "writer", "title": "Writer", "category": "writer", "status": "active", "summary": "Natural-language responses, plans, summaries, and structured output."},
        {"id": "media-image", "title": "Image Studio", "category": "media", "status": "active", "summary": "Image generation workflow."},
        {"id": "media-video", "title": "Video Studio", "category": "media", "status": "active", "summary": "Video generation workflow."},
        {"id": "clone", "title": "Site Clone", "category": "file_intelligence", "status": "active", "summary": "Fetch, inspect, and preview cloned site HTML."},
        {"id": "search", "title": "Research Search", "category": "research", "status": "active", "summary": "Search and contextual lookup support."},
        {"id": "planner", "title": "Planner", "category": "planner", "status": "active", "summary": "Preview, plan, and execute flow orchestration."},
        {"id": "device", "title": "Device Control", "category": "device_control", "status": "active", "summary": "App and device action routing with execution guard rails."},
        {"id": "memory", "title": "Memory Engine", "category": "memory", "status": "active", "summary": "Learns preferences and stores reusable context."},
    ]


def seed_user_workspace(db: Session, user: User) -> None:
    settings = ensure_user_settings(user)
    _ = settings

    if not user.name:
        user.name = "Lilith User" if not user.is_super_admin else "Lilith Owner"
    if not user.role:
        user.role = "super_admin" if user.is_super_admin else "user"
    if user.credits is None:
        user.credits = 24.0

    if not db.query(FinanceAccount).filter(FinanceAccount.user_id == user.id).first():
        checking = FinanceAccount(user_id=user.id, name="Checking", kind="checking", balance=5820.43)
        savings = FinanceAccount(user_id=user.id, name="Savings", kind="savings", balance=12440.12)
        db.add_all([checking, savings])
        db.flush()

        sample_rows = [
            ("Payroll", "income", 2400.00, "credit", 1),
            ("Whole Foods", "groceries", 86.14, "debit", 2),
            ("Shell", "transport", 54.22, "debit", 3),
            ("Dropbox", "software", 12.99, "debit", 4),
            ("Sweetgreen", "dining", 19.48, "debit", 5),
            ("Amazon", "shopping", 128.77, "debit", 6),
            ("Comcast", "utilities", 92.11, "debit", 7),
            ("Trader Joe's", "groceries", 64.38, "debit", 9),
            ("Uber", "transport", 23.40, "debit", 10),
            ("Apple", "software", 9.99, "debit", 11),
            ("Rent", "housing", 1650.00, "debit", 12),
            ("Chipotle", "dining", 14.92, "debit", 13),
        ]
        for merchant, category, amount, direction, days_ago in sample_rows:
            db.add(
                FinanceTransaction(
                    user_id=user.id,
                    account_id=checking.id,
                    merchant=merchant,
                    category=category,
                    amount=amount,
                    direction=direction,
                    occurred_at=utcnow() - timedelta(days=days_ago),
                )
            )

    if not db.query(Project).filter(Project.user_id == user.id).first():
        project = Project(
            user_id=user.id,
            name="Lilith Starter",
            description="Starter workspace for chat, code, and document flows.",
        )
        db.add(project)
        db.flush()
        db.add_all(
            [
                ProjectFile(
                    project_id=project.id,
                    name="README.md",
                    path="README.md",
                    language="markdown",
                    content="# Lilith Starter\nUse this project to sketch prompts, code, and plans.",
                ),
                ProjectFile(
                    project_id=project.id,
                    name="main.py",
                    path="main.py",
                    language="python",
                    content="def greet(name):\n    return f'Hello, {name}'\n\nprint(greet('Lilith'))\n",
                ),
            ]
        )

    if not db.query(MemoryItem).filter(MemoryItem.user_id == user.id).first():
        db.add(
            MemoryItem(
                user_id=user.id,
                label="working-style",
                value="Prefers concise responses with clear next steps.",
                source="system",
            )
        )

    if not db.query(ActivityEvent).filter(ActivityEvent.user_id == user.id).first():
        record_activity(
            db,
            user.id,
            kind="system",
            title="Workspace prepared",
            detail="Lilith initialized chat, finance, legal, memory, and project contexts.",
            metadata={"surface": "startup"},
        )

    db.commit()


def seed_all_users(db: Session) -> None:
    for user in db.query(User).all():
        seed_user_workspace(db, user)


def iso(dt: datetime | None) -> str:
    return (dt or utcnow()).isoformat()


def safe_title(source: str) -> str:
    stripped = " ".join(source.strip().split())
    if not stripped:
        return "New conversation"
    words = stripped.split(" ")
    return " ".join(words[:8])[:72]


def ensure_conversation(db: Session, user: User, conversation_id: str | None, first_message: str) -> Conversation:
    conversation = None
    if conversation_id:
        conversation = (
            db.query(Conversation)
            .filter(Conversation.id == conversation_id, Conversation.user_id == user.id)
            .first()
        )
    if conversation is None:
        conversation = Conversation(user_id=user.id, title=safe_title(first_message))
        db.add(conversation)
        db.flush()
    conversation.updated_at = utcnow()
    return conversation


def message_to_dict(message: ChatMessage) -> dict[str, Any]:
    return {
        "id": message.id,
        "role": message.role,
        "content": message.content,
        "toolUsed": message.tool_used,
        "createdAt": iso(message.created_at),
    }


def top_categories(transactions: Iterable[FinanceTransaction], limit: int = 4) -> list[dict[str, Any]]:
    buckets: dict[str, float] = {}
    for transaction in transactions:
        if transaction.direction != "debit":
            continue
        buckets[transaction.category] = buckets.get(transaction.category, 0.0) + float(transaction.amount)
    ordered = sorted(buckets.items(), key=lambda item: item[1], reverse=True)
    return [{"category": category, "amount": round(amount, 2)} for category, amount in ordered[:limit]]
