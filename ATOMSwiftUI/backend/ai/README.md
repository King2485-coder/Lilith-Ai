# AI Layer

Split into three bounded modules:
- `intent`: classify user intent and route candidate actions.
- `reasoning`: produce constrained plans with policy context.
- `orchestration`: execute async jobs and call service/tool adapters.

