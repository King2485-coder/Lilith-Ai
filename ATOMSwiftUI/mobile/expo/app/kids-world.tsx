import React from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";

const zones = [
  { name: "School Zone", detail: "Adaptive lessons and AI teacher quests." },
  { name: "Theater", detail: "Guardian-approved shows and movies." },
  { name: "Game Zone", detail: "Curated play with friends-only multiplayer." },
  { name: "Creative Studio", detail: "Drawing, crafts, and guided projects." },
  { name: "Friends Park", detail: "Safe social interactions with approved contacts." },
];

export default function KidsWorldScreen() {
  return (
    <EnvironmentShell
      screenKey="kids-world"
      title="Kids World"
      subtitle="Safe immersive world blending learning, play, creativity, and guided social."
      leftActions={buildRailActions("left", "kids-world")}
      rightActions={buildRailActions("right", "kids-world")}
      bottomActions={buildRailActions("bottom", "kids-world")}
    >
      <SurfaceScroll>
        <SectionCard title="Living Environment" subtitle="Interactive objects replace traditional menus">
          <View style={{ borderRadius: 14, padding: 14, backgroundColor: browserTheme.panelElevated, gap: 10 }}>
            <Text style={ui.bodyText}>Tap desk to learn. Tap TV to watch approved content. Tap console to play.</Text>
            <View style={ui.rowWrap}>
              <ActionChip label="Theme: Space" />
              <ActionChip label="Avatar" />
              <ActionChip label="Customize Layout" />
            </View>
          </View>
        </SectionCard>

        <SectionCard title="Zones">
          {zones.map((zone) => (
            <View key={zone.name} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{zone.name}</Text>
              <Text style={ui.bodyText}>{zone.detail}</Text>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Rewards + Safety">
          <View style={ui.rowWrap}>
            <ActionChip label="Daily Streak: 12" />
            <ActionChip label="Points: 1,840" />
            <ActionChip label="Safe Mode: On" />
            <ActionChip label="Guardian Rules Active" />
          </View>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
