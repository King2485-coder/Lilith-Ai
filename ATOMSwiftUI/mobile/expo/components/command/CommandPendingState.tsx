import React from "react";
import { ActivityIndicator, StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../../constants/colors";

export function CommandPendingState({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <View style={styles.card}>
      <View style={styles.row}>
        <ActivityIndicator color={browserTheme.action} />
        <Text style={styles.title}>{title}</Text>
      </View>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "rgba(87,160,255,0.4)",
    backgroundColor: "rgba(15,26,43,0.95)",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 5,
  },
  row: { flexDirection: "row", alignItems: "center", gap: 8 },
  title: { color: browserTheme.text, fontSize: 13, fontWeight: "800" },
  subtitle: { color: browserTheme.textMuted, fontSize: 12 },
});
