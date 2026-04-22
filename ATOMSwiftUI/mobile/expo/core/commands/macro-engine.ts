import { UserMemoryProfile } from "./memory-types";

export function detectMacroCandidate(memory: UserMemoryProfile): { key: string; command: string } | null {
  const commands = memory.recent_commands.map((c) => c.command.toLowerCase());
  if (commands.length < 3) return null;
  const top = commands[0];
  const repeated = commands.filter((c) => c === top).length;
  if (repeated >= 3) {
    return {
      key: `macro_${top.replace(/[^a-z0-9]+/g, "_").slice(0, 24)}`,
      command: top,
    };
  }
  return null;
}

export function saveMacro(memory: UserMemoryProfile, key: string, command: string): UserMemoryProfile {
  const next = JSON.parse(JSON.stringify(memory)) as UserMemoryProfile;
  const existing = next.macros[key];
  next.macros[key] = {
    command,
    uses: (existing?.uses || 0) + 1,
    last_used_ts: Date.now(),
  };
  return next;
}
