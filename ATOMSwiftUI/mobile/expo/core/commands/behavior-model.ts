import { UserMemoryProfile } from "./memory-types";
import { LearningInput, LearningScore } from "./learning-types";

function bump(map: Record<string, number>, key: string, delta: number, min = -1, max = 1) {
  const current = map[key] || 0;
  const next = Math.max(min, Math.min(max, Number((current + delta).toFixed(4))));
  map[key] = next;
}

export function applyBehaviorLearning(
  memory: UserMemoryProfile,
  input: LearningInput,
  score: LearningScore
): UserMemoryProfile {
  const next: UserMemoryProfile = JSON.parse(JSON.stringify(memory));
  const intentKey = input.plan.intent.type;
  const commandKey = input.command.toLowerCase();
  const userKey = input.plan.intent.entities.user || "";
  const toolKey = input.plan.intent.entities.tool_name || "";

  bump(next.behavior_model.intent_confidence, intentKey, score.total * 0.02);
  bump(next.behavior_model.suggestion_scores, commandKey, score.total * 0.015);
  if (userKey) bump(next.behavior_model.autofill_entity_scores, `user:${userKey}`, score.total * 0.02);
  if (toolKey) bump(next.behavior_model.autofill_entity_scores, `tool:${toolKey}`, score.total * 0.02);

  if (input.usedSuggestion) {
    bump(next.behavior_model.suggestion_scores, input.usedSuggestion.command.toLowerCase(), 0.03);
  }

  next.learning_stats.positive += score.positive;
  next.learning_stats.negative += score.negative;
  if (score.total > 0 && input.previousActionStatus === "error") next.learning_stats.corrections += 1;
  if (!input.result.ok && /cancel/i.test(input.result.subtitle || "")) next.learning_stats.abandonments += 1;
  next.updated_at = Date.now();
  next.version += 1;
  return next;
}
