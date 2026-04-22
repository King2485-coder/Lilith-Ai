import { CommandSuggestion } from "./types";
import { UserMemoryProfile } from "./memory-types";

function ensureByCommand(memory: UserMemoryProfile, command: string) {
  if (!memory.prediction_feedback.by_command[command]) {
    memory.prediction_feedback.by_command[command] = { shown: 0, used: 0, correct: 0 };
  }
}

export function recordPredictionsShown(memory: UserMemoryProfile, suggestions: CommandSuggestion[]): UserMemoryProfile {
  const next = JSON.parse(JSON.stringify(memory)) as UserMemoryProfile;
  suggestions.forEach((s) => {
    const cmd = s.command.toLowerCase();
    ensureByCommand(next, cmd);
    next.prediction_feedback.by_command[cmd].shown += 1;
    next.prediction_feedback.shown += 1;
  });
  return next;
}

export function recordPredictionUsed(memory: UserMemoryProfile, suggestion: CommandSuggestion): UserMemoryProfile {
  const next = JSON.parse(JSON.stringify(memory)) as UserMemoryProfile;
  const cmd = suggestion.command.toLowerCase();
  ensureByCommand(next, cmd);
  next.prediction_feedback.by_command[cmd].used += 1;
  next.prediction_feedback.used += 1;
  return next;
}

export function recordPredictionCorrect(memory: UserMemoryProfile, command: string): UserMemoryProfile {
  const next = JSON.parse(JSON.stringify(memory)) as UserMemoryProfile;
  const cmd = command.toLowerCase();
  ensureByCommand(next, cmd);
  next.prediction_feedback.by_command[cmd].correct += 1;
  next.prediction_feedback.correct += 1;
  return next;
}
