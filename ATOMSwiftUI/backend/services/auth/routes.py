from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.core.redis import consume_rate_limit
from backend.models.user import User
from backend.schemas.auth import LoginPayload, TokenResponse
from backend.schemas.user import UserCreate, UserOut
from backend.services.auth.service import login_user, register_user


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut)
async def register(payload: UserCreate, db: Session = Depends(get_db)):
    allowed = await consume_rate_limit("auth.register", f"user:{payload.username.lower()}", limit=8, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Register rate limit exceeded")
    return register_user(db, payload)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginPayload, db: Session = Depends(get_db)):
    allowed = await consume_rate_limit("auth.login", f"user:{payload.username.lower()}", limit=20, window_seconds=60)
    if not allowed:
        from fastapi import HTTPException

        raise HTTPException(status_code=429, detail="Login rate limit exceeded")
    token = login_user(db, payload.username, payload.password)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user
