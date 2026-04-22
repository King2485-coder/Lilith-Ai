from __future__ import annotations

from backend.db.base import Base
from backend.db.session import engine
from backend.models import application, admin, browser, finance_hub, first100, growth, income_engine, message, neurocloud, notification, payment, presence, real_world, reputation, self_heal, social, storage, tool, user  # noqa: F401


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
