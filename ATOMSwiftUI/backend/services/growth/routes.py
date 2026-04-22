from __future__ import annotations

from pydantic import BaseModel, EmailStr
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.user import User
from backend.services.growth.service import create_landing_page, get_landing_page, send_email_campaign, subscribe_email


router = APIRouter(prefix="/growth", tags=["growth"])


class SubscribePayload(BaseModel):
    email: EmailStr


class SendEmailPayload(BaseModel):
    subject: str
    body: str


class CreatePagePayload(BaseModel):
    title: str
    slug: str
    content_html: str


@router.post("/subscribe")
def growth_subscribe(payload: SubscribePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = subscribe_email(db, user, payload.email)
    return {"id": row.id, "email": row.email}


@router.post("/send-email")
def growth_send_email(payload: SendEmailPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return send_email_campaign(db, user, payload.subject, payload.body)


@router.post("/create-page")
def growth_create_page(payload: CreatePagePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_landing_page(db, user, payload.title, payload.slug, payload.content_html)
    return {"id": row.id, "title": row.title, "slug": row.slug}


@router.get("/page/{page_id}")
def growth_get_page(page_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = get_landing_page(db, page_id)
    return {"id": row.id, "title": row.title, "slug": row.slug, "content_html": row.content_html}

