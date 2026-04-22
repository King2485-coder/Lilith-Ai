import { router } from "expo-router";
import { useEffect, useMemo, useRef, useState } from "react";

import { apiRequest } from "../../lib/api";
import { useSession } from "../../providers/SessionProvider";
import { useCommandContext } from "../../providers/CommandContextProvider";
import { recordCommand } from "./command-memory-engine";
import { executePlan } from "./execution-engine";
import { detectMacroCandidate, saveMacro } from "./macro-engine";
import { getMemory, mergeMemory, seedMemoryIfEmpty, setMemory } from "./memory-store";
import { decodeMemoryFromBackend, encodeMemoryPatchForBackend } from "./memory-sync";
import { UserMemoryProfile } from "./memory-types";
import { recordPredictionCorrect, recordPredictionUsed, recordPredictionsShown } from "./prediction-feedback-engine";
import { predictActions } from "./predictive-engine";
import { createPlan } from "./task-planner";
import { buildSuggestions } from "./suggestions";
import { annotateTrace, createTraceId } from "./trace-logger";
import { applyPersonalityToResult, buildPendingCopy, getResultRevealDelayMs } from "./personality-engine";
import { CommandExecutionResult, CommandPendingState, CommandStepExecutionState, CommandSuggestion, SafetyTier } from "./types";
import { runLearningPipelineAsync } from "./learning-pipeline";
import { emitLilithFeedback, markLilithInteraction } from "../feedback/identity-feedback";
import { createLinksForResult, mergeResultLinks } from "../../lib/lilith-links";

type ConfirmState = {
  visible: boolean;
  tier: SafetyTier;
  title: string;
  subtitle: string;
  operationId: string;
  stepId: string;
};

type IntentPreviewState = {
  visible: boolean;
  interpreted: string;
  editableCommand: string;
};

export function useCommandSystem() {
  const { apiBase, token, sessionId } = useSession();
  const {
    activeScreen,
    activeConversationUserId,
    setActiveConversationUserId,
    activeBrowserUrl,
    setActiveBrowserUrl,
    activeSelectedContent,
    setActiveSelectedContent,
    preferredCurrency,
    setPreferredCurrency,
    chatParticipants,
    setChatParticipants,
    vaultLocked,
    unlockVault,
    lockVault,
    recentActions,
    pushAction,
  } = useCommandContext();
  const [commandBusy, setCommandBusy] = useState(false);
  const [pending, setPending] = useState<CommandPendingState | null>(null);
  const [lastOutput, setLastOutput] = useState<CommandExecutionResult | null>(null);
  const [stepStatuses, setStepStatuses] = useState<CommandStepExecutionState[]>([]);
  const [memory, setMemoryState] = useState<UserMemoryProfile>(getMemory());
  const [confirmState, setConfirmState] = useState<ConfirmState>({
    visible: false,
    tier: "none",
    title: "",
    subtitle: "",
    operationId: "",
    stepId: "",
  });
  const [intentPreview, setIntentPreview] = useState<IntentPreviewState>({
    visible: false,
    interpreted: "",
    editableCommand: "",
  });
  const [macroCandidate, setMacroCandidate] = useState<{ key: string; command: string } | null>(null);
  const confirmResolverRef = useRef<((approved: boolean) => void) | null>(null);
  const selectedSuggestionRef = useRef<CommandSuggestion | null>(null);
  const lastUndoActionRef = useRef<{ type: "navigation" } | null>(null);
  const firstActionTrackedRef = useRef(false);
  const lastCommandStartedAtRef = useRef(0);

  useEffect(() => {
    const seeded = seedMemoryIfEmpty("casual_user");
    setMemoryState(seeded);
  }, []);

  useEffect(() => {
    let mounted = true;
    const syncFromBackend = async () => {
      if (!token) return;
      try {
        const data = await apiRequest<{ memory: Partial<UserMemoryProfile> }>(apiBase, token, "/api/v1/memory");
        const merged = mergeMemory(getMemory(), decodeMemoryFromBackend(data.memory || {}));
        const updated = setMemory(merged);
        if (mounted) setMemoryState(updated);
      } catch {
        // Non-blocking fallback to local memory.
      }
    };
    syncFromBackend();
    return () => {
      mounted = false;
    };
  }, [apiBase, token]);

  const confirm = (state: Omit<ConfirmState, "visible">) =>
    new Promise<boolean>((resolve) => {
      confirmResolverRef.current = resolve;
      setConfirmState({ ...state, visible: true });
    });

  const onConfirm = () => {
    setConfirmState((prev) => ({ ...prev, visible: false }));
    confirmResolverRef.current?.(true);
    confirmResolverRef.current = null;
  };

  const onCancel = () => {
    setConfirmState((prev) => ({ ...prev, visible: false }));
    confirmResolverRef.current?.(false);
    confirmResolverRef.current = null;
  };

  const executeCommand = async (command: string) => {
    const normalized = command.trim();
    if (!normalized) return null;
    const now = Date.now();
    const lastActionTs = recentActions[0]?.createdAt ? new Date(recentActions[0].createdAt).getTime() : 0;
    const signal = {
      screen: activeScreen,
      isFast: now - lastCommandStartedAtRef.current < 5000,
      isHesitating: !!lastActionTs && now - lastActionTs > 45000,
      isRepeated: memory.recent_commands.filter((x) => x.command.toLowerCase() === normalized.toLowerCase()).length >= 2,
      hour: new Date().getHours(),
    };
    lastCommandStartedAtRef.current = now;
    setCommandBusy(true);
    setStepStatuses([]);
    const earlyTrace = createTraceId();
    try {
      markLilithInteraction();
      await emitLilithFeedback("command_sent", { haptic: true, sound: true });
      const runtime = {
        activeScreen,
        activeConversationUserId,
        activeBrowserUrl,
        activeSelectedContent,
        preferredCurrency,
        chatParticipants,
        vaultLocked,
      };
      const predictions = predictActions(runtime, memory);
      const shownSuggestions = buildSuggestions({
        screen: activeScreen,
        recentCommands: recentActions.map((x) => x.command),
        predictions,
        memory,
      });
      const memoryBefore = memory;
      const plan = createPlan(normalized, runtime, memoryBefore);
      const pendingCopy = buildPendingCopy(signal);

      setPending({
        trace_id: earlyTrace,
        operation_id: plan.operationId,
        title: pendingCopy.title || plan.steps[0]?.label || "Working on it.",
        subtitle: pendingCopy.subtitle,
      });
      emitLilithFeedback("processing_start", { haptic: true, sound: false }).catch(() => null);

      const startedAt = Date.now();
      const { result, stepStatuses: statuses } = await executePlan(plan, {
        apiBase,
        token,
        runtime,
        confirm,
        onVaultLock: () => lockVault(),
        onVaultUnlock: (unlockMs) => unlockVault(unlockMs),
        onStepUpdate: (steps) => setStepStatuses([...steps]),
      });
      const shaped = applyPersonalityToResult(result, signal, plan.steps.length);
      const linked = mergeResultLinks(shaped, createLinksForResult(shaped, normalized, runtime, sessionId));
      setStepStatuses(statuses);
      const textRevealDelay = getResultRevealDelayMs(plan.steps.length, linked.type);
      const elapsed = Date.now() - startedAt;
      if (elapsed < textRevealDelay) await new Promise((r) => setTimeout(r, textRevealDelay - elapsed));
      setLastOutput(linked);
      setPending(null);
      const predictionHit = predictions.some((p) => p.command.toLowerCase() === normalized.toLowerCase());
      let memoryWorking = recordPredictionsShown(memoryBefore, shownSuggestions);
      if (selectedSuggestionRef.current) {
        memoryWorking = recordPredictionUsed(memoryWorking, selectedSuggestionRef.current);
      }
      if (predictionHit && result.ok) {
        memoryWorking = recordPredictionCorrect(memoryWorking, normalized);
      }

      const trackedEntities = Object.fromEntries(
        Object.entries(plan.intent.entities || {}).filter(([, v]) => !!v)
      ) as Record<string, string>;
      const recorded = recordCommand(memoryWorking, {
        command: normalized,
        intentType: plan.intent.type,
        entities: trackedEntities,
        runtime,
        result,
      });
      let memoryAfter = setMemory(recorded.next);
      setMemoryState(memoryAfter);
      let memoryDelta: Record<string, unknown> = {};
      memoryDelta = recorded.delta as unknown as Record<string, unknown>;
      if (result.ok) {
        setMacroCandidate(detectMacroCandidate(memoryAfter));
      } else {
        setMacroCandidate(null);
      }
      runLearningPipelineAsync({
        memory: memoryAfter,
        input: {
          command: normalized,
          plan,
          result: shaped,
          suggestionsShown: shownSuggestions,
          usedSuggestion: selectedSuggestionRef.current || undefined,
          previousActionStatus: recentActions[0]?.status,
        },
        onComplete: (learnedMemory) => {
          const next = setMemory(learnedMemory);
          setMemoryState(next);
          apiRequest(apiBase, token, "/api/v1/memory/update", "POST", {
            patch: encodeMemoryPatchForBackend({
              ...recorded.delta,
              profile_type: next.profile_type,
              behavior_model: next.behavior_model,
              learning_stats: next.learning_stats,
              prediction_feedback: next.prediction_feedback,
              macros: next.macros,
            }),
            client_updated_at: next.updated_at,
          }).catch(() => null);
        },
      });
      annotateTrace(result.trace_id, {
        memory_before: memoryBefore,
        memory_after: memoryAfter,
        memory_changes: memoryDelta,
        predictions_generated: predictions,
        suggestions_shown: shownSuggestions.map((s) => s.command),
        used_suggestion: selectedSuggestionRef.current?.command,
        prediction_hit: predictionHit,
      });
      pushAction({
        command: normalized,
        status: linked.ok ? "success" : "error",
        detail: linked.subtitle || linked.title,
        trace_id: linked.trace_id,
        operation_id: linked.operation_id,
      });
      apiRequest(
        apiBase,
        token,
        "/api/v1/first100/events",
        "POST",
        {
          event_type: linked.ok ? "action_completed" : "drop_off_point",
          screen: activeScreen,
          session_id: sessionId,
          payload: {
            command: normalized,
            result_type: linked.type,
            ok: linked.ok,
            timing_ms: linked.timing_ms,
          },
        }
      ).catch(() => null);
      if (linked.ok && !firstActionTrackedRef.current) {
        firstActionTrackedRef.current = true;
        apiRequest(
          apiBase,
          token,
          "/api/v1/first100/events",
          "POST",
          {
            event_type: "first_action_completed",
            screen: activeScreen,
            session_id: sessionId,
            payload: {
              command: normalized,
              result_type: linked.type,
              trace_id: linked.trace_id,
            },
          }
        ).catch(() => null);
      }
      if (linked.ok) {
        await emitLilithFeedback("success", {
          haptic: true,
          sound: !((linked.payload as { silent?: boolean } | undefined)?.silent),
        });
      } else {
        await emitLilithFeedback("error", { haptic: true, sound: true });
      }
      if (linked.type === "navigation") lastUndoActionRef.current = { type: "navigation" };
      selectedSuggestionRef.current = null;
      return linked;
    } catch (error) {
      const message = String(error);
      const fail: CommandExecutionResult = {
        trace_id: earlyTrace,
        operation_id: "unknown",
        type: "error",
        title: "That didn’t go through.",
        subtitle: "Try this.",
        status: "error",
        ok: false,
        timing_ms: 0,
        step_statuses: [],
        payload: { raw_subtitle: message },
      };
      await new Promise((r) => setTimeout(r, 300));
      setPending(null);
      setLastOutput(fail);
      pushAction({ command: normalized, status: "error", detail: message, trace_id: fail.trace_id });
      apiRequest(
        apiBase,
        token,
        "/api/v1/first100/events",
        "POST",
        {
          event_type: "drop_off_point",
          screen: activeScreen,
          session_id: sessionId,
          payload: {
            command: normalized,
            error: message.slice(0, 400),
          },
        }
      ).catch(() => null);
      await emitLilithFeedback("error", { haptic: true, sound: true });
      selectedSuggestionRef.current = null;
      return fail;
    } finally {
      setCommandBusy(false);
    }
  };

  const requestIntentPreview = (command: string) => {
      const runtime = {
        activeScreen,
        activeConversationUserId,
        activeBrowserUrl,
        activeSelectedContent,
        preferredCurrency,
        chatParticipants,
        vaultLocked,
      };
    const plan = createPlan(command, runtime, memory);
    const interpreted = `${plan.intent.type} · ${plan.steps.map((s) => s.label).join(" -> ")}`;
    setIntentPreview({ visible: true, interpreted, editableCommand: command });
  };

  const updateIntentPreviewCommand = (command: string) => {
    setIntentPreview((prev) => ({ ...prev, editableCommand: command }));
  };

  const cancelIntentPreview = () => {
    setIntentPreview((prev) => ({ ...prev, visible: false }));
  };

  const confirmIntentPreview = async () => {
    const cmd = intentPreview.editableCommand.trim();
    setIntentPreview((prev) => ({ ...prev, visible: false }));
    if (!cmd) return null;
    return executeCommand(cmd);
  };

  const rerunCommand = async (command: string) => executeCommand(command);

  const undoLastSafeAction = async () => {
    if (!lastUndoActionRef.current || lastUndoActionRef.current.type !== "navigation") return false;
    router.back();
    return true;
  };

  const saveMacroFromCandidate = () => {
    if (!macroCandidate) return;
    const next = saveMacro(memory, macroCandidate.key, macroCandidate.command);
    const updated = setMemory(next);
    setMemoryState(updated);
    setMacroCandidate(null);
  };

  const registerConversationContext = (userId: string) => {
    setActiveConversationUserId(userId);
  };

  const registerBrowserContext = (url: string) => {
    setActiveBrowserUrl(url);
  };

  const registerSelectedContent = (content: string) => {
    setActiveSelectedContent(content);
  };

  const registerPreferredCurrency = (currency: string) => {
    setPreferredCurrency(currency.toUpperCase());
  };

  const registerChatParticipants = (participants: string[]) => {
    setChatParticipants(participants);
  };

  const suggestions = useMemo(
    () =>
      buildSuggestions({
        screen: activeScreen,
        recentCommands: recentActions.map((x) => x.command),
        predictions: predictActions(
          {
            activeScreen,
            activeConversationUserId,
            activeBrowserUrl,
            activeSelectedContent,
            preferredCurrency,
            chatParticipants,
            vaultLocked,
          },
          memory
        ),
        memory,
      }),
    [
      activeScreen,
      recentActions,
      activeConversationUserId,
      activeBrowserUrl,
      activeSelectedContent,
      preferredCurrency,
      chatParticipants,
      vaultLocked,
      memory,
    ]
  );

  const markSuggestionUsed = (suggestion: CommandSuggestion) => {
    selectedSuggestionRef.current = suggestion;
  };

  return {
    commandBusy,
    pending,
    lastOutput,
    stepStatuses,
    suggestions,
    markSuggestionUsed,
    executeCommand,
    requestIntentPreview,
    intentPreview,
    updateIntentPreviewCommand,
    confirmIntentPreview,
    cancelIntentPreview,
    rerunCommand,
    undoLastSafeAction,
    commandHistory: memory.recent_commands,
    macroCandidate,
    saveMacroFromCandidate,
    registerConversationContext,
    registerBrowserContext,
    registerSelectedContent,
    registerPreferredCurrency,
    registerChatParticipants,
    lockVault,
    unlockVault,
    recentActions,
    confirmState,
    onConfirm,
    onCancel,
  };
}
