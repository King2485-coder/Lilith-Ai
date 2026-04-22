import { LilithScreenKey } from "../../constants/lilith-ui";
import { CommandRuntimeContext } from "./types";
import { UserMemoryProfile } from "./memory-types";

export type PredictedAction = {
  intent: string;
  entities: Record<string, string>;
  label: string;
  command: string;
  confidence: number;
  source: "memory" | "context";
};

function topKey(map: Record<string, number>) {
  return Object.entries(map)
    .sort((a, b) => b[1] - a[1])[0]?.[0];
}

function contextualPredictors(screen: LilithScreenKey, runtime: CommandRuntimeContext): PredictedAction[] {
  const user = runtime.activeConversationUserId || "alex";
  if (screen === "chat") {
    return [
      { intent: "payment.send", entities: { user, amount: "10", currency: runtime.preferredCurrency || "USD" }, label: "Send money", command: `send $10 to ${user}`, confidence: 0.78, source: "context" },
      { intent: "tool.run", entities: { tool_name: "text_summarizer" }, label: "Summarize", command: "summarize this", confidence: 0.74, source: "context" },
      { intent: "workflow.video_send", entities: { user }, label: "Create video", command: `turn this into a video and send it to ${user}`, confidence: 0.71, source: "context" },
    ];
  }
  if (screen === "browser") {
    return [
      { intent: "browser.summarize_current_page", entities: { url: runtime.activeBrowserUrl }, label: "Summarize page", command: "summarize this page", confidence: 0.79, source: "context" },
      { intent: "browser.send_to_chat", entities: { user, url: runtime.activeBrowserUrl }, label: "Send to chat", command: `send this page to ${user}`, confidence: 0.76, source: "context" },
      { intent: "tool.run", entities: { tool_name: "text_summarizer" }, label: "Use tool", command: "run tool text_summarizer on this page", confidence: 0.72, source: "context" },
    ];
  }
  if (screen === "wallet") {
    return [
      { intent: "payment.send", entities: { user, amount: "20", currency: runtime.preferredCurrency || "USD" }, label: "Request payment", command: `send $20 to ${user}`, confidence: 0.74, source: "context" },
      { intent: "payment.split_bill", entities: {}, label: "Split bill", command: "split this bill with everyone in this chat", confidence: 0.72, source: "context" },
      { intent: "wallet.balance", entities: {}, label: "Show history", command: "show balance", confidence: 0.7, source: "context" },
    ];
  }
  if (screen === "library") {
    return [
      { intent: "browser.save_page", entities: { url: runtime.activeBrowserUrl || "" }, label: "Save current page", command: "save this page", confidence: 0.73, source: "context" },
      { intent: "notifications.show", entities: {}, label: "Find receipts", command: "search receipts", confidence: 0.67, source: "context" },
      { intent: "navigation.open", entities: { content_ref: "workspace" }, label: "Open Workspace", command: "open workspace", confidence: 0.65, source: "context" },
    ];
  }
  if (screen === "workspace") {
    return [
      { intent: "tool.run", entities: { tool_name: "text_summarizer" }, label: "Summarize current draft", command: "run tool text_summarizer", confidence: 0.7, source: "context" },
      { intent: "navigation.open", entities: { content_ref: "library" }, label: "Move to Library", command: "open library", confidence: 0.64, source: "context" },
      { intent: "refresh", entities: {}, label: "Continue latest", command: "refresh", confidence: 0.62, source: "context" },
    ];
  }
  if (screen === "vault") {
    return [
      { intent: "navigation.open", entities: { content_ref: "cloud" }, label: "Open cloud settings", command: "open cloud", confidence: 0.68, source: "context" },
      { intent: "notifications.show", entities: {}, label: "Review access logs", command: "show notifications", confidence: 0.61, source: "context" },
      { intent: "wallet.balance", entities: {}, label: "Check payment profile", command: "show balance", confidence: 0.58, source: "context" },
    ];
  }
  return [];
}

export function predictActions(runtime: CommandRuntimeContext, memory: UserMemoryProfile): PredictedAction[] {
  const started = Date.now();
  const predictions: PredictedAction[] = [];

  const topIntent = topKey(memory.frequent_intents);
  const topContact = topKey(memory.frequent_contacts) || memory.last_used_entities.user || runtime.activeConversationUserId;

  if (topIntent === "payment.send" && topContact) {
    predictions.push({
      intent: "payment.send",
      entities: { user: topContact, amount: memory.last_used_entities.amount || "10", currency: memory.last_used_entities.currency || runtime.preferredCurrency || "USD" },
      label: `Send ${memory.last_used_entities.amount || "10"} to ${topContact}`,
      command: `send ${memory.last_used_entities.amount || "10"} to ${topContact}`,
      confidence: 0.82,
      source: "memory",
    });
  }
  if (memory.last_used_entities.tool_name) {
    predictions.push({
      intent: "tool.run",
      entities: { tool_name: memory.last_used_entities.tool_name },
      label: `Run ${memory.last_used_entities.tool_name} again`,
      command: "run it again",
      confidence: 0.77,
      source: "memory",
    });
  }
  if (memory.recent_commands[0]?.command) {
    predictions.push({
      intent: memory.recent_commands[0].intent_type,
      entities: memory.recent_commands[0].entities,
      label: "Repeat last command",
      command: memory.recent_commands[0].command,
      confidence: 0.69,
      source: "memory",
    });
  }

  predictions.push(...contextualPredictors(runtime.activeScreen, runtime));
  const uniq = new Map<string, PredictedAction>();
  predictions.forEach((p) => {
    if (!uniq.has(p.command)) uniq.set(p.command, p);
  });
  const ranked = [...uniq.values()]
    .map((item) => {
      const intentBoost = memory.behavior_model.intent_confidence[item.intent] || 0;
      const cmdBoost = memory.behavior_model.suggestion_scores[item.command.toLowerCase()] || 0;
      const fb = memory.prediction_feedback.by_command[item.command.toLowerCase()];
      const precisionBoost = fb && fb.shown > 0 ? ((fb.correct / fb.shown) - 0.5) * 0.2 : 0;
      const finalConfidence = Math.max(0, Math.min(1, item.confidence + intentBoost * 0.35 + cmdBoost * 0.3 + precisionBoost));
      return { ...item, confidence: Number(finalConfidence.toFixed(4)) };
    })
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 3);

  // Keep under target budget in normal device conditions.
  const elapsed = Date.now() - started;
  if (elapsed > 50) {
    return ranked.slice(0, 2);
  }
  return ranked;
}
