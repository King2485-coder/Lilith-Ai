from __future__ import annotations

from typing import Any, Optional

import httpx

from .tool import LilithTool


class LilithDeveloperClient:
    def __init__(self, base_url: str, *, user_token: Optional[str] = None, developer_token: Optional[str] = None, timeout: float = 20.0):
        self.base_url = base_url.rstrip("/")
        self.user_token = user_token
        self.developer_token = developer_token
        self.timeout = timeout

    def _headers(self, *, user_auth: bool = False, developer_auth: bool = False) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if user_auth and self.user_token:
            headers["Authorization"] = f"Bearer {self.user_token}"
        if developer_auth and self.developer_token:
            headers["Authorization"] = f"Bearer {self.developer_token}"
        return headers

    def create_app(self, name: str, redirect_uri: str, scopes: Optional[list[str]] = None, metadata: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        payload = {
            "name": name,
            "redirect_uri": redirect_uri,
            "scopes": scopes or [],
            "metadata": metadata or {},
        }
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(f"{self.base_url}/api/v1/developer/apps", json=payload, headers=self._headers(user_auth=True))
            res.raise_for_status()
            return res.json()

    def authorize(self, client_id: str, redirect_uri: str, scopes: Optional[list[str]] = None, state: Optional[str] = None) -> dict[str, Any]:
        payload = {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scopes": scopes or [],
            "state": state,
        }
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(f"{self.base_url}/api/v1/oauth/authorize", json=payload, headers=self._headers(user_auth=True))
            res.raise_for_status()
            return res.json()

    def exchange_token(self, client_id: str, client_secret: str, code: str, redirect_uri: str) -> dict[str, Any]:
        payload = {
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
        }
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(f"{self.base_url}/api/v1/oauth/token", json=payload)
            res.raise_for_status()
            data = res.json()
            self.developer_token = data.get("access_token")
            return data

    def publish_tool(self, app_id: str, tool: LilithTool, *, entrypoint: str, runtime: str = "python", version: str = "1.0.0", tags: Optional[list[str]] = None, policy: Optional[dict[str, Any]] = None, publish: bool = True) -> dict[str, Any]:
        payload = {
            "app_id": app_id,
            "tool_id": tool.tool_id,
            "name": tool.name,
            "description": tool.description,
            "category": tool.category,
            "pricing_model": tool.pricing_model,
            "price_amount": tool.price_amount,
            "currency": tool.currency,
            "tags": tags or [],
            "runtime": runtime,
            "entrypoint": entrypoint,
            "version": version,
            "input_schema": tool.input_schema,
            "output_schema": tool.output_schema,
            "policy": policy or {},
            "publish": publish,
        }
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(f"{self.base_url}/api/v1/developer/tools", json=payload, headers=self._headers(developer_auth=True))
            res.raise_for_status()
            return res.json()

    def run_tool(self, listing_id: str, tool_input: dict[str, Any], *, conversation_id: Optional[str] = None, message_id: Optional[str] = None, insert_message: bool = True, insert_media: bool = False, trigger_action: Optional[str] = None) -> dict[str, Any]:
        payload = {
            "input": tool_input,
            "conversation_id": conversation_id,
            "message_id": message_id,
            "insert_message": insert_message,
            "insert_media": insert_media,
            "trigger_action": trigger_action,
        }
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(
                f"{self.base_url}/api/v1/developer/tools/{listing_id}/run",
                json=payload,
                headers=self._headers(developer_auth=True),
            )
            res.raise_for_status()
            return res.json()

    def get_context(self, *, conversation_id: Optional[str] = None, message_id: Optional[str] = None) -> dict[str, Any]:
        payload = {"conversation_id": conversation_id, "message_id": message_id}
        with httpx.Client(timeout=self.timeout) as client:
            res = client.post(f"{self.base_url}/api/v1/developer/context", json=payload, headers=self._headers(developer_auth=True))
            res.raise_for_status()
            return res.json()

    def revenue(self) -> dict[str, Any]:
        with httpx.Client(timeout=self.timeout) as client:
            res = client.get(f"{self.base_url}/api/v1/developer/payments/revenue", headers=self._headers(developer_auth=True))
            res.raise_for_status()
            return res.json()

