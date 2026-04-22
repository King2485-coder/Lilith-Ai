import React from "react";
import { Modal, Pressable, StyleSheet, Text, View } from "react-native";

import { browserTheme } from "../../constants/colors";
import { SafetyTier } from "../../core/commands/types";

type Props = {
  visible: boolean;
  tier: SafetyTier;
  title: string;
  subtitle: string;
  onCancel: () => void;
  onConfirm: () => void;
};

export function CommandConfirmDialog({ visible, tier, title, subtitle, onCancel, onConfirm }: Props) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <View style={styles.backdrop}>
        <View style={styles.modal}>
          <Text style={styles.tier}>{tier === "hard" ? "Hard Confirm" : "Soft Confirm"}</Text>
          <Text style={styles.title}>{title}</Text>
          <Text style={styles.subtitle}>{subtitle}</Text>
          {tier === "hard" ? <Text style={styles.hook}>Biometric hook: available for passkey/FaceID integration.</Text> : null}
          <View style={styles.actions}>
            <Pressable onPress={onCancel} style={styles.cancelBtn}>
              <Text style={styles.cancelText}>Cancel</Text>
            </Pressable>
            <Pressable onPress={onConfirm} style={styles.confirmBtn}>
              <Text style={styles.confirmText}>Confirm</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(2,8,16,0.7)",
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
  },
  modal: {
    width: "100%",
    maxWidth: 420,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: "rgba(11,23,41,0.96)",
    padding: 16,
    gap: 8,
  },
  tier: { color: browserTheme.warning, fontSize: 12, fontWeight: "800" },
  title: { color: browserTheme.text, fontSize: 17, fontWeight: "800" },
  subtitle: { color: browserTheme.textSoft, fontSize: 13 },
  hook: { color: browserTheme.textMuted, fontSize: 11 },
  actions: { flexDirection: "row", justifyContent: "flex-end", gap: 8, marginTop: 8 },
  cancelBtn: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: browserTheme.border,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  cancelText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "700" },
  confirmBtn: {
    borderRadius: 10,
    backgroundColor: browserTheme.action,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  confirmText: { color: "#03101E", fontSize: 12, fontWeight: "800" },
});
