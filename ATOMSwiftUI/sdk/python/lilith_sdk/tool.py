from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable, Dict, Optional


@dataclass(slots=True)
class ToolContext:
    user: dict[str, Any] = field(default_factory=dict)
    chat: Optional[dict[str, Any]] = None
    message: Optional[dict[str, Any]] = None
    permissions: list[str] = field(default_factory=list)


class LilithTool:
    tool_id: str = ""
    name: str = ""
    description: str = ""
    category: str = "Automation"
    input_schema: Dict[str, Any] = {}
    output_schema: Dict[str, Any] = {}
    pricing_model: str = "free"
    price_amount: float = 0.0
    currency: str = "USD"

    async def run(self, tool_input: dict[str, Any], context: ToolContext) -> dict[str, Any]:
        raise NotImplementedError("Implement run() in your tool class.")


def tool(
    *,
    tool_id: str,
    name: str,
    description: str,
    category: str = "Automation",
    input_schema: Optional[dict[str, Any]] = None,
    output_schema: Optional[dict[str, Any]] = None,
    pricing_model: str = "free",
    price_amount: float = 0.0,
    currency: str = "USD",
) -> Callable[[Callable[[dict[str, Any], ToolContext], Awaitable[dict[str, Any]]]], LilithTool]:
    def _decorate(fn: Callable[[dict[str, Any], ToolContext], Awaitable[dict[str, Any]]]) -> LilithTool:
        class _FunctionTool(LilithTool):
            pass

        instance = _FunctionTool()
        instance.tool_id = tool_id
        instance.name = name
        instance.description = description
        instance.category = category
        instance.input_schema = input_schema or {}
        instance.output_schema = output_schema or {}
        instance.pricing_model = pricing_model
        instance.price_amount = price_amount
        instance.currency = currency

        async def _runner(tool_input: dict[str, Any], context: ToolContext) -> dict[str, Any]:
            return await fn(tool_input, context)

        instance.run = _runner  # type: ignore[assignment]
        return instance

    return _decorate

