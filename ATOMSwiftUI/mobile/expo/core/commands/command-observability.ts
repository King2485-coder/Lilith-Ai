import { getCommandStats, getCommandTraces } from "./trace-logger";
import { getMemory } from "./memory-store";

export function readCommandObservability() {
  const memory = getMemory();
  return {
    traces: getCommandTraces(),
    stats: getCommandStats(),
    learning: memory.learning_stats,
    prediction_feedback: memory.prediction_feedback,
    macros: memory.macros,
  };
}
