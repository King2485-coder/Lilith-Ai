import { router } from "expo-router";
import React, { useMemo, useState } from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

type IntentOption = {
  id: string;
  label: string;
  command: string;
  next: string[];
};

const INTENTS: IntentOption[] = [
  {
    id: "balance",
    label: "Check my wallet",
    command: "show balance",
    next: ["send 10 usd to alex", "show notifications", "open tools"],
  },
  {
    id: "tool",
    label: "Run AI tool",
    command: "run tool text_summarizer",
    next: ["show tools", "save this", "message alex hello"],
  },
  {
    id: "notifications",
    label: "See updates",
    command: "show notifications",
    next: ["open chat", "show balance", "run tool text_summarizer"],
  },
  {
    id: "tools",
    label: "Open my tools",
    command: "show tools",
    next: ["run tool text_summarizer", "open browser", "show balance"],
  },
];

export default function OnboardingScreen() {
  const { apiBase, token, sessionId, setOnboardingCompleted } = useSession();
  const [selectedId, setSelectedId] = useState(INTENTS[0].id);
  const [completedOnce, setCompletedOnce] = useState(false);

  const selected = useMemo(() => INTENTS.find((x) => x.id === selectedId) || INTENTS[0], [selectedId]);
  const trackedStartRef = React.useRef(false);

  React.useEffect(() => {
    if (trackedStartRef.current) return;
    trackedStartRef.current = true;
    apiRequest(apiBase, token, "/api/v1/first100/events", "POST", {
      event_type: "onboarding_started",
      screen: "onboarding",
      session_id: sessionId,
      payload: { selected_intent: selected.id },
    }).catch(() => null);
  }, [apiBase, token, sessionId, selected.id]);

  return (
    <EnvironmentShell
      screenKey="home"
      title="Lilith"
      subtitle="What do you want to do?"
      leftActions={buildRailActions("left", "home")}
      rightActions={buildRailActions("right", "home")}
      bottomActions={buildRailActions("bottom", "home")}
      guidedIntentLabel="Command -> Execution -> Result"
      guidedCommand={selected.command}
      onGuidedSuccess={() => {
        setCompletedOnce(true);
        apiRequest(apiBase, token, "/api/v1/first100/events", "POST", {
          event_type: "first_action_completed",
          screen: "onboarding",
          session_id: sessionId,
          payload: { command: selected.command },
        }).catch(() => null);
      }}
    >
      <SurfaceScroll>
        <SectionCard title="What do you want to do?" subtitle="Pick one intent. Lilith runs it immediately.">
          <View style={ui.rowWrap}>
            {INTENTS.map((intent) => (
              <ActionChip
                key={intent.id}
                label={`${selected.id === intent.id ? "• " : ""}${intent.label}`}
                onPress={() => setSelectedId(intent.id)}
              />
            ))}
          </View>
          <Text style={ui.bodyText}>Prefilled command: {selected.command}</Text>
        </SectionCard>

        <SectionCard title="Next Actions" subtitle="After the first result, continue with one tap.">
          <View style={ui.rowWrap}>
            {selected.next.map((cmd) => (
              <ActionChip key={cmd} label={cmd} />
            ))}
          </View>
        </SectionCard>

        {completedOnce ? (
          <SectionCard title="You’re In" subtitle="Lilith is command-first. Say it, it happens.">
            <View style={ui.rowWrap}>
              <ActionChip
                label="Continue to Lilith"
                onPress={() => {
                  setOnboardingCompleted(true);
                  router.replace("/home");
                }}
              />
            </View>
          </SectionCard>
        ) : null}
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
