import { LilithScreenKey } from "../../constants/lilith-ui";
import { CommandExecutionResult } from "./types";

type PersonalitySignal = {
  screen: LilithScreenKey;
  isFast: boolean;
  isHesitating: boolean;
  isRepeated: boolean;
  hour: number;
};

type ComplexityTier = "simple" | "standard" | "complex";

export function buildPendingCopy(signal: PersonalitySignal): { title: string; subtitle: string } {
  if (signal.isHesitating) return { title: "Working on it.", subtitle: "I can take care of this." };
  return { title: "Working on it.", subtitle: "" };
}

function getComplexityTier(stepCount: number, type: CommandExecutionResult["type"]): ComplexityTier {
  if (stepCount >= 3 || type === "workflow.completed" || type === "tool.result" || type === "storage.search_results") return "complex";
  if (stepCount <= 1 && (type === "navigation" || type === "notifications.shown" || type === "browser.connected_apps")) return "simple";
  return "standard";
}

export function getResultRevealDelayMs(stepCount: number, type: CommandExecutionResult["type"]): number {
  const tier = getComplexityTier(stepCount, type);
  if (tier === "simple") return 100;
  if (tier === "complex") return 700;
  return 300;
}

export function applyPersonalityToResult(
  result: CommandExecutionResult,
  signal: PersonalitySignal,
  stepCount: number
): CommandExecutionResult {
  const basePayload = typeof result.payload === "object" && result.payload ? result.payload : {};
  const payload = {
    ...basePayload,
    raw_title: result.title,
    raw_subtitle: result.subtitle,
  };

  if (!result.ok || result.status === "error" || result.type === "error") {
    return {
      ...result,
      title: "That didn’t go through.",
      subtitle: "Try this.",
      payload,
    };
  }

  const highValue = result.type === "tool.result" || result.type === "workflow.completed" || result.type === "storage.search_results";
  const critical = result.type === "payment.sent" || result.type === "payment.split" || result.type === "vault.state";
  const usefulDirectional = result.type === "browser.analyzed" || result.type === "post.published";
  const simple = result.type === "navigation" || result.type === "notifications.shown" || result.type === "browser.connected_apps";

  let title = "Done.";
  if (critical) title = "Use this.";
  else if (highValue) title = "This is the best option.";
  else if (usefulDirectional) title = "Start here.";
  else if (simple) title = "Here.";
  else if (stepCount >= 3) title = "Start here.";

  let subtitle = "";
  if (signal.isFast) subtitle = "Next?";
  else if (signal.isRepeated) subtitle = "I can automate this.";
  else if (usefulDirectional) subtitle = "Do this next.";
  else if (highValue && !critical) subtitle = "Continue here.";

  const obvious = simple && !signal.isHesitating;
  const decisionsNeeded = critical || highValue || Boolean(result.cta);
  const risk = result.type === "payment.sent" || result.type === "payment.split" || result.type === "vault.state";
  const shouldSpeak = !obvious || decisionsNeeded || risk || signal.isHesitating;

  if (signal.isHesitating && !subtitle && !risk) {
    subtitle = "Let me handle it.";
  }

  const silent = !shouldSpeak;

  return {
    ...result,
    title,
    subtitle: silent ? "" : subtitle,
    payload: {
      ...payload,
      silent,
    },
  };
}

