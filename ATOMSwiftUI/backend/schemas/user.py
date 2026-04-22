from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    username: str
    password: str
    email: EmailStr | None = None


class UserOut(BaseModel):
    id: str
    username: str
    email: str | None
    created_at: datetime

    class Config:
        from_attributes = True
