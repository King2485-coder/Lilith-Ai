import { router, useLocalSearchParams } from "expo-router";
import React, { useMemo, useState } from "react";
import { Image, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { WebView } from "react-native-webview";

import { browserTheme } from "../../constants/colors";
import { useCommandSystem } from "../../core/commands/use-command-system";
import { resolveLilithLinkRecord, LilithLinkRoute } from "../../lib/lilith-links";
import { useCommandContext } from "../../providers/CommandContextProvider";

function LinkButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable style={styles.button} onPress={onPress}>
      <Text style={styles.buttonText}>{label}</Text>
    </Pressable>
  );
}

export function LilithLinkScreen({ route }: { route: LilithLinkRoute }) {
  const params = useLocalSearchParams<{ id?: string; data?: string }>();
  const record = useMemo(() => {
    if (!params.id) return null;
    return resolveLilithLinkRecord(route, params.id, params.data);
  }, [params.data, params.id, route]);
  const { executeCommand } = useCommandSystem();
  const {
    setActiveScreen,
    setActiveBrowserUrl,
    setActiveSelectedContent,
    setActiveConversationUserId,
    setPreferredCurrency,
  } = useCommandContext();
  const [runState, setRunState] = useState("Ready.");

  if (!record) {
    return (
      <View style={styles.root}>
        <Text style={styles.title}>Link unavailable</Text>
        <Text style={styles.body}>This Lilith link could not be resolved.</Text>
      </View>
    );
  }

  const payload = record.payload || {};
  const metadata = record.metadata || {};
  const title = String(metadata.title || metadata.label || record.type || "Lilith link");
  const subtitle = String(metadata.subtitle || `${route.toUpperCase()} · ${record.id}`);

  const renderCommon = () => (
    <>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>
    </>
  );

  if (route === "site") {
    const html = typeof payload.html === "string" ? payload.html : "";
    const uri =
      typeof payload.page_url === "string"
        ? payload.page_url
        : typeof payload.pageUrl === "string"
          ? payload.pageUrl
          : typeof payload.url === "string"
            ? payload.url
            : "";
    return (
      <View style={styles.root}>
        {renderCommon()}
        <View style={styles.webWrap}>
          <WebView source={html ? { html } : { uri }} />
        </View>
      </View>
    );
  }

  if (route === "run") {
    const command = typeof payload.command === "string" ? payload.command : "";
    return (
      <ScrollView contentContainerStyle={styles.root}>
        {renderCommon()}
        <Text style={styles.body}>{command || "No executable command was attached to this workflow."}</Text>
        <LinkButton
          label="Run workflow"
          onPress={async () => {
            if (!command) return;
            setRunState("Running...");
            const result = await executeCommand(command);
            setRunState(result?.subtitle || result?.title || "Workflow completed.");
          }}
        />
        <Text style={styles.body}>{runState}</Text>
      </ScrollView>
    );
  }

  if (route === "session") {
    const screen = typeof payload.activeScreen === "string" ? payload.activeScreen : "home";
    const browserUrl = typeof payload.activeBrowserUrl === "string" ? payload.activeBrowserUrl : "";
    const selectedContent = typeof payload.activeSelectedContent === "string" ? payload.activeSelectedContent : "";
    const userId = typeof payload.activeConversationUserId === "string" ? payload.activeConversationUserId : "";
    const currency = typeof payload.preferredCurrency === "string" ? payload.preferredCurrency : "USD";
    return (
      <ScrollView contentContainerStyle={styles.root}>
        {renderCommon()}
        <Text style={styles.body}>Restore screen: {screen}</Text>
        <Text style={styles.body}>Browser: {browserUrl || "None"}</Text>
        <Text style={styles.body}>Conversation: {userId || "None"}</Text>
        <LinkButton
          label="Restore session"
          onPress={() => {
            setActiveScreen(screen as never);
            setActiveBrowserUrl(browserUrl);
            setActiveSelectedContent(selectedContent);
            setActiveConversationUserId(userId);
            setPreferredCurrency(currency);
            router.push(`/${screen}` as never);
          }}
        />
      </ScrollView>
    );
  }

  const textContent =
    typeof payload.summary === "string"
      ? payload.summary
      : typeof payload.text === "string"
        ? payload.text
        : typeof payload.message === "string"
          ? payload.message
          : JSON.stringify(payload, null, 2);
  const imageUrl =
    typeof payload.image_url === "string"
      ? payload.image_url
      : typeof payload.imageUrl === "string"
        ? payload.imageUrl
        : typeof payload.preview_url === "string"
          ? payload.preview_url
          : "";

  return (
    <ScrollView contentContainerStyle={styles.root}>
      {renderCommon()}
      {imageUrl ? <Image source={{ uri: imageUrl }} resizeMode="cover" style={styles.image} /> : null}
      <Text style={styles.body}>{textContent}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flexGrow: 1,
    backgroundColor: "#02060c",
    padding: 18,
    gap: 12,
  },
  title: {
    color: browserTheme.text,
    fontSize: 20,
    fontWeight: "800",
  },
  subtitle: {
    color: browserTheme.textMuted,
    fontSize: 12,
  },
  body: {
    color: browserTheme.textSoft,
    fontSize: 13,
    lineHeight: 20,
  },
  button: {
    alignSelf: "flex-start",
    borderRadius: 12,
    backgroundColor: "rgba(123,191,255,0.16)",
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  buttonText: {
    color: browserTheme.text,
    fontWeight: "700",
    fontSize: 12,
  },
  webWrap: {
    flex: 1,
    minHeight: 560,
    overflow: "hidden",
    borderRadius: 18,
    backgroundColor: "#040912",
  },
  image: {
    width: "100%",
    height: 280,
    borderRadius: 18,
    backgroundColor: "#050a12",
  },
});
