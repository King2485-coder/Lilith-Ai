import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../../constants/colors";
import { CommandExecutionResult } from "../../core/commands/types";

export function CommandResultCard({
  result,
  onCta,
}: {
  result: CommandExecutionResult;
  onCta?: (action: string) => void;
}) {
  return (
    <View style={styles.card}>
      <Text style={styles.title}>{result.title}</Text>
      {result.subtitle ? <Text style={styles.subtitle}>{result.subtitle}</Text> : null}
      {result.cta ? (
        <Pressable onPress={() => onCta?.(result.cta!.action)} style={styles.cta}>
          <Text style={styles.ctaText}>{result.cta.label}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "rgba(47,210,132,0.45)",
    backgroundColor: "rgba(15,26,43,0.95)",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 4,
  },
  title: { color: browserTheme.text, fontSize: 14, fontWeight: "800" },
  subtitle: { color: browserTheme.textSoft, fontSize: 12 },
  cta: {
    marginTop: 5,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: browserTheme.actionSecondary,
    paddingHorizontal: 10,
    paddingVertical: 7,
    alignSelf: "flex-start",
  },
  ctaText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "700" },
});
