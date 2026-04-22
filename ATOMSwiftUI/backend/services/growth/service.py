from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from backend.models.growth import EmailList, LandingPage, Subscriber
from backend.models.user import User


def ensure_default_list(db: Session, user: User) -> EmailList:
    row = db.query(EmailList).filter(EmailList.owner_user_id == user.id).first()
    if row is None:
        row = EmailList(owner_user_id=user.id, name=f"{user.username}-default")
        db.add(row)
        db.flush()
    return row


def subscribe_email(db: Session, user: User, email: str) -> Subscriber:
    email_list = ensure_default_list(db, user)
    row = Subscriber(email_list_id=email_list.id, email=email.strip().lower())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def send_email_campaign(db: Session, user: User, subject: str, body: str) -> dict:
    email_list = ensure_default_list(db, user)
    count = db.query(Subscriber).filter(Subscriber.email_list_id == email_list.id).count()
    # Scaffold: delivery provider integration to be added later.
    return {"delivered": count, "subject": subject, "status": "queued"}


def create_landing_page(db: Session, user: User, title: str, slug: str, content_html: str) -> LandingPage:
    existing = db.query(LandingPage).filter(LandingPage.slug == slug).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Slug already exists")
    row = LandingPage(owner_user_id=user.id, title=title.strip()[:180], slug=slug.strip()[:180], content_html=content_html)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_landing_page(db: Session, page_id: str) -> LandingPage:
    row = db.query(LandingPage).filter(LandingPage.id == page_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Page not found")
    return row

