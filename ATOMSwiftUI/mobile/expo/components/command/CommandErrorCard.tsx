import React from "react";
import { StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../../constants/colors";
import { CommandExecutionResult } from "../../core/commands/types";

export function CommandErrorCard({ result }: { result: CommandExecutionResult }) {
  return (
    <View style={styles.card}>
      <Text style={styles.subtitle}>{result.title}</Text>
      {result.subtitle ? <Text style={styles.detail}>{result.subtitle}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "rgba(238,90,90,0.5)",
    backgroundColor: "rgba(40,20,24,0.88)",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 4,
  },
  subtitle: { color: browserTheme.text, fontSize: 14, fontWeight: "800" },
  detail: { color: browserTheme.textSoft, fontSize: 12 },
});
