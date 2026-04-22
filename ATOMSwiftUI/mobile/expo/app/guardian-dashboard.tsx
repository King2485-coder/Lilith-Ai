import React from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";

export default function GuardianDashboardScreen() {
  return (
    <EnvironmentShell
      screenKey="guardian-dashboard"
      title="Guardian Dashboard"
      subtitle="Calm safety controls with clear activity visibility and rule management."
      leftActions={buildRailActions("left", "guardian-dashboard")}
      rightActions={buildRailActions("right", "guardian-dashboard")}
      bottomActions={buildRailActions("bottom", "guardian-dashboard")}
    >
      <SurfaceScroll>
        <SectionCard title="Child Status" subtitle="Avery · Safe mode active">
          <View style={ui.rowWrap}>
            <ActionChip label="Activity" />
            <ActionChip label="Controls" />
            <ActionChip label="Connections" />
            <ActionChip label="Safety" />
            <ActionChip label="Reports" />
          </View>
        </SectionCard>

        <SectionCard title="Activity Timeline">
          {["08:30 Learning: Math quest completed", "10:05 Theater: Approved documentary watched", "12:20 Friends Park: chatted with approved contact"].map((item) => (
            <View key={item} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={ui.bodyText}>{item}</Text>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Safety Controls">
          <View style={ui.rowWrap}>
            <ActionChip label="Blocked Topics" />
            <ActionChip label="Communication Rules" />
            <ActionChip label="Tool Access" />
            <ActionChip label="Time Limits" />
            <ActionChip label="Trusted Creators" />
          </View>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
