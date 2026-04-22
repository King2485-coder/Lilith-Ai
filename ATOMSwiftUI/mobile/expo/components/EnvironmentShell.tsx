import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import * as Haptics from "expo-haptics";
import { Circle, LayoutGrid, Mic, MessageSquare, Save, Search, Sparkles, Wallet, X, Zap } from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Animated,
  Easing,
  PanResponder,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from "react-native";

import { browserTheme } from "../constants/colors";
import { LILITH_SCREENS, LilithScreenKey } from "../constants/lilith-ui";
import { useVoiceCommandController } from "../core/commands/voice-command-controller";
import { emitLilithFeedback, markLilithInteraction } from "../core/feedback/identity-feedback";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";
import { ActionChip, styles as ui } from "./LilithPrimitives";
import { CanvasModeLayer } from "./CanvasModeLayer";
import { CommandConfirmDialog } from "./command/CommandConfirmDialog";
import { CommandErrorCard } from "./command/CommandErrorCard";
import { CommandExecutionStatus } from "./command/CommandExecutionStatus";
import { CommandIntentPreviewDialog } from "./command/CommandIntentPreviewDialog";
import { CommandPendingState } from "./command/CommandPendingState";
import { CommandResultCard } from "./command/CommandResultCard";
import { CommandSuggestionChips } from "./command/CommandSuggestionChips";
import { useCommandSystem } from "../core/commands/use-command-system";

type OrbState = "idle" | "listening" | "thinking" | "ready";

type RailAction = {
  id: string;
  label: string;
  onPress: () => void;
};

type EnvironmentShellProps = {
  screenKey: LilithScreenKey;
  title: string;
  subtitle: string;
  leftActions: RailAction[];
  rightActions: RailAction[];
  bottomActions: RailAction[];
  guidedCommand?: string;
  guidedIntentLabel?: string;
  onGuidedSuccess?: () => void;
  children: React.ReactNode;
};

export function EnvironmentShell({
  screenKey,
  title,
  subtitle,
  leftActions,
  rightActions,
  bottomActions,
  guidedCommand,
  guidedIntentLabel,
  onGuidedSuccess,
  children,
}: EnvironmentShellProps) {
  const { width } = useWindowDimensions();
  const { apiBase, token, sessionId, setToken } = useSession();
  const {
    setActiveScreen,
    activeSelectedContent,
    activeBrowserUrl,
    activeScreen,
    activeConversationUserId,
    vaultLocked,
  } = useCommandContext();
  const {
    commandBusy,
    pending,
    lastOutput,
    stepStatuses,
    suggestions,
    markSuggestionUsed,
    requestIntentPreview,
    intentPreview,
    updateIntentPreviewCommand,
    confirmIntentPreview,
    cancelIntentPreview,
    rerunCommand,
    undoLastSafeAction,
    commandHistory,
    macroCandidate,
    saveMacroFromCandidate,
    recentActions,
    confirmState,
    onConfirm,
    onCancel,
    executeCommand,
  } = useCommandSystem();
  const voice = useVoiceCommandController();

  const [orbState, setOrbState] = useState<OrbState>("idle");
  const [aiQuery, setAiQuery] = useState("");
  const [quickSaveOpen, setQuickSaveOpen] = useState(false);
  const [quickSaveTitle, setQuickSaveTitle] = useState("");
  const [quickSaveDestination, setQuickSaveDestination] = useState<"library" | "workspace" | "vault">("library");
  const [quickSaveStatus, setQuickSaveStatus] = useState("");
  const [leftOpen, setLeftOpen] = useState(width >= 1100);
  const [rightOpen, setRightOpen] = useState(width >= 1100);
  const [aiExpanded, setAiExpanded] = useState(false);
  const [quickActionsOpen, setQuickActionsOpen] = useState(false);
  const [contextMenuOpen, setContextMenuOpen] = useState(false);
  const [dragStatus, setDragStatus] = useState("");
  const [canvasMode, setCanvasMode] = useState(true);
  const [commandInputFocused, setCommandInputFocused] = useState(false);
  const [first100Status, setFirst100Status] = useState("");
  const [helpPrompt, setHelpPrompt] = useState("");
  const [showHints, setShowHints] = useState(true);
  const [showSuggestions, setShowSuggestions] = useState(true);
  const [showPanels, setShowPanels] = useState(true);

  const pulse = useRef(new Animated.Value(0)).current;
  const leftRailX = useRef(new Animated.Value(-24)).current;
  const rightRailX = useRef(new Animated.Value(24)).current;
  const panelOpacity = useRef(new Animated.Value(0.7)).current;
  const aiExpandAnim = useRef(new Animated.Value(0)).current;
  const quickActionsAnim = useRef(new Animated.Value(0)).current;
  const contextMenuAnim = useRef(new Animated.Value(0)).current;
  const dragX = useRef(new Animated.Value(0)).current;
  const dragY = useRef(new Animated.Value(0)).current;
  const commandBarPulse = useRef(new Animated.Value(0)).current;
  const hintsAnim = useRef(new Animated.Value(1)).current;
  const suggestionsAnim = useRef(new Animated.Value(1)).current;
  const panelsAnim = useRef(new Animated.Value(1)).current;
  const lastInteractionAtRef = useRef(Date.now());
  const commandInputRef = useRef<TextInput>(null);
  const draftStartedAtRef = useRef<number | null>(null);
  const hesitationReportedRef = useRef(false);
  const lastInactivityReportedAtRef = useRef<number>(0);
  const lastDropoffReportedAtRef = useRef<number>(0);
  const dismissTimersRef = useRef<{
    hints?: ReturnType<typeof setTimeout>;
    suggestions?: ReturnType<typeof setTimeout>;
    panels?: ReturnType<typeof setTimeout>;
  }>({});

  const isPhone = width < 700;
  const isTablet = width >= 700 && width < 1100;
  const currentScreen = LILITH_SCREENS.find((s) => s.key === screenKey);

  const clearDismissTimers = useCallback(() => {
    if (dismissTimersRef.current.hints) clearTimeout(dismissTimersRef.current.hints);
    if (dismissTimersRef.current.suggestions) clearTimeout(dismissTimersRef.current.suggestions);
    if (dismissTimersRef.current.panels) clearTimeout(dismissTimersRef.current.panels);
    dismissTimersRef.current = {};
  }, []);

  const animateCalmLayer = useCallback((value: Animated.Value, visible: boolean, delay = 0) => {
    Animated.timing(value, {
      toValue: visible ? 1 : 0,
      duration: visible ? 160 : 210,
      delay,
      easing: visible ? Easing.out(Easing.cubic) : Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start();
  }, []);

  const scheduleAutoDismiss = useCallback(() => {
    clearDismissTimers();
    dismissTimersRef.current.hints = setTimeout(() => {
      setShowHints(false);
      animateCalmLayer(hintsAnim, false);
    }, 2000);
    dismissTimersRef.current.suggestions = setTimeout(() => {
      setShowSuggestions(false);
      animateCalmLayer(suggestionsAnim, false);
    }, 3000);
    dismissTimersRef.current.panels = setTimeout(() => {
      setShowPanels(false);
      animateCalmLayer(panelsAnim, false);
      setAiExpanded(false);
      setQuickActionsOpen(false);
      setContextMenuOpen(false);
    }, 4500);
  }, [animateCalmLayer, clearDismissTimers, hintsAnim, panelsAnim, suggestionsAnim]);

  const registerInteraction = useCallback(() => {
    markLilithInteraction();
    lastInteractionAtRef.current = Date.now();
    if (!showHints) setShowHints(true);
    if (!showSuggestions) setShowSuggestions(true);
    if (!showPanels) setShowPanels(true);
    animateCalmLayer(hintsAnim, true);
    animateCalmLayer(suggestionsAnim, true, 10);
    animateCalmLayer(panelsAnim, true, 20);
    scheduleAutoDismiss();
  }, [animateCalmLayer, hintsAnim, panelsAnim, scheduleAutoDismiss, showHints, showPanels, showSuggestions, suggestionsAnim]);

  useEffect(() => {
    setLeftOpen(!isPhone && width >= 900);
    setRightOpen(!isPhone && width >= 900);
  }, [isPhone, width]);

  useEffect(() => {
    setActiveScreen(screenKey);
  }, [screenKey, setActiveScreen]);

  useEffect(() => {
    scheduleAutoDismiss();
    return () => clearDismissTimers();
  }, [clearDismissTimers, scheduleAutoDismiss]);

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 220, easing: Easing.out(Easing.quad), useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 180, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(commandBarPulse, { toValue: 1, duration: 2600, easing: Easing.out(Easing.quad), useNativeDriver: true }),
        Animated.timing(commandBarPulse, { toValue: 0, duration: 2400, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [commandBarPulse]);

  useEffect(() => {
    Animated.parallel([
      Animated.timing(panelOpacity, {
        toValue: leftOpen || rightOpen ? 1 : 0.7,
        duration: 180,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(leftRailX, {
        toValue: leftOpen || !isPhone ? 0 : -24,
        duration: 180,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(rightRailX, {
        toValue: rightOpen || !isPhone ? 0 : 24,
        duration: 180,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
    ]).start();
  }, [leftOpen, rightOpen, isPhone, leftRailX, rightRailX, panelOpacity]);

  useEffect(() => {
    Animated.timing(aiExpandAnim, {
      toValue: aiExpanded ? 1 : 0,
      duration: aiExpanded ? 220 : 160,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [aiExpanded, aiExpandAnim]);

  useEffect(() => {
    Animated.timing(quickActionsAnim, {
      toValue: quickActionsOpen ? 1 : 0,
      duration: quickActionsOpen ? 220 : 160,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [quickActionsOpen, quickActionsAnim]);

  useEffect(() => {
    Animated.timing(contextMenuAnim, {
      toValue: contextMenuOpen ? 1 : 0,
      duration: contextMenuOpen ? 160 : 120,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [contextMenuOpen, contextMenuAnim]);

  const gesture = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 24 || Math.abs(g.dy) > 24,
        onPanResponderRelease: async (_, g) => {
          registerInteraction();
          if (g.dx < -70) {
            // swipe left -> communication panel
            setLeftOpen(true);
            setRightOpen(false);
            await emitLilithFeedback("guidance", { haptic: true, sound: false });
            return;
          }
          if (g.dx > 70) {
            // swipe right -> tools panel
            setRightOpen(true);
            setLeftOpen(false);
            await emitLilithFeedback("guidance", { haptic: true, sound: false });
            return;
          }
          if (g.dy < -70) {
            // swipe up -> AI expansion
            setAiExpanded(true);
            setQuickActionsOpen(false);
            setOrbState("thinking");
            await emitLilithFeedback("guidance", { haptic: true, sound: false });
            return;
          }
          if (g.dy > 70) {
            // swipe down -> quick actions
            setQuickActionsOpen(true);
            setAiExpanded(false);
            setOrbState("ready");
            await emitLilithFeedback("guidance", { haptic: true, sound: false });
          }
        },
      }),
    [registerInteraction]
  );

  const dragResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 8 || Math.abs(g.dy) > 8,
        onPanResponderMove: (_, g) => {
          registerInteraction();
          dragX.setValue(g.dx);
          dragY.setValue(g.dy);
        },
        onPanResponderRelease: async (_, g) => {
          registerInteraction();
          const appliedToAI = aiExpanded && g.dy < -60;
          const appliedToQuick = quickActionsOpen && g.dy > 60;
          if (appliedToAI) {
            setDragStatus("Applied to AI");
            await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
          } else if (appliedToQuick) {
            setDragStatus("Added to quick actions");
            await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          } else {
            setDragStatus("Drop target missed");
          }
          Animated.parallel([
            Animated.spring(dragX, { toValue: 0, useNativeDriver: true, damping: 12, stiffness: 120 }),
            Animated.spring(dragY, { toValue: 0, useNativeDriver: true, damping: 12, stiffness: 120 }),
          ]).start();
          setTimeout(() => setDragStatus(""), 1000);
        },
      }),
    [aiExpanded, quickActionsOpen, dragX, dragY, registerInteraction]
  );

  const orbScale = pulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] });
  const orbOpacity = pulse.interpolate({ inputRange: [0, 1], outputRange: [0.78, 1] });

  const orbColor = (() => {
    if (orbState === "listening") return browserTheme.success;
    if (orbState === "thinking") return browserTheme.warning;
    if (orbState === "ready") return browserTheme.action;
    return browserTheme.textMuted;
  })();

  const destinationSuggestions = useMemo(() => {
    if (activeScreen === "workspace" || screenKey === "tools") return ["workspace", "library", "vault"] as const;
    if (screenKey === "browser") return ["library", "workspace", "vault"] as const;
    if (screenKey === "vault") return ["vault", "library", "workspace"] as const;
    return ["library", "workspace", "vault"] as const;
  }, [activeScreen, screenKey]);

  const aiTranslateY = aiExpandAnim.interpolate({ inputRange: [0, 1], outputRange: [20, 0] });
  const aiOpacity = aiExpandAnim.interpolate({ inputRange: [0, 1], outputRange: [0, 1] });
  const quickActionsTranslateY = quickActionsAnim.interpolate({ inputRange: [0, 1], outputRange: [24, 0] });
  const quickActionsOpacity = quickActionsAnim.interpolate({ inputRange: [0, 1], outputRange: [0, 1] });
  const contextMenuScale = contextMenuAnim.interpolate({ inputRange: [0, 1], outputRange: [0.92, 1] });
  const contextMenuOpacity = contextMenuAnim.interpolate({ inputRange: [0, 1], outputRange: [0, 1] });

  const runCanvasCommand = useCallback(
    async (command: string) => {
      if (!command.trim()) return null;
      setOrbState("thinking");
      emitLilithFeedback("orb_tighten", { haptic: true, sound: false }).catch(() => null);
      const out = await executeCommand(command);
      if (out?.ok) {
        setOrbState("ready");
        emitLilithFeedback("orb_expand", { haptic: true, sound: false }).catch(() => null);
      } else {
        setOrbState("idle");
      }
      return out;
    },
    [executeCommand]
  );

  const trackFirst100 = useCallback(
    async (path: "/api/v1/first100/events" | "/api/v1/first100/session-insight" | "/api/v1/first100/feedback", body: Record<string, unknown>) => {
      try {
        await apiRequest(apiBase, token, path, "POST", body);
      } catch {
        // non-blocking instrumentation
      }
    },
    [apiBase, token]
  );

  useEffect(() => {
    const tick = setInterval(() => {
      const now = Date.now();
      const idleSeconds = Math.floor((now - lastInteractionAtRef.current) / 1000);
      if (idleSeconds >= 45 && aiQuery.trim() && draftStartedAtRef.current && !hesitationReportedRef.current) {
        hesitationReportedRef.current = true;
        trackFirst100("/api/v1/first100/session-insight", {
          session_id: sessionId,
          screen: screenKey,
          insight_type: "hesitation",
          seconds: Math.floor((now - draftStartedAtRef.current) / 1000),
          detail: { draft_length: aiQuery.trim().length },
        });
      }
      if (idleSeconds >= 75 && now - lastInactivityReportedAtRef.current > 120000) {
        lastInactivityReportedAtRef.current = now;
        setHelpPrompt("I can take care of this.");
        setFirst100Status("Detected inactivity. Surfacing help.");
        trackFirst100("/api/v1/first100/session-insight", {
          session_id: sessionId,
          screen: screenKey,
          insight_type: "inactivity",
          seconds: idleSeconds,
          detail: { orb_state: orbState },
        });
        trackFirst100("/api/v1/first100/events", {
          event_type: "confusion_detected",
          screen: screenKey,
          session_id: sessionId,
          payload: { idle_seconds: idleSeconds, hint_shown: true },
        });
      }
      if (idleSeconds >= 140 && now - lastDropoffReportedAtRef.current > 180000) {
        lastDropoffReportedAtRef.current = now;
        trackFirst100("/api/v1/first100/events", {
          event_type: "drop_off_point",
          screen: screenKey,
          session_id: sessionId,
          payload: { idle_seconds: idleSeconds, context: "environment_shell" },
        });
      }
    }, 5000);
    return () => clearInterval(tick);
  }, [aiQuery, orbState, screenKey, sessionId, trackFirst100]);

  const saveCanvasOutputToVault = useCallback(
    async (input: { title: string; content: string }) => {
      if (vaultLocked) {
        return { ok: false, detail: "Vault is locked. Unlock vault before secure save." };
      }
      try {
        await apiRequest(apiBase, token, "/api/v1/storage/vault/documents", "POST", {
          title: input.title,
          doc_type: "canvas_output",
          file_url: "",
          metadata: { source: "canvas_mode", content_preview: input.content.slice(0, 400) },
        });
        return { ok: true, detail: "Saved securely to Vault." };
      } catch (error) {
        return { ok: false, detail: String(error) };
      }
    },
    [apiBase, token, vaultLocked]
  );

  return (
    <View
      style={styles.screen}
      {...gesture.panHandlers}
      onTouchStart={registerInteraction}
    >
      <LinearGradient colors={["#050A13", "#08101D", "#0A1526"]} style={StyleSheet.absoluteFill} />
      <View pointerEvents="none" style={styles.atmosphereLayer}>
        <View style={styles.atmosphereHaloMain} />
        <View style={styles.atmosphereHaloSide} />
        <View style={styles.arcRingPrimary} />
        <View style={styles.arcRingSecondary} />
      </View>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.topBar}>
          <View style={styles.topLeft}>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.commandBarGlow,
                {
                  opacity: commandBarPulse.interpolate({ inputRange: [0, 1], outputRange: [0.1, 0.24] }),
                  transform: [{ scale: commandBarPulse.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1.02] }) }],
                },
              ]}
            />
            <Search size={16} color={browserTheme.textMuted} />
            <TextInput
              ref={commandInputRef}
              value={aiQuery}
              onChangeText={(value) => {
                setAiQuery(value);
                registerInteraction();
                if (value.trim()) {
                  if (!draftStartedAtRef.current) draftStartedAtRef.current = Date.now();
                } else {
                  draftStartedAtRef.current = null;
                  hesitationReportedRef.current = false;
                }
              }}
              onFocus={() => {
                registerInteraction();
                setCommandInputFocused(true);
                setOrbState("listening");
              }}
              onBlur={() => {
                setCommandInputFocused(false);
                setOrbState("idle");
              }}
              placeholder="Ask Lilith or search your environment..."
              placeholderTextColor={browserTheme.textMuted}
              style={styles.searchInput}
              returnKeyType="send"
              onSubmitEditing={async () => {
                if (!aiQuery.trim()) return;
                setOrbState("thinking");
                requestIntentPreview(aiQuery.trim());
                if (draftStartedAtRef.current && !hesitationReportedRef.current) {
                  trackFirst100("/api/v1/first100/session-insight", {
                    session_id: sessionId,
                    screen: screenKey,
                    insight_type: "hesitation",
                    seconds: Math.floor((Date.now() - draftStartedAtRef.current) / 1000),
                    detail: { submitted: true, draft_length: aiQuery.trim().length },
                  });
                }
                draftStartedAtRef.current = null;
                hesitationReportedRef.current = false;
                setAiQuery("");
                setOrbState("ready");
              }}
            />
            <Pressable
              onPressIn={() => {
                registerInteraction();
                voice.startListening();
                setOrbState("listening");
              }}
              onPressOut={async () => {
                const out = await voice.stopListening();
                if (out.transcript) setAiQuery(out.transcript);
                const candidate = out.transcript || aiQuery;
                if (candidate.trim()) {
                  setOrbState("thinking");
                  requestIntentPreview(candidate.trim());
                  setAiQuery("");
                  voice.clearTranscript();
                }
                setOrbState("ready");
              }}
              style={styles.voiceButton}
            >
              <Mic size={14} color={voice.isListening ? browserTheme.success : browserTheme.textMuted} />
            </Pressable>
          </View>
          <Animated.View style={[styles.orb, { borderColor: orbColor, transform: [{ scale: orbScale }], opacity: orbOpacity }]}>
            <Sparkles size={16} color={orbColor} />
          </Animated.View>
          {!canvasMode ? (
            <Pressable
              style={styles.statusChip}
              onPress={() => setOrbState((s) => (s === "thinking" ? "ready" : "thinking"))}
              onLongPress={() => setContextMenuOpen((v) => !v)}
            >
              <Text style={styles.statusChipText}>{orbState.toUpperCase()}</Text>
            </Pressable>
          ) : (
            <View style={styles.canvasStatusHint}>
              <Text style={styles.canvasStatusHintText}>{orbState === "thinking" ? "Working on it." : "Ready"}</Text>
            </View>
          )}
          {!canvasMode ? (
            <Pressable style={styles.quickSaveIconBtn} onPress={() => setQuickSaveOpen(true)}>
              <Save size={14} color={browserTheme.textSoft} />
            </Pressable>
          ) : null}
        </View>

        {showSuggestions ? (
          <Animated.View
            style={[
              styles.commandRow,
              {
                opacity: suggestionsAnim,
                transform: [{ translateY: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
              },
            ]}
            pointerEvents={showSuggestions ? "auto" : "none"}
          >
          <Animated.View
            style={[
              styles.dismissLayer,
              {
                opacity: suggestionsAnim,
                transform: [
                  { translateY: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) },
                  { scale: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1] }) },
                ],
              },
            ]}
            pointerEvents={showSuggestions ? "auto" : "none"}
          >
            {showSuggestions ? (
              <CommandSuggestionChips
                suggestions={suggestions}
                onSelect={(value) => {
                  registerInteraction();
                  markSuggestionUsed(value);
                  setAiQuery(value.command);
                }}
              />
            ) : null}
          </Animated.View>
          {!canvasMode ? (
            <View style={styles.commandStatusChip}>
              <Text style={styles.commandStatusText}>{commandBusy ? "Executing..." : "Command Ready"}</Text>
            </View>
          ) : null}
          <Pressable
            style={styles.canvasToggle}
            onPress={() => {
              registerInteraction();
              setCanvasMode((v) => !v);
            }}
          >
            <Text style={styles.canvasToggleText}>{canvasMode ? "Live" : "Classic"}</Text>
          </Pressable>
          </Animated.View>
        ) : null}

        {guidedCommand && !canvasMode ? (
          <View style={styles.guidedBar}>
            <View style={styles.guidedCopy}>
              <Text style={styles.guidedTitle}>{guidedIntentLabel || "Try this command"}</Text>
              <Text style={styles.guidedCommand}>{guidedCommand}</Text>
            </View>
            <Pressable
              style={styles.guidedRunButton}
              onPress={async () => {
                setOrbState("thinking");
                const out = await executeCommand(guidedCommand);
                setOrbState("ready");
                if (out?.ok) onGuidedSuccess?.();
              }}
            >
              <Text style={styles.guidedRunButtonText}>Run</Text>
            </Pressable>
          </View>
        ) : null}

        {!canvasMode && showSuggestions ? (
          <Animated.View
            style={[
              styles.passiveRow,
              {
                opacity: suggestionsAnim,
                transform: [{ translateY: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
              },
            ]}
            pointerEvents={showSuggestions ? "auto" : "none"}
          >
            <Text style={styles.passiveText}>Passive prompt:</Text>
            <Pressable
              style={styles.passiveChip}
              onPress={async () => {
                registerInteraction();
                const candidate = suggestions[0]?.command;
                if (!candidate) return;
                if (suggestions[0]) markSuggestionUsed(suggestions[0]);
                setOrbState("thinking");
                requestIntentPreview(candidate);
                setOrbState("ready");
              }}
            >
              <Text style={styles.passiveChipText}>{suggestions[0]?.label || "No suggestion available"}</Text>
            </Pressable>
            <Pressable
              style={styles.passiveMiniBtn}
              onPress={async () => {
                registerInteraction();
                await undoLastSafeAction();
              }}
            >
              <Text style={styles.passiveMiniBtnText}>Undo</Text>
            </Pressable>
          </Animated.View>
        ) : null}

        {helpPrompt && showHints ? (
          <Animated.View
            style={[
              styles.first100HelpBar,
              {
                opacity: hintsAnim,
                transform: [{ translateY: hintsAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
              },
            ]}
            pointerEvents={showHints ? "auto" : "none"}
          >
            <Text style={styles.first100HelpText}>{helpPrompt}</Text>
            <View style={ui.rowWrap}>
              <ActionChip
                label="Run help command"
                onPress={() => {
                  registerInteraction();
                  setAiQuery("show tools");
                  setHelpPrompt("");
                }}
              />
              <ActionChip
                label="Dismiss"
                onPress={() => {
                  registerInteraction();
                  setHelpPrompt("");
                }}
              />
            </View>
          </Animated.View>
        ) : null}

        {macroCandidate && !canvasMode && showHints ? (
          <Animated.View
            style={[
              styles.macroBar,
              {
                opacity: hintsAnim,
                transform: [{ translateY: hintsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
              },
            ]}
            pointerEvents={showHints ? "auto" : "none"}
          >
            <Text style={styles.macroText}>I can automate this.</Text>
            <Pressable
              onPress={() => {
                registerInteraction();
                saveMacroFromCandidate();
              }}
              style={styles.macroBtn}
            >
              <Text style={styles.macroBtnText}>Save</Text>
            </Pressable>
          </Animated.View>
        ) : null}

        {lastOutput ? (
          <View style={styles.commandResultMetaWrap}>
            <Text style={styles.commandResultMeta}>Context actions: {recentActions.length}</Text>
            <View style={styles.first100FeedbackRow}>
              <ActionChip
                label="Helpful"
                onPress={async () => {
                  const command = recentActions[0]?.command || "";
                  await trackFirst100("/api/v1/first100/feedback", {
                    session_id: sessionId,
                    sentiment: "up",
                    reason: "helpful",
                    command,
                    context: { screen: screenKey, result_type: lastOutput.type },
                  });
                  setFirst100Status("Feedback saved.");
                }}
              />
              <ActionChip
                label="Confusing"
                onPress={async () => {
                  const command = recentActions[0]?.command || "";
                  await trackFirst100("/api/v1/first100/feedback", {
                    session_id: sessionId,
                    sentiment: "down",
                    reason: "confusing",
                    command,
                    context: { screen: screenKey, result_type: lastOutput.type },
                  });
                  await trackFirst100("/api/v1/first100/events", {
                    event_type: "confusion_detected",
                    screen: screenKey,
                    session_id: sessionId,
                    payload: { source: "micro_feedback" },
                  });
                  setFirst100Status("Feedback saved. We’ll improve this flow.");
                }}
              />
            </View>
            {first100Status ? <Text style={styles.first100StatusText}>{first100Status}</Text> : null}
          </View>
        ) : null}

        {commandHistory.length && !canvasMode && showPanels ? (
          <Animated.View
            style={[
              styles.historyRow,
              {
                opacity: panelsAnim,
                transform: [{ translateY: panelsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
              },
            ]}
            pointerEvents={showPanels ? "auto" : "none"}
          >
            <Text style={styles.historyTitle}>History</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.historyChips}>
              {commandHistory.slice(0, 4).map((item) => (
                <Pressable
                  key={`${item.ts}-${item.command}`}
                  style={styles.historyChip}
                  onPress={async () => {
                    registerInteraction();
                    setOrbState("thinking");
                    await rerunCommand(item.command);
                    setOrbState("ready");
                  }}
                >
                  <Text style={styles.historyChipText}>{item.command}</Text>
                </Pressable>
              ))}
            </ScrollView>
          </Animated.View>
        ) : null}

        <View style={styles.main}>
          {canvasMode ? (
            <CanvasModeLayer
              title={title}
              subtitle={subtitle}
              leftActions={leftActions}
              rightActions={rightActions}
              bottomActions={bottomActions}
              suggestions={suggestions}
              recentActionCount={recentActions.length}
              activeScreen={activeScreen}
              activeConversationUserId={activeConversationUserId}
              activeBrowserUrl={activeBrowserUrl}
              activeSelectedContent={activeSelectedContent}
              commandDraft={aiQuery}
              commandInputFocused={commandInputFocused}
              vaultLocked={vaultLocked}
              commandActive={Boolean(aiQuery.trim()) || voice.isListening || orbState === "thinking"}
              pendingResult={pending}
              latestResult={lastOutput}
              onOrbTap={() => {
                registerInteraction();
                commandInputRef.current?.focus();
                setOrbState("listening");
              }}
              onRunCommand={runCanvasCommand}
              onSaveToVault={saveCanvasOutputToVault}
            >
              {children}
            </CanvasModeLayer>
          ) : (
            <>
          {(leftOpen || !isPhone) && (
            <Animated.View style={[styles.rail, styles.leftRail, { opacity: panelOpacity, transform: [{ translateX: leftRailX }] }]}>
              <Text style={styles.railTitle}>Communication</Text>
              <ScrollView style={styles.railScroll} showsVerticalScrollIndicator={false}>
                {leftActions.map((action) => (
                  <Pressable key={action.id} style={styles.railButton} onPress={action.onPress}>
                    <Text style={styles.railButtonText}>{action.label}</Text>
                  </Pressable>
                ))}
              </ScrollView>
            </Animated.View>
          )}

          <View style={styles.center}>
            <View style={styles.centerHeader}>
              <View>
                <Text style={styles.title}>{title}</Text>
                <Text style={styles.subtitle}>{subtitle}</Text>
              </View>
              <View style={styles.centerHeaderRight}>
                <Circle size={12} color={browserTheme.success} />
                <Text style={styles.centerHeaderHint}>{currentScreen?.subtitle ?? "Environment"}</Text>
              </View>
            </View>
            <View style={styles.environmentSurface}>
              <View style={styles.environmentCommandLayer}>
                {pending ? <CommandPendingState title={pending.title} subtitle={pending.subtitle} /> : null}
                {lastOutput &&
                !pending &&
                !(
                  lastOutput.ok &&
                  (lastOutput.payload as { silent?: boolean; image_url?: string; video_url?: string; live_tv?: unknown; output_payload?: Record<string, unknown> } | undefined)?.silent &&
                  !(
                    (lastOutput.payload as Record<string, unknown> | undefined)?.image_url ||
                    (lastOutput.payload as Record<string, unknown> | undefined)?.video_url ||
                    (lastOutput.payload as Record<string, unknown> | undefined)?.live_tv ||
                    ((lastOutput.payload as { output_payload?: Record<string, unknown> } | undefined)?.output_payload?.image_url as string | undefined) ||
                    ((lastOutput.payload as { output_payload?: Record<string, unknown> } | undefined)?.output_payload?.video_url as string | undefined)
                  )
                ) ? (
                  lastOutput.ok ? <CommandResultCard result={lastOutput} /> : <CommandErrorCard result={lastOutput} />
                ) : null}
                <CommandExecutionStatus steps={stepStatuses} />
              </View>
              {children}
            </View>
          </View>

          {(rightOpen || !isPhone) && (
            <Animated.View style={[styles.rail, styles.rightRail, { opacity: panelOpacity, transform: [{ translateX: rightRailX }] }]}>
              <Text style={styles.railTitle}>Tools</Text>
              <ScrollView style={styles.railScroll} showsVerticalScrollIndicator={false}>
                {rightActions.map((action) => (
                  <Pressable key={action.id} style={styles.railButton} onPress={action.onPress}>
                    <Text style={styles.railButtonText}>{action.label}</Text>
                  </Pressable>
                ))}
              </ScrollView>
            </Animated.View>
          )}
            </>
          )}
        </View>

        <Animated.View
          pointerEvents={aiExpanded && showPanels ? "auto" : "none"}
          style={[
            styles.aiExpandSheet,
            {
              opacity: Animated.multiply(aiOpacity, panelsAnim),
              transform: [
                { translateY: aiTranslateY },
                { translateY: panelsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) },
              ],
            },
          ]}
        >
          <View style={styles.aiExpandHeader}>
            <Text style={styles.aiExpandTitle}>AI Expansion</Text>
            <Pressable onPress={() => setAiExpanded(false)}>
              <X size={14} color={browserTheme.textMuted} />
            </Pressable>
          </View>
          <Text style={styles.aiExpandBody}>Run intent-rich actions here with full context visibility.</Text>
          <View style={ui.rowWrap}>
            <ActionChip
              label="Analyze Context"
              onPress={() => {
                setAiExpanded(false);
                requestIntentPreview(aiQuery.trim() ? aiQuery.trim() : `analyze ${currentScreen?.title.toLowerCase() || "context"}`);
              }}
            />
            <ActionChip label="Close" onPress={() => setAiExpanded(false)} />
          </View>
        </Animated.View>

        <Animated.View
          pointerEvents={quickActionsOpen && showPanels ? "auto" : "none"}
          style={[
            styles.quickActionsSheet,
            {
              opacity: Animated.multiply(quickActionsOpacity, panelsAnim),
              transform: [
                { translateY: quickActionsTranslateY },
                { translateY: panelsAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) },
              ],
            },
          ]}
        >
          <View style={styles.aiExpandHeader}>
            <Text style={styles.aiExpandTitle}>Quick Actions</Text>
            <Pressable onPress={() => setQuickActionsOpen(false)}>
              <X size={14} color={browserTheme.textMuted} />
            </Pressable>
          </View>
          <View style={ui.rowWrap}>
            {["Save", "Message", "Pay", "Open Tool"].map((label) => (
              <ActionChip key={label} label={label} />
            ))}
            <Animated.View {...dragResponder.panHandlers} style={[styles.dragActionChip, { transform: [{ translateX: dragX }, { translateY: dragY }] }]}>
              <Zap size={12} color={browserTheme.action} />
              <Text style={styles.dragActionText}>Drag Action</Text>
            </Animated.View>
          </View>
          {dragStatus ? <Text style={styles.dragStatus}>{dragStatus}</Text> : null}
        </Animated.View>

        <View style={styles.bottomBar}>
          <Pressable style={styles.bottomNav} onPress={() => router.push("/home")}>
            <LayoutGrid size={16} color={browserTheme.textSoft} />
            {!canvasMode ? <Text style={styles.bottomNavText}>Home</Text> : null}
          </Pressable>
          <Pressable style={styles.bottomNav} onPress={() => router.push("/chat")}>
            <MessageSquare size={16} color={browserTheme.textSoft} />
            {!canvasMode ? <Text style={styles.bottomNavText}>Chat</Text> : null}
          </Pressable>
          <Pressable style={styles.bottomNav} onPress={() => router.push("/wallet")}>
            <Wallet size={16} color={browserTheme.textSoft} />
            {!canvasMode ? <Text style={styles.bottomNavText}>Pay</Text> : null}
          </Pressable>
          {bottomActions.slice(0, canvasMode ? 1 : isTablet ? 3 : 2).map((action) => (
            <Pressable key={action.id} style={styles.bottomAction} onPress={action.onPress}>
              <Text style={styles.bottomActionText}>{canvasMode ? action.label.slice(0, 6) : action.label}</Text>
            </Pressable>
          ))}
          {!canvasMode ? (
            <Pressable
              style={styles.tokenButton}
              onPress={() => {
                if (token) setToken("");
                else setToken("PASTE_JWT_HERE");
              }}
              onLongPress={() => setLeftOpen((v) => !v)}
            >
              <Text style={styles.tokenButtonText}>{token ? "Token Ready" : "Set Token"}</Text>
            </Pressable>
          ) : null}
        </View>
      </SafeAreaView>

      <CommandConfirmDialog
        visible={confirmState.visible}
        tier={confirmState.tier}
        title={confirmState.title}
        subtitle={confirmState.subtitle}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />
      <CommandIntentPreviewDialog
        visible={intentPreview.visible}
        interpreted={intentPreview.interpreted}
        editableCommand={intentPreview.editableCommand}
        onChangeCommand={updateIntentPreviewCommand}
        onCancel={cancelIntentPreview}
        onConfirm={async () => {
          setOrbState("thinking");
          await confirmIntentPreview();
          setOrbState("ready");
        }}
      />

      {contextMenuOpen && showPanels ? (
        <Animated.View style={[styles.contextMenuBackdrop, { opacity: contextMenuOpacity }]}>
          <Animated.View style={[styles.contextMenu, { transform: [{ scale: contextMenuScale }] }]}>
            <Text style={styles.contextMenuTitle}>Context Menu</Text>
            <View style={ui.rowWrap}>
              <ActionChip label="Communication" onPress={() => { setLeftOpen(true); setContextMenuOpen(false); }} />
              <ActionChip label="Tools" onPress={() => { setRightOpen(true); setContextMenuOpen(false); }} />
              <ActionChip label="AI Expand" onPress={() => { setAiExpanded(true); setContextMenuOpen(false); }} />
              <ActionChip label="Quick Actions" onPress={() => { setQuickActionsOpen(true); setContextMenuOpen(false); }} />
            </View>
          </Animated.View>
        </Animated.View>
      ) : null}

      {quickSaveOpen ? (
        <View style={styles.quickSaveBackdrop}>
          <View style={styles.quickSaveModal}>
            <View style={styles.quickSaveHeader}>
              <Text style={styles.quickSaveTitle}>Quick Save</Text>
              <Pressable onPress={() => setQuickSaveOpen(false)}>
                <X size={14} color={browserTheme.textMuted} />
              </Pressable>
            </View>
            <Text style={styles.quickSaveBody}>Save from anywhere with smart destination suggestions.</Text>
            <TextInput
              value={quickSaveTitle}
              onChangeText={setQuickSaveTitle}
              placeholder="Title"
              placeholderTextColor={browserTheme.textMuted}
              style={styles.quickSaveInput}
            />
            <View style={styles.quickSaveDestinations}>
              {destinationSuggestions.map((dest) => (
                <Pressable
                  key={dest}
                  style={[styles.quickSaveDestination, quickSaveDestination === dest && styles.quickSaveDestinationActive]}
                  onPress={() => setQuickSaveDestination(dest)}
                >
                  <Text style={styles.quickSaveDestinationText}>{dest}</Text>
                </Pressable>
              ))}
            </View>
            <View style={styles.quickSaveActions}>
              <Pressable
                style={styles.quickSavePrimary}
                onPress={async () => {
                  try {
                    const fallback = activeSelectedContent || activeBrowserUrl || "current context";
                    if (quickSaveDestination === "workspace") {
                      await apiRequest(apiBase, token, "/api/v1/storage/workspace", "POST", {
                        workspace_type: "draft",
                        title: quickSaveTitle.trim() || "Quick Saved Draft",
                        content_ref: fallback,
                        status: "active",
                      });
                    } else if (quickSaveDestination === "vault") {
                      await apiRequest(apiBase, token, "/api/v1/storage/vault/documents", "POST", {
                        title: quickSaveTitle.trim() || "Quick Saved Secure Document",
                        doc_type: "sensitive_document",
                        file_url: "",
                        metadata: { source: "quick_save", content_preview: String(fallback).slice(0, 240) },
                      });
                    } else {
                      await apiRequest(apiBase, token, "/api/v1/storage/library", "POST", {
                        item_type: "note",
                        title: quickSaveTitle.trim() || "Quick Saved Item",
                        description: String(fallback).slice(0, 500),
                        category: "Quick Saves",
                        folder: "My Library",
                        source: "quick_save",
                      });
                    }
                    setQuickSaveStatus("Saved");
                    setQuickSaveTitle("");
                    setQuickSaveOpen(false);
                  } catch (error) {
                    setQuickSaveStatus(String(error));
                  }
                }}
              >
                <Text style={styles.quickSavePrimaryText}>Save</Text>
              </Pressable>
            </View>
            {quickSaveStatus ? <Text style={styles.quickSaveStatus}>{quickSaveStatus}</Text> : null}
          </View>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: browserTheme.background },
  safeArea: { flex: 1 },
  atmosphereLayer: { ...StyleSheet.absoluteFillObject },
  atmosphereHaloMain: {
    position: "absolute",
    width: 560,
    height: 560,
    borderRadius: 280,
    left: -120,
    top: -180,
    backgroundColor: "rgba(116,181,255,0.10)",
  },
  atmosphereHaloSide: {
    position: "absolute",
    width: 460,
    height: 460,
    borderRadius: 230,
    right: -140,
    bottom: -120,
    backgroundColor: "rgba(156,141,255,0.08)",
  },
  arcRingPrimary: {
    position: "absolute",
    width: 760,
    height: 760,
    borderRadius: 380,
    borderWidth: 1,
    borderColor: "rgba(119,176,243,0.14)",
    top: -210,
    left: -180,
  },
  arcRingSecondary: {
    position: "absolute",
    width: 540,
    height: 540,
    borderRadius: 270,
    borderWidth: 1,
    borderColor: "rgba(156,141,255,0.10)",
    right: -160,
    top: -100,
  },
  topBar: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 16, paddingTop: 8, paddingBottom: 12 },
  topLeft: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    position: "relative",
    overflow: "hidden",
    borderRadius: 18,
    backgroundColor: "rgba(17,30,49,0.62)",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    shadowColor: "#000",
    shadowOpacity: 0.25,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 9 },
  },
  commandBarGlow: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(121,188,255,0.16)",
  },
  voiceButton: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(32,52,80,0.82)",
  },
  dismissLayer: { flex: 1, minWidth: 0 },
  commandRow: { flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 12, paddingBottom: 8 },
  commandStatusChip: {
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 6,
    backgroundColor: "rgba(45,74,110,0.72)",
  },
  commandStatusText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  canvasToggle: {
    borderRadius: 12,
    backgroundColor: "rgba(38,59,90,0.75)",
    paddingHorizontal: 9,
    paddingVertical: 7,
  },
  canvasToggleText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  commandResultMetaWrap: { paddingHorizontal: 10, paddingBottom: 4 },
  commandResultMeta: { color: browserTheme.textMuted, fontSize: 11 },
  first100FeedbackRow: { flexDirection: "row", alignItems: "center", gap: 8, marginTop: 6, flexWrap: "wrap" },
  first100StatusText: { color: browserTheme.textMuted, fontSize: 11, marginTop: 4 },
  first100HelpBar: {
    marginHorizontal: 12,
    marginBottom: 8,
    borderRadius: 14,
    backgroundColor: "rgba(14,27,45,0.62)",
    paddingHorizontal: 10,
    paddingVertical: 8,
    gap: 8,
  },
  first100HelpText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "600" },
  guidedBar: {
    marginHorizontal: 10,
    marginBottom: 8,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "rgba(87,160,255,0.35)",
    backgroundColor: "rgba(14,28,48,0.92)",
    paddingHorizontal: 10,
    paddingVertical: 9,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  guidedCopy: { flex: 1, gap: 2 },
  guidedTitle: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "800" },
  guidedCommand: { color: browserTheme.textMuted, fontSize: 11 },
  guidedRunButton: {
    borderRadius: 10,
    backgroundColor: browserTheme.action,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  guidedRunButtonText: { color: "#03101E", fontSize: 12, fontWeight: "800" },
  passiveRow: { paddingHorizontal: 10, paddingBottom: 8, flexDirection: "row", alignItems: "center", gap: 8 },
  passiveText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  passiveChip: {
    flex: 1,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: "rgba(29,52,77,0.7)",
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  passiveChipText: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "600" },
  passiveMiniBtn: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: browserTheme.panelElevated,
    paddingHorizontal: 8,
    paddingVertical: 7,
  },
  passiveMiniBtnText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  macroBar: {
    marginHorizontal: 12,
    marginBottom: 6,
    borderRadius: 12,
    backgroundColor: "rgba(14,27,45,0.64)",
    paddingHorizontal: 10,
    paddingVertical: 8,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  macroText: { color: browserTheme.textSoft, fontSize: 11, flex: 1 },
  macroBtn: { borderRadius: 8, backgroundColor: browserTheme.action, paddingHorizontal: 9, paddingVertical: 6 },
  macroBtnText: { color: "#03101E", fontSize: 11, fontWeight: "800" },
  historyRow: { paddingHorizontal: 10, paddingBottom: 8, gap: 6 },
  historyTitle: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  historyChips: { gap: 8, paddingRight: 8 },
  historyChip: {
    borderRadius: 999,
    backgroundColor: "rgba(18,32,51,0.72)",
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  historyChipText: { color: browserTheme.textSoft, fontSize: 11 },
  searchInput: { flex: 1, color: browserTheme.text, fontSize: 14, paddingVertical: 0 },
  orb: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(120,182,255,0.14)",
    shadowColor: browserTheme.glow,
    shadowRadius: 16,
    shadowOpacity: 0.85,
    shadowOffset: { width: 0, height: 0 },
  },
  statusChip: {
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: browserTheme.border,
    backgroundColor: browserTheme.panelElevated,
  },
  statusChipText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  canvasStatusHint: {
    borderRadius: 12,
    backgroundColor: "rgba(20,34,55,0.72)",
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  canvasStatusHintText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  quickSaveIconBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(28,45,71,0.76)",
  },
  main: { flex: 1, flexDirection: "row", gap: 10, paddingHorizontal: 12 },
  rail: {
    width: 128,
    borderRadius: 20,
    backgroundColor: "rgba(15,28,45,0.58)",
    overflow: "hidden",
  },
  leftRail: { marginRight: 4 },
  rightRail: { marginLeft: 4 },
  railTitle: { color: browserTheme.text, fontSize: 12, fontWeight: "700", paddingHorizontal: 10, paddingTop: 10, paddingBottom: 8 },
  railScroll: { paddingHorizontal: 8, paddingBottom: 8 },
  railButton: {
    borderRadius: 10,
    paddingVertical: 8,
    paddingHorizontal: 8,
    marginBottom: 8,
    backgroundColor: "rgba(28,48,74,0.78)",
  },
  railButtonText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "600" },
  center: { flex: 1, minWidth: 0 },
  centerHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 10, paddingVertical: 8 },
  title: { color: browserTheme.text, fontSize: 26, fontWeight: "800" },
  subtitle: { color: browserTheme.textMuted, fontSize: 13, marginTop: 2 },
  centerHeaderRight: { flexDirection: "row", gap: 6, alignItems: "center" },
  centerHeaderHint: { color: browserTheme.textSoft, fontSize: 12 },
  environmentSurface: {
    flex: 1,
    borderRadius: 26,
    backgroundColor: "rgba(10,20,34,0.54)",
    overflow: "hidden",
    shadowColor: "#000",
    shadowOpacity: 0.28,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 12 },
  },
  environmentCommandLayer: { position: "absolute", top: 12, left: 12, right: 12, zIndex: 20, gap: 8 },
  aiExpandSheet: {
    position: "absolute",
    left: 14,
    right: 14,
    top: 96,
    borderRadius: 16,
    backgroundColor: "rgba(11,23,41,0.82)",
    padding: 12,
    gap: 8,
    zIndex: 70,
  },
  aiExpandHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  aiExpandTitle: { color: browserTheme.text, fontSize: 13, fontWeight: "800" },
  aiExpandBody: { color: browserTheme.textMuted, fontSize: 11 },
  quickActionsSheet: {
    position: "absolute",
    left: 14,
    right: 14,
    bottom: 74,
    borderRadius: 16,
    backgroundColor: "rgba(11,23,41,0.82)",
    padding: 12,
    gap: 8,
    zIndex: 70,
  },
  dragActionChip: {
    borderRadius: 999,
    backgroundColor: "rgba(79,163,255,0.14)",
    paddingHorizontal: 10,
    paddingVertical: 7,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  dragActionText: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" },
  dragStatus: { color: browserTheme.textMuted, fontSize: 11 },
  bottomBar: {
    position: "absolute",
    left: 14,
    right: 14,
    bottom: 10,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 18,
    backgroundColor: "rgba(12,24,39,0.76)",
    shadowColor: "#000",
    shadowOpacity: 0.26,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
  },
  bottomNav: {
    flexDirection: "column",
    alignItems: "center",
    gap: 3,
    borderRadius: 12,
    paddingHorizontal: 8,
    paddingVertical: 6,
    minWidth: 42,
  },
  bottomNavText: { color: browserTheme.textSoft, fontSize: 10, fontWeight: "600" },
  bottomAction: {
    borderRadius: 12,
    paddingHorizontal: 9,
    paddingVertical: 7,
    backgroundColor: "rgba(41,63,94,0.76)",
  },
  bottomActionText: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" },
  tokenButton: {
    marginLeft: "auto",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: browserTheme.border,
    paddingHorizontal: 9,
    paddingVertical: 7,
    backgroundColor: browserTheme.panelElevated,
  },
  tokenButtonText: { color: browserTheme.textMuted, fontSize: 11, fontWeight: "700" },
  contextMenuBackdrop: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(2,8,16,0.40)",
    alignItems: "center",
    justifyContent: "center",
    zIndex: 85,
    padding: 20,
  },
  contextMenu: {
    width: "100%",
    maxWidth: 460,
    borderRadius: 16,
    backgroundColor: "rgba(11,23,41,0.86)",
    padding: 12,
    gap: 8,
  },
  contextMenuTitle: { color: browserTheme.text, fontSize: 14, fontWeight: "800" },
  quickSaveBackdrop: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(2,8,16,0.72)",
    alignItems: "center",
    justifyContent: "center",
    padding: 20,
    zIndex: 80,
  },
  quickSaveModal: {
    width: "100%",
    maxWidth: 420,
    borderRadius: 16,
    backgroundColor: "rgba(11,23,41,0.88)",
    padding: 14,
    gap: 10,
  },
  quickSaveHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  quickSaveTitle: { color: browserTheme.text, fontWeight: "800", fontSize: 16 },
  quickSaveBody: { color: browserTheme.textMuted, fontSize: 12 },
  quickSaveInput: {
    borderRadius: 10,
    backgroundColor: "rgba(28,48,74,0.76)",
    color: browserTheme.text,
    paddingHorizontal: 10,
    paddingVertical: 9,
  },
  quickSaveDestinations: { flexDirection: "row", gap: 8 },
  quickSaveDestination: {
    borderRadius: 10,
    paddingHorizontal: 10,
    paddingVertical: 8,
    backgroundColor: "rgba(28,48,74,0.76)",
  },
  quickSaveDestinationActive: { borderColor: browserTheme.action, backgroundColor: "rgba(79,163,255,0.18)" },
  quickSaveDestinationText: { color: browserTheme.textSoft, fontSize: 12, fontWeight: "700", textTransform: "capitalize" },
  quickSaveActions: { flexDirection: "row", justifyContent: "flex-end" },
  quickSavePrimary: { borderRadius: 10, backgroundColor: browserTheme.action, paddingHorizontal: 12, paddingVertical: 8 },
  quickSavePrimaryText: { color: "#03101E", fontSize: 12, fontWeight: "800" },
  quickSaveStatus: { color: browserTheme.textMuted, fontSize: 11 },
});
