from __future__ import annotations

import re
from typing import Any

from sqlalchemy.orm import Session

from backend.state import LegalArtifact, User, record_activity


CLAUSE_PATTERNS = {
    "termination": r"(termination|terminate|end of agreement)",
    "confidentiality": r"(confidential|non-disclosure|nda)",
    "payment": r"(payment|invoice|fees|compensation)",
    "liability": r"(liability|indemnif|damages|warranty)",
    "governing_law": r"(governing law|jurisdiction|venue)",
}


def summarize_text(db: Session, user: User, text: str, title: str = "Legal summary") -> dict[str, Any]:
    cleaned = " ".join(text.split())
    sentences = re.split(r"(?<=[.!?])\s+", cleaned)
    summary_sentences = sentences[:3]
    summary = " ".join(summary_sentences) if summary_sentences else cleaned[:320]
    artifact = LegalArtifact(user_id=user.id, kind="summary", title=title, source_text=text, output_text=summary)
    db.add(artifact)
    record_activity(db, user.id, kind="legal", title="Legal summary generated", detail=title)
    db.commit()
    return {"summary": summary, "artifactId": artifact.id}


def extract_clauses(db: Session, user: User, text: str, title: str = "Clause extraction") -> dict[str, Any]:
    matches = []
    lowered = text.lower()
    for label, pattern in CLAUSE_PATTERNS.items():
        if re.search(pattern, lowered):
            matches.append({"label": label.replace("_", " ").title(), "confidence": 0.82})
    if not matches:
        matches.append({"label": "General obligations", "confidence": 0.51})

    artifact = LegalArtifact(
        user_id=user.id,
        kind="clause_extraction",
        title=title,
        source_text=text,
        output_text="\n".join(match["label"] for match in matches),
    )
    db.add(artifact)
    record_activity(db, user.id, kind="legal", title="Clauses extracted", detail=title, metadata={"count": len(matches)})
    db.commit()
    return {"clauses": matches, "artifactId": artifact.id}


def draft_document(
    db: Session,
    user: User,
    prompt: str,
    document_type: str = "General Agreement",
    parties: list[str] | None = None,
) -> dict[str, Any]:
    party_line = ", ".join(parties or ["Party A", "Party B"])
    draft = f"""{document_type}

Parties
This agreement is between {party_line}.

Purpose
{prompt.strip() or "The parties agree to collaborate under the following terms."}

Core Terms
1. Scope: Work will be performed as described in attached statements of work.
2. Payment: Fees and reimbursement terms will be approved in writing.
3. Confidentiality: Each party will protect confidential information.
4. Termination: Either party may terminate with reasonable written notice.
5. Governing Law: The agreement will be governed by the parties' chosen jurisdiction.
"""
    artifact = LegalArtifact(
        user_id=user.id,
        kind="draft",
        title=document_type,
        source_text=prompt,
        output_text=draft,
    )
    db.add(artifact)
    record_activity(db, user.id, kind="legal", title="Legal draft created", detail=document_type)
    db.commit()
    return {"document": draft, "artifactId": artifact.id}
