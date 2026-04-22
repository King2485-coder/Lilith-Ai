import * as Haptics from "expo-haptics";
import { AppState, Platform } from "react-native";

type FeedbackEvent =
  | "command_sent"
  | "processing_start"
  | "success"
  | "error"
  | "notification"
  | "orb_tighten"
  | "orb_expand"
  | "guidance";

type FeedbackOptions = {
  sound?: boolean;
  haptic?: boolean;
};

const state = {
  lastInteractionAt: 0,
  lastEventAt: {} as Record<string, number>,
  repeatCount: {} as Record<string, number>,
};

const EVENT_COOLDOWN_MS: Record<FeedbackEvent, number> = {
  command_sent: 120,
  processing_start: 300,
  success: 260,
  error: 260,
  notification: 500,
  orb_tighten: 300,
  orb_expand: 320,
  guidance: 260,
};

function nowMs() {
  return Date.now();
}

function isUserActive() {
  return AppState.currentState === "active" && nowMs() - state.lastInteractionAt < 4500;
}

function canEmit(event: FeedbackEvent) {
  const last = state.lastEventAt[event] || 0;
  const cooldown = EVENT_COOLDOWN_MS[event];
  if (nowMs() - last < cooldown) return false;
  state.lastEventAt[event] = nowMs();
  return true;
}

function updateRepeat(event: FeedbackEvent) {
  const last = state.lastEventAt[event] || 0;
  const close = nowMs() - last < 4000;
  state.repeatCount[event] = close ? Math.min((state.repeatCount[event] || 0) + 1, 4) : 0;
}

function toneScale(event: FeedbackEvent) {
  const activeScale = isUserActive() ? 0.35 : 0.7;
  const repeatPenalty = Math.max(0.45, 1 - (state.repeatCount[event] || 0) * 0.12);
  return activeScale * repeatPenalty;
}

async function playWebTone(frequency: number, durationMs: number, volume: number) {
  if (Platform.OS !== "web") return;
  const w = globalThis as unknown as { AudioContext?: typeof AudioContext; webkitAudioContext?: typeof AudioContext };
  const Ctx = w.AudioContext || w.webkitAudioContext;
  if (!Ctx) return;
  const ctx = new Ctx();
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = "sine";
  osc.frequency.value = frequency;
  gain.gain.value = 0.0001;
  osc.connect(gain);
  gain.connect(ctx.destination);
  const t0 = ctx.currentTime;
  const t1 = t0 + Math.max(0.04, durationMs / 1000);
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, volume), t0 + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t1);
  osc.start(t0);
  osc.stop(t1);
  await new Promise((r) => setTimeout(r, durationMs + 10));
  ctx.close().catch(() => null);
}

async function playSound(event: FeedbackEvent) {
  if (Platform.OS !== "web") return;
  const scale = toneScale(event);
  if (scale < 0.08) return;

  if (event === "command_sent") {
    await playWebTone(620, 80, 0.014 * scale);
    return;
  }
  if (event === "success" || event === "orb_expand") {
    await playWebTone(760, 70, 0.014 * scale);
    await playWebTone(900, 80, 0.013 * scale);
    return;
  }
  if (event === "error") {
    await playWebTone(340, 120, 0.013 * scale);
    return;
  }
  if (event === "notification") {
    await playWebTone(520, 100, 0.011 * scale);
    return;
  }
  if (event === "processing_start" || event === "orb_tighten") {
    await playWebTone(470, 70, 0.009 * scale);
  }
}

async function playHaptic(event: FeedbackEvent) {
  if (event === "command_sent") {
    await Haptics.selectionAsync();
    return;
  }
  if (event === "success" || event === "orb_expand") {
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    return;
  }
  if (event === "error") {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    return;
  }
  if (event === "guidance") {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    return;
  }
  if (event === "processing_start" || event === "orb_tighten") {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Soft);
    return;
  }
  if (event === "notification") {
    await Haptics.selectionAsync();
  }
}

export function markLilithInteraction() {
  state.lastInteractionAt = nowMs();
}

export async function emitLilithFeedback(event: FeedbackEvent, options?: FeedbackOptions) {
  if (!canEmit(event)) return;
  updateRepeat(event);
  const withHaptic = options?.haptic ?? true;
  const withSound = options?.sound ?? false;
  if (withHaptic) await playHaptic(event).catch(() => null);
  if (withSound) await playSound(event).catch(() => null);
}

