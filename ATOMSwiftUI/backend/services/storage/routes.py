from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from backend.core.deps import current_user, get_db
from backend.models.user import User
from backend.services.storage.service import (
    apply_autofill,
    bookmark_response,
    cloud_state_response,
    create_bookmark,
    create_library_item,
    delete_library_item,
    delete_saved_page,
    create_saved_page,
    create_vault_document,
    create_vault_profile,
    create_workspace_item,
    create_cloud_export,
    detect_autofill,
    ensure_cloud_state,
    library_item_response,
    list_bookmarks,
    list_library_items,
    list_saved_pages,
    list_vault_documents,
    list_vault_logs,
    list_vault_profiles,
    list_workspace_items,
    move_workspace_item_to_library,
    cloud_devices_summary,
    storage_usage_summary,
    saved_page_response,
    unified_search,
    upsert_cloud_state,
    vault_document_response,
    workspace_item_response,
)


router = APIRouter(prefix="/storage", tags=["storage"])


class LibraryItemPayload(BaseModel):
    item_type: str
    title: str
    description: str = ""
    category: str = "General"
    folder: str = "My Library"
    source: str = "manual"
    storage_url: str = ""
    preview_url: str = ""
    tags: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class WorkspaceItemPayload(BaseModel):
    workspace_type: str = "draft"
    title: str
    status: str = "active"
    content_ref: str = ""
    resume_state: dict[str, Any] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)


class VaultProfilePayload(BaseModel):
    profile_name: str
    profile_type: str = "personal"
    fields: dict[str, Any] = Field(default_factory=dict)
    is_default: bool = False


class VaultDocumentPayload(BaseModel):
    title: str
    doc_type: str = "sensitive_document"
    file_url: str = ""
    profile_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class CloudUpdatePayload(BaseModel):
    sync_enabled: bool | None = None
    encrypted_sync: bool | None = None
    sync_library: bool | None = None
    sync_workspace: bool | None = None
    sync_vault: bool | None = None
    conflict_policy: str | None = None


class CloudExportPayload(BaseModel):
    scope: str = "all"  # all | library | workspace | vault


class AutofillDetectPayload(BaseModel):
    form_name: str
    target_type: str = "generic_form"
    fields: list[str] = Field(default_factory=list)


class AutofillApplyPayload(BaseModel):
    profile_id: str
    fields: list[str] = Field(default_factory=list)
    mode: str = "review_first"  # fill_all | review_first | fill_selected
    approved: bool = False
    unlock_token: str | None = None


class BookmarkPayload(BaseModel):
    title: str
    url: str
    tags: list[str] = Field(default_factory=list)


class SavedPagePayload(BaseModel):
    title: str
    url: str
    summary: str = ""
    snapshot: dict[str, Any] = Field(default_factory=dict)


@router.get("/library")
def get_library(
    q: str | None = Query(default=None),
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    rows = list_library_items(db, user, q, category)
    return {"items": [library_item_response(x) for x in rows]}


@router.post("/library")
def add_library(payload: LibraryItemPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_library_item(db, user, payload.model_dump())
    return library_item_response(row)


@router.delete("/library/{item_id}")
def remove_library_item(item_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return delete_library_item(db, user, item_id)


@router.get("/workspace")
def get_workspace(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_workspace_items(db, user)
    return {"items": [workspace_item_response(x) for x in rows]}


@router.post("/workspace")
def add_workspace(payload: WorkspaceItemPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_workspace_item(db, user, payload.model_dump())
    return workspace_item_response(row)


@router.post("/workspace/{workspace_item_id}/move-to-library")
def move_to_library(
    workspace_item_id: str,
    category: str = Query(default="Workspace Exports"),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    row = move_workspace_item_to_library(db, user, workspace_item_id, category)
    return library_item_response(row)


@router.get("/vault/profiles")
def get_vault_profiles(
    include_fields: bool = Query(default=False),
    unlock_token: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    return {"items": list_vault_profiles(db, user, include_fields=include_fields, unlock_token=unlock_token)}


@router.post("/vault/profiles")
def add_vault_profile(payload: VaultProfilePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_vault_profile(db, user, payload.model_dump())
    return {"id": row.id, "profile_name": row.profile_name, "profile_type": row.profile_type, "is_default": row.is_default}


@router.get("/vault/documents")
def get_vault_docs(db: Session = Depends(get_db), user: User = Depends(current_user)):
    rows = list_vault_documents(db, user)
    return {"items": [vault_document_response(x) for x in rows]}


@router.post("/vault/documents")
def add_vault_doc(payload: VaultDocumentPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_vault_document(db, user, payload.model_dump())
    return vault_document_response(row)


@router.get("/vault/access-logs")
def get_vault_logs(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": list_vault_logs(db, user)}


@router.get("/cloud")
def get_cloud(db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = ensure_cloud_state(db, user.id)
    db.commit()
    db.refresh(row)
    return cloud_state_response(row)


@router.patch("/cloud")
def patch_cloud(payload: CloudUpdatePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = upsert_cloud_state(db, user, payload.model_dump(exclude_none=True))
    return cloud_state_response(row)


@router.get("/cloud/panel")
def get_cloud_panel(db: Session = Depends(get_db), user: User = Depends(current_user)):
    state = ensure_cloud_state(db, user.id)
    db.commit()
    db.refresh(state)
    return {
        "sync": cloud_state_response(state),
        "usage": storage_usage_summary(db, user),
        "devices": cloud_devices_summary(db, user),
        "export_supported": True,
    }


@router.post("/cloud/export")
def post_cloud_export(payload: CloudExportPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return create_cloud_export(db, user, payload.scope)


@router.post("/autofill/detect")
def post_autofill_detect(payload: AutofillDetectPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return detect_autofill(db, user, payload.form_name, payload.fields, payload.target_type)


@router.post("/autofill/apply")
def post_autofill_apply(payload: AutofillApplyPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return apply_autofill(
        db,
        user,
        profile_id=payload.profile_id,
        fields=payload.fields,
        mode=payload.mode,
        approved=payload.approved,
        unlock_token=payload.unlock_token,
    )


@router.get("/bookmarks")
def get_bookmarks(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": [bookmark_response(x) for x in list_bookmarks(db, user)]}


@router.post("/bookmarks")
def add_bookmark(payload: BookmarkPayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_bookmark(db, user, payload.model_dump())
    return bookmark_response(row)


@router.get("/saved-pages")
def get_saved_pages(db: Session = Depends(get_db), user: User = Depends(current_user)):
    return {"items": [saved_page_response(x) for x in list_saved_pages(db, user)]}


@router.post("/saved-pages")
def add_saved_page(payload: SavedPagePayload, db: Session = Depends(get_db), user: User = Depends(current_user)):
    row = create_saved_page(db, user, payload.model_dump())
    return saved_page_response(row)


@router.delete("/saved-pages/{page_id}")
def remove_saved_page(page_id: str, db: Session = Depends(get_db), user: User = Depends(current_user)):
    return delete_saved_page(db, user, page_id)


@router.get("/search")
def get_search(
    q: str = Query(..., min_length=1),
    include_vault: bool = Query(default=False),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    return unified_search(db, user, q=q, include_vault=include_vault)
