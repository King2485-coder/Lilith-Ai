import React, { useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { router } from "expo-router";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

const toolCatalog = [
  { name: "PDF Editor", key: "pdf_editor", category: "Documents" },
  { name: "Video Editor", key: "video_editor", category: "Media" },
  { name: "Long-form to Reels", key: "reels_generator", category: "Media" },
  { name: "Prompt from Screenshot", key: "screenshot_analysis_stub", category: "AI" },
  { name: "Website Clone", key: "website_clone", category: "Web" },
  { name: "Prompt from Link", key: "page_analyzer", category: "Web" },
  { name: "Finance / Wealth Wizard", key: "wealthwizard", category: "Finance" },
  { name: "Legal Ease", key: "legal_ease", category: "Legal" },
];

export default function ToolsScreen() {
  const { apiBase, token } = useSession();
  const { setActiveSelectedContent } = useCommandContext();
  const [toolName, setToolName] = useState("text_summarizer");
  const [payload, setPayload] = useState('{"text":"Summarize this note into one sentence."}');
  const [output, setOutput] = useState("Run a tool to see output.");

  return (
    <EnvironmentShell
      screenKey="tools"
      title="Tools"
      subtitle="Lilith abilities as full workspaces with fast run/return flow."
      leftActions={buildRailActions("left", "tools")}
      rightActions={buildRailActions("right", "tools")}
      bottomActions={buildRailActions("bottom", "tools")}
    >
      <SurfaceScroll>
        <SectionCard title="Tool Shelf" subtitle="Pinned and high-value capabilities">
          <View style={ui.rowWrap}>
            {toolCatalog.map((tool) => (
              <View key={tool.key} style={{ borderRadius: 12, padding: 10, minWidth: 144, backgroundColor: browserTheme.panelElevated }}>
                <Text style={{ color: browserTheme.text, fontWeight: "700", fontSize: 13 }}>{tool.name}</Text>
                <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{tool.category}</Text>
              </View>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Tool Runner" subtitle="Run against backend tool engine">
          <TextInput
            value={toolName}
            onChangeText={setToolName}
            placeholder="Tool key"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <TextInput
            value={payload}
            onChangeText={setPayload}
            multiline
            style={{ minHeight: 110, borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Favorite" />
            <ActionChip label="Use in Chat" />
            <ActionChip label="Share to Feed" />
            <ActionChip label="Application Builder" onPress={() => router.push("/application-builder")} />
          </View>
          <Pressable
            onPress={async () => {
              try {
                const data = await apiRequest<{ job_id: string }>(apiBase, token, "/api/v1/tools/run", "POST", {
                  tool_name: toolName,
                  input_payload: JSON.parse(payload),
                });
                const result = await apiRequest<any>(apiBase, token, `/api/v1/tools/results/${data.job_id}`);
                const out = JSON.stringify(result, null, 2);
                setOutput(out);
                setActiveSelectedContent(out);
              } catch (error) {
                setOutput(String(error));
              }
            }}
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Run Tool</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Result">
          <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{output}</Text>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
