import { Cloud, HardDrive, Laptop, LockKeyhole, RefreshCw, Upload } from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Pressable, Switch, Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

type CloudState = {
  sync_enabled: boolean;
  encrypted_sync: boolean;
  sync_library: boolean;
  sync_workspace: boolean;
  sync_vault: boolean;
  conflict_policy: string;
  last_sync_at: string | null;
  updated_at: string;
};

type CloudPanel = {
  sync: CloudState;
  usage: {
    estimated_mb: number;
    library_items: number;
    workspace_items: number;
    vault_profiles: number;
    vault_documents: number;
  };
  devices: Array<{ id: string; name: string; platform: string; last_seen: string | null; trusted: boolean }>;
  export_supported: boolean;
};

type WorkspaceItem = { id: string; title: string; workspace_type: string; status: string; updated_at: string };

export default function CloudScreen() {
  const { apiBase, token } = useSession();
  const [state, setState] = useState<CloudState | null>(null);
  const [panel, setPanel] = useState<CloudPanel | null>(null);
  const [workspaceContinue, setWorkspaceContinue] = useState<WorkspaceItem | null>(null);
  const [deviceActionId, setDeviceActionId] = useState("");
  const [status, setStatus] = useState("Cloud settings ready.");

  const load = useCallback(async () => {
    try {
      const [data, panelData, workspaceRes] = await Promise.all([
        apiRequest<CloudState>(apiBase, token, "/api/v1/storage/cloud"),
        apiRequest<CloudPanel>(apiBase, token, "/api/v1/storage/cloud/panel"),
        apiRequest<{ items: WorkspaceItem[] }>(apiBase, token, "/api/v1/storage/workspace"),
      ]);
      setState(data);
      setPanel(panelData);
      setWorkspaceContinue((workspaceRes.items || []).find((x) => x.status === "active") || workspaceRes.items?.[0] || null);
      setStatus("Cloud state loaded.");
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token]);

  useEffect(() => {
    load();
  }, [load]);

  const patch = useCallback(
    async (patchPayload: Partial<CloudState>) => {
      if (!state) return;
      try {
        const next = await apiRequest<CloudState>(apiBase, token, "/api/v1/storage/cloud", "PATCH", patchPayload);
        setState(next);
        const panelData = await apiRequest<CloudPanel>(apiBase, token, "/api/v1/storage/cloud/panel");
        setPanel(panelData);
        setStatus("Cloud preferences updated.");
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, state]
  );

  const usagePercent = useMemo(() => {
    if (!panel) return 0;
    return Math.min(100, Math.round((panel.usage.estimated_mb / 1024) * 100));
  }, [panel]);

  return (
    <EnvironmentShell
      screenKey="cloud"
      title="Lilith Cloud"
      subtitle="Calm, secure sync control for all devices with encrypted local-first backup."
      leftActions={buildRailActions("left", "cloud")}
      rightActions={buildRailActions("right", "cloud")}
      bottomActions={buildRailActions("bottom", "cloud")}
    >
      <SurfaceScroll>
        {workspaceContinue ? (
          <SectionCard title="Continue" subtitle="Resume your latest unfinished work">
            <View style={{ borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 11, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "800" }}>{workspaceContinue.title}</Text>
              <Text style={ui.bodyText}>{workspaceContinue.workspace_type} • {workspaceContinue.status}</Text>
            </View>
          </SectionCard>
        ) : null}

        <SectionCard title="Cloud Control Panel" subtitle={status}>
          <View style={ui.rowWrap}>
            <ActionChip label="Refresh" onPress={load} />
            <ActionChip label="Sync Now" onPress={() => patch({})} />
          </View>
          {!state ? (
            <View style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 12, gap: 8 }}>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>Loading secure sync controls...</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Retry" onPress={load} />
                <ActionChip label="Enable Sync" />
              </View>
            </View>
          ) : null}
        </SectionCard>

        {state ? (
          <SectionCard title="Sync Preferences" subtitle={`Policy: ${state.conflict_policy}`}>
            {[
              { key: "sync_enabled", label: "Cloud Sync", value: state.sync_enabled, icon: Cloud },
              { key: "encrypted_sync", label: "Encrypted Sync", value: state.encrypted_sync, icon: LockKeyhole },
              { key: "sync_library", label: "Library", value: state.sync_library, icon: HardDrive },
              { key: "sync_workspace", label: "Workspace", value: state.sync_workspace, icon: RefreshCw },
              { key: "sync_vault", label: "Vault Metadata", value: state.sync_vault, icon: LockKeyhole },
            ].map((entry) => (
              <View
                key={entry.key}
                style={{
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: browserTheme.border,
                  backgroundColor: browserTheme.panelElevated,
                  paddingHorizontal: 12,
                  paddingVertical: 10,
                  flexDirection: "row",
                  alignItems: "center",
                  justifyContent: "space-between",
                }}
              >
                <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
                  <entry.icon size={13} color={browserTheme.action} />
                  <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{entry.label}</Text>
                </View>
                <Switch
                  value={entry.value}
                  onValueChange={(v) => patch({ [entry.key]: v } as Partial<CloudState>)}
                  trackColor={{ false: "#213247", true: "#4FA3FF" }}
                  thumbColor={entry.value ? "#FFFFFF" : "#8FA8C4"}
                />
              </View>
            ))}
            <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
              Last sync: {state.last_sync_at || "Not synced yet"} • Updated: {state.updated_at}
            </Text>
          </SectionCard>
        ) : null}

        {panel ? (
          <SectionCard title="Storage Usage" subtitle={`${panel.usage.estimated_mb} MB estimated`}>
            <View
              style={{
                borderRadius: 12,
                borderWidth: 1,
                borderColor: browserTheme.border,
                backgroundColor: browserTheme.panelElevated,
                padding: 10,
                gap: 8,
              }}
            >
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>Capacity used</Text>
                <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{usagePercent}%</Text>
              </View>
              <View
                style={{
                  height: 8,
                  borderRadius: 999,
                  backgroundColor: "rgba(21,36,55,0.8)",
                  borderWidth: 1,
                  borderColor: browserTheme.border,
                  overflow: "hidden",
                }}
              >
                <View
                  style={{
                    width: `${usagePercent}%`,
                    height: "100%",
                    borderRadius: 999,
                    backgroundColor: browserTheme.action,
                  }}
                />
              </View>
            </View>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
              {[
                { label: "Library", value: panel.usage.library_items },
                { label: "Workspace", value: panel.usage.workspace_items },
                { label: "Vault Profiles", value: panel.usage.vault_profiles },
                { label: "Vault Docs", value: panel.usage.vault_documents },
              ].map((u) => (
                <View
                  key={u.label}
                  style={{
                    width: "47%",
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: browserTheme.border,
                    backgroundColor: browserTheme.panelElevated,
                    padding: 10,
                    gap: 4,
                  }}
                >
                  <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{u.label}</Text>
                  <Text style={{ color: browserTheme.text, fontSize: 20, fontWeight: "800" }}>{u.value}</Text>
                </View>
              ))}
            </View>
          </SectionCard>
        ) : null}

        {panel ? (
          <SectionCard title="Devices + Export" subtitle="Trusted access and backup portability">
            {panel.devices.map((device) => (
              <View key={device.id} style={{ gap: 6 }}>
              <Pressable
                onLongPress={() => setDeviceActionId((prev) => (prev === device.id ? "" : device.id))}
                style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 2 }}
              >
                <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                  <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
                    <Laptop size={13} color={browserTheme.action} />
                    <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{device.name}</Text>
                  </View>
                  <Text style={{ color: device.trusted ? browserTheme.success : browserTheme.warning, fontSize: 11 }}>
                    {device.trusted ? "trusted" : "review"}
                  </Text>
                </View>
                <Text style={ui.bodyText}>{device.platform} • Last seen {device.last_seen || "unknown"}</Text>
              </Pressable>
              {deviceActionId === device.id ? (
                <View style={ui.rowWrap}>
                  <ActionChip label="Trust" />
                  <ActionChip label="Pause Sync" />
                  <ActionChip label="Remove Device" />
                </View>
              ) : null}
              </View>
            ))}
            <View style={ui.rowWrap}>
              <ActionChip
                label="Export All"
                onPress={async () => {
                  const out = await apiRequest<any>(apiBase, token, "/api/v1/storage/cloud/export", "POST", { scope: "all" });
                  setStatus(`Export queued: ${out.export_id}`);
                }}
              />
              <ActionChip
                label="Export Library"
                onPress={async () => {
                  const out = await apiRequest<any>(apiBase, token, "/api/v1/storage/cloud/export", "POST", { scope: "library" });
                  setStatus(`Export queued: ${out.export_id}`);
                }}
              />
              <ActionChip
                label="Export Vault"
                onPress={async () => {
                  const out = await apiRequest<any>(apiBase, token, "/api/v1/storage/cloud/export", "POST", { scope: "vault" });
                  setStatus(`Export queued: ${out.export_id}`);
                }}
              />
              <View
                style={{
                  borderRadius: 999,
                  borderWidth: 1,
                  borderColor: browserTheme.border,
                  backgroundColor: "rgba(79,163,255,0.15)",
                  paddingHorizontal: 10,
                  paddingVertical: 8,
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 6,
                }}
              >
                <Upload size={12} color={browserTheme.action} />
                <Text style={{ color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" }}>
                  Manual export only
                </Text>
              </View>
            </View>
          </SectionCard>
        ) : null}
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
