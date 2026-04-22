import { router } from "expo-router";
import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../constants/colors";
import { LILITH_SCREENS, LilithScreenKey } from "../constants/lilith-ui";

type RailAction = { id: string; label: string; onPress: () => void };

export function buildRailActions(kind: "left" | "right" | "bottom", screenKey: LilithScreenKey): RailAction[] {
  const leftRoutes: LilithScreenKey[] = ["chat", "inbox", "profile", "wallet", "home", "library", "vault"];
  const rightRoutes: LilithScreenKey[] = ["tools", "browser", "workspace", "cloud", "tool-marketplace", "growth-system", "observability-dashboard"];
  const bottomRoutes: LilithScreenKey[] = ["home", "chat", "inbox", "wallet", "library", "tools"];

  const source = kind === "left" ? leftRoutes : kind === "right" ? rightRoutes : bottomRoutes;
  return source
    .filter((key) => key !== screenKey)
    .map((key) => {
      const item = LILITH_SCREENS.find((s) => s.key === key);
      return {
        id: `${kind}-${key}`,
        label: item?.title ?? key,
        onPress: () => router.push((item?.route ?? "/home") as never),
      };
    });
}

export function SurfaceScroll({ children }: { children: React.ReactNode }) {
  return (
    <ScrollView contentContainerStyle={styles.surfaceContent} showsVerticalScrollIndicator={false}>
      {children}
    </ScrollView>
  );
}

export function SectionCard({
  title,
  subtitle,
  right,
  children,
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderCopy}>
          <Text style={styles.cardTitle}>{title}</Text>
          {subtitle ? <Text style={styles.cardSubtitle}>{subtitle}</Text> : null}
        </View>
        {right}
      </View>
      {children}
    </View>
  );
}

export function StatPill({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statPill}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue}>{value}</Text>
    </View>
  );
}

export function ActionChip({ label, onPress }: { label: string; onPress?: () => void }) {
  return (
    <Pressable onPress={onPress} style={styles.actionChip}>
      <Text style={styles.actionChipText}>{label}</Text>
    </Pressable>
  );
}

export const styles = StyleSheet.create({
  surfaceContent: { padding: 16, gap: 14, paddingBottom: 132 },
  card: {
    borderRadius: 24,
    backgroundColor: "rgba(12,24,40,0.58)",
    padding: 16,
    gap: 10,
    shadowColor: "#000",
    shadowOpacity: 0.2,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 10 },
  },
  cardHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  cardHeaderCopy: { gap: 2, flex: 1 },
  cardTitle: { color: browserTheme.text, fontSize: 18, fontWeight: "800" },
  cardSubtitle: { color: browserTheme.textMuted, fontSize: 13 },
  rowWrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  statPill: {
    borderRadius: 14,
    backgroundColor: "rgba(20,35,57,0.78)",
    paddingHorizontal: 11,
    paddingVertical: 9,
    minWidth: 100,
  },
  statLabel: { color: browserTheme.textMuted, fontSize: 11 },
  statValue: { color: browserTheme.text, fontSize: 14, marginTop: 2, fontWeight: "700" },
  actionChip: {
    borderRadius: 999,
    backgroundColor: "rgba(37,61,92,0.78)",
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  actionChipText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "700" },
  bodyText: { color: browserTheme.textSoft, fontSize: 13, lineHeight: 19 },
});
