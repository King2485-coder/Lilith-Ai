import React, { createContext, useContext, useMemo, useState } from "react";
import { useSession } from "./SessionProvider";

type ConnectedApp = {
  id: string;
  name: string;
  domain: string;
  lastSync: string;
};

type BrowserContextValue = {
  connectedApps: ConnectedApp[];
  pageUrl: string;
  setPageUrl: (url: string) => void;
  refreshApps: () => Promise<void>;
  connectApp: (name: string, domain: string) => Promise<void>;
  analyzePage: (url: string) => Promise<any>;
  sendToChat: (targetUserId: string, text: string) => Promise<any>;
  runTool: (toolName: string, payload: Record<string, any>) => Promise<any>;
};

const BrowserContext = createContext<BrowserContextValue | undefined>(undefined);

async function api(apiBase: string, path: string, method: string, token: string, body?: any) {
  const response = await fetch(`${apiBase}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || "Request failed");
  }
  return response.json();
}

export function BrowserProvider({ children }: { children: React.ReactNode }) {
  const { token, apiBase } = useSession();
  const [connectedApps, setConnectedApps] = useState<ConnectedApp[]>([]);
  const [pageUrl, setPageUrl] = useState("https://example.com");

  const refreshApps = async () => {
    const data = await api(apiBase, "/api/v1/browser/apps", "GET", token);
    setConnectedApps(
      (data.items || []).map((item: any) => ({
        id: item.id,
        name: item.name,
        domain: item.domain,
        lastSync: item.last_sync,
      }))
    );
  };

  const connectApp = async (name: string, domain: string) => {
    await api(apiBase, "/api/v1/browser/connect", "POST", token, { name, domain });
    await refreshApps();
  };

  const analyzePage = async (url: string) => api(apiBase, "/api/v1/browser/analyze", "POST", token, { url });

  const sendToChat = async (targetUserId: string, text: string) =>
    api(apiBase, "/api/v1/browser/send-to-chat", "POST", token, { target_user_id: targetUserId, text });

  const runTool = async (toolName: string, payload: Record<string, any>) =>
    api(apiBase, "/api/v1/browser/run-tool", "POST", token, { tool_name: toolName, input_payload: payload });

  const value = useMemo(
    () => ({ connectedApps, pageUrl, setPageUrl, refreshApps, connectApp, analyzePage, sendToChat, runTool }),
    [connectedApps, pageUrl]
  );

  return <BrowserContext.Provider value={value}>{children}</BrowserContext.Provider>;
}

export function useBrowser() {
  const value = useContext(BrowserContext);
  if (!value) {
    throw new Error("useBrowser must be used inside BrowserProvider");
  }
  return value;
}
