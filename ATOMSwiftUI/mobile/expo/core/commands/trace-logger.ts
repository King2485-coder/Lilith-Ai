import { CommandExecutionResult, CommandIntent, CommandPlan, CommandStepExecutionState } from "./types";
import { UserMemoryProfile } from "./memory-types";
import { PredictedAction } from "./predictive-engine";

type CommandTrace = {
  trace_id: string;
  operation_id: string;
  raw_input: string;
  intent: CommandIntent;
  plan: CommandPlan;
  steps: CommandStepExecutionState[];
  memory_before?: UserMemoryProfile;
  memory_after?: UserMemoryProfile;
  memory_changes?: Record<string, unknown>;
  predictions_generated?: PredictedAction[];
  suggestions_shown?: string[];
  used_suggestion?: string;
  prediction_hit?: boolean;
  result?: CommandExecutionResult;
  error?: string;
  started_at: number;
  ended_at?: number;
};

const traces: CommandTrace[] = [];

export function createTraceId() {
  return `trace_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export function createOperationId() {
  return `op_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export function startTrace(rawInput: string, plan: CommandPlan): CommandTrace {
  const trace: CommandTrace = {
    trace_id: createTraceId(),
    operation_id: plan.operationId,
    raw_input: rawInput,
    intent: plan.intent,
    plan,
    steps: [],
    started_at: Date.now(),
  };
  traces.unshift(trace);
  if (traces.length > 200) traces.pop();
  return trace;
}

export function updateTraceSteps(traceId: string, steps: CommandStepExecutionState[]) {
  const trace = traces.find((t) => t.trace_id === traceId);
  if (!trace) return;
  trace.steps = steps;
}

export function completeTrace(traceId: string, result: CommandExecutionResult, error?: string) {
  const trace = traces.find((t) => t.trace_id === traceId);
  if (!trace) return;
  trace.result = result;
  trace.error = error;
  trace.ended_at = Date.now();
}

export function annotateTrace(
  traceId: string,
  patch: Partial<
    Pick<
      CommandTrace,
      "memory_before" | "memory_after" | "memory_changes" | "predictions_generated" | "suggestions_shown" | "prediction_hit"
      | "used_suggestion"
    >
  >
) {
  const trace = traces.find((t) => t.trace_id === traceId);
  if (!trace) return;
  Object.assign(trace, patch);
}

export function getCommandTraces() {
  return traces;
}

export function getCommandStats() {
  const completed = traces.filter((t) => t.ended_at && t.result);
  const successCount = completed.filter((t) => t.result?.ok).length;
  const failCount = completed.length - successCount;
  const avgMs =
    completed.length > 0
      ? Math.round(
          completed.reduce((acc, t) => acc + ((t.ended_at || t.started_at) - t.started_at), 0) / completed.length
        )
      : 0;
  const intentCounts = completed.reduce<Record<string, number>>((acc, t) => {
    acc[t.intent.type] = (acc[t.intent.type] || 0) + 1;
    return acc;
  }, {});
  const predictionHits = completed.filter((t) => t.prediction_hit).length;
  const predictedActions = completed
    .flatMap((t) => (t.predictions_generated || []).map((p) => p.intent))
    .reduce<Record<string, number>>((acc, intent) => {
      acc[intent] = (acc[intent] || 0) + 1;
      return acc;
    }, {});

  return {
    total: completed.length,
    success_rate: completed.length ? Number((successCount / completed.length).toFixed(3)) : 0,
    failed: failCount,
    average_execution_ms: avgMs,
    intent_counts: intentCounts,
    prediction_success_rate: completed.length ? Number((predictionHits / completed.length).toFixed(3)) : 0,
    most_predicted_actions: predictedActions,
  };
}
