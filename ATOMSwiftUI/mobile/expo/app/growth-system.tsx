import React, { useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

export default function GrowthSystemScreen() {
  const { apiBase, token } = useSession();
  const [title, setTitle] = useState("Launch with Lilith");
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState("Growth hub ready.");

  return (
    <EnvironmentShell
      screenKey="growth-system"
      title="Growth System"
      subtitle="Landing pages, waitlists, and AI-guided email campaigns integrated into Lilith."
      leftActions={buildRailActions("left", "growth-system")}
      rightActions={buildRailActions("right", "growth-system")}
      bottomActions={buildRailActions("bottom", "growth-system")}
    >
      <SurfaceScroll>
        <SectionCard title="Landing Page Builder">
          <TextInput
            value={title}
            onChangeText={setTitle}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <Pressable
            style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}
            onPress={async () => {
              try {
                const out = await apiRequest<any>(apiBase, token, "/api/v1/growth/create-page", "POST", {
                  title,
                  slug: title.toLowerCase().replace(/\s+/g, "-"),
                  body: "AI-generated landing page draft.",
                });
                setStatus(JSON.stringify(out));
              } catch (error) {
                setStatus(String(error));
              }
            }}
          >
            <Text style={{ color: "#03101E", fontWeight: "700" }}>Create Page</Text>
          </Pressable>
        </SectionCard>

        <SectionCard title="Waitlist + Email">
          <TextInput
            value={email}
            onChangeText={setEmail}
            placeholder="user@email.com"
            autoCapitalize="none"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip
              label="Join Waitlist"
              onPress={async () => {
                try {
                  const out = await apiRequest<any>(apiBase, token, "/api/v1/growth/subscribe", "POST", { email });
                  setStatus(JSON.stringify(out));
                } catch (error) {
                  setStatus(String(error));
                }
              }}
            />
            <ActionChip
              label="Send Campaign"
              onPress={async () => {
                try {
                  const out = await apiRequest<any>(apiBase, token, "/api/v1/growth/send-email", "POST", {
                    subject: "Welcome to Lilith",
                    body: "Your growth workspace is live.",
                    audience: "waitlist",
                  });
                  setStatus(JSON.stringify(out));
                } catch (error) {
                  setStatus(String(error));
                }
              }}
            />
          </View>
        </SectionCard>

        <SectionCard title="Analytics">
          <View style={ui.rowWrap}>
            <ActionChip label="Visitors: 12.4K" />
            <ActionChip label="Waitlist: 2,890" />
            <ActionChip label="CTR: 9.2%" />
            <ActionChip label="Conversion: 6.3%" />
          </View>
          <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{status}</Text>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
