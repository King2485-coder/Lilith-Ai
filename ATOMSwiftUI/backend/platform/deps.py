from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Generator, Optional

from fastapi import Depends, Header, HTTPException, status
from fastapi.security.utils import get_authorization_scheme_param
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from backend.state import SessionLocal, User


JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))
MASTER_TOKEN = os.getenv("MASTER_TOKEN", "LILITH_MASTER_TOKEN")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "antoniohoshaw6@gmail.com").lower()
ALGORITHM = "HS256"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(email: str, expires_minutes: Optional[int] = None) -> str:
    expire = datetime.utcnow() + timedelta(minutes=expires_minutes or JWT_EXPIRE_MINUTES)
    payload = {"sub": email, "exp": expire}
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


async def bearer_token(authorization: Optional[str] = Header(None)) -> str:
    scheme, token = get_authorization_scheme_param(authorization or "")
    if not authorization or scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token


async def current_user(
    token: str = Depends(bearer_token),
    db: Session = Depends(get_db),
) -> User:
    if token == MASTER_TOKEN:
        user = db.query(User).filter(User.email == ADMIN_EMAIL).first()
        if user is None:
            raise HTTPException(status_code=401, detail="Master user unavailable")
        return user
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError as error:
        raise HTTPException(status_code=401, detail="Invalid token") from error
    user = db.query(User).filter(User.email == email.lower()).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user

