from __future__ import annotations

from typing import Any

from backend.services.tools.registry import REGISTRY


def run_tool(tool_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    handler = REGISTRY.get(tool_name)
    if handler is None:
        raise ValueError(f"Unknown tool: {tool_name}")
    return handler(payload)

