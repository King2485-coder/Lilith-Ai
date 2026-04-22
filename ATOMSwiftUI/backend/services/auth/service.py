from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.core.auth import create_access_token
from backend.core.security import hash_password, verify_password
from backend.models.admin import UserRole
from backend.models.payment import PaymentAccount
from backend.models.user import User
from backend.schemas.user import UserCreate


def register_user(db: Session, payload: UserCreate) -> User:
    existing = db.query(User).filter(User.username == payload.username).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Username already exists")
    user = User(username=payload.username, email=payload.email, hashed_password=hash_password(payload.password))
    db.add(user)
    db.flush()
    db.add(UserRole(user_id=user.id, role="user", status="active"))
    db.add(PaymentAccount(user_id=user.id, fiat_balance=100.0, usdc_balance=0.0))
    db.commit()
    db.refresh(user)
    return user


def login_user(db: Session, username: str, password: str) -> str:
    user = db.query(User).filter(User.username == username).first()
    if user is None or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    role = db.query(UserRole).filter(UserRole.user_id == user.id).first()
    if role and role.status in {"suspended", "banned"}:
        raise HTTPException(status_code=403, detail=f"Account {role.status}")
    return create_access_token(user.username)
