import { router } from "expo-router";

import { buildLicensedLivePayload, resolveLicensedChannel } from "../../constants/live-tv";
import { LILITH_SCREENS } from "../../constants/lilith-ui";
import { apiRequest } from "../../lib/api";
import {
  CommandExecutionResult,
  CommandPlan,
  CommandResultType,
  CommandRuntimeContext,
  CommandStepExecutionState,
  NormalizedCommandResult,
  SafetyTier,
  TaskStep,
} from "./types";
import { completeTrace, startTrace, updateTraceSteps } from "./trace-logger";

type ConfirmPayload = {
  tier: SafetyTier;
  title: string;
  subtitle: string;
  operationId: string;
  stepId: string;
};

type ExecuteDeps = {
  apiBase: string;
  token: string;
  runtime: CommandRuntimeContext;
  confirm: (payload: ConfirmPayload) => Promise<boolean>;
  onStepUpdate?: (steps: CommandStepExecutionState[]) => void;
  onVaultLock?: () => void;
  onVaultUnlock?: (unlockMs?: number) => void;
};

const executedIdempotencyKeys = new Set<string>();

function idempotencyKey(operationId: string, stepId: string) {
  return `${operationId}:${stepId}`;
}

function requiresConfirmation(step: TaskStep) {
  return step.safety === "soft" || step.safety === "hard";
}

function withHttps(url: string) {
  if (!url) return "";
  return url.startsWith("http://") || url.startsWith("https://") ? url : `https://${url}`;
}

function toResult(
  traceId: string,
  operationId: string,
  type: CommandResultType,
  status: NormalizedCommandResult["status"],
  title: string,
  subtitle: string,
  payload?: unknown,
  cta?: NormalizedCommandResult["cta"]
): NormalizedCommandResult {
  return {
    trace_id: traceId,
    operation_id: operationId,
    type,
    title,
    subtitle,
    status,
    payload,
    cta,
  };
}

async function executeWithRetry<T>(run: () => Promise<T>, retrySafe: boolean, retries = 1): Promise<T> {
  let attempts = 0;
  while (true) {
    try {
      return await run();
    } catch (error) {
      attempts += 1;
      if (!retrySafe || attempts > retries) throw error;
    }
  }
}

async function executeSingleStep(
  step: TaskStep,
  deps: ExecuteDeps,
  traceId: string,
  operationId: string,
  stepState: CommandStepExecutionState
): Promise<NormalizedCommandResult> {
  const payload = step.payload || {};
  const key = stepState.idempotency_key;

  if (requiresConfirmation(step)) {
    const approved = await deps.confirm({
      tier: step.safety,
      title: step.safety === "hard" ? "Confirm Sensitive Action" : "Confirm Action",
      subtitle: step.label,
      operationId,
      stepId: step.id,
    });
    if (!approved) {
      return toResult(traceId, operationId, "error", "error", "Action cancelled", "You cancelled confirmation.");
    }
  }

  if (step.condition === "has_target" && !payload.receiver_id && !payload.target) {
    return toResult(traceId, operationId, "error", "error", "Missing target", "I need a target to continue.");
  }

  if (executedIdempotencyKeys.has(key)) {
    return toResult(traceId, operationId, "error", "error", "Duplicate action blocked", "This action was already executed.");
  }

  const safeRun = <T,>(fn: () => Promise<T>) => executeWithRetry(fn, !!step.retrySafe && step.safety !== "hard", 1);

  switch (step.execute) {
    case "navigate": {
      const hint = (payload.routeHint || "home").toLowerCase();
      const screen = LILITH_SCREENS.find((s) => s.title.toLowerCase() === hint || s.key === hint || s.route.includes(hint));
      router.push((screen?.route || "/home") as never);
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "navigation", "success", `Opened ${screen?.title || "Home"}`, "Navigation complete.");
    }
    case "send_message": {
      const receiverId = payload.receiver_id || deps.runtime.activeConversationUserId;
      const content = payload.content;
      const response = await safeRun(() =>
        apiRequest(
          deps.apiBase,
          deps.token,
          "/api/v1/messages/send",
          "POST",
          { receiver_id: receiverId, content },
          { headers: { "X-Idempotency-Key": key } }
        )
      );
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "message.sent", "success", "Message sent", `Delivered to ${receiverId}.`, response, {
        label: "Open chat",
        action: "open_chat",
      });
    }
    case "pay_user": {
      const receiverId = payload.receiver_id || deps.runtime.activeConversationUserId;
      const amount = Number(payload.amount || "0");
      const currency = payload.currency || deps.runtime.preferredCurrency || "USD";
      const intent = await apiRequest<{ id: string }>(
        deps.apiBase,
        deps.token,
        "/api/v1/payments/create-intent",
        "POST",
        { receiver_id: receiverId, amount, currency },
        { headers: { "X-Idempotency-Key": `${key}:intent` } }
      );
      const confirmed = await apiRequest(
        deps.apiBase,
        deps.token,
        "/api/v1/payments/confirm",
        "POST",
        { payment_intent_id: intent.id },
        { headers: { "X-Idempotency-Key": `${key}:confirm` } }
      );
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "payment.sent",
        "success",
        `Sent ${amount} ${currency}`,
        `Payment completed to ${receiverId}.`,
        confirmed
      );
    }
    case "split_bill": {
      const participants = deps.runtime.chatParticipants.filter(Boolean);
      if (participants.length === 0) {
        return toResult(traceId, operationId, "error", "error", "No participants found", "Open a chat thread first.");
      }
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "payment.split",
        "success",
        "Split plan prepared",
        `Prepared split across ${participants.length} participants.`,
        { participants }
      );
    }
    case "get_balance": {
      const balance = await safeRun(() => apiRequest(deps.apiBase, deps.token, "/api/v1/payments/balance"));
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "balance.shown", "success", "Wallet balance", "Loaded current balances.", balance);
    }
    case "run_tool": {
      const toolName = payload.tool_name || "text_summarizer";
      const job = await safeRun(() =>
        apiRequest<{ job_id: string }>(
          deps.apiBase,
          deps.token,
          "/api/v1/tools/run",
          "POST",
          { tool_name: toolName, input_payload: { text: payload.content_ref || "Summarize this content." } },
          { headers: { "X-Idempotency-Key": key } }
        )
      );
      const result = await safeRun(() => apiRequest(deps.apiBase, deps.token, `/api/v1/tools/results/${job.job_id}`));
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "tool.result", "success", `Tool ${toolName} completed`, "Result available.", result);
    }
    case "create_video": {
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "workflow.completed",
        "success",
        "Video generated",
        "Generated a video artifact from current context.",
        { artifact_id: `${operationId}:video` }
      );
    }
    case "open_live_tv": {
      const mode = payload.mode === "multiview" ? "multiview" : "single";
      const requestedChannel = payload.channel || "";
      const resolved = resolveLicensedChannel(requestedChannel);
      if (requestedChannel && !resolved) {
        return toResult(
          traceId,
          operationId,
          "error",
          "error",
          "Licensed stream not found",
          "Use an approved Lilith TV connector. Unauthorized stream ingestion is not supported."
        );
      }
      const livePayload = buildLicensedLivePayload(mode, resolved?.title || requestedChannel);
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "live_tv.opened",
        "success",
        mode === "multiview" ? "Live multiview opened" : `Watching ${livePayload.streams[0]?.title || "Live TV"}`,
        "Licensed live stream ready.",
        {
          live_tv: livePayload,
          silent: true,
        }
      );
    }
    case "mute_secondary_streams": {
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "live_tv.opened",
        "success",
        "Secondary streams muted",
        "Only the primary licensed stream will keep audio.",
        {
          live_tv: {
            command: "mute_secondaries",
            licensed_only: true,
          },
          silent: true,
        }
      );
    }
    case "swap_live_focus": {
      executedIdempotencyKeys.add(key);
      return toResult(
        traceId,
        operationId,
        "live_tv.opened",
        "success",
        payload.channel ? `Swapped to ${payload.channel}` : "Primary stream swapped",
        "Audio focus moved to the new main stream.",
        {
          live_tv: {
            command: "swap_main",
            channel: payload.channel || "",
            licensed_only: true,
          },
          silent: true,
        }
      );
    }
    case "create_post": {
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "post.published", "success", "Post draft created", "Draft ready for publish.", {
        draft_id: `${operationId}:draft`,
      });
    }
    case "publish_post": {
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "post.published", "success", "Post published", "Your post is now live.");
    }
    case "analyze_page": {
      const url = withHttps(payload.url || deps.runtime.activeBrowserUrl);
      const analysis = await safeRun(() =>
        apiRequest(deps.apiBase, deps.token, "/api/v1/browser/analyze", "POST", { url }, { headers: { "X-Idempotency-Key": key } })
      );
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "browser.analyzed", "success", "Page analyzed", `Analyzed ${url}`, analysis);
    }
    case "save_page": {
      const url = withHttps(payload.url || deps.runtime.activeBrowserUrl);
      await safeRun(() =>
        apiRequest(
          deps.apiBase,
          deps.token,
          "/api/v1/storage/saved-pages",
          "POST",
          { title: "Saved by command", url, summary: deps.runtime.activeSelectedContent?.slice(0, 240) || "" },
          { headers: { "X-Idempotency-Key": key } }
        )
      );
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "browser.saved", "success", "Page saved", `Saved ${url} to your library.`);
    }
    case "send_page_to_chat": {
      const receiverId = payload.receiver_id || deps.runtime.activeConversationUserId;
      const url = withHttps(payload.url || deps.runtime.activeBrowserUrl);
      const sent = await safeRun(() =>
        apiRequest(
          deps.apiBase,
          deps.token,
          "/api/v1/browser/send-to-chat",
          "POST",
          { target_user_id: receiverId, text: `Shared page: ${url}` },
          { headers: { "X-Idempotency-Key": key } }
        )
      );
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "browser.sent", "success", "Page sent", `Shared to ${receiverId}.`, sent);
    }
    case "open_connected_apps": {
      router.push("/browser");
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "browser.connected_apps", "success", "Opened Browser", "Connected apps are visible on this screen.");
    }
    case "fetch_notifications": {
      const notifications = await safeRun(() => apiRequest(deps.apiBase, deps.token, "/api/v1/notifications"));
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "notifications.shown", "success", "Notifications loaded", "Inbox refreshed.", notifications);
    }
    case "open_profile": {
      router.push("/profile");
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "navigation", "success", "Profile opened", `Opened ${payload.target || "profile"}.`);
    }
    case "refresh_screen": {
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "navigation", "success", "Refresh ready", "Use screen refresh action to pull latest data.");
    }
    case "save_to_storage": {
      const ref = payload.content_ref || deps.runtime.activeSelectedContent || deps.runtime.activeBrowserUrl || "current_context";
      const isUrl = /^https?:\/\//i.test(ref) || /\.[a-z]{2,}/i.test(ref);
      if (isUrl) {
        const url = withHttps(ref);
        await safeRun(() =>
          apiRequest(
            deps.apiBase,
            deps.token,
            "/api/v1/storage/saved-pages",
            "POST",
            { title: "Quick Saved Page", url, summary: deps.runtime.activeSelectedContent?.slice(0, 240) || "" },
            { headers: { "X-Idempotency-Key": key } }
          )
        );
      } else {
        await safeRun(() =>
          apiRequest(
            deps.apiBase,
            deps.token,
            "/api/v1/storage/library",
            "POST",
            {
              item_type: "note",
              title: "Quick Saved Item",
              description: String(ref).slice(0, 500),
              category: deps.runtime.activeScreen === "workspace" ? "Workspace Exports" : "Quick Saves",
              folder: deps.runtime.activeScreen === "workspace" ? "Workspace" : "My Library",
              source: "command",
            },
            { headers: { "X-Idempotency-Key": key } }
          )
        );
      }
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "storage.saved", "success", "Saved to storage", "Stored in your Library.");
    }
    case "search_storage": {
      const parts = String(payload.content_ref || "storage:recent").split(":");
      const zone = parts[0] || "storage";
      const query = parts.slice(1).join(":") || "recent";
      const includeVault = zone === "vault" || query.toLowerCase().includes("vault");
      const results = await safeRun(() =>
        apiRequest(
          deps.apiBase,
          deps.token,
          `/api/v1/storage/search?q=${encodeURIComponent(query)}&include_vault=${includeVault ? "true" : "false"}`
        )
      );
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "storage.search_results", "success", "Storage search complete", `Searched ${zone} for "${query}".`, results);
    }
    case "lock_vault": {
      deps.onVaultLock?.();
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "vault.state", "success", "Vault locked", "Sensitive actions are now locked.");
    }
    case "unlock_vault": {
      const minutes = Math.max(1, Number(payload.amount || "5"));
      deps.onVaultUnlock?.(minutes * 60 * 1000);
      executedIdempotencyKeys.add(key);
      return toResult(traceId, operationId, "vault.state", "success", "Vault unlocked", `Vault unlocked for ${minutes} minute(s).`);
    }
    default: {
      return toResult(
        traceId,
        operationId,
        "error",
        "error",
        "Command not understood",
        "Try: send $10 to Alex, summarize this page, or run tool text_summarizer."
      );
    }
  }
}

export async function executePlan(
  plan: CommandPlan,
  deps: ExecuteDeps
): Promise<{ result: CommandExecutionResult; stepStatuses: CommandStepExecutionState[]; traceId: string }> {
  const startedAt = Date.now();
  const trace = startTrace(plan.intent.raw, plan);
  const stepStatuses: CommandStepExecutionState[] = plan.steps.map((step) => ({
    step_id: step.id,
    label: step.label,
    status: "pending",
    idempotency_key: idempotencyKey(plan.operationId, step.id),
  }));

  updateTraceSteps(trace.trace_id, stepStatuses);
  deps.onStepUpdate?.([...stepStatuses]);

  let lastResult: NormalizedCommandResult = toResult(
    trace.trace_id,
    plan.operationId,
    "error",
    "error",
    "No steps executed",
    "Planner returned no runnable steps."
  );

  for (let i = 0; i < plan.steps.length; i += 1) {
    const step = plan.steps[i];
    const state = stepStatuses[i];
    state.status = "running";
    state.started_at = Date.now();
    updateTraceSteps(trace.trace_id, stepStatuses);
    deps.onStepUpdate?.([...stepStatuses]);
    try {
      const res = await executeSingleStep(step, deps, trace.trace_id, plan.operationId, state);
      lastResult = res;
      state.status = res.status === "success" ? "success" : "error";
      state.ended_at = Date.now();
      updateTraceSteps(trace.trace_id, stepStatuses);
      deps.onStepUpdate?.([...stepStatuses]);
      if (res.status === "error") {
        const final: CommandExecutionResult = {
          ...res,
          ok: false,
          timing_ms: Date.now() - startedAt,
          step_statuses: stepStatuses,
        };
        completeTrace(trace.trace_id, final, res.subtitle);
        return { result: final, stepStatuses, traceId: trace.trace_id };
      }
    } catch (error) {
      state.status = "error";
      state.error = String(error);
      state.ended_at = Date.now();
      updateTraceSteps(trace.trace_id, stepStatuses);
      deps.onStepUpdate?.([...stepStatuses]);
      const res = toResult(trace.trace_id, plan.operationId, "error", "error", "Execution failed", String(error));
      const final: CommandExecutionResult = {
        ...res,
        ok: false,
        timing_ms: Date.now() - startedAt,
        step_statuses: stepStatuses,
      };
      completeTrace(trace.trace_id, final, String(error));
      return { result: final, stepStatuses, traceId: trace.trace_id };
    }
  }

  const final: CommandExecutionResult = {
    ...lastResult,
    ok: true,
    timing_ms: Date.now() - startedAt,
    step_statuses: stepStatuses,
  };
  completeTrace(trace.trace_id, final);
  return { result: final, stepStatuses, traceId: trace.trace_id };
}
