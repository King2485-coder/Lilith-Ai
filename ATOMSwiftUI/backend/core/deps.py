from __future__ import annotations

from typing import Generator, Optional

from fastapi import Depends, Header, HTTPException, Query, status
from fastapi.security.utils import get_authorization_scheme_param
from sqlalchemy.orm import Session

from backend.core.auth import decode_access_token
from backend.db.session import SessionLocal
from backend.models.admin import UserRole
from backend.models.user import User


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _extract_bearer(authorization: Optional[str]) -> str:
    scheme, token = get_authorization_scheme_param(authorization or "")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return token


async def current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    token = _extract_bearer(authorization)
    username = decode_access_token(token)
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return user


async def websocket_user(
    token: str = Query(...),
    db: Session = Depends(get_db),
) -> User:
    username = decode_access_token(token)
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return user


def ensure_user_role(db: Session, user: User) -> UserRole:
    role = db.query(UserRole).filter(UserRole.user_id == user.id).first()
    if role is None:
        role = UserRole(user_id=user.id, role="user", status="active")
        db.add(role)
        db.commit()
        db.refresh(role)
    return role


async def current_admin_user(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> User:
    role = ensure_user_role(db, user)
    if role.status != "active":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account not active")
    if role.role not in {"admin", "super_admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user
