import React from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, StatPill, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";

export default function ProfileScreen() {
  return (
    <EnvironmentShell
      screenKey="profile"
      title="Profile"
      subtitle="Identity hub for social, communication, payments, and subscriptions."
      leftActions={buildRailActions("left", "profile")}
      rightActions={buildRailActions("right", "profile")}
      bottomActions={buildRailActions("bottom", "profile")}
    >
      <SurfaceScroll>
        <SectionCard title="Lilith Identity" subtitle="@king · Lilith ID: lilith_7J92">
          <View style={{ flexDirection: "row", gap: 12, alignItems: "center" }}>
            <View style={{ width: 58, height: 58, borderRadius: 29, backgroundColor: "rgba(87,160,255,0.3)" }} />
            <View style={{ gap: 3, flex: 1 }}>
              <Text style={{ color: browserTheme.text, fontSize: 18, fontWeight: "800" }}>King</Text>
              <Text style={ui.bodyText}>Creator + builder. AI-first workflows, social tooling, and communication systems.</Text>
            </View>
          </View>
          <View style={ui.rowWrap}>
            <ActionChip label="Message" />
            <ActionChip label="Call" />
            <ActionChip label="Pay" />
            <ActionChip label="Follow" />
            <ActionChip label="Subscribe" />
          </View>
        </SectionCard>

        <SectionCard title="Stats">
          <View style={ui.rowWrap}>
            <StatPill label="Posts" value="189" />
            <StatPill label="Followers" value="18.2K" />
            <StatPill label="Following" value="510" />
            <StatPill label="Tool Sales" value="$8.4K" />
          </View>
        </SectionCard>

        <SectionCard title="Profile Tabs" subtitle="Posts · Media · Activity · Tools · Reviews">
          {["Pinned post: Lilith OS launch journal", "Top tool: Prompt from Screenshot", "Latest review: 4.9 avg from 124 buyers"].map((line) => (
            <View key={line} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={ui.bodyText}>{line}</Text>
            </View>
          ))}
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
