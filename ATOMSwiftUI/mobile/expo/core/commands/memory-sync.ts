import { MemoryPatchPayload, UserMemoryProfile } from "./memory-types";

const BEHAVIOR_KEY = "__behavior_model";
const LEARNING_KEY = "__learning_stats";

export function decodeMemoryFromBackend(raw: Partial<UserMemoryProfile>): UserMemoryProfile {
  const entities = raw.last_used_entities || {};
  const behavior = (entities as any)[BEHAVIOR_KEY] || raw.behavior_model || {
    intent_confidence: {},
    suggestion_scores: {},
    autofill_entity_scores: {},
  };
  const learning = (entities as any)[LEARNING_KEY] || raw.learning_stats || {
    positive: 0,
    negative: 0,
    corrections: 0,
    abandonments: 0,
  };
  const cleanedEntities = { ...entities } as Record<string, string>;
  delete (cleanedEntities as any)[BEHAVIOR_KEY];
  delete (cleanedEntities as any)[LEARNING_KEY];
  return {
    version: raw.version || 1,
    updated_at: raw.updated_at || Date.now(),
    profile_type: raw.profile_type || "casual_user",
    frequent_contacts: raw.frequent_contacts || {},
    frequent_intents: raw.frequent_intents || {},
    recent_commands: raw.recent_commands || [],
    last_used_entities: cleanedEntities,
    context_usage: raw.context_usage || {},
    behavior_model: behavior,
    learning_stats: learning,
    prediction_feedback: raw.prediction_feedback || { shown: 0, used: 0, correct: 0, by_command: {} },
    macros: raw.macros || {},
  };
}

export function encodeMemoryPatchForBackend(patch: MemoryPatchPayload): MemoryPatchPayload {
  const entities = { ...(patch.last_used_entities || {}) } as Record<string, any>;
  if (patch.behavior_model) entities[BEHAVIOR_KEY] = patch.behavior_model;
  if (patch.learning_stats) entities[LEARNING_KEY] = patch.learning_stats;
  return {
    ...patch,
    behavior_model: undefined,
    learning_stats: undefined,
    last_used_entities: entities,
  };
}
