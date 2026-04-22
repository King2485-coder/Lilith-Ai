from __future__ import annotations

from typing import Any, Callable


ToolHandler = Callable[[dict[str, Any]], dict[str, Any]]


def text_summarizer(payload: dict[str, Any]) -> dict[str, Any]:
    text = str(payload.get("text", "")).strip()
    words = text.split()
    summary = " ".join(words[:40])
    return {"summary": summary, "word_count": len(words)}


def text_to_video_stub(payload: dict[str, Any]) -> dict[str, Any]:
    prompt = str(payload.get("prompt", "")).strip()
    return {"status": "generated", "video_url": f"https://example.local/videos/{abs(hash(prompt)) % 100000}.mp4"}


def page_analyzer(payload: dict[str, Any]) -> dict[str, Any]:
    url = str(payload.get("url", "")).strip()
    title_hint = str(payload.get("title_hint", "Untitled"))
    return {
        "url": url,
        "title": title_hint,
        "insights": ["content_summary", "key_links", "recommended_actions"],
    }


def screenshot_analysis_stub(payload: dict[str, Any]) -> dict[str, Any]:
    hint = str(payload.get("hint", ""))
    return {"detected_text": "Stub OCR text", "analysis": f"Structured prompt generated from screenshot. {hint}".strip()}


REGISTRY: dict[str, ToolHandler] = {
    "text_summarizer": text_summarizer,
    "text_to_video_stub": text_to_video_stub,
    "page_analyzer": page_analyzer,
    "screenshot_analysis_stub": screenshot_analysis_stub,
}
