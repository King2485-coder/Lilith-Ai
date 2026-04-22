import { LilithScreenKey } from "../../constants/lilith-ui";

export type CommandAction =
  | "navigate"
  | "send_message"
  | "pay_user"
  | "split_bill"
  | "get_balance"
  | "run_tool"
  | "create_video"
  | "open_live_tv"
  | "mute_secondary_streams"
  | "swap_live_focus"
  | "create_post"
  | "publish_post"
  | "analyze_page"
  | "save_page"
  | "send_page_to_chat"
  | "open_connected_apps"
  | "fetch_notifications"
  | "open_profile"
  | "refresh_screen"
  | "save_to_storage"
  | "search_storage"
  | "lock_vault"
  | "unlock_vault"
  | "unknown";

export type CommandIntentType =
  | "navigation.open"
  | "message.send"
  | "payment.send"
  | "payment.split_bill"
  | "wallet.balance"
  | "tool.run"
  | "media.live_tv"
  | "media.live_multiview"
  | "media.live_audio"
  | "media.live_swap"
  | "browser.analyze"
  | "browser.summarize_current_page"
  | "browser.send_to_chat"
  | "browser.save_page"
  | "browser.open_connected_apps"
  | "social.create_post"
  | "notifications.show"
  | "profile.open"
  | "refresh"
  | "workflow.video_send"
  | "workflow.summarize_save"
  | "workflow.post_publish"
  | "storage.save"
  | "storage.search"
  | "vault.lock"
  | "vault.unlock"
  | "unknown";

export type CommandIntent = {
  raw: string;
  type: CommandIntentType;
  action: CommandAction;
  entities: {
    user?: string;
    amount?: string;
    currency?: string;
    url?: string;
    tool_name?: string;
    message_text?: string;
    content_ref?: string;
    channel?: string;
    mode?: string;
  };
  confidence: number;
  source_context: LilithScreenKey | "global";
};

export type SafetyTier = "none" | "soft" | "hard";

export type TaskStep = {
  id: string;
  label: string;
  execute: CommandAction;
  safety: SafetyTier;
  condition?: "always" | "has_target" | "has_content";
  payload?: Record<string, string>;
  retrySafe?: boolean;
  onSuccess?: string[];
  onFailure?: string[];
};

export type CommandPlan = {
  operationId: string;
  intent: CommandIntent;
  steps: TaskStep[];
  parallel?: boolean;
  requiresConfirm?: boolean;
};

export type CommandResultType =
  | "navigation"
  | "message.sent"
  | "payment.sent"
  | "payment.split"
  | "tool.result"
  | "browser.analyzed"
  | "browser.saved"
  | "browser.sent"
  | "browser.connected_apps"
  | "balance.shown"
  | "live_tv.opened"
  | "notifications.shown"
  | "post.published"
  | "workflow.completed"
  | "storage.saved"
  | "storage.search_results"
  | "vault.state"
  | "error";

export type CommandResultStatus = "pending" | "success" | "error" | "confirm_required";

export type NormalizedCommandResult = {
  trace_id: string;
  operation_id: string;
  type: CommandResultType;
  title: string;
  subtitle: string;
  status: CommandResultStatus;
  cta?: {
    label: string;
    action: string;
  };
  payload?: unknown;
};

export type CommandExecutionResult = NormalizedCommandResult & {
  ok: boolean;
  timing_ms: number;
  step_statuses: CommandStepExecutionState[];
};

export type CommandStepExecutionState = {
  step_id: string;
  label: string;
  status: "pending" | "running" | "success" | "error" | "skipped";
  started_at?: number;
  ended_at?: number;
  error?: string;
  idempotency_key: string;
};

export type CommandPendingState = {
  trace_id: string;
  operation_id: string;
  title: string;
  subtitle: string;
};

export type CommandRuntimeContext = {
  activeScreen: LilithScreenKey;
  activeConversationUserId: string;
  activeBrowserUrl: string;
  activeSelectedContent: string;
  preferredCurrency: string;
  chatParticipants: string[];
  vaultLocked: boolean;
};

export type CommandSuggestion = {
  id: string;
  label: string;
  command: string;
  confidence: number;
  source: "predictive" | "contextual";
  isSuggested: boolean;
};
