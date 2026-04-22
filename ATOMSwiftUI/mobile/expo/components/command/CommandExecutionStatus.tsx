import React from "react";
import { StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../../constants/colors";
import { CommandStepExecutionState } from "../../core/commands/types";

export function CommandExecutionStatus({ steps }: { steps: CommandStepExecutionState[] }) {
  if (!steps.length) return null;
  return (
    <View style={styles.wrap}>
      {steps.map((step) => (
        <View key={step.step_id} style={styles.step}>
          <Text style={styles.stepLabel}>{step.label}</Text>
          <Text style={[styles.stepStatus, step.status === "success" ? styles.good : step.status === "error" ? styles.bad : styles.pending]}>
            {step.status}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: "rgba(11,23,41,0.85)",
    padding: 10,
    gap: 6,
  },
  step: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  stepLabel: { color: browserTheme.textSoft, fontSize: 12, flex: 1, paddingRight: 8 },
  stepStatus: { fontSize: 11, fontWeight: "800", textTransform: "uppercase" },
  pending: { color: browserTheme.warning },
  good: { color: browserTheme.success },
  bad: { color: browserTheme.critical },
});
