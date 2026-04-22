import { Bookmark, FileText, Film, Image as ImageIcon, Receipt, Search, Sparkles, Wand2 } from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Animated, Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type LibraryItem = {
  id: string;
  item_type: string;
  title: string;
  description: string;
  category: string;
  folder: string;
  source: string;
  tags: string[];
  updated_at: string;
};

type BookmarkItem = { id: string; title: string; url: string; updated_at: string };
type SavedPage = { id: string; title: string; url: string; summary: string; updated_at: string };
type Grouped = { library: LibraryItem[]; workspace: any[]; vault: any[] };
type WorkspaceItem = { id: string; title: string; workspace_type: string; status: string; updated_at: string };

const CATEGORY_ACCENTS: Record<string, string> = {
  media: "#5DA8FF",
  documents: "#7EDFA4",
  bookmarks: "#F3B13E",
  receipts: "#C29BFF",
  tools: "#55D3CE",
};

function iconForCategory(category: string) {
  const c = category.toLowerCase();
  if (c.includes("media") || c.includes("video")) return Film;
  if (c.includes("bookmark") || c.includes("web")) return Bookmark;
  if (c.includes("receipt")) return Receipt;
  if (c.includes("image") || c.includes("photo")) return ImageIcon;
  return FileText;
}

function HighlightedText({ text, query }: { text: string; query: string }) {
  if (!query.trim()) return <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{text}</Text>;
  const lowerText = text.toLowerCase();
  const lowerQuery = query.toLowerCase();
  const idx = lowerText.indexOf(lowerQuery);
  if (idx === -1) return <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{text}</Text>;
  const before = text.slice(0, idx);
  const match = text.slice(idx, idx + query.length);
  const after = text.slice(idx + query.length);
  return (
    <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
      {before}
      <Text style={{ color: browserTheme.textSoft, fontWeight: "800", backgroundColor: "rgba(79,163,255,0.18)" }}>{match}</Text>
      {after}
    </Text>
  );
}

export default function LibraryScreen() {
  const { apiBase, token } = useSession();
  const { activeBrowserUrl, activeSelectedContent, setActiveSelectedContent } = useCommandContext();
  const [query, setQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState<string>("all");
  const [items, setItems] = useState<LibraryItem[]>([]);
  const [bookmarks, setBookmarks] = useState<BookmarkItem[]>([]);
  const [pages, setPages] = useState<SavedPage[]>([]);
  const [grouped, setGrouped] = useState<Grouped | null>(null);
  const [workspaceContinue, setWorkspaceContinue] = useState<WorkspaceItem | null>(null);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [status, setStatus] = useState("Library ready.");
  const [quickActionId, setQuickActionId] = useState<string>("");
  const [saveToast, setSaveToast] = useState<{ message: string; kind: "library" | "page"; id: string } | null>(null);
  const savePulse = useRef(new Animated.Value(0)).current;
  const liveSearchTimer = useRef<number | null>(null);

  const runLoad = useCallback(
    async (liveMode = false) => {
      try {
        const categoryParam = activeCategory !== "all" ? `&category=${encodeURIComponent(activeCategory)}` : "";
        const qParam = query ? `?q=${encodeURIComponent(query)}${categoryParam}` : categoryParam ? `?${categoryParam.slice(1)}` : "";
        const [libraryRes, bookmarksRes, pagesRes, workspaceRes] = await Promise.all([
          apiRequest<{ items: LibraryItem[] }>(apiBase, token, `/api/v1/storage/library${qParam}`),
          apiRequest<{ items: BookmarkItem[] }>(apiBase, token, "/api/v1/storage/bookmarks"),
          apiRequest<{ items: SavedPage[] }>(apiBase, token, "/api/v1/storage/saved-pages"),
          apiRequest<{ items: WorkspaceItem[] }>(apiBase, token, "/api/v1/storage/workspace"),
        ]);
        if (query.trim()) {
          const groupedRes = await apiRequest<Grouped>(
            apiBase,
            token,
            `/api/v1/storage/search?q=${encodeURIComponent(query)}&include_vault=true`
          );
          setGrouped(groupedRes);
          if (!liveMode) {
            setRecentSearches((prev) => [query.trim(), ...prev.filter((x) => x !== query.trim())].slice(0, 6));
          }
        } else {
          setGrouped(null);
        }
        setItems(libraryRes.items || []);
        setBookmarks(bookmarksRes.items || []);
        setPages(pagesRes.items || []);
        setWorkspaceContinue((workspaceRes.items || []).find((x) => x.status === "active") || workspaceRes.items?.[0] || null);
        setStatus(`Loaded ${libraryRes.items.length} items.`);
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, query, activeCategory]
  );

  useEffect(() => {
    runLoad();
  }, [runLoad]);

  useEffect(() => {
    if (liveSearchTimer.current) clearTimeout(liveSearchTimer.current);
    liveSearchTimer.current = setTimeout(() => {
      runLoad(true);
    }, 250) as unknown as number;
    return () => {
      if (liveSearchTimer.current) clearTimeout(liveSearchTimer.current);
    };
  }, [query, activeCategory, runLoad]);

  const animateSaved = () => {
    Animated.sequence([
      Animated.timing(savePulse, { toValue: 1, duration: 180, useNativeDriver: true }),
      Animated.timing(savePulse, { toValue: 0, duration: 360, useNativeDriver: true }),
    ]).start();
  };

  const saveCurrentPage = useCallback(async () => {
    if (!activeBrowserUrl) return;
    try {
      const out = await apiRequest<SavedPage>(apiBase, token, "/api/v1/storage/saved-pages", "POST", {
        title: "Saved from Browser",
        url: activeBrowserUrl,
        summary: activeSelectedContent?.slice(0, 200) || "",
      });
      animateSaved();
      setSaveToast({ message: "Saved page to Library", kind: "page", id: out.id });
      setStatus("Saved page to Library.");
      await runLoad();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, activeBrowserUrl, activeSelectedContent, runLoad]);

  const saveToolOutput = useCallback(async () => {
    if (!activeSelectedContent) return;
    try {
      const out = await apiRequest<LibraryItem>(apiBase, token, "/api/v1/storage/library", "POST", {
        item_type: "tool_output",
        title: "Tool Output",
        description: activeSelectedContent.slice(0, 180),
        category: "tools",
        folder: "Tool Outputs",
        source: "tools",
        storage_url: "",
      });
      animateSaved();
      setSaveToast({ message: "Saved output with auto-tags", kind: "library", id: out.id });
      setStatus("Saved output to Library.");
      await runLoad();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, activeSelectedContent, runLoad]);

  const undoLastSave = useCallback(async () => {
    if (!saveToast) return;
    try {
      if (saveToast.kind === "library") {
        await apiRequest(apiBase, token, `/api/v1/storage/library/${saveToast.id}`, "DELETE");
      } else {
        await apiRequest(apiBase, token, `/api/v1/storage/saved-pages/${saveToast.id}`, "DELETE");
      }
      setStatus("Save undone.");
      setSaveToast(null);
      await runLoad();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, saveToast, runLoad]);

  const categoryCounts = useMemo(() => {
    const map: Record<string, number> = {};
    items.forEach((it) => {
      const key = (it.category || "general").toLowerCase();
      map[key] = (map[key] || 0) + 1;
    });
    return map;
  }, [items]);

  const categories = useMemo(() => ["all", "media", "documents", "bookmarks", "receipts", "tools"], []);
  const recent = useMemo(() => items.slice(0, 4), [items]);

  return (
    <EnvironmentShell
      screenKey="library"
      title="Library"
      subtitle="Everything saved, organized, and instantly reusable."
      leftActions={buildRailActions("left", "library")}
      rightActions={buildRailActions("right", "library")}
      bottomActions={buildRailActions("bottom", "library")}
    >
      <SurfaceScroll>
        {workspaceContinue ? (
          <SectionCard title="Continue" subtitle="Resume your latest unfinished work">
            <View style={{ borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 11, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "800" }}>{workspaceContinue.title}</Text>
              <Text style={ui.bodyText}>{workspaceContinue.workspace_type} • {workspaceContinue.status}</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Resume" onPress={() => setActiveSelectedContent(workspaceContinue.title)} />
                <ActionChip label="Open Workspace" />
              </View>
            </View>
          </SectionCard>
        ) : null}

        <SectionCard title="Search + Save" subtitle={status}>
          <View style={{ borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, paddingHorizontal: 10, paddingVertical: 8, flexDirection: "row", alignItems: "center", gap: 8 }}>
            <Search size={15} color={browserTheme.textMuted} />
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder="Search receipts, pages, outputs..."
              placeholderTextColor={browserTheme.textMuted}
              style={{ flex: 1, color: browserTheme.text, fontSize: 13 }}
            />
          </View>
          <View style={ui.rowWrap}>
            <ActionChip label="Search" onPress={() => runLoad()} />
            <ActionChip label="Save Page" onPress={saveCurrentPage} />
            <ActionChip label="Save Output" onPress={saveToolOutput} />
            <Animated.View style={{ transform: [{ scale: savePulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.1] }) }] }}>
              <View style={{ borderRadius: 999, borderWidth: 1, borderColor: "rgba(79,163,255,0.45)", backgroundColor: "rgba(79,163,255,0.16)", paddingHorizontal: 10, paddingVertical: 6, flexDirection: "row", alignItems: "center", gap: 5 }}>
                <Wand2 size={12} color={browserTheme.action} />
                <Text style={{ color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" }}>Auto-tagging</Text>
              </View>
            </Animated.View>
          </View>
          {recentSearches.length ? (
            <View style={ui.rowWrap}>
              {recentSearches.map((s) => (
                <Pressable key={s} onPress={() => setQuery(s)} style={{ borderRadius: 999, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, paddingHorizontal: 10, paddingVertical: 7 }}>
                  <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{s}</Text>
                </Pressable>
              ))}
            </View>
          ) : null}
        </SectionCard>

        <SectionCard title="Categories" subtitle="Smart lanes">
          <View style={ui.rowWrap}>
            {categories.map((category) => {
              const accent = CATEGORY_ACCENTS[category] || browserTheme.action;
              const count = category === "all" ? items.length : categoryCounts[category] || 0;
              const active = category === activeCategory;
              return (
                <Pressable
                  key={category}
                  onPress={() => setActiveCategory(category)}
                  style={{ borderRadius: 999, borderWidth: 1, borderColor: active ? accent : browserTheme.border, backgroundColor: active ? `${accent}22` : browserTheme.panelElevated, paddingHorizontal: 11, paddingVertical: 8 }}
                >
                  <Text style={{ color: browserTheme.textSoft, fontSize: 12, fontWeight: "700", textTransform: "capitalize" }}>
                    {category} ({count})
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </SectionCard>

        {grouped ? (
          <SectionCard title="Live Grouped Results" subtitle="Library, Workspace, Vault metadata">
            <View style={{ flexDirection: "row", gap: 10 }}>
              {[
                { label: "Library", value: grouped.library.length },
                { label: "Workspace", value: grouped.workspace.length },
                { label: "Vault", value: grouped.vault.length },
              ].map((box) => (
                <View key={box.label} style={{ flex: 1, borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 10, alignItems: "center" }}>
                  <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>{box.label}</Text>
                  <Text style={{ color: browserTheme.text, fontSize: 20, fontWeight: "800" }}>{box.value}</Text>
                </View>
              ))}
            </View>
          </SectionCard>
        ) : null}

        <SectionCard title="Library Grid" subtitle={`${items.length} items`}>
          {!!items.length ? (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
              {items.map((item) => {
                const categoryKey = (item.category || "").toLowerCase();
                const accent = CATEGORY_ACCENTS[categoryKey] || browserTheme.action;
                const Icon = iconForCategory(item.category || item.item_type);
                const showQuick = quickActionId === item.id;
                return (
                  <View key={item.id} style={{ width: "47%", gap: 6 }}>
                    <Pressable
                      onPress={() => setActiveSelectedContent(item.description || item.title)}
                      onLongPress={() => setQuickActionId((prev) => (prev === item.id ? "" : item.id))}
                      style={{ borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 10, gap: 5 }}
                    >
                      <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
                        <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: `${accent}33`, alignItems: "center", justifyContent: "center" }}>
                          <Icon size={12} color={accent} />
                        </View>
                        <Text numberOfLines={1} style={{ color: browserTheme.text, fontWeight: "700", flex: 1 }}>
                          {item.title}
                        </Text>
                      </View>
                      <HighlightedText text={item.description || `${item.item_type} in ${item.folder}`} query={query} />
                      <Text style={{ color: browserTheme.textMuted, fontSize: 10 }}>
                        {item.category} • {item.updated_at}
                      </Text>
                      {item.tags?.length ? (
                        <Text style={{ color: browserTheme.textMuted, fontSize: 10 }}>#{item.tags.slice(0, 3).join(" #")}</Text>
                      ) : null}
                    </Pressable>
                    {showQuick ? (
                      <View style={ui.rowWrap}>
                        <ActionChip label="Open" onPress={() => setActiveSelectedContent(item.description || item.title)} />
                        <ActionChip label="Send to Workspace" />
                        <ActionChip label="Secure in Vault" />
                      </View>
                    ) : null}
                  </View>
                );
              })}
            </View>
          ) : (
            <View style={{ borderRadius: 14, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 14, alignItems: "center", gap: 8 }}>
              <Sparkles size={15} color={browserTheme.textMuted} />
              <Text style={{ color: browserTheme.textSoft, fontSize: 13, fontWeight: "700" }}>Nothing saved yet</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12, textAlign: "center" }}>
                Try: Save a page from Browser, save a tool output, or quick save from anywhere.
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Save Page" onPress={saveCurrentPage} />
                <ActionChip label="Save Output" onPress={saveToolOutput} />
              </View>
            </View>
          )}
        </SectionCard>

        {!!(bookmarks.length || pages.length) ? (
          <SectionCard title="Recent Media + Links" subtitle={`${bookmarks.length} bookmarks • ${pages.length} pages`}>
            {bookmarks.slice(0, 2).map((bm) => (
              <View key={bm.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 2 }}>
                <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{bm.title}</Text>
                <HighlightedText text={bm.url} query={query} />
              </View>
            ))}
            {pages.slice(0, 2).map((pg) => (
              <View key={pg.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 2 }}>
                <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{pg.title}</Text>
                <HighlightedText text={pg.summary || pg.url} query={query} />
              </View>
            ))}
          </SectionCard>
        ) : null}

        {saveToast ? (
          <View style={{ borderRadius: 12, borderWidth: 1, borderColor: "rgba(47,210,132,0.35)", backgroundColor: "rgba(47,210,132,0.12)", padding: 10, flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
            <Text style={{ color: browserTheme.textSoft, fontSize: 12, flex: 1 }}>{saveToast.message}</Text>
            <ActionChip label="Undo" onPress={undoLastSave} />
          </View>
        ) : null}
      </SurfaceScroll>
    </EnvironmentShell>
  );
}

