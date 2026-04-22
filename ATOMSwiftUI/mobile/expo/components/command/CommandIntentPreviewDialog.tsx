import React from "react";
import { Modal, Pressable, StyleSheet, Text, TextInput, View } from "react-native";

import { browserTheme } from "../../constants/colors";

export function CommandIntentPreviewDialog({
  visible,
  interpreted,
  editableCommand,
  onChangeCommand,
  onCancel,
  onConfirm,
}: {
  visible: boolean;
  interpreted: string;
  editableCommand: string;
  onChangeCommand: (value: string) => void;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <View style={styles.backdrop}>
        <View style={styles.modal}>
          <Text style={styles.tag}>Intent Preview</Text>
          <Text style={styles.interpreted}>{interpreted}</Text>
          <TextInput
            value={editableCommand}
            onChangeText={onChangeCommand}
            style={styles.input}
            placeholder="Edit command before execution"
            placeholderTextColor={browserTheme.textMuted}
          />
          <View style={styles.actions}>
            <Pressable onPress={onCancel} style={styles.cancelBtn}>
              <Text style={styles.cancelText}>Cancel</Text>
            </Pressable>
            <Pressable onPress={onConfirm} style={styles.confirmBtn}>
              <Text style={styles.confirmText}>Execute</Text>
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
    backgroundColor: "rgba(2,8,16,0.72)",
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
  },
  modal: {
    width: "100%",
    maxWidth: 460,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: "rgba(11,23,41,0.96)",
    padding: 16,
    gap: 10,
  },
  tag: { color: browserTheme.action, fontSize: 12, fontWeight: "800" },
  interpreted: { color: browserTheme.textSoft, fontSize: 12 },
  input: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: browserTheme.panelElevated,
    color: browserTheme.text,
    paddingHorizontal: 10,
    paddingVertical: 9,
    fontSize: 13,
  },
  actions: { flexDirection: "row", justifyContent: "flex-end", gap: 8 },
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
