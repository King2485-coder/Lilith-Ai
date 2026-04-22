import React, { useCallback, useState } from "react";
import { Pressable, Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

type NotificationItem = { id: string; type: string; title: string; body: string; read: boolean; created_at: string };

export default function InboxScreen() {
  const { apiBase, token } = useSession();
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [status, setStatus] = useState("Unified inbox ready.");

  const load = useCallback(async () => {
    try {
      const data = await apiRequest<NotificationItem[]>(apiBase, token, "/api/v1/notifications");
      setItems(data);
      setStatus(`Loaded ${data.length} inbox cards.`);
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token]);

  const cardTypeColor = (type: string) => {
    if (type.includes("payment")) return "#2F8BFF";
    if (type.includes("message")) return "#2FD284";
    if (type.includes("call")) return "#A688FF";
    if (type.includes("tool")) return "#F3B13E";
    return browserTheme.textMuted;
  };

  return (
    <EnvironmentShell
      screenKey="inbox"
      title="Inbox"
      subtitle="Action-driven stream for messages, payments, requests, documents, and tool results."
      leftActions={buildRailActions("left", "inbox")}
      rightActions={buildRailActions("right", "inbox")}
      bottomActions={buildRailActions("bottom", "inbox")}
    >
      <SurfaceScroll>
        <SectionCard title="Filters" subtitle={status}>
          <View style={ui.rowWrap}>
            {["All", "Messages", "Business", "Requests", "Transactions", "Documents", "Tools"].map((tab) => (
              <ActionChip key={tab} label={tab} />
            ))}
            <ActionChip label="Refresh" onPress={load} />
          </View>
        </SectionCard>

        <SectionCard title="Priority">
          {items.slice(0, 3).map((item) => (
            <Pressable
              key={item.id}
              style={{
                borderRadius: 14,
                borderWidth: 1,
                borderColor: browserTheme.border,
                backgroundColor: browserTheme.panelElevated,
                padding: 12,
                gap: 6,
              }}
            >
              <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{item.title}</Text>
                <View style={{ width: 9, height: 9, borderRadius: 5, backgroundColor: cardTypeColor(item.type) }} />
              </View>
              <Text style={ui.bodyText}>{item.body}</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Open" />
                <ActionChip label="Archive" />
                <ActionChip label="Mark Read" onPress={() => apiRequest(apiBase, token, `/api/v1/notifications/read/${item.id}`, "POST")} />
              </View>
            </Pressable>
          ))}
        </SectionCard>

        <SectionCard title="Recent">
          {items.slice(3).map((item) => (
            <View key={item.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{item.title}</Text>
              <Text style={ui.bodyText}>{item.body}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{item.created_at}</Text>
            </View>
          ))}
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
