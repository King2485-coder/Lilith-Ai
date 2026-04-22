import { detectIntent } from "./intent-engine";
import { UserMemoryProfile } from "./memory-types";
import { CommandPlan, CommandRuntimeContext, TaskStep } from "./types";
import { createOperationId } from "./trace-logger";

function step(
  id: string,
  label: string,
  execute: TaskStep["execute"],
  payload: Record<string, string> = {},
  options?: Partial<TaskStep>
): TaskStep {
  return {
    id,
    label,
    execute,
    payload,
    condition: "always",
    safety: "none",
    retrySafe: true,
    ...options,
  };
}

export function createPlan(command: string, runtime: CommandRuntimeContext, memory?: UserMemoryProfile): CommandPlan {
  const intent = detectIntent(command, runtime, memory);
  const operationId = createOperationId();
  const steps: TaskStep[] = [];
  let parallel = false;

  switch (intent.type) {
    case "workflow.video_send": {
      steps.push(
        step("create_video", "Create video from current context", "create_video", {
          content_ref: intent.entities.content_ref || runtime.activeSelectedContent || "this",
        }, { safety: "none", retrySafe: true, onSuccess: ["send_video"] }),
        step(
          "send_video",
          `Send video to ${intent.entities.user || runtime.activeConversationUserId}`,
          "send_message",
          {
            receiver_id: intent.entities.user || runtime.activeConversationUserId,
            content: "Video is ready. Sending now.",
          },
          { safety: "soft", retrySafe: true }
        )
      );
      break;
    }
    case "payment.split_bill": {
      steps.push(
        step(
          "split_bill",
          "Split this bill across current chat participants",
          "split_bill",
          {},
          { safety: "hard", retrySafe: false }
        )
      );
      break;
    }
    case "workflow.summarize_save": {
      steps.push(
        step("summarize_page", "Summarize current page", "analyze_page", { url: intent.entities.url || runtime.activeBrowserUrl }, { safety: "none" }),
        step("save_page", "Save summarized page", "save_page", { url: intent.entities.url || runtime.activeBrowserUrl }, { safety: "soft" })
      );
      break;
    }
    case "workflow.post_publish": {
      steps.push(
        step("create_post", "Create post from current context", "create_post", { content_ref: intent.entities.content_ref || runtime.activeSelectedContent || "this" }, { safety: "soft" }),
        step("publish_post", "Publish post", "publish_post", {}, { safety: "soft" })
      );
      break;
    }
    case "navigation.open": {
      steps.push(step("navigate", `Open ${intent.entities.content_ref || "home"}`, "navigate", { routeHint: intent.entities.content_ref || "home" }));
      break;
    }
    case "message.send": {
      const receiver = intent.entities.user || runtime.activeConversationUserId;
      steps.push(
        step(
          "send_message",
          `Send message to ${receiver || "current chat"}`,
          "send_message",
          { receiver_id: receiver, content: intent.entities.message_text || "" },
          { safety: receiver ? "none" : "soft", condition: "has_target" }
        )
      );
      break;
    }
    case "payment.send": {
      const receiver = intent.entities.user || runtime.activeConversationUserId;
      steps.push(
        step(
          "pay_user",
          `Send ${intent.entities.amount || "0"} ${intent.entities.currency || runtime.preferredCurrency} to ${receiver || "current chat"}`,
          "pay_user",
          {
            receiver_id: receiver,
            amount: intent.entities.amount || "0",
            currency: intent.entities.currency || runtime.preferredCurrency || "USD",
          },
          { safety: "hard", retrySafe: false, condition: "has_target" }
        )
      );
      break;
    }
    case "wallet.balance": {
      steps.push(step("get_balance", "Show wallet balance", "get_balance", {}, { safety: "none" }));
      break;
    }
    case "tool.run": {
      steps.push(
        step(
          "run_tool",
          `Run ${intent.entities.tool_name || "text_summarizer"}`,
          "run_tool",
          {
            tool_name: intent.entities.tool_name || "text_summarizer",
            content_ref: intent.entities.content_ref || runtime.activeSelectedContent,
          },
          { safety: "none", retrySafe: true }
        )
      );
      break;
    }
    case "media.live_tv":
    case "media.live_multiview": {
      steps.push(
        step(
          "open_live_tv",
          intent.type === "media.live_multiview" ? "Open licensed live TV multiview" : "Open licensed live TV",
          "open_live_tv",
          {
            channel: intent.entities.channel || "",
            mode: intent.entities.mode || (intent.type === "media.live_multiview" ? "multiview" : "single"),
          },
          { safety: "none", retrySafe: true }
        )
      );
      break;
    }
    case "media.live_audio": {
      steps.push(step("mute_secondary_streams", "Mute secondary live streams", "mute_secondary_streams", {}, { safety: "none", retrySafe: true }));
      break;
    }
    case "media.live_swap": {
      steps.push(
        step(
          "swap_live_focus",
          "Swap the main live stream",
          "swap_live_focus",
          { channel: intent.entities.channel || "" },
          { safety: "none", retrySafe: true }
        )
      );
      break;
    }
    case "browser.summarize_current_page":
    case "browser.analyze": {
      steps.push(
        step("analyze_page", "Analyze page", "analyze_page", { url: intent.entities.url || runtime.activeBrowserUrl }, { safety: "none" })
      );
      break;
    }
    case "browser.send_to_chat": {
      steps.push(
        step(
          "send_page_to_chat",
          `Send page to ${intent.entities.user || runtime.activeConversationUserId || "current chat"}`,
          "send_page_to_chat",
          { url: intent.entities.url || runtime.activeBrowserUrl, receiver_id: intent.entities.user || runtime.activeConversationUserId },
          { safety: "soft", condition: "has_target" }
        )
      );
      break;
    }
    case "browser.save_page": {
      steps.push(step("save_page", "Save page", "save_page", { url: intent.entities.url || runtime.activeBrowserUrl }, { safety: "soft" }));
      break;
    }
    case "browser.open_connected_apps": {
      steps.push(step("open_connected_apps", "Open connected apps", "open_connected_apps", {}, { safety: "none" }));
      break;
    }
    case "notifications.show": {
      steps.push(step("fetch_notifications", "Show notifications", "fetch_notifications", {}, { safety: "none" }));
      break;
    }
    case "profile.open": {
      steps.push(step("open_profile", `Open profile ${intent.entities.user || ""}`, "open_profile", { target: intent.entities.user || "" }, { safety: "none" }));
      break;
    }
    case "refresh": {
      steps.push(step("refresh", `Refresh ${runtime.activeScreen}`, "refresh_screen", {}, { safety: "none" }));
      break;
    }
    case "storage.save": {
      steps.push(
        step(
          "save_storage",
          "Save current context",
          "save_to_storage",
          { content_ref: intent.entities.content_ref || runtime.activeSelectedContent || runtime.activeBrowserUrl || "current_context" },
          { safety: "soft", retrySafe: true }
        )
      );
      break;
    }
    case "storage.search": {
      steps.push(
        step(
          "search_storage",
          "Search personal storage",
          "search_storage",
          { content_ref: intent.entities.content_ref || "storage:recent" },
          { safety: "none", retrySafe: true }
        )
      );
      break;
    }
    case "vault.lock": {
      steps.push(step("lock_vault", "Lock vault", "lock_vault", {}, { safety: "none", retrySafe: true }));
      break;
    }
    case "vault.unlock": {
      steps.push(
        step(
          "unlock_vault",
          "Unlock vault for sensitive actions",
          "unlock_vault",
          { amount: intent.entities.amount || "5" },
          { safety: "soft", retrySafe: true }
        )
      );
      break;
    }
    default: {
      steps.push(step("unknown", "Ask clarifying follow-up", "unknown", {}, { safety: "none", retrySafe: false }));
      break;
    }
  }

  if (intent.type === "workflow.video_send" || intent.type === "workflow.post_publish") {
    parallel = false;
  }
  if (intent.type === "workflow.post_publish") {
    // parallel-ready plan shape, kept sequential for publish consistency.
    parallel = false;
  }

  const requiresConfirm = steps.some((s) => s.safety === "hard");

  return { operationId, intent, steps, parallel, requiresConfirm };
}
