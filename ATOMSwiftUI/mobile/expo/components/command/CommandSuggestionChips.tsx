import React from "react";
import { Pressable, ScrollView, StyleSheet, Text } from "react-native";

import { browserTheme } from "../../constants/colors";
import { CommandSuggestion } from "../../core/commands/types";

export function CommandSuggestionChips({
  suggestions,
  onSelect,
}: {
  suggestions: CommandSuggestion[];
  onSelect: (value: CommandSuggestion) => void;
}) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.wrap}>
      {suggestions.slice(0, 3).map((item) => (
        <Pressable key={item.id} style={styles.chip} onPress={() => onSelect(item)}>
          <Text style={styles.chipText}>
            {item.isSuggested ? "Suggested · " : ""}
            {item.label}
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: 8, paddingRight: 8 },
  chip: {
    borderRadius: 999,
    backgroundColor: "rgba(21,38,59,0.72)",
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  chipText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "600" },
});
