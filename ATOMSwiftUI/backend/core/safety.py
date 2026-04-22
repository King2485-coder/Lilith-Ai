from __future__ import annotations

import re


BLOCKED_TERMS = {
    "terrorist",
    "credit card dump",
    "csam",
    "explosive recipe",
    "sexual minors",
}

CHILD_STRICT_TERMS = {
    "drug",
    "weapon",
    "violence",
    "porn",
}


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip())


def content_violations(text: str, child_mode: bool = False) -> list[str]:
    normalized = (text or "").lower()
    violated: list[str] = []
    for term in BLOCKED_TERMS:
        if term in normalized:
            violated.append(term)
    if child_mode:
        for term in CHILD_STRICT_TERMS:
            if term in normalized:
                violated.append(term)
    return violated


def validate_url(url: str) -> str:
    cleaned = (url or "").strip()
    if not cleaned:
        raise ValueError("URL is required")
    if not (cleaned.startswith("https://") or cleaned.startswith("http://")):
        raise ValueError("Only http/https URLs are allowed")
    if len(cleaned) > 2048:
        raise ValueError("URL is too long")
    return cleaned

