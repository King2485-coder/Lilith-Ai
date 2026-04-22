import React from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";

const tools = [
  { name: "Reel Genius", desc: "Long video into platform-ready reels.", price: "$9/mo", usage: "12.4K runs" },
  { name: "Contract Lens", desc: "Extract legal clauses and summarize risk.", price: "$0.50/run", usage: "7.1K runs" },
  { name: "Site Clone Pro", desc: "Analyze and map site structure in seconds.", price: "Free", usage: "34K runs" },
];

export default function ToolMarketplaceScreen() {
  return (
    <EnvironmentShell
      screenKey="tool-marketplace"
      title="Tool Marketplace"
      subtitle="Discover, create, price, and distribute tools across chat, feed, and profiles."
      leftActions={buildRailActions("left", "tool-marketplace")}
      rightActions={buildRailActions("right", "tool-marketplace")}
      bottomActions={buildRailActions("bottom", "tool-marketplace")}
    >
      <SurfaceScroll>
        <SectionCard title="Discovery" subtitle="Trending + personalized tools">
          <View style={ui.rowWrap}>
            {["Trending", "Media", "Finance", "Legal", "Automation", "Education"].map((tab) => (
              <ActionChip key={tab} label={tab} />
            ))}
          </View>
          {tools.map((tool) => (
            <View key={tool.name} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "800" }}>{tool.name}</Text>
              <Text style={ui.bodyText}>{tool.desc}</Text>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{tool.usage}</Text>
                <Text style={{ color: browserTheme.text, fontSize: 12 }}>{tool.price}</Text>
              </View>
              <View style={ui.rowWrap}>
                <ActionChip label="Try" />
                <ActionChip label="Share" />
                <ActionChip label="Run in Chat" />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Creator Console" subtitle="Build and monetize directly inside Lilith">
          <View style={ui.rowWrap}>
            <ActionChip label="New Tool" />
            <ActionChip label="Set Pricing" />
            <ActionChip label="Publish" />
            <ActionChip label="Revenue" />
          </View>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
