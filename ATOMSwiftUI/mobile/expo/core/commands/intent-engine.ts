import { CommandIntent, CommandRuntimeContext } from "./types";
import { UserMemoryProfile } from "./memory-types";

function clean(input: string) {
  return input.trim().toLowerCase();
}

function normalizeUser(raw?: string, runtime?: CommandRuntimeContext) {
  if (!raw) return runtime?.activeConversationUserId || "";
  const value = raw.replace(/^@/, "").trim();
  if (value === "current chat" || value === "last person") return runtime?.activeConversationUserId || "";
  return value;
}

function inferUser(runtime: CommandRuntimeContext, memory?: UserMemoryProfile) {
  const topLearnedUser = Object.entries(memory?.behavior_model.autofill_entity_scores || {})
    .filter(([k]) => k.startsWith("user:"))
    .sort((a, b) => b[1] - a[1])[0]?.[0]
    ?.replace(/^user:/, "");
  return (
    runtime.activeConversationUserId ||
    topLearnedUser ||
    memory?.last_used_entities.user ||
    Object.entries(memory?.frequent_contacts || {}).sort((a, b) => b[1] - a[1])[0]?.[0] ||
    ""
  );
}

function detectCurrency(raw?: string) {
  if (!raw) return "USD";
  const c = raw.toUpperCase();
  if (c === "$") return "USD";
  if (c === "USDC") return "USDC";
  return "USD";
}

function extractUrl(input: string) {
  const found = input.match(/(https?:\/\/\S+|\b[a-z0-9.-]+\.[a-z]{2,}(?:\/\S*)?)/i)?.[1];
  if (!found) return "";
  return found.startsWith("http://") || found.startsWith("https://") ? found : `https://${found}`;
}

export function detectIntent(command: string, runtime: CommandRuntimeContext, memory?: UserMemoryProfile): CommandIntent {
  const raw = command.trim();
  const c = clean(command);

  if (/turn this into a video and send it to\s+@?([a-z0-9_\-]+)/i.test(c)) {
    const user = normalizeUser(c.match(/send it to\s+@?([a-z0-9_\-]+)/i)?.[1], runtime);
    return {
      raw,
      type: "workflow.video_send",
      action: "create_video",
      entities: { user, content_ref: "this" },
      confidence: 0.97,
      source_context: runtime.activeScreen,
    };
  }

  if (/split this bill with everyone in this chat/i.test(c)) {
    return {
      raw,
      type: "payment.split_bill",
      action: "split_bill",
      entities: { content_ref: "this_bill" },
      confidence: 0.96,
      source_context: runtime.activeScreen,
    };
  }

  if (/^send it$/i.test(c) || /^send this$/i.test(c)) {
    return {
      raw,
      type: "message.send",
      action: "send_message",
      entities: {
        user: inferUser(runtime, memory),
        message_text: runtime.activeSelectedContent || memory?.last_used_entities.message_text || "Sending current item.",
      },
      confidence: 0.78,
      source_context: runtime.activeScreen,
    };
  }

  if (/summarize this page and save it/i.test(c)) {
    return {
      raw,
      type: "workflow.summarize_save",
      action: "analyze_page",
      entities: { url: runtime.activeBrowserUrl || "", content_ref: "current_page" },
      confidence: 0.96,
      source_context: runtime.activeScreen,
    };
  }

  if (/create a post from this and publish it/i.test(c)) {
    return {
      raw,
      type: "workflow.post_publish",
      action: "create_post",
      entities: { content_ref: runtime.activeSelectedContent || "this" },
      confidence: 0.95,
      source_context: runtime.activeScreen,
    };
  }

  const liveChannelMatch = c.match(/(?:watch|open)\s+(?:this\s+)?channel\s*(.+)?$/i);
  if (/open live tv|open tv|live tv/i.test(c)) {
    return {
      raw,
      type: "media.live_tv",
      action: "open_live_tv",
      entities: { channel: liveChannelMatch?.[1]?.trim() || "", mode: "single" },
      confidence: 0.95,
      source_context: runtime.activeScreen,
    };
  }

  if (/open multiview|open multi view|watch multiview|watch multiple streams/i.test(c)) {
    return {
      raw,
      type: "media.live_multiview",
      action: "open_live_tv",
      entities: { channel: liveChannelMatch?.[1]?.trim() || "", mode: "multiview" },
      confidence: 0.96,
      source_context: runtime.activeScreen,
    };
  }

  if (/mute secondary streams|mute secondaries|mute secondary/i.test(c)) {
    return {
      raw,
      type: "media.live_audio",
      action: "mute_secondary_streams",
      entities: {},
      confidence: 0.94,
      source_context: runtime.activeScreen,
    };
  }

  if (/swap main stream|swap main channel|swap focus/i.test(c)) {
    return {
      raw,
      type: "media.live_swap",
      action: "swap_live_focus",
      entities: { channel: liveChannelMatch?.[1]?.trim() || "" },
      confidence: 0.93,
      source_context: runtime.activeScreen,
    };
  }

  const sendMoneyMatch = c.match(/(pay|send money|transfer|send)\s+\$?([0-9]+(?:\.[0-9]{1,2})?)\s*(usd|usdc|\$)?(?:\s+to\s+@?([a-z0-9_\-]+|last person|current chat))?/i);
  if (sendMoneyMatch) {
    return {
      raw,
      type: "payment.send",
      action: "pay_user",
      entities: {
        amount: sendMoneyMatch[2],
        currency: detectCurrency(sendMoneyMatch[3] || runtime.preferredCurrency),
        user: normalizeUser(sendMoneyMatch[4], runtime) || inferUser(runtime, memory),
      },
      confidence: 0.94,
      source_context: runtime.activeScreen,
    };
  }

  const shortSend = c.match(/^(send|pay|transfer)\s+\$?([0-9]+(?:\.[0-9]{1,2})?)$/i);
  if (shortSend) {
    return {
      raw,
      type: "payment.send",
      action: "pay_user",
      entities: {
        amount: shortSend[2],
        currency: memory?.last_used_entities.currency || runtime.preferredCurrency || "USD",
        user: inferUser(runtime, memory),
      },
      confidence: 0.81,
      source_context: runtime.activeScreen,
    };
  }

  const tellMatch = c.match(/(tell|message|send message to|send)\s+@?([a-z0-9_\-]+|last person|current chat)\s+(.+)/i);
  if (tellMatch) {
    return {
      raw,
      type: "message.send",
      action: "send_message",
      entities: {
        user: normalizeUser(tellMatch[2], runtime) || inferUser(runtime, memory),
        message_text: tellMatch[3],
      },
      confidence: 0.92,
      source_context: runtime.activeScreen,
    };
  }

  const navMatch = c.match(/^(go to|open|show)\s+(.+)$/);
  if (navMatch) {
    const destination = navMatch[2].trim();
    if (destination.includes("connected apps")) {
      return {
        raw,
        type: "browser.open_connected_apps",
        action: "open_connected_apps",
        entities: {},
        confidence: 0.9,
        source_context: runtime.activeScreen,
      };
    }
    if (destination.includes("notifications") || destination.includes("inbox")) {
      return {
        raw,
        type: "notifications.show",
        action: "fetch_notifications",
        entities: {},
        confidence: 0.88,
        source_context: runtime.activeScreen,
      };
    }
    return {
      raw,
      type: "navigation.open",
      action: "navigate",
      entities: { content_ref: destination },
      confidence: 0.95,
      source_context: runtime.activeScreen,
    };
  }

  if (/(analyze|inspect|summarize)\s+(this page|current page)/i.test(c)) {
    return {
      raw,
      type: "browser.summarize_current_page",
      action: "analyze_page",
      entities: { url: runtime.activeBrowserUrl || "" },
      confidence: 0.91,
      source_context: runtime.activeScreen,
    };
  }

  if (c === "summarize" || c === "summarize this") {
    if (runtime.activeScreen === "browser") {
      return {
        raw,
        type: "browser.summarize_current_page",
        action: "analyze_page",
        entities: { url: runtime.activeBrowserUrl || memory?.last_used_entities.url || "" },
        confidence: 0.83,
        source_context: runtime.activeScreen,
      };
    }
    return {
      raw,
      type: "tool.run",
      action: "run_tool",
      entities: { tool_name: "text_summarizer", content_ref: runtime.activeSelectedContent || "this" },
      confidence: 0.74,
      source_context: runtime.activeScreen,
    };
  }

  const analyzeUrl = extractUrl(c);
  if (/(analyze|inspect|summarize)/i.test(c) && analyzeUrl) {
    return {
      raw,
      type: "browser.analyze",
      action: "analyze_page",
      entities: { url: analyzeUrl },
      confidence: 0.91,
      source_context: runtime.activeScreen,
    };
  }

  if (analyzeUrl) {
    return {
      raw,
      type: "browser.analyze",
      action: "analyze_page",
      entities: { url: analyzeUrl },
      confidence: 0.72,
      source_context: runtime.activeScreen,
    };
  }

  if (/(run|use)\s+(tool\s+)?([a-z0-9_\-]+)(?:\s+on\s+this)?/i.test(c)) {
    const toolName = c.match(/(run|use)\s+(tool\s+)?([a-z0-9_\-]+)/i)?.[3] || "text_summarizer";
    return {
      raw,
      type: "tool.run",
      action: "run_tool",
      entities: {
        tool_name: toolName,
        content_ref: c.includes("on this") ? runtime.activeSelectedContent || "this" : "",
      },
      confidence: 0.89,
      source_context: runtime.activeScreen,
    };
  }

  if (/(run it again|do it again)/i.test(c)) {
    return {
      raw,
      type: "tool.run",
      action: "run_tool",
      entities: {
        tool_name:
          Object.entries(memory?.behavior_model.autofill_entity_scores || {})
            .filter(([k]) => k.startsWith("tool:"))
            .sort((a, b) => b[1] - a[1])[0]?.[0]
            ?.replace(/^tool:/, "") ||
          memory?.last_used_entities.tool_name ||
          "text_summarizer",
        content_ref: runtime.activeSelectedContent || memory?.last_used_entities.message_text || "this",
      },
      confidence: 0.8,
      source_context: runtime.activeScreen,
    };
  }

  if (/(send this page to|send this to)\s+@?([a-z0-9_\-]+|last person|current chat)/i.test(c)) {
    const user = normalizeUser(c.match(/to\s+@?([a-z0-9_\-]+|last person|current chat)/i)?.[1], runtime);
    return {
      raw,
      type: "browser.send_to_chat",
      action: "send_page_to_chat",
      entities: { user, url: runtime.activeBrowserUrl || "" },
      confidence: 0.9,
      source_context: runtime.activeScreen,
    };
  }

  if (/(save this page|save page)/i.test(c)) {
    return {
      raw,
      type: "browser.save_page",
      action: "save_page",
      entities: { url: runtime.activeBrowserUrl || "" },
      confidence: 0.88,
      source_context: runtime.activeScreen,
    };
  }

  if (/(save this|save to library|quick save)/i.test(c)) {
    return {
      raw,
      type: "storage.save",
      action: "save_to_storage",
      entities: {
        content_ref: runtime.activeSelectedContent || runtime.activeBrowserUrl || "current_context",
      },
      confidence: 0.86,
      source_context: runtime.activeScreen,
    };
  }

  const searchMatch = c.match(/(search|find)\s+(library|workspace|vault|storage)?\s*(for)?\s*(.+)/i);
  if (searchMatch) {
    const zone = (searchMatch[2] || "storage").trim();
    const query = (searchMatch[4] || "").trim() || runtime.activeSelectedContent || "recent";
    return {
      raw,
      type: "storage.search",
      action: "search_storage",
      entities: {
        content_ref: `${zone}:${query}`,
      },
      confidence: 0.84,
      source_context: runtime.activeScreen,
    };
  }

  if (/(lock vault|secure vault)/i.test(c)) {
    return {
      raw,
      type: "vault.lock",
      action: "lock_vault",
      entities: {},
      confidence: 0.92,
      source_context: runtime.activeScreen,
    };
  }

  if (/(unlock vault|open vault|unlock for)/i.test(c)) {
    const mins = c.match(/(\d+)\s*(m|min|minute)/i)?.[1] || "5";
    return {
      raw,
      type: "vault.unlock",
      action: "unlock_vault",
      entities: { amount: mins },
      confidence: 0.9,
      source_context: runtime.activeScreen,
    };
  }

  if (c.includes("balance") || c.includes("wallet")) {
    return {
      raw,
      type: "wallet.balance",
      action: "get_balance",
      entities: { currency: runtime.preferredCurrency || "USD" },
      confidence: 0.88,
      source_context: runtime.activeScreen,
    };
  }

  if (c.includes("notifications") || c.includes("inbox")) {
    return {
      raw,
      type: "notifications.show",
      action: "fetch_notifications",
      entities: {},
      confidence: 0.84,
      source_context: runtime.activeScreen,
    };
  }

  if (c.startsWith("profile ")) {
    const user = normalizeUser(c.replace("profile ", ""), runtime);
    return {
      raw,
      type: "profile.open",
      action: "open_profile",
      entities: { user },
      confidence: 0.82,
      source_context: runtime.activeScreen,
    };
  }

  if (c.startsWith("refresh") || c.includes("reload")) {
    return {
      raw,
      type: "refresh",
      action: "refresh_screen",
      entities: {},
      confidence: 0.8,
      source_context: runtime.activeScreen,
    };
  }

  return {
    raw,
    type: "unknown",
    action: "unknown",
    entities: {},
    confidence: 0.2,
    source_context: runtime.activeScreen,
  };
}
