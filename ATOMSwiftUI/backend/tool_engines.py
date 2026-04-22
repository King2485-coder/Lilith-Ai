from __future__ import annotations

import io
import json
import re
from collections import Counter
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import Any

try:
    from pypdf import PdfReader, PdfWriter
except Exception:  # pragma: no cover - optional dependency fallback
    PdfReader = None
    PdfWriter = None


class StructureParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tag_counter: Counter[str] = Counter()
        self.headings: list[str] = []
        self._capture_heading = False
        self._heading_buffer: list[str] = []
        self.text_chunks: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.tag_counter[tag.lower()] += 1
        if tag.lower() in {"h1", "h2", "h3"}:
            self._capture_heading = True
            self._heading_buffer = []

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"h1", "h2", "h3"} and self._capture_heading:
            heading = "".join(self._heading_buffer).strip()
            if heading:
                self.headings.append(heading)
            self._capture_heading = False
            self._heading_buffer = []

    def handle_data(self, data: str) -> None:
        cleaned = re.sub(r"\s+", " ", data or "").strip()
        if not cleaned:
            return
        if self._capture_heading:
            self._heading_buffer.append(cleaned)
        if len(cleaned) >= 20:
            self.text_chunks.append(cleaned)


def analyze_html_structure(html: str) -> dict[str, Any]:
    parser = StructureParser()
    parser.feed(html or "")
    most_common = parser.tag_counter.most_common(24)
    return {
        "tags": [{"tag": tag, "count": count} for tag, count in most_common],
        "headings": parser.headings[:12],
        "textSample": parser.text_chunks[:8],
        "estimatedSections": parser.tag_counter.get("section", 0) or parser.tag_counter.get("article", 0),
    }


def build_prompt_from_html(url: str, html: str) -> dict[str, Any]:
    structure = analyze_html_structure(html)
    heading = structure["headings"][0] if structure["headings"] else "No headline detected"
    key_tags = ", ".join(item["tag"] for item in structure["tags"][:10]) or "div, section, article"
    prompt = (
        f"Rebuild and improve the page from {url}.\n\n"
        f"Primary heading: {heading}\n"
        f"Estimated sections: {structure['estimatedSections'] or 3}\n"
        f"Primary DOM components: {key_tags}\n\n"
        "Deliverables:\n"
        "- clean semantic HTML structure\n"
        "- modern responsive CSS system\n"
        "- clearer conversion-focused copy\n"
        "- accessibility pass (landmarks, labels, contrast)"
    )
    return {
        "url": url,
        "summary": {
            "primaryHeading": heading,
            "estimatedSections": structure["estimatedSections"] or 3,
            "components": key_tags,
        },
        "prompt": prompt,
        "structure": structure,
    }


def inspect_pdf_bytes(pdf_bytes: bytes) -> dict[str, Any]:
    if PdfReader is None:
        return {"pageCount": 0, "pages": [], "engine": "unavailable", "reason": "pypdf not installed"}
    reader = PdfReader(io.BytesIO(pdf_bytes))
    pages: list[dict[str, Any]] = []
    for idx, page in enumerate(reader.pages):
        text = (page.extract_text() or "").strip()
        pages.append({
            "page": idx + 1,
            "previewText": re.sub(r"\s+", " ", text)[:240] or f"Page {idx + 1}",
        })
    return {"pageCount": len(reader.pages), "pages": pages, "engine": "pypdf"}


def export_pdf_bytes(
    source_pdf_bytes: bytes,
    annotations: list[dict[str, Any]] | None = None,
    removed_pages: list[int] | None = None,
    added_pages: int = 0,
) -> bytes:
    if PdfReader is None or PdfWriter is None:
        return source_pdf_bytes

    annotations = annotations or []
    removed = {int(page) for page in (removed_pages or []) if int(page) > 0}
    writer = PdfWriter()
    reader = PdfReader(io.BytesIO(source_pdf_bytes))

    selected_pages = []
    for idx, page in enumerate(reader.pages, start=1):
        if idx in removed:
            continue
        selected_pages.append(page)

    if not selected_pages:
        selected_pages = [reader.pages[0]]

    for page in selected_pages:
        writer.add_page(page)

    first_page = selected_pages[0]
    width = float(first_page.mediabox.width)
    height = float(first_page.mediabox.height)
    for _ in range(max(0, int(added_pages))):
        writer.add_blank_page(width=width, height=height)

    metadata = dict(reader.metadata or {})
    metadata.update({
        "/LilithAnnotations": json.dumps(annotations, default=str)[:50000],
        "/LilithExportedAt": "true",
    })
    writer.add_metadata(metadata)

    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()
