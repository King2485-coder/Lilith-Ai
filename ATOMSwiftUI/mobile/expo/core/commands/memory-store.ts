import { MemoryPatchPayload, UserMemoryProfile } from "./memory-types";

const MAX_RECENT_COMMANDS = 50;
const DECAY_INTERVAL_MS = 1000 * 60 * 60 * 24; // 1 day
const DECAY_PER_INTERVAL = 0.96;

const EMPTY_MEMORY: UserMemoryProfile = {
  version: 1,
  updated_at: Date.now(),
  profile_type: "casual_user",
  frequent_contacts: {},
  frequent_intents: {},
  recent_commands: [],
  last_used_entities: {},
  context_usage: {},
  behavior_model: {
    intent_confidence: {},
    suggestion_scores: {},
    autofill_entity_scores: {},
  },
  learning_stats: {
    positive: 0,
    negative: 0,
    corrections: 0,
    abandonments: 0,
  },
  prediction_feedback: {
    shown: 0,
    used: 0,
    correct: 0,
    by_command: {},
  },
  macros: {},
};

let memoryState: UserMemoryProfile = { ...EMPTY_MEMORY };

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value));
}

function applyDecayMap(map: Record<string, number>, elapsedMs: number) {
  const intervals = Math.floor(elapsedMs / DECAY_INTERVAL_MS);
  if (intervals <= 0) return map;
  const factor = Math.pow(DECAY_PER_INTERVAL, intervals);
  const out: Record<string, number> = {};
  Object.entries(map).forEach(([k, v]) => {
    const next = Number((v * factor).toFixed(4));
    if (next > 0.0001) out[k] = next;
  });
  return out;
}

export function applyMemoryDecay(memory: UserMemoryProfile): UserMemoryProfile {
  const now = Date.now();
  const elapsed = now - (memory.updated_at || now);
  if (elapsed < DECAY_INTERVAL_MS) return memory;
  return {
    ...memory,
    frequent_contacts: applyDecayMap(memory.frequent_contacts, elapsed),
    frequent_intents: applyDecayMap(memory.frequent_intents, elapsed),
    context_usage: applyDecayMap(memory.context_usage, elapsed),
    behavior_model: {
      intent_confidence: applyDecayMap(memory.behavior_model.intent_confidence, elapsed),
      suggestion_scores: applyDecayMap(memory.behavior_model.suggestion_scores, elapsed),
      autofill_entity_scores: applyDecayMap(memory.behavior_model.autofill_entity_scores, elapsed),
    },
    updated_at: now,
  };
}

export function getDefaultMemoryProfile(profileType: UserMemoryProfile["profile_type"]): UserMemoryProfile {
  const base = clone(EMPTY_MEMORY);
  base.profile_type = profileType;
  if (profileType === "creator") {
    base.frequent_intents = { "tool.run": 2, "workflow.post_publish": 2 };
    base.behavior_model.suggestion_scores = {
      "create a post from this and publish it": 0.4,
      "run tool text_summarizer": 0.3,
    };
  } else if (profileType === "business_user") {
    base.frequent_intents = { "payment.send": 2, "message.send": 1 };
    base.behavior_model.suggestion_scores = { "send 20 to alex": 0.35, "show balance": 0.25 };
  } else if (profileType === "student") {
    base.frequent_intents = { "tool.run": 2, "browser.summarize_current_page": 2 };
    base.behavior_model.suggestion_scores = { summarize: 0.4, "run it again": 0.25 };
  } else {
    base.frequent_intents = { "navigation.open": 1, "message.send": 1 };
  }
  return base;
}

export function seedMemoryIfEmpty(profileType: UserMemoryProfile["profile_type"] = "casual_user"): UserMemoryProfile {
  const hasData =
    Object.keys(memoryState.frequent_intents).length > 0 ||
    memoryState.recent_commands.length > 0 ||
    memoryState.prediction_feedback.shown > 0;
  if (!hasData) {
    memoryState = getDefaultMemoryProfile(profileType);
  }
  return getMemory();
}

export function getMemory(): UserMemoryProfile {
  memoryState = applyMemoryDecay(memoryState);
  return clone(memoryState);
}

export function updateMemory(
  updater: MemoryPatchPayload | ((current: UserMemoryProfile) => UserMemoryProfile)
): UserMemoryProfile {
  const current = getMemory();
  const next =
    typeof updater === "function"
      ? updater(current)
      : {
          ...current,
          ...updater,
          frequent_contacts: { ...current.frequent_contacts, ...(updater.frequent_contacts || {}) },
          frequent_intents: { ...current.frequent_intents, ...(updater.frequent_intents || {}) },
          context_usage: { ...current.context_usage, ...(updater.context_usage || {}) },
          last_used_entities: { ...current.last_used_entities, ...(updater.last_used_entities || {}) },
          behavior_model: {
            ...current.behavior_model,
            ...(updater.behavior_model || {}),
            intent_confidence: {
              ...current.behavior_model.intent_confidence,
              ...(updater.behavior_model?.intent_confidence || {}),
            },
            suggestion_scores: {
              ...current.behavior_model.suggestion_scores,
              ...(updater.behavior_model?.suggestion_scores || {}),
            },
            autofill_entity_scores: {
              ...current.behavior_model.autofill_entity_scores,
              ...(updater.behavior_model?.autofill_entity_scores || {}),
            },
          },
          learning_stats: { ...current.learning_stats, ...(updater.learning_stats || {}) },
          prediction_feedback: {
            ...current.prediction_feedback,
            ...(updater.prediction_feedback || {}),
            by_command: {
              ...current.prediction_feedback.by_command,
              ...(updater.prediction_feedback?.by_command || {}),
            },
          },
          macros: { ...current.macros, ...(updater.macros || {}) },
          recent_commands: updater.recent_commands || current.recent_commands,
        };

  next.recent_commands = next.recent_commands.slice(0, MAX_RECENT_COMMANDS);
  next.updated_at = Date.now();
  next.version = (next.version || 1) + 1;
  memoryState = next;
  return getMemory();
}

export function mergeMemory(local: UserMemoryProfile, remote?: Partial<UserMemoryProfile>): UserMemoryProfile {
  if (!remote) return local;
  const merged: UserMemoryProfile = {
    version: Math.max(local.version || 1, remote.version || 1),
    updated_at: Math.max(local.updated_at || 0, remote.updated_at || 0),
    profile_type: (remote.profile_type as any) || local.profile_type || "casual_user",
    frequent_contacts: { ...local.frequent_contacts },
    frequent_intents: { ...local.frequent_intents },
    recent_commands: [...local.recent_commands],
    last_used_entities: { ...local.last_used_entities },
    context_usage: { ...local.context_usage },
    behavior_model: {
      intent_confidence: { ...local.behavior_model.intent_confidence },
      suggestion_scores: { ...local.behavior_model.suggestion_scores },
      autofill_entity_scores: { ...local.behavior_model.autofill_entity_scores },
    },
    learning_stats: { ...local.learning_stats },
    prediction_feedback: {
      shown: local.prediction_feedback.shown,
      used: local.prediction_feedback.used,
      correct: local.prediction_feedback.correct,
      by_command: { ...local.prediction_feedback.by_command },
    },
    macros: { ...local.macros },
  };

  Object.entries(remote.frequent_contacts || {}).forEach(([k, v]) => {
    merged.frequent_contacts[k] = (merged.frequent_contacts[k] || 0) + Number(v || 0);
  });
  Object.entries(remote.frequent_intents || {}).forEach(([k, v]) => {
    merged.frequent_intents[k] = (merged.frequent_intents[k] || 0) + Number(v || 0);
  });
  Object.entries(remote.context_usage || {}).forEach(([k, v]) => {
    merged.context_usage[k] = (merged.context_usage[k] || 0) + Number(v || 0);
  });

  const combinedCommands = [...(remote.recent_commands || []), ...merged.recent_commands]
    .sort((a, b) => b.ts - a.ts)
    .slice(0, MAX_RECENT_COMMANDS);
  merged.recent_commands = combinedCommands;

  if ((remote.updated_at || 0) >= (local.updated_at || 0)) {
    merged.last_used_entities = { ...merged.last_used_entities, ...(remote.last_used_entities || {}) };
  }

  if (remote.behavior_model) {
    merged.behavior_model = {
      intent_confidence: { ...merged.behavior_model.intent_confidence, ...(remote.behavior_model.intent_confidence || {}) },
      suggestion_scores: { ...merged.behavior_model.suggestion_scores, ...(remote.behavior_model.suggestion_scores || {}) },
      autofill_entity_scores: {
        ...merged.behavior_model.autofill_entity_scores,
        ...(remote.behavior_model.autofill_entity_scores || {}),
      },
    };
  }
  if (remote.learning_stats) {
    merged.learning_stats = {
      positive: Math.max(merged.learning_stats.positive, remote.learning_stats.positive || 0),
      negative: Math.max(merged.learning_stats.negative, remote.learning_stats.negative || 0),
      corrections: Math.max(merged.learning_stats.corrections, remote.learning_stats.corrections || 0),
      abandonments: Math.max(merged.learning_stats.abandonments, remote.learning_stats.abandonments || 0),
    };
  }
  if (remote.prediction_feedback) {
    merged.prediction_feedback = {
      shown: Math.max(merged.prediction_feedback.shown, remote.prediction_feedback.shown || 0),
      used: Math.max(merged.prediction_feedback.used, remote.prediction_feedback.used || 0),
      correct: Math.max(merged.prediction_feedback.correct, remote.prediction_feedback.correct || 0),
      by_command: {
        ...merged.prediction_feedback.by_command,
        ...(remote.prediction_feedback.by_command || {}),
      },
    };
  }
  if (remote.macros) {
    merged.macros = { ...merged.macros, ...remote.macros };
  }
  return applyMemoryDecay(merged);
}

export function setMemory(next: UserMemoryProfile): UserMemoryProfile {
  memoryState = clone(next);
  return getMemory();
}
