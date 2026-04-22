from __future__ import annotations

from sqlalchemy.orm import Session

from backend.core.security import hash_password
from backend.models.admin import UserRole
from backend.models.payment import PaymentAccount
from backend.models.user import User
from backend.services.payments.monetization import ensure_default_catalog


def seed_dev_data(db: Session) -> None:
    ensure_default_catalog(db)
    if db.query(User).count() > 0:
        return
    users = [
        User(username="lilith_admin", email="admin@lilith.local", hashed_password=hash_password("123456")),
        User(username="demo_user", email="demo@lilith.local", hashed_password=hash_password("123456")),
    ]
    db.add_all(users)
    db.flush()
    db.add_all(
        [
            PaymentAccount(user_id=users[0].id, fiat_balance=1000.0, usdc_balance=50.0),
            PaymentAccount(user_id=users[1].id, fiat_balance=500.0, usdc_balance=25.0),
        ]
    )
    db.add_all(
        [
            UserRole(user_id=users[0].id, role="admin", status="active"),
            UserRole(user_id=users[1].id, role="user", status="active"),
        ]
    )
    db.commit()
