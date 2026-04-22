import { CommandExecutionResult, CommandRuntimeContext } from "./types";
import { MemoryEvent, UserMemoryProfile } from "./memory-types";

const MAX_RECENT_COMMANDS = 50;

function increment(map: Record<string, number>, key?: string) {
  if (!key) return;
  map[key] = (map[key] || 0) + 1;
}

export function recordCommand(
  memory: UserMemoryProfile,
  input: {
    command: string;
    intentType: string;
    entities: Record<string, string>;
    runtime: CommandRuntimeContext;
    result: CommandExecutionResult;
  }
): { next: UserMemoryProfile; delta: Partial<UserMemoryProfile> } {
  const next: UserMemoryProfile = JSON.parse(JSON.stringify(memory));
  const successful = input.result.ok;
  const event: MemoryEvent = {
    ts: Date.now(),
    command: input.command,
    intent_type: input.intentType as any,
    entities: input.entities,
    screen: input.runtime.activeScreen,
    conversation_user_id: input.runtime.activeConversationUserId || undefined,
    success: successful,
  };

  next.recent_commands = [event, ...next.recent_commands].slice(0, MAX_RECENT_COMMANDS);
  increment(next.context_usage, input.runtime.activeScreen);
  if (successful) increment(next.frequent_intents, input.intentType);

  if (successful && input.entities.user) increment(next.frequent_contacts, input.entities.user);
  const changedEntities = Object.fromEntries(Object.entries(input.entities).filter(([, v]) => !!v));
  if (successful) {
    next.last_used_entities = {
      ...next.last_used_entities,
      ...changedEntities,
    };
  }
  next.updated_at = Date.now();
  next.version = (next.version || 1) + 1;

  const contactsDelta: Record<string, number> = {};
  const intentsDelta: Record<string, number> = {};
  const contextDelta: Record<string, number> = {};
  contextDelta[input.runtime.activeScreen] = 1;
  if (successful && input.entities.user) contactsDelta[input.entities.user] = 1;
  if (successful) intentsDelta[input.intentType] = 1;

  return {
    next,
    delta: {
      frequent_contacts: contactsDelta,
      frequent_intents: intentsDelta,
      context_usage: contextDelta,
      last_used_entities: successful ? changedEntities : {},
      recent_commands: [event],
      updated_at: next.updated_at,
      version: next.version,
    },
  };
}
