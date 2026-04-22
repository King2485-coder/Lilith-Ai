import React, { useEffect, useMemo, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { WebView } from "react-native-webview";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useBrowser } from "../providers/BrowserProvider";

export default function BrowserScreen() {
  const { connectedApps, refreshApps, pageUrl, setPageUrl, analyzePage, runTool, sendToChat } = useBrowser();
  const { setActiveBrowserUrl, setActiveSelectedContent, setActiveConversationUserId } = useCommandContext();
  const [targetUserId, setTargetUserId] = useState("");
  const [output, setOutput] = useState("No analysis yet.");

  const cleanUrl = useMemo(() => {
    if (pageUrl.startsWith("http://") || pageUrl.startsWith("https://")) return pageUrl;
    return `https://${pageUrl}`;
  }, [pageUrl]);

  useEffect(() => {
    setActiveBrowserUrl(cleanUrl);
  }, [cleanUrl, setActiveBrowserUrl]);

  return (
    <EnvironmentShell
      screenKey="browser"
      title="Browser"
      subtitle="Analyze any page, run tools, and move outputs directly into chat or feed."
      leftActions={buildRailActions("left", "browser")}
      rightActions={buildRailActions("right", "browser")}
      bottomActions={buildRailActions("bottom", "browser")}
    >
      <SurfaceScroll>
        <SectionCard title="Live Browser Canvas" subtitle="Interactive web + Lilith AI layer">
          <TextInput
            value={pageUrl}
            onChangeText={setPageUrl}
            autoCapitalize="none"
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={{ height: 290, borderRadius: 14, overflow: "hidden", borderWidth: 1, borderColor: browserTheme.border }}>
            <WebView source={{ uri: cleanUrl }} />
          </View>
          <View style={ui.rowWrap}>
            <ActionChip
              label="Analyze"
              onPress={async () => {
                const out = JSON.stringify(await analyzePage(cleanUrl), null, 2);
                setOutput(out);
                setActiveSelectedContent(out);
              }}
            />
            <ActionChip
              label="Run Tool"
              onPress={async () => {
                const out = JSON.stringify(await runTool("page_analyzer", { url: cleanUrl }), null, 2);
                setOutput(out);
                setActiveSelectedContent(out);
              }}
            />
            <ActionChip label="Refresh Apps" onPress={refreshApps} />
          </View>
        </SectionCard>

        <SectionCard title="Send to Chat" subtitle="Push browser outputs into conversations">
          <TextInput
            value={targetUserId}
            onChangeText={(value) => {
              setTargetUserId(value);
              setActiveConversationUserId(value);
            }}
            placeholder="Target user id"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable
            onPress={async () => setOutput(JSON.stringify(await sendToChat(targetUserId, output), null, 2))}
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Send</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Connected Apps" subtitle={`${connectedApps.length} linked services`}>
          {connectedApps.map((app) => (
            <View key={app.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{app.name}</Text>
              <Text style={ui.bodyText}>{app.domain}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{app.lastSync}</Text>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Output">
          <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{output}</Text>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
