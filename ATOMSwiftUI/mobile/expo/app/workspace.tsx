import { CheckCircle2, Clock3, MoveRight, PlayCircle, Sparkles, UploadCloud } from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Animated, PanResponder, Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type WorkspaceItem = {
  id: string;
  workspace_type: string;
  title: string;
  status: string;
  content_ref: string;
  updated_at: string;
};

function WorkspaceLaneCard({
  item,
  onContinue,
  onMoveToLibrary,
  onQuickActions,
}: {
  item: WorkspaceItem;
  onContinue: () => void;
  onMoveToLibrary: () => Promise<void>;
  onQuickActions: () => void;
}) {
  const x = useRef(new Animated.Value(0)).current;
  const progress = progressFor(item);
  const pan = PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 14 && Math.abs(g.dx) > Math.abs(g.dy),
    onPanResponderMove: (_, g) => {
      if (g.dx > 0) x.setValue(Math.min(g.dx, 120));
    },
    onPanResponderRelease: async (_, g) => {
      if (g.dx > 92) {
        await onMoveToLibrary();
      }
      Animated.spring(x, { toValue: 0, useNativeDriver: true, bounciness: 8 }).start();
    },
  });

  return (
    <View style={{ borderRadius: 14, overflow: "hidden", backgroundColor: "transparent" }}>
      <View
        style={{
          position: "absolute",
          right: 0,
          top: 0,
          bottom: 0,
          width: 110,
          borderRadius: 14,
          backgroundColor: "rgba(47,210,132,0.22)",
          borderWidth: 1,
          borderColor: "rgba(47,210,132,0.35)",
          alignItems: "center",
          justifyContent: "center",
          gap: 4,
        }}
      >
        <UploadCloud size={14} color={browserTheme.success} />
        <Text style={{ color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" }}>Move to Library</Text>
      </View>
      <Animated.View
        {...pan.panHandlers}
        onTouchEnd={() => {}}
        style={{
          transform: [{ translateX: x }],
          borderRadius: 14,
          borderWidth: 1,
          borderColor: browserTheme.border,
          backgroundColor: browserTheme.panelElevated,
          padding: 11,
          gap: 8,
        }}
      >
        <Pressable onPress={onContinue} onLongPress={onQuickActions}>
          <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
            <Text style={{ color: browserTheme.text, fontWeight: "800", flex: 1 }} numberOfLines={1}>
              {item.title}
            </Text>
            <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{item.workspace_type}</Text>
          </View>
          <Text style={ui.bodyText}>{item.status} • updated {item.updated_at}</Text>
          <View
            style={{
              marginTop: 8,
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
                width: `${Math.round(progress * 100)}%`,
                height: "100%",
                borderRadius: 999,
                backgroundColor: progress > 0.86 ? browserTheme.success : browserTheme.action,
              }}
            />
          </View>
        </Pressable>
        <View style={ui.rowWrap}>
          <ActionChip label="Continue" onPress={onContinue} />
          <ActionChip label="Move to Library" onPress={onMoveToLibrary} />
        </View>
      </Animated.View>
    </View>
  );
}

function progressFor(item: WorkspaceItem) {
  const base = item.status === "moved_to_library" ? 1 : item.status === "completed" ? 0.95 : item.status === "paused" ? 0.56 : 0.72;
  const typeBoost = item.workspace_type.includes("video") ? 0.08 : item.workspace_type.includes("pdf") ? 0.05 : 0;
  return Math.min(1, Number((base + typeBoost).toFixed(2)));
}

export default function WorkspaceScreen() {
  const { apiBase, token } = useSession();
  const { activeSelectedContent, setActiveSelectedContent } = useCommandContext();
  const [items, setItems] = useState<WorkspaceItem[]>([]);
  const [title, setTitle] = useState("");
  const [workspaceType, setWorkspaceType] = useState("draft");
  const [status, setStatus] = useState("Workspace ready.");
  const [quickActionId, setQuickActionId] = useState("");
  const pulse = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 900, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 900, useNativeDriver: true }),
      ])
    ).start();
  }, [pulse]);

  const load = useCallback(async () => {
    try {
      const data = await apiRequest<{ items: WorkspaceItem[] }>(apiBase, token, "/api/v1/storage/workspace");
      setItems(data.items || []);
      setStatus(`Loaded ${data.items.length} active items.`);
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token]);

  useEffect(() => {
    load();
  }, [load]);

  const create = useCallback(async () => {
    if (!title.trim()) return;
    try {
      await apiRequest(apiBase, token, "/api/v1/storage/workspace", "POST", {
        workspace_type: workspaceType,
        title: title.trim(),
        content_ref: activeSelectedContent || "",
        status: "active",
      });
      setTitle("");
      setStatus("Workspace item created.");
      await load();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, title, workspaceType, activeSelectedContent, load]);

  const moveToLibrary = useCallback(
    async (itemId: string) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/storage/workspace/${itemId}/move-to-library`, "POST");
        setStatus("Moved to Library.");
        await load();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, load]
  );

  const activeCount = useMemo(() => items.filter((x) => x.status === "active").length, [items]);
  const doneCount = useMemo(() => items.filter((x) => x.status === "completed" || x.status === "moved_to_library").length, [items]);

  return (
    <EnvironmentShell
      screenKey="workspace"
      title="Workspace"
      subtitle="In-progress intelligence layer: drafts, edits, forms, and projects in one calm flow."
      leftActions={buildRailActions("left", "workspace")}
      rightActions={buildRailActions("right", "workspace")}
      bottomActions={buildRailActions("bottom", "workspace")}
    >
      <SurfaceScroll>
        <SectionCard title="Active Flow" subtitle={status}>
          <View style={{ flexDirection: "row", gap: 10 }}>
            {[
              { label: "Active", value: activeCount.toString(), icon: PlayCircle },
              { label: "Done", value: doneCount.toString(), icon: CheckCircle2 },
              { label: "Total", value: items.length.toString(), icon: Clock3 },
            ].map((s) => (
              <View
                key={s.label}
                style={{
                  flex: 1,
                  borderRadius: 14,
                  borderWidth: 1,
                  borderColor: browserTheme.border,
                  backgroundColor: browserTheme.panelElevated,
                  padding: 10,
                  gap: 4,
                }}
              >
                <s.icon size={14} color={browserTheme.action} />
                <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{s.label}</Text>
                <Text style={{ color: browserTheme.text, fontSize: 20, fontWeight: "800" }}>{s.value}</Text>
              </View>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Start New Work" subtitle="Simple creation, resume instantly">
          <TextInput
            value={title}
            onChangeText={setTitle}
            placeholder="Project title"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <TextInput
            value={workspaceType}
            onChangeText={setWorkspaceType}
            placeholder="Type: draft, video_edit, pdf_edit, form"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Create" onPress={create} />
            <ActionChip label="Refresh" onPress={load} />
          </View>
        </SectionCard>

        <SectionCard title="Project Lanes" subtitle="Drag-style move: swipe card right to move to Library">
          {items.map((item) => {
            return (
              <WorkspaceLaneCard
                key={item.id}
                item={item}
                onContinue={() => setActiveSelectedContent(item.content_ref || item.title)}
                onMoveToLibrary={() => moveToLibrary(item.id)}
                onQuickActions={() => setQuickActionId((prev) => (prev === item.id ? "" : item.id))}
              />
            );
          })}
          {quickActionId ? (
            <View style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 10, gap: 8 }}>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>Quick actions</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Continue" onPress={() => {
                  const item = items.find((x) => x.id === quickActionId);
                  if (item) setActiveSelectedContent(item.content_ref || item.title);
                }} />
                <ActionChip label="Move to Library" onPress={async () => {
                  await moveToLibrary(quickActionId);
                  setQuickActionId("");
                }} />
                <ActionChip label="Summarize Draft" />
              </View>
            </View>
          ) : null}
          {!items.length ? (
            <View
              style={{
                borderRadius: 14,
                borderWidth: 1,
                borderColor: browserTheme.border,
                backgroundColor: browserTheme.panelElevated,
                padding: 14,
                alignItems: "center",
                gap: 6,
              }}
            >
              <Animated.View style={{ transform: [{ scale: pulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] }) }] }}>
                <Sparkles size={15} color={browserTheme.action} />
              </Animated.View>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12, fontWeight: "700" }}>No active work yet</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12, textAlign: "center" }}>
                Start with a draft, video edit, PDF pass, or form. Lilith will keep it ready to continue.
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="New Draft" onPress={() => {
                  setWorkspaceType("draft");
                  setTitle("Quick Draft");
                }} />
                <ActionChip label="New Video Edit" onPress={() => {
                  setWorkspaceType("video_edit");
                  setTitle("New Video Edit");
                }} />
              </View>
            </View>
          ) : null}
          <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
            <MoveRight size={13} color={browserTheme.textMuted} />
            <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
              Gesture support: swipe right on project cards to drop into Library.
            </Text>
          </View>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
