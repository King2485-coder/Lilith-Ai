import React, { useCallback, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

export default function AdminControlScreen() {
  const { apiBase, token } = useSession();
  const [status, setStatus] = useState("Admin controls ready.");
  const [suspendUserId, setSuspendUserId] = useState("");
  const [refundIntentId, setRefundIntentId] = useState("");
  const [toolName, setToolName] = useState("text_summarizer");

  const runAction = useCallback(
    async (path: string, body?: unknown) => {
      try {
        const data = await apiRequest<any>(apiBase, token, path, "POST", body);
        setStatus(JSON.stringify(data));
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token]
  );

  return (
    <EnvironmentShell
      screenKey="admin-control"
      title="Admin Control"
      subtitle="Platform control for users, payments, tools, moderation, and system operations."
      leftActions={buildRailActions("left", "admin-control")}
      rightActions={buildRailActions("right", "admin-control")}
      bottomActions={buildRailActions("bottom", "admin-control")}
    >
      <SurfaceScroll>
        <SectionCard title="System">
          <View style={ui.rowWrap}>
            <ActionChip label="Restart Realtime" onPress={() => runAction("/api/v1/admin/system/fix/restart", { service_name: "realtime" })} />
            <ActionChip label="Clear Cache" onPress={() => runAction("/api/v1/admin/system/fix/clear-cache", { prefix: "lilith:" })} />
            <ActionChip label="Trigger Health Refresh" onPress={() => runAction("/api/v1/admin/system/fix/restart", { service_name: "api" })} />
          </View>
        </SectionCard>

        <SectionCard title="Users">
          <TextInput
            value={suspendUserId}
            onChangeText={setSuspendUserId}
            placeholder="User id"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable
            onPress={() => runAction(`/api/v1/admin/users/${suspendUserId}/status`, { status: "suspended" })}
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Suspend User</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Payments">
          <TextInput
            value={refundIntentId}
            onChangeText={setRefundIntentId}
            placeholder="Payment intent id"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable
            onPress={() => runAction("/api/v1/admin/payments/refund", { payment_intent_id: refundIntentId })}
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Refund</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Tools Moderation">
          <TextInput
            value={toolName}
            onChangeText={setToolName}
            placeholder="Tool name"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable
            onPress={() => runAction("/api/v1/admin/tools/control", { tool_name: toolName, approved: true, enabled: false, note: "Disabled via admin panel" })}
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Disable Tool</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Action Log">
          <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{status}</Text>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
