import { LilithScreenKey } from "../../constants/lilith-ui";
import { CommandIntentType } from "./types";

export type MemoryEvent = {
  ts: number;
  command: string;
  intent_type: CommandIntentType;
  entities: Record<string, string>;
  screen: LilithScreenKey;
  conversation_user_id?: string;
  success: boolean;
};

export type UserMemoryProfile = {
  version: number;
  updated_at: number;
  profile_type: "casual_user" | "creator" | "business_user" | "student";
  frequent_contacts: Record<string, number>;
  frequent_intents: Record<string, number>;
  recent_commands: MemoryEvent[];
  last_used_entities: {
    user?: string;
    amount?: string;
    currency?: string;
    tool_name?: string;
    url?: string;
    message_text?: string;
  };
  context_usage: Record<string, number>;
  behavior_model: {
    intent_confidence: Record<string, number>;
    suggestion_scores: Record<string, number>;
    autofill_entity_scores: Record<string, number>;
  };
  learning_stats: {
    positive: number;
    negative: number;
    corrections: number;
    abandonments: number;
  };
  prediction_feedback: {
    shown: number;
    used: number;
    correct: number;
    by_command: Record<string, { shown: number; used: number; correct: number }>;
  };
  macros: Record<string, { command: string; uses: number; last_used_ts: number }>;
};

export type MemoryPatchPayload = Partial<UserMemoryProfile> & {
  client_updated_at?: number;
};
