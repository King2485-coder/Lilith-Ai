from __future__ import annotations

import json

from sqlalchemy.orm import Session

from backend.models.neurocloud import NeuroMemory


def get_memory(db: Session, user_id: str) -> dict:
    row = db.query(NeuroMemory).filter(NeuroMemory.user_id == user_id).first()
    if row is None:
        row = NeuroMemory(user_id=user_id, preferences_json="{}")
        db.add(row)
        db.commit()
        db.refresh(row)
    return json.loads(row.preferences_json or "{}")


def patch_memory(db: Session, user_id: str, patch: dict) -> dict:
    row = db.query(NeuroMemory).filter(NeuroMemory.user_id == user_id).first()
    if row is None:
        row = NeuroMemory(user_id=user_id, preferences_json="{}")
        db.add(row)
        db.flush()
    current = json.loads(row.preferences_json or "{}")
    current.update(patch or {})
    row.preferences_json = json.dumps(current, default=str)
    db.add(row)
    db.commit()
    db.refresh(row)
    return current

