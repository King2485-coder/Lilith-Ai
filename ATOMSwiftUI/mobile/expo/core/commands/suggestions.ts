import { LilithScreenKey } from "../../constants/lilith-ui";
import { CommandSuggestion } from "./types";
import { PredictedAction } from "./predictive-engine";
import { UserMemoryProfile } from "./memory-types";

const suggestionMap: Record<LilithScreenKey, string[]> = {
  home: ["show inbox", "open chat", "run tool text_summarizer"],
  chat: ["send $10 to alex", "summarize this", "turn this into a video and send it to alex"],
  browser: ["summarize this page", "send this page to alex", "run tool text_summarizer on this"],
  wallet: ["request payment", "split this bill with everyone in this chat", "show balance"],
  library: ["search receipts", "save this page", "open workspace"],
  workspace: ["continue last project", "move this to library", "run tool text_summarizer"],
  vault: ["review vault profile", "detect autofill", "open cloud settings"],
  cloud: ["sync now", "review vault sync", "open library"],
  tools: ["run tool text_summarizer", "share result to chat", "open tool marketplace"],
  inbox: ["show notifications", "open chat", "open wallet"],
  profile: ["message alex hello", "send $10 to alex", "open tools"],
  "kids-world": ["open guardian dashboard", "show inbox", "open home"],
  "guardian-dashboard": ["show notifications", "open kids world", "open profile"],
  "admin-control": ["open observability dashboard", "show notifications", "open home"],
  "observability-dashboard": ["show notifications", "open admin control", "open home"],
  "growth-system": ["create a post from this and publish it", "open browser", "show inbox"],
  "tool-marketplace": ["run tool text_summarizer", "open tools", "open profile"],
};

function contextualAsSuggestions(screen: LilithScreenKey, recentCommands: string[]): CommandSuggestion[] {
  const base = suggestionMap[screen] || suggestionMap.home;
  const repeat = recentCommands[0] ? [recentCommands[0]] : [];
  return [...repeat, ...base].map((command, idx) => ({
    id: `ctx-${screen}-${idx}-${command}`,
    label: command,
    command,
    confidence: Math.max(0.5, 0.8 - idx * 0.1),
    source: "contextual",
    isSuggested: false,
  }));
}

export function buildSuggestions({
  screen,
  recentCommands,
  predictions,
  memory,
}: {
  screen: LilithScreenKey;
  recentCommands: string[];
  predictions: PredictedAction[];
  memory: UserMemoryProfile;
}): CommandSuggestion[] {
  const contextual = contextualAsSuggestions(screen, recentCommands);
  const predictive: CommandSuggestion[] = predictions.map((p, idx) => ({
    id: `pred-${idx}-${p.command}`,
    label: p.label,
    command: p.command,
    confidence: p.confidence,
    source: "predictive",
    isSuggested: true,
  }));

  const macroSuggestions: CommandSuggestion[] = Object.entries(memory.macros)
    .slice(0, 2)
    .map(([key, value]) => ({
      id: `macro-${key}`,
      label: `Macro: ${value.command}`,
      command: value.command,
      confidence: Math.min(0.95, 0.65 + Math.min(value.uses, 10) * 0.02),
      source: "predictive",
      isSuggested: true,
    }));

  const merged = [...predictive, ...macroSuggestions, ...contextual];
  const seen = new Set<string>();
  const unique = merged.filter((s) => {
    if (seen.has(s.command)) return false;
    seen.add(s.command);
    return true;
  });

  const recencyMap = new Map<string, number>();
  recentCommands.slice(0, 12).forEach((command, idx) => {
    recencyMap.set(command.toLowerCase(), idx);
  });

  const contextBoost = (source: CommandSuggestion["source"]) => (source === "contextual" ? 0.08 : 0.16);
  const recencyBoost = (command: string) => {
    const idx = recencyMap.get(command.toLowerCase());
    if (idx === undefined) return 0;
    return Math.max(0, 0.12 - idx * 0.01);
  };

  return unique
    .map((s) => ({
      ...s,
      confidence: Math.min(0.99, s.confidence + contextBoost(s.source) + recencyBoost(s.command)),
    }))
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 3);
}
