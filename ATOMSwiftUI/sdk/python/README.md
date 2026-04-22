# Lilith Developer SDK (Python)

Minimal SDK for publishing and running Lilith tools with OAuth2 scoped access.

## Install

Copy `sdk/python/lilith_sdk` into your project, or add this repo as a dependency path.

## Example

```python
import asyncio

from lilith_sdk import LilithDeveloperClient, ToolContext, tool


@tool(
    tool_id="creator.caption.refiner",
    name="Caption Refiner",
    description="Improve social post captions.",
    category="Create",
    input_schema={"type": "object", "properties": {"text": {"type": "string"}}},
    output_schema={"type": "object", "properties": {"caption": {"type": "string"}}},
    pricing_model="per_use",
    price_amount=1.0,
)
async def caption_refiner(tool_input: dict, context: ToolContext) -> dict:
    text = (tool_input.get("text") or "").strip()
    return {"caption": f"{text} #Lilith"}


client = LilithDeveloperClient(
    "http://127.0.0.1:8000",
    user_token="<user access token>",
)

app_info = client.create_app(
    name="Creator Studio App",
    redirect_uri="https://example.com/oauth/callback",
    scopes=["tools.write", "tools.run", "context.read", "chat.write", "payments.read"],
)
client_id = app_info["app"]["clientId"]
client_secret = app_info["clientSecret"]

authorize = client.authorize(
    client_id=client_id,
    redirect_uri="https://example.com/oauth/callback",
    scopes=["tools.write", "tools.run", "context.read", "chat.write", "payments.read"],
)
token = client.exchange_token(
    client_id=client_id,
    client_secret=client_secret,
    code=authorize["code"],
    redirect_uri="https://example.com/oauth/callback",
)

publish = client.publish_tool(
    app_id=app_info["app"]["id"],
    tool=caption_refiner,
    entrypoint="my_tools.caption_refiner:run",
    policy={"moderation_required": True, "min_age": 13},
)
listing_id = publish["listing"]["id"]

run = client.run_tool(
    listing_id=listing_id,
    tool_input={"text": "launch day"},
    conversation_id="conversation-id",
    insert_message=True,
)
print(run)
```

