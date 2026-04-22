from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.models.storage import (
    AutofillProfile,
    Bookmark,
    CloudSyncState,
    LibraryItem,
    SavedPage,
    VaultAccessLog,
    VaultDocument,
    VaultProfile,
    WorkspaceItem,
)
from backend.models.user import User


SENSITIVE_FIELD_HINTS = {
    "ssn",
    "tax",
    "ein",
    "card",
    "cvv",
    "bank",
    "routing",
    "account_number",
    "dob",
    "passport",
    "driver_license",
    "legal_name",
    "address",
    "phone",
    "email",
}


def _safe_json(raw: str, fallback: Any):
    try:
        return json.loads(raw or "")
    except Exception:
        return fallback


def _iso(dt: datetime | None):
    return dt.isoformat() if dt else None


def _now():
    return datetime.utcnow()


def ensure_cloud_state(db: Session, user_id: str) -> CloudSyncState:
    row = db.query(CloudSyncState).filter(CloudSyncState.user_id == user_id).first()
    if row is None:
        row = CloudSyncState(
            user_id=user_id,
            sync_enabled=True,
            encrypted_sync=True,
            sync_library=True,
            sync_workspace=True,
            sync_vault=True,
            conflict_policy="latest_timestamp",
            last_sync_at=None,
        )
        db.add(row)
        db.flush()
    return row


def upsert_cloud_state(db: Session, user: User, patch: dict[str, Any]) -> CloudSyncState:
    row = ensure_cloud_state(db, user.id)
    row.sync_enabled = bool(patch.get("sync_enabled", row.sync_enabled))
    row.encrypted_sync = bool(patch.get("encrypted_sync", row.encrypted_sync))
    row.sync_library = bool(patch.get("sync_library", row.sync_library))
    row.sync_workspace = bool(patch.get("sync_workspace", row.sync_workspace))
    row.sync_vault = bool(patch.get("sync_vault", row.sync_vault))
    row.conflict_policy = str(patch.get("conflict_policy", row.conflict_policy or "latest_timestamp"))
    row.last_sync_at = _now()
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def cloud_state_response(row: CloudSyncState):
    return {
        "sync_enabled": row.sync_enabled,
        "encrypted_sync": row.encrypted_sync,
        "sync_library": row.sync_library,
        "sync_workspace": row.sync_workspace,
        "sync_vault": row.sync_vault,
        "conflict_policy": row.conflict_policy,
        "last_sync_at": _iso(row.last_sync_at),
        "updated_at": _iso(row.updated_at),
    }


def create_library_item(db: Session, user: User, payload: dict[str, Any]) -> LibraryItem:
    def infer_tags() -> list[str]:
        seed = " ".join(
            [
                str(payload.get("title", "")),
                str(payload.get("description", "")),
                str(payload.get("category", "")),
                str(payload.get("item_type", "")),
                str(payload.get("source", "")),
            ]
        ).lower()
        tags = set([str(x).lower() for x in payload.get("tags", []) if str(x).strip()])
        keyword_map = {
            "receipt": "receipt",
            "invoice": "invoice",
            "video": "video",
            "image": "image",
            "photo": "photo",
            "pdf": "pdf",
            "doc": "document",
            "tool": "tool_output",
            "legal": "legal",
            "finance": "finance",
            "wallet": "payment",
            "bookmark": "bookmark",
            "page": "saved_page",
            "workspace": "workspace",
        }
        for needle, tag in keyword_map.items():
            if needle in seed:
                tags.add(tag)
        if not tags:
            tags.add("saved")
        return sorted(tags)[:8]

    resolved_tags = infer_tags()
    row = LibraryItem(
        user_id=user.id,
        item_type=str(payload.get("item_type", "document")),
        title=str(payload.get("title", "Untitled item")),
        description=str(payload.get("description", "")),
        category=str(payload.get("category", "General")),
        folder=str(payload.get("folder", "My Library")),
        source=str(payload.get("source", "manual")),
        storage_url=str(payload.get("storage_url", "")),
        preview_url=str(payload.get("preview_url", "")),
        tags_json=json.dumps(resolved_tags, default=str),
        metadata_json=json.dumps(payload.get("metadata", {}), default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_library_items(db: Session, user: User, query: str | None = None, category: str | None = None):
    q = db.query(LibraryItem).filter(LibraryItem.user_id == user.id, LibraryItem.is_archived.is_(False))
    if category:
        q = q.filter(LibraryItem.category == category)
    if query:
        like = f"%{query.strip()}%"
        q = q.filter(or_(LibraryItem.title.ilike(like), LibraryItem.description.ilike(like), LibraryItem.folder.ilike(like)))
    return q.order_by(LibraryItem.updated_at.desc()).all()


def library_item_response(row: LibraryItem):
    return {
        "id": row.id,
        "item_type": row.item_type,
        "title": row.title,
        "description": row.description,
        "category": row.category,
        "folder": row.folder,
        "source": row.source,
        "storage_url": row.storage_url,
        "preview_url": row.preview_url,
        "tags": _safe_json(row.tags_json, []),
        "metadata": _safe_json(row.metadata_json, {}),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def create_workspace_item(db: Session, user: User, payload: dict[str, Any]) -> WorkspaceItem:
    row = WorkspaceItem(
        user_id=user.id,
        workspace_type=str(payload.get("workspace_type", "draft")),
        title=str(payload.get("title", "Untitled workspace item")),
        status=str(payload.get("status", "active")),
        content_ref=str(payload.get("content_ref", "")),
        resume_state_json=json.dumps(payload.get("resume_state", {}), default=str),
        metadata_json=json.dumps(payload.get("metadata", {}), default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_workspace_items(db: Session, user: User):
    return (
        db.query(WorkspaceItem)
        .filter(WorkspaceItem.user_id == user.id)
        .order_by(WorkspaceItem.updated_at.desc())
        .all()
    )


def workspace_item_response(row: WorkspaceItem):
    return {
        "id": row.id,
        "workspace_type": row.workspace_type,
        "title": row.title,
        "status": row.status,
        "content_ref": row.content_ref,
        "resume_state": _safe_json(row.resume_state_json, {}),
        "metadata": _safe_json(row.metadata_json, {}),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def move_workspace_item_to_library(db: Session, user: User, workspace_item_id: str, category: str = "Workspace Exports"):
    row = (
        db.query(WorkspaceItem)
        .filter(WorkspaceItem.user_id == user.id, WorkspaceItem.id == workspace_item_id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Workspace item not found")
    row.status = "moved_to_library"
    db.add(row)
    library = create_library_item(
        db,
        user,
        {
            "item_type": row.workspace_type,
            "title": row.title,
            "description": "Moved from Workspace",
            "category": category,
            "folder": "Workspace",
            "source": "workspace",
            "storage_url": row.content_ref,
            "metadata": _safe_json(row.metadata_json, {}),
        },
    )
    return library


def _log_vault_access(
    db: Session,
    user_id: str,
    action: str,
    resource_type: str,
    resource_id: str,
    approved: bool,
    reason: str = "",
):
    row = VaultAccessLog(
        user_id=user_id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        approved=approved,
        reason=reason,
    )
    db.add(row)
    db.flush()
    return row


def create_vault_profile(db: Session, user: User, payload: dict[str, Any]) -> VaultProfile:
    row = VaultProfile(
        user_id=user.id,
        profile_name=str(payload.get("profile_name", "Default Vault Profile")),
        profile_type=str(payload.get("profile_type", "personal")),
        fields_json=json.dumps(payload.get("fields", {}), default=str),
        is_default=bool(payload.get("is_default", False)),
    )
    if row.is_default:
        (
            db.query(VaultProfile)
            .filter(VaultProfile.user_id == user.id, VaultProfile.is_default.is_(True))
            .update({"is_default": False})
        )
    db.add(row)
    db.commit()
    db.refresh(row)
    _log_vault_access(db, user.id, "vault.profile.create", "vault_profile", row.id, approved=True, reason="profile_created")
    db.commit()
    return row


def _vault_unlocked(unlock_token: str | None):
    return bool(unlock_token and len(unlock_token.strip()) >= 4)


def list_vault_profiles(db: Session, user: User, include_fields: bool = False, unlock_token: str | None = None):
    rows = db.query(VaultProfile).filter(VaultProfile.user_id == user.id).order_by(VaultProfile.updated_at.desc()).all()
    unlocked = _vault_unlocked(unlock_token)
    out = []
    for row in rows:
        out.append(
            {
                "id": row.id,
                "profile_name": row.profile_name,
                "profile_type": row.profile_type,
                "is_default": row.is_default,
                "fields": _safe_json(row.fields_json, {}) if include_fields and unlocked else {},
                "requires_unlock": bool(include_fields and not unlocked),
                "created_at": _iso(row.created_at),
                "updated_at": _iso(row.updated_at),
            }
        )
    _log_vault_access(
        db,
        user.id,
        "vault.profile.read",
        "vault_profile_list",
        "",
        approved=unlocked if include_fields else True,
        reason="include_fields" if include_fields else "metadata_read",
    )
    db.commit()
    return out


def create_vault_document(db: Session, user: User, payload: dict[str, Any]):
    row = VaultDocument(
        user_id=user.id,
        profile_id=payload.get("profile_id"),
        title=str(payload.get("title", "Vault Document")),
        doc_type=str(payload.get("doc_type", "sensitive_document")),
        file_url=str(payload.get("file_url", "")),
        metadata_json=json.dumps(payload.get("metadata", {}), default=str),
    )
    db.add(row)
    _log_vault_access(db, user.id, "vault.document.create", "vault_document", row.id, approved=True, reason="document_saved")
    db.commit()
    db.refresh(row)
    return row


def list_vault_documents(db: Session, user: User):
    rows = (
        db.query(VaultDocument)
        .filter(VaultDocument.user_id == user.id)
        .order_by(VaultDocument.updated_at.desc())
        .all()
    )
    _log_vault_access(db, user.id, "vault.document.read", "vault_document_list", "", approved=True, reason="metadata_read")
    db.commit()
    return rows


def vault_document_response(row: VaultDocument):
    return {
        "id": row.id,
        "profile_id": row.profile_id,
        "title": row.title,
        "doc_type": row.doc_type,
        "file_url": row.file_url,
        "metadata": _safe_json(row.metadata_json, {}),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def create_bookmark(db: Session, user: User, payload: dict[str, Any]):
    row = Bookmark(
        user_id=user.id,
        title=str(payload.get("title", payload.get("url", "Bookmark"))),
        url=str(payload.get("url", "")),
        tags_json=json.dumps(payload.get("tags", []), default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_bookmarks(db: Session, user: User):
    return db.query(Bookmark).filter(Bookmark.user_id == user.id).order_by(Bookmark.updated_at.desc()).all()


def bookmark_response(row: Bookmark):
    return {
        "id": row.id,
        "title": row.title,
        "url": row.url,
        "tags": _safe_json(row.tags_json, []),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def create_saved_page(db: Session, user: User, payload: dict[str, Any]):
    row = SavedPage(
        user_id=user.id,
        title=str(payload.get("title", payload.get("url", "Saved Page"))),
        url=str(payload.get("url", "")),
        summary=str(payload.get("summary", "")),
        snapshot_json=json.dumps(payload.get("snapshot", {}), default=str),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def delete_library_item(db: Session, user: User, item_id: str):
    row = db.query(LibraryItem).filter(LibraryItem.user_id == user.id, LibraryItem.id == item_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Library item not found")
    db.delete(row)
    db.commit()
    return {"ok": True, "id": item_id}


def delete_saved_page(db: Session, user: User, page_id: str):
    row = db.query(SavedPage).filter(SavedPage.user_id == user.id, SavedPage.id == page_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Saved page not found")
    db.delete(row)
    db.commit()
    return {"ok": True, "id": page_id}


def list_saved_pages(db: Session, user: User):
    return db.query(SavedPage).filter(SavedPage.user_id == user.id).order_by(SavedPage.updated_at.desc()).all()


def saved_page_response(row: SavedPage):
    return {
        "id": row.id,
        "title": row.title,
        "url": row.url,
        "summary": row.summary,
        "snapshot": _safe_json(row.snapshot_json, {}),
        "created_at": _iso(row.created_at),
        "updated_at": _iso(row.updated_at),
    }


def unified_search(db: Session, user: User, q: str, include_vault: bool = False):
    normalized = q.strip().lower()
    include_vault = include_vault or any(word in normalized for word in ["vault", "secure", "sensitive", "private"])
    forced_library = any(word in normalized for word in ["library", "saved", "bookmark", "receipt", "invoice"])
    forced_workspace = any(word in normalized for word in ["workspace", "draft", "project", "in progress"])

    cleaned = (
        normalized.replace("find", "")
        .replace("show", "")
        .replace("search", "")
        .replace("in library", "")
        .replace("in workspace", "")
        .replace("in vault", "")
        .replace("library", "")
        .replace("workspace", "")
        .replace("vault", "")
        .strip()
    )
    like = f"%{(cleaned or normalized).strip()}%"
    library = (
        db.query(LibraryItem)
        .filter(
            LibraryItem.user_id == user.id,
            LibraryItem.is_archived.is_(False),
            or_(
                LibraryItem.title.ilike(like),
                LibraryItem.description.ilike(like),
                LibraryItem.category.ilike(like),
            ),
        )
        .limit(20)
        .all()
    )
    workspace = (
        db.query(WorkspaceItem)
        .filter(
            WorkspaceItem.user_id == user.id,
            or_(
                WorkspaceItem.title.ilike(like),
                WorkspaceItem.workspace_type.ilike(like),
            ),
        )
        .limit(20)
        .all()
    )
    out = {
        "query": q,
        "normalized_query": cleaned or normalized,
        "library": [library_item_response(x) for x in (library if not forced_workspace else [])],
        "workspace": [workspace_item_response(x) for x in (workspace if not forced_library else [])],
        "vault": [],
    }
    if include_vault:
        vault = (
            db.query(VaultProfile)
            .filter(VaultProfile.user_id == user.id, or_(VaultProfile.profile_name.ilike(like), VaultProfile.profile_type.ilike(like)))
            .limit(10)
            .all()
        )
        out["vault"] = [
            {
                "id": row.id,
                "profile_name": row.profile_name,
                "profile_type": row.profile_type,
                "is_default": row.is_default,
                "requires_unlock": True,
            }
            for row in vault
        ]
        _log_vault_access(db, user.id, "vault.search", "vault_profile_list", "", approved=False, reason="metadata_only_search")
    db.commit()
    return out


def storage_usage_summary(db: Session, user: User):
    library_count = db.query(LibraryItem).filter(LibraryItem.user_id == user.id, LibraryItem.is_archived.is_(False)).count()
    workspace_count = db.query(WorkspaceItem).filter(WorkspaceItem.user_id == user.id).count()
    vault_profiles = db.query(VaultProfile).filter(VaultProfile.user_id == user.id).count()
    vault_docs = db.query(VaultDocument).filter(VaultDocument.user_id == user.id).count()

    # Lightweight estimate for local usage dashboards.
    est_mb = round((library_count * 0.9) + (workspace_count * 0.35) + (vault_docs * 0.8) + (vault_profiles * 0.05), 2)
    return {
        "estimated_mb": est_mb,
        "library_items": library_count,
        "workspace_items": workspace_count,
        "vault_profiles": vault_profiles,
        "vault_documents": vault_docs,
    }


def cloud_devices_summary(db: Session, user: User):
    logs = (
        db.query(VaultAccessLog)
        .filter(VaultAccessLog.user_id == user.id)
        .order_by(VaultAccessLog.created_at.desc())
        .limit(5)
        .all()
    )
    recent_seen = _iso(logs[0].created_at) if logs else None
    return [
        {
            "id": f"device-{user.id[:8]}-primary",
            "name": "Primary Device",
            "platform": "local",
            "last_seen": recent_seen,
            "trusted": True,
        }
    ]


def create_cloud_export(db: Session, user: User, export_scope: str):
    now = _now()
    export_id = f"export-{int(now.timestamp())}-{user.id[:6]}"
    _log_vault_access(
        db,
        user.id,
        "cloud.export.request",
        "cloud_export",
        export_id,
        approved=True,
        reason=f"scope:{export_scope}",
    )
    db.commit()
    return {
        "export_id": export_id,
        "scope": export_scope,
        "status": "queued",
        "requested_at": _iso(now),
    }


def _field_looks_sensitive(field_name: str):
    lowered = field_name.lower().replace(" ", "_")
    return any(hint in lowered for hint in SENSITIVE_FIELD_HINTS)


def _resolve_autofill_profile(db: Session, user_id: str):
    profile = (
        db.query(AutofillProfile)
        .filter(AutofillProfile.user_id == user_id, AutofillProfile.is_active.is_(True))
        .order_by(AutofillProfile.updated_at.desc())
        .first()
    )
    if profile:
        return profile
    default_vault = (
        db.query(VaultProfile)
        .filter(VaultProfile.user_id == user_id, VaultProfile.is_default.is_(True))
        .order_by(VaultProfile.updated_at.desc())
        .first()
    )
    if default_vault:
        profile = AutofillProfile(
            user_id=user_id,
            name="Default Autofill",
            target_type="generic_form",
            field_map_json=default_vault.fields_json,
            sensitive_fields_json="[]",
            is_active=True,
        )
        db.add(profile)
        db.flush()
        return profile
    return None


def detect_autofill(db: Session, user: User, form_name: str, fields: list[str], target_type: str):
    profile = _resolve_autofill_profile(db, user.id)
    if profile is None:
        return {
            "form_name": form_name,
            "target_type": target_type,
            "matches": [],
            "recommended_mode": "review_first",
            "requires_approval": True,
            "never_auto_submit": True,
        }

    value_map = _safe_json(profile.field_map_json, {})
    sensitive_profile = set(_safe_json(profile.sensitive_fields_json, []))
    matches = []
    requires_approval = False
    for field in fields:
        if field in value_map:
            sensitive = field in sensitive_profile or _field_looks_sensitive(field)
            if sensitive:
                requires_approval = True
            matches.append(
                {
                    "field": field,
                    "value_preview": "***" if sensitive else str(value_map[field])[:80],
                    "sensitive": sensitive,
                }
            )
    db.commit()
    return {
        "form_name": form_name,
        "target_type": target_type,
        "profile_id": profile.id,
        "matches": matches,
        "recommended_mode": "review_first" if requires_approval else "fill_all",
        "requires_approval": requires_approval,
        "never_auto_submit": True,
    }


def apply_autofill(
    db: Session,
    user: User,
    profile_id: str,
    fields: list[str],
    mode: str,
    approved: bool,
    unlock_token: str | None,
):
    profile = db.query(AutofillProfile).filter(AutofillProfile.user_id == user.id, AutofillProfile.id == profile_id).first()
    if profile is None:
        raise HTTPException(status_code=404, detail="Autofill profile not found")
    if not approved:
        _log_vault_access(db, user.id, "autofill.apply", "autofill_profile", profile_id, approved=False, reason="approval_missing")
        db.commit()
        raise HTTPException(status_code=403, detail="Explicit approval required before autofill")
    values = _safe_json(profile.field_map_json, {})
    sensitive = set(_safe_json(profile.sensitive_fields_json, []))
    selected_fields = fields if mode in {"fill_selected", "review_first"} else list(values.keys())
    resolved: dict[str, str] = {}
    for field in selected_fields:
        if field not in values:
            continue
        if (field in sensitive or _field_looks_sensitive(field)) and not _vault_unlocked(unlock_token):
            _log_vault_access(
                db,
                user.id,
                "autofill.apply",
                "autofill_profile",
                profile_id,
                approved=False,
                reason=f"sensitive_field_requires_unlock:{field}",
            )
            db.commit()
            raise HTTPException(status_code=403, detail=f"Sensitive field `{field}` requires unlock confirmation")
        resolved[field] = str(values[field])
    _log_vault_access(
        db,
        user.id,
        "autofill.apply",
        "autofill_profile",
        profile_id,
        approved=True,
        reason=f"mode:{mode}",
    )
    db.commit()
    return {
        "profile_id": profile_id,
        "mode": mode,
        "filled_fields": resolved,
        "requires_manual_submit": True,
        "submitted": False,
    }


def list_vault_logs(db: Session, user: User):
    rows = (
        db.query(VaultAccessLog)
        .filter(VaultAccessLog.user_id == user.id)
        .order_by(VaultAccessLog.created_at.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": row.id,
            "action": row.action,
            "resource_type": row.resource_type,
            "resource_id": row.resource_id,
            "approved": row.approved,
            "reason": row.reason,
            "created_at": _iso(row.created_at),
        }
        for row in rows
    ]
