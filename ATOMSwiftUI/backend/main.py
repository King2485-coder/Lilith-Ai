"""
Lilith AI Backend
FastAPI server — GPT-4o-mini powered chat endpoint

Start:
    pip install fastapi uvicorn openai python-dotenv
    uvicorn main:app --reload

Env:  set OPENAI_API_KEY in a .env file or your shell.
"""

import json
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Lilith AI Backend")

# Allow iOS simulator / local connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

SYSTEM_PROMPT = (
    "You are Lilith — a deeply personal AI that learns the user over time "
    "and helps them with life decisions, planning, finance, media, and more. "
    "Be concise, direct, and insightful. Never break character."
)


class Msg(BaseModel):
    message: str
    memory: list[str] = []
    system_prompt: str | None = None


class EmbedReq(BaseModel):
    text: str


class Reply(BaseModel):
    reply: str


class EmbedReply(BaseModel):
    embedding: list[float]


@app.post("/api/embed", response_model=EmbedReply)
def embed(req: EmbedReq) -> EmbedReply:
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Empty text")
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=req.text,
    )
    return EmbedReply(embedding=response.data[0].embedding)


@app.post("/api/chat", response_model=Reply)
def chat(msg: Msg) -> Reply:
    if not msg.message.strip():
        raise HTTPException(status_code=400, detail="Empty message")

    base_system = SYSTEM_PROMPT
    if msg.system_prompt and msg.system_prompt.strip():
        base_system = f"{SYSTEM_PROMPT}\n\n{msg.system_prompt.strip()}"

    memory_context = "\n".join(msg.memory)
    system = (
        base_system
        + (
            f"\n\nRelevant memory (use naturally, never list it):\n{memory_context}"
            if memory_context else ""
        )
    )

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system},
            {"role": "user",   "content": msg.message},
        ],
        max_tokens=256,
        temperature=0.7,
    )

    reply_text = response.choices[0].message.content or ""
    return Reply(reply=reply_text.strip())


@app.get("/health")
def health():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# /api/plan  — autonomous GPT planner
# ---------------------------------------------------------------------------

PLAN_SYSTEM = """
You are Lilith's autonomous planner.

Given user context and memory, propose helpful actions.

Return ONLY valid JSON in this exact format (no markdown, no extra text):
{
  "actions": [
    {
      "id": "unique_id",
      "type": "suggest | remind | checkin | notify | askUser",
      "text": "what Lilith will say or do",
      "confidence": 0.0,
      "cooldownSeconds": 900
    }
  ]
}

Rules:
- Be helpful, not spammy
- Prefer 0-2 actions per cycle
- Use memory naturally
- Avoid repetition
- Use askUser for anything sensitive or irreversible
"""


class PlanReq(BaseModel):
    context: dict
    memory: dict


@app.post("/api/plan")
def plan(req: PlanReq):
    user_msg = f"Context: {req.context}\nMemory: {req.memory}"

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": PLAN_SYSTEM},
            {"role": "user",   "content": user_msg},
        ],
        max_tokens=512,
        temperature=0.4,
    )

    raw = response.choices[0].message.content or ""
    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = {"actions": []}

    return parsed


# ---------------------------------------------------------------------------
# /api/schedule  — GPT event parser
# ---------------------------------------------------------------------------

SCHEDULE_SYSTEM = """
You convert user scheduling requests into structured calendar events.

Return ONLY a valid JSON array, no markdown, no extra text:
[
  {
    "id": "1",
    "title": "Event title",
    "start": "ISO-8601 datetime",
    "end":   "ISO-8601 datetime",
    "isRecurring": false,
    "recurrenceRule": null
  }
]

Support:
- Multiple events in one request
- Recurring schedules (daily / weekly / monthly)
- Natural language time expressions
- Assume current year/timezone when not specified
"""


class ScheduleReq(BaseModel):
    text: str


@app.post("/api/schedule")
def schedule_parse(req: ScheduleReq):
    if not req.text.strip():
        return []

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": SCHEDULE_SYSTEM},
            {"role": "user",   "content": req.text},
        ],
        max_tokens=512,
        temperature=0.2,
    )

    raw = response.choices[0].message.content or ""
    try:
        return json.loads(raw)
    except Exception:
        return []


# ---------------------------------------------------------------------------
# /api/dayplan  — GPT full-day planner
# ---------------------------------------------------------------------------

DAYPLAN_SYSTEM = """
You are an AI day planner.

You receive a target date and the user's already-scheduled events.
Fill the remaining gaps intelligently:
- Balance work, deep focus, rest, meals, and exercise
- Avoid any overlaps with existing events
- Sort by priority (1 = highest)

Return ONLY a valid JSON array, no markdown:
[
  {
    "id": "1",
    "title": "Deep Work Session",
    "start": "ISO-8601 datetime",
    "end":   "ISO-8601 datetime",
    "priority": 1
  }
]
"""


class DayPlanReq(BaseModel):
    date:   str
    events: list[dict] = []


@app.post("/api/dayplan")
def dayplan(req: DayPlanReq):
    user_msg = f"Date: {req.date}\nExisting events: {req.events}"

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": DAYPLAN_SYSTEM},
            {"role": "user",   "content": user_msg},
        ],
        max_tokens=768,
        temperature=0.3,
    )

    raw = response.choices[0].message.content or ""
    try:
        return json.loads(raw)
    except Exception:
        return []


# ---------------------------------------------------------------------------
# /api/workflow  — GPT workflow planner
# ---------------------------------------------------------------------------

WORKFLOW_SYSTEM = """
You are Lilith's workflow engine.

Convert user intent into a sequence of executable steps.

Return ONLY valid JSON in this exact shape:
{
  "id": "workflow_1",
  "steps": [
    {"id": "1", "type": "openMaps", "payload": {"query": "gym"}},
    {"id": "2", "type": "delay", "payload": {"seconds": "2"}},
    {"id": "3", "type": "notification", "payload": {"text": "You're on your way"}}
  ]
}

Allowed step types only:
- openURL (payload: url)
- openMaps (payload: query)
- notification (payload: text)
- delay (payload: seconds)
"""


class WorkflowReq(BaseModel):
    text: str


@app.post("/api/workflow")
def workflow(req: WorkflowReq):
    if not req.text.strip():
        return {"id": "workflow_empty", "steps": []}

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": WORKFLOW_SYSTEM},
            {"role": "user",   "content": req.text},
        ],
        max_tokens=512,
        temperature=0.2,
    )

    raw = response.choices[0].message.content or ""
    try:
        return json.loads(raw)
    except Exception:
        return {"id": "workflow_fallback", "steps": []}
