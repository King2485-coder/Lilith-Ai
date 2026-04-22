import React, { useCallback, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type Message = { id: string; sender_id: string; receiver_id: string; content: string; created_at: string };

export default function ChatScreen() {
  const { apiBase, token } = useSession();
  const { setActiveConversationUserId, setActiveSelectedContent, setChatParticipants } = useCommandContext();
  const [peerUserId, setPeerUserId] = useState("");
  const [composer, setComposer] = useState("");
  const [messages, setMessages] = useState<Message[]>([]);
  const [status, setStatus] = useState("Thread ready.");

  const loadThread = useCallback(async () => {
    if (!peerUserId) return;
    try {
      const data = await apiRequest<Message[]>(apiBase, token, `/api/v1/messages/thread/${peerUserId}`);
      setMessages(data);
      setChatParticipants([peerUserId]);
      if (data[0]?.content) setActiveSelectedContent(data[0].content);
      setStatus(`Loaded ${data.length} messages.`);
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, peerUserId]);

  const send = useCallback(async () => {
    if (!peerUserId || !composer.trim()) return;
    try {
      await apiRequest(apiBase, token, "/api/v1/messages/send", "POST", {
        receiver_id: peerUserId,
        content: composer.trim(),
      });
      setActiveSelectedContent(composer.trim());
      setComposer("");
      setStatus("Message sent.");
      await loadThread();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, peerUserId, composer, loadThread]);

  return (
    <EnvironmentShell
      screenKey="chat"
      title="Chat"
      subtitle="Username-first communication with AI actions and in-thread payments."
      leftActions={buildRailActions("left", "chat")}
      rightActions={buildRailActions("right", "chat")}
      bottomActions={buildRailActions("bottom", "chat")}
    >
      <SurfaceScroll>
        <SectionCard title="Conversations Rail" subtitle="Open by Lilith ID / username">
          <TextInput
            value={peerUserId}
            onChangeText={(value) => {
              setPeerUserId(value);
              setActiveConversationUserId(value);
            }}
            placeholder="Peer user id"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Load Thread" onPress={loadThread} />
            <ActionChip label="Inline Pay" />
            <ActionChip label="AI Suggest" />
            <ActionChip label="Create Video" />
          </View>
        </SectionCard>

        <SectionCard title="Thread View" subtitle={status}>
          {messages.length === 0 ? <Text style={ui.bodyText}>No messages yet.</Text> : null}
          {messages.map((msg) => (
            <View
              key={msg.id}
              style={{
                alignSelf: msg.receiver_id === peerUserId ? "flex-end" : "flex-start",
                maxWidth: "84%",
                borderRadius: 14,
                padding: 10,
                backgroundColor: msg.receiver_id === peerUserId ? "rgba(87,160,255,0.2)" : browserTheme.panelElevated,
              }}
            >
              <Text style={ui.bodyText}>{msg.content}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 11, marginTop: 4 }}>{msg.created_at}</Text>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Composer">
          <TextInput
            value={composer}
            onChangeText={setComposer}
            multiline
            placeholder="Write message, ask Lilith, send payment note..."
            placeholderTextColor={browserTheme.textMuted}
            style={{ minHeight: 80, borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable onPress={send} style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}>
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Send</Text>
          </Pressable>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
