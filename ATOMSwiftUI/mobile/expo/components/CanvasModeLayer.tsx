import { LinearGradient } from "expo-linear-gradient";
import React, { useCallback, useMemo, useRef, useState } from "react";
import {
  Animated,
  Image,
  LayoutAnimation,
  Linking,
  PanResponder,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { WebView } from "react-native-webview";

import { browserTheme } from "../constants/colors";
import { CommandExecutionResult, CommandPendingState } from "../core/commands/types";

type CanvasAction = {
  id: string;
  label: string;
  onPress: () => void;
};

type CommandRunner = (command: string) => Promise<CommandExecutionResult | null>;
type VaultSaver = (input: { title: string; content: string }) => Promise<{ ok: boolean; detail: string }>;

type FlowStepDef = {
  id: string;
  label: string;
  kind: "command" | "vault_save";
  run: (ctx: {
    activeConversationUserId: string;
    activeBrowserUrl: string;
    activeSelectedContent: string;
  }) => string;
};

type FlowDef = {
  id: string;
  label: string;
  subtitle: string;
  screens: string[];
  steps: FlowStepDef[];
};

type FlowStepState = {
  id: string;
  label: string;
  status: "pending" | "running" | "success" | "error";
  detail?: string;
};

type TaskDepthLayer = "front" | "mid" | "back";
type TaskFocusState = "none" | "soft" | "hard";

type TaskWindow = {
  id: string;
  title: string;
  subtitle: string;
  status: "idle" | "running" | "success" | "error";
  x: number;
  y: number;
  scale: number;
  depthLayer: TaskDepthLayer;
  focusState: TaskFocusState;
  controlsVisible: boolean;
  commandHint?: string;
  sourceOperationId?: string;
  contentKind?: "default" | "live_stream";
  mediaUrl?: string;
  posterUrl?: string;
  providerName?: string;
  streamId?: string;
  muted?: boolean;
  createdAt: number;
  lastFocusedAt?: number;
};

type SpatialTaskViewModel = {
  task: TaskWindow;
  index: number;
  anchorX: number;
  anchorY: number;
  scale: number;
  opacity: number;
  width: number;
  minHeight: number;
  zIndex: number;
  shadowOpacity: number;
  shadowRadius: number;
  borderOpacity: number;
  glowOpacity: number;
  dimOpacity: number;
  verticalLift: number;
};

type CenterResultType = "image" | "video" | "text" | "mixed" | "page" | "flow" | "payment" | "fallback" | "live_tv";

type CenterResultState = {
  id: string;
  title: string;
  subtitle: string;
  resultType: CenterResultType;
  resultStatus: "idle" | "working" | "ready" | "error";
  assetUrl?: string;
  assetId?: string;
  previewUrl?: string;
  textContent?: string;
  payload?: Record<string, unknown>;
  cta?: { label: string; action: string };
};

type ResultLink = {
  id: string;
  route: string;
  privateUrl: string;
  publicUrl: string;
  visibility: string;
};

type VoidState = "idle" | "anticipating" | "engaged" | "manifesting" | "settling" | "recovering";
type PredictiveIntentType = "image" | "text" | "video" | "payment" | "page" | "mixed" | "none";
type PredictiveGhostStructure = "frame" | "lines" | "list" | "steps" | "chat" | "code" | "page" | "payment" | "video";

type PredictiveGhost = {
  type: PredictiveIntentType;
  confidence: number;
  aspectRatio: number;
  semanticStructure: PredictiveGhostStructure;
  lineCount: number;
  tint: string;
  stability: number;
  motion: number;
};

type LiveTvStream = {
  id: string;
  title: string;
  provider_id: string;
  provider_name: string;
  stream_url: string;
  poster_url: string;
  description: string;
  licensed: boolean;
  muted: boolean;
};

type CanvasModeLayerProps = {
  title: string;
  subtitle: string;
  leftActions: CanvasAction[];
  rightActions: CanvasAction[];
  bottomActions: CanvasAction[];
  suggestions: Array<{ id: string; label: string; command: string }>;
  recentActionCount: number;
  activeScreen: string;
  activeConversationUserId: string;
  activeBrowserUrl: string;
  activeSelectedContent: string;
  commandDraft: string;
  commandInputFocused: boolean;
  vaultLocked: boolean;
  commandActive: boolean;
  pendingResult: CommandPendingState | null;
  latestResult: CommandExecutionResult | null;
  onOrbTap?: () => void;
  onRunCommand: CommandRunner;
  onSaveToVault: VaultSaver;
  children: React.ReactNode;
};

const GHOST_HINTS = ["Apply to a job", "Make money today", "Summarize this"];
const TASK_STORAGE_KEY = "lilith.canvas.spatial_stack.v1";
const TAP_WINDOW_MS = 260;
const VOID_PARTICLES = [
  { id: "p1", x: -116, y: -72, size: 2.4, opacity: 0.24 },
  { id: "p2", x: -92, y: 18, size: 1.8, opacity: 0.18 },
  { id: "p3", x: -48, y: -116, size: 2.2, opacity: 0.14 },
  { id: "p4", x: -22, y: 82, size: 1.6, opacity: 0.18 },
  { id: "p5", x: 18, y: -94, size: 2.1, opacity: 0.2 },
  { id: "p6", x: 46, y: 36, size: 1.7, opacity: 0.14 },
  { id: "p7", x: 86, y: -38, size: 2.3, opacity: 0.16 },
  { id: "p8", x: 118, y: 72, size: 2, opacity: 0.2 },
];
const VOID_MICRO_FRAGMENTS = [
  { id: "f1", x: -182, y: -96, w: 18, h: 1, opacity: 0.06, rotate: "-18deg" },
  { id: "f2", x: -154, y: 122, w: 10, h: 10, opacity: 0.05, rotate: "0deg" },
  { id: "f3", x: -108, y: -156, w: 12, h: 1, opacity: 0.04, rotate: "24deg" },
  { id: "f4", x: -84, y: 156, w: 14, h: 1, opacity: 0.05, rotate: "-28deg" },
  { id: "f5", x: 92, y: -148, w: 16, h: 1, opacity: 0.045, rotate: "-12deg" },
  { id: "f6", x: 138, y: -92, w: 8, h: 8, opacity: 0.04, rotate: "0deg" },
  { id: "f7", x: 166, y: 74, w: 20, h: 1, opacity: 0.05, rotate: "16deg" },
  { id: "f8", x: 112, y: 144, w: 12, h: 1, opacity: 0.04, rotate: "-24deg" },
];
const GHOST_COLOR_KEYWORDS: Array<{ pattern: RegExp; tint: string }> = [
  { pattern: /\b(red|crimson|scarlet|ruby)\b/, tint: "rgba(255,120,120,0.18)" },
  { pattern: /\b(blue|azure|navy|cyan)\b/, tint: "rgba(110,182,255,0.18)" },
  { pattern: /\b(green|emerald|lime|mint)\b/, tint: "rgba(112,226,182,0.18)" },
  { pattern: /\b(gold|yellow|amber|bronze)\b/, tint: "rgba(255,212,122,0.18)" },
  { pattern: /\b(pink|rose|magenta)\b/, tint: "rgba(255,156,214,0.18)" },
  { pattern: /\b(purple|violet|lavender)\b/, tint: "rgba(182,154,255,0.18)" },
  { pattern: /\b(orange|tangerine|peach)\b/, tint: "rgba(255,170,116,0.18)" },
  { pattern: /\b(white|silver|chrome)\b/, tint: "rgba(212,228,255,0.16)" },
  { pattern: /\b(black|charcoal|obsidian)\b/, tint: "rgba(118,136,162,0.14)" },
];
const COMMAND_DOCK_LABELS = ["Send", "Scan", "Pay", "Automate"];

function configureSpatialSpring() {
  LayoutAnimation.configureNext({
    duration: 420,
    create: { type: "spring", property: "opacity", springDamping: 0.82 },
    update: { type: "spring", springDamping: 0.82 },
    delete: { type: "spring", property: "opacity", springDamping: 0.9 },
  });
}

function readPersistedCanvasState(): { taskWindows: TaskWindow[]; focusedTaskId: string } {
  if (typeof globalThis === "undefined" || !("localStorage" in globalThis)) {
    return { taskWindows: [], focusedTaskId: "" };
  }

  try {
    const raw = globalThis.localStorage.getItem(TASK_STORAGE_KEY);
    if (!raw) return { taskWindows: [], focusedTaskId: "" };
    const parsed = JSON.parse(raw) as { taskWindows?: TaskWindow[]; focusedTaskId?: string };
    return {
      taskWindows: Array.isArray(parsed.taskWindows) ? parsed.taskWindows : [],
      focusedTaskId: typeof parsed.focusedTaskId === "string" ? parsed.focusedTaskId : "",
    };
  } catch {
    return { taskWindows: [], focusedTaskId: "" };
  }
}

function persistCanvasState(taskWindows: TaskWindow[], focusedTaskId: string) {
  if (typeof globalThis === "undefined" || !("localStorage" in globalThis)) return;

  try {
    globalThis.localStorage.setItem(TASK_STORAGE_KEY, JSON.stringify({ taskWindows, focusedTaskId }));
  } catch {
    // Ignore persistence failures and keep the canvas interactive.
  }
}

function depthLayerForIndex(index: number): TaskDepthLayer {
  if (index === 0) return "front";
  if (index <= 2) return "mid";
  return "back";
}

function normalizeTaskWindows(
  taskWindows: TaskWindow[],
  focusedTaskId: string,
  preferredFocus: TaskFocusState = "soft"
): TaskWindow[] {
  if (taskWindows.length === 0) return [];

  const sorted = [...taskWindows].sort((a, b) => {
    if (a.id === focusedTaskId) return -1;
    if (b.id === focusedTaskId) return 1;
    return (b.lastFocusedAt || b.createdAt) - (a.lastFocusedAt || a.createdAt);
  });

  return sorted.map((task, index) => {
    const isFocused = task.id === focusedTaskId;
    return {
      ...task,
      focusState: isFocused ? preferredFocus : "none",
      depthLayer: depthLayerForIndex(index),
    };
  });
}

function promoteDepth(layer: TaskDepthLayer): TaskDepthLayer {
  if (layer === "back") return "mid";
  return "front";
}

function demoteDepth(layer: TaskDepthLayer): TaskDepthLayer {
  if (layer === "front") return "mid";
  return "back";
}

function flattenPayload(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object") return {};
  const objectValue = value as Record<string, unknown>;
  const nestedOutput = objectValue.output_payload;
  if (nestedOutput && typeof nestedOutput === "object") {
    return { ...objectValue, ...(nestedOutput as Record<string, unknown>) };
  }
  return objectValue;
}

function getStringCandidate(payload: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = payload[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function summarizePayload(payload: Record<string, unknown>): string {
  const directText = getStringCandidate(payload, [
    "summary",
    "text",
    "message",
    "description",
    "detail",
    "previewText",
    "preview",
    "analysis",
    "raw_subtitle",
  ]);
  if (directText) return directText;

  const entries = Object.entries(payload)
    .filter(([, value]) => typeof value === "string" || typeof value === "number" || typeof value === "boolean")
    .slice(0, 6)
    .map(([key, value]) => `${key}: ${String(value)}`);
  return entries.join("\n");
}

function resolveCenterResult(result: CommandExecutionResult | null): CenterResultState | null {
  if (!result) return null;

  const payload = flattenPayload(result.payload);
  const liveTvPayload = payload.live_tv as { primary_stream_id?: string; streams?: LiveTvStream[] } | undefined;
  const imageUrl = getStringCandidate(payload, ["image_url", "imageUrl", "asset_url", "assetUrl", "preview_url", "previewUrl", "thumbnail_url", "thumbnailUrl"]);
  const videoUrl = getStringCandidate(payload, ["video_url", "videoUrl", "media_url", "mediaUrl"]);
  const pageUrl = getStringCandidate(payload, ["page_url", "pageUrl", "url", "open_url", "openUrl"]);
  const assetId = getStringCandidate(payload, ["asset_id", "assetId", "artifact_id", "artifactId", "id", "tool_job_id"]);
  const thumbnail = getStringCandidate(payload, ["thumbnail_url", "thumbnailUrl", "preview_url", "previewUrl", "image_url", "imageUrl"]);
  const textContent = summarizePayload(payload) || result.subtitle || result.title;
  const hasVisual = Boolean(imageUrl || videoUrl);

  let resultType: CenterResultType = "text";
  if (liveTvPayload?.streams?.length) resultType = "live_tv";
  else if (hasVisual && textContent) resultType = "mixed";
  else if (imageUrl) resultType = "image";
  else if (videoUrl) resultType = "video";
  else if (pageUrl && (result.type === "browser.analyzed" || result.type === "browser.saved" || result.type === "browser.sent")) resultType = "page";
  else if (result.type === "payment.sent" || result.type === "payment.split") resultType = "payment";
  else if (result.type === "workflow.completed") resultType = videoUrl ? "video" : imageUrl ? "image" : "flow";
  else if (!textContent && !imageUrl && !videoUrl) resultType = "fallback";

  return {
    id: result.operation_id || result.trace_id,
    title: result.title,
    subtitle: result.subtitle,
    resultType,
    resultStatus: result.ok ? "ready" : "error",
    assetUrl: imageUrl || videoUrl || pageUrl,
    assetId,
    previewUrl: thumbnail,
    textContent,
    payload,
    cta: result.cta,
  };
}

function extractResultLinks(payload?: Record<string, unknown>): ResultLink[] {
  const links = payload?.lilith_links;
  if (!Array.isArray(links)) return [];
  return links.filter((item): item is ResultLink => Boolean(item && typeof item === "object" && typeof (item as ResultLink).publicUrl === "string"));
}

const DEFAULT_FLOWS: FlowDef[] = [
  {
    id: "chat_tool_send",
    label: "Chat -> Tool -> Send",
    subtitle: "Generate with a tool then send in-thread.",
    screens: ["chat", "home", "messages"],
    steps: [
      { id: "tool", label: "Run summarizer", kind: "command", run: () => "run tool text_summarizer on this" },
      { id: "send", label: "Send in chat", kind: "command", run: (ctx) => `message ${ctx.activeConversationUserId || "last person"} Tool output ready.` },
    ],
  },
  {
    id: "chat_payment",
    label: "Chat -> Payment",
    subtitle: "Prepare payment directly in thread.",
    screens: ["chat", "wallet", "messages"],
    steps: [{ id: "pay", label: "Send payment", kind: "command", run: (ctx) => `send 20 usd to ${ctx.activeConversationUserId || "last person"}` }],
  },
  {
    id: "browser_tool_post",
    label: "Browser -> Tool -> Post",
    subtitle: "Analyze page and publish from canvas.",
    screens: ["browser", "home", "social"],
    steps: [
      { id: "summarize_page", label: "Summarize page", kind: "command", run: () => "summarize this page" },
      { id: "publish", label: "Publish post", kind: "command", run: () => "create a post from this and publish it" },
    ],
  },
  {
    id: "tool_save_vault",
    label: "Tool -> Save -> Vault",
    subtitle: "Securely store generated output.",
    screens: ["tools", "workspace", "vault", "home"],
    steps: [
      { id: "tool", label: "Run summarizer", kind: "command", run: () => "run tool text_summarizer on this" },
      { id: "save_vault", label: "Save to vault", kind: "vault_save", run: () => "" },
    ],
  },
];

function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v));
}

function getVoidTargets(voidState: VoidState) {
  switch (voidState) {
    case "anticipating":
      return { intensity: 0.36, distortion: 0.28, gravity: 0.26 };
    case "engaged":
      return { intensity: 0.62, distortion: 0.54, gravity: 0.46 };
    case "manifesting":
      return { intensity: 0.78, distortion: 0.7, gravity: 0.58 };
    case "settling":
      return { intensity: 0.48, distortion: 0.38, gravity: 0.34 };
    case "recovering":
      return { intensity: 0.18, distortion: 0.14, gravity: 0.12 };
    case "idle":
    default:
      return { intensity: 0.08, distortion: 0.06, gravity: 0.08 };
  }
}

function buildStreamPlayerHtml(streamUrl: string, posterUrl: string, muted: boolean) {
  return `
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
        <style>
          html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            background: #02060c;
            overflow: hidden;
          }
          video {
            width: 100%;
            height: 100%;
            object-fit: cover;
            background: #02060c;
          }
        </style>
      </head>
      <body>
        <video
          src="${streamUrl}"
          poster="${posterUrl}"
          autoplay
          playsinline
          controls
          ${muted ? "muted" : ""}
        ></video>
      </body>
    </html>
  `;
}

function detectPredictiveIntent(commandDraft: string): PredictiveGhost {
  const input = commandDraft.trim().toLowerCase();
  if (!input) {
    return {
      type: "none",
      confidence: 0,
      aspectRatio: 1,
      semanticStructure: "frame",
      lineCount: 0,
      tint: "rgba(142,200,248,0.16)",
      stability: 0,
      motion: 1,
    };
  }

  const score = (patterns: RegExp[]) => patterns.reduce((acc, pattern) => acc + (pattern.test(input) ? 1 : 0), 0);
  const imageScore = score([/\bimage\b/, /\bpicture\b/, /\bphoto\b/, /\bdraw\b/, /\billustration\b/, /\blogo\b/, /\bposter\b/, /\bgenerate\b.+\bimage\b/]);
  const videoScore = score([/\bvideo\b/, /\banimate\b/, /\bmotion\b/, /\breel\b/, /\bclip\b/, /\bgenerate\b.+\bvideo\b/]);
  const paymentScore = score([/\bpay\b/, /\bsend\b.+\b(usd|dollars|\$)\b/, /\btransfer\b/, /\binvoice\b/, /\bpayment\b/]);
  const pageScore = score([/\bpage\b/, /\bsite\b/, /\bwebsite\b/, /\blanding\b/, /\bapp\b/, /\bdashboard\b/]);
  const textScore = score([/\bsummarize\b/, /\bwrite\b/, /\bexplain\b/, /\bplan\b/, /\bemail\b/, /\bmessage\b/, /\bnotes?\b/, /\bbrief\b/]);

  const scored: Array<{ type: PredictiveIntentType; value: number }> = [
    { type: "image" as const, value: imageScore },
    { type: "video" as const, value: videoScore },
    { type: "payment" as const, value: paymentScore },
    { type: "page" as const, value: pageScore },
    { type: "text" as const, value: textScore },
  ].sort((a, b) => b.value - a.value);

  const top = scored[0];
  const next = scored[1];
  if (!top || top.value === 0) {
    return {
      type: "none",
      confidence: 0.18,
      aspectRatio: 1,
      semanticStructure: "frame",
      lineCount: 0,
      tint: "rgba(142,200,248,0.16)",
      stability: 0.12,
      motion: 0.84,
    };
  }

  const mixed = top.value > 0 && next && next.value > 0 && Math.abs(top.value - next.value) <= 1;
  const base = 0.34 + Math.min(0.46, top.value * 0.16) + Math.min(0.1, input.length / 180);
  const confidence = clamp(base, 0, 0.96);
  let aspectRatio = 1;
  if (/\b(portrait|vertical|story)\b/.test(input)) aspectRatio = 0.72;
  else if (/\b(square|avatar|icon)\b/.test(input)) aspectRatio = 1;
  else if (/\b(cinematic|widescreen|wide|landscape|banner)\b/.test(input)) aspectRatio = 1.78;
  else if (/\b(tall|poster)\b/.test(input)) aspectRatio = 0.82;
  else if (top.type === "video") aspectRatio = 1.65;
  else if (top.type === "page") aspectRatio = 0.92;

  const wordCount = input.split(/\s+/).filter(Boolean).length;
  const lineCount = clamp(Math.round(2 + wordCount / 6), 2, 8);
  let semanticStructure: PredictiveGhostStructure =
    top.type === "payment" ? "payment" : top.type === "page" ? "page" : top.type === "video" ? "video" : top.type === "text" ? "lines" : "frame";
  if (/\b(list|bullet|bullets)\b/.test(input)) semanticStructure = "list";
  else if (/\b(steps|step by step|step-by-step|instructions)\b/.test(input)) semanticStructure = "steps";
  else if (/\b(chat|conversation|messages?|dialogue|dm)\b/.test(input)) semanticStructure = "chat";
  else if (/\b(code|function|component|typescript|javascript|swift|python|react)\b/.test(input)) semanticStructure = "code";

  const tint =
    GHOST_COLOR_KEYWORDS.find(({ pattern }) => pattern.test(input))?.tint ||
    (top.type === "payment"
      ? "rgba(154,224,188,0.16)"
      : top.type === "video"
        ? "rgba(132,196,255,0.16)"
        : "rgba(142,200,248,0.16)");
  const stability = clamp(0.18 + confidence * 0.82, 0.16, 0.96);
  const motion = clamp(1.06 - confidence * 0.4, 0.56, 1.02);

  return {
    type: mixed ? "mixed" : top.type,
    confidence,
    aspectRatio,
    semanticStructure,
    lineCount,
    tint,
    stability,
    motion,
  };
}

export function CanvasModeLayer({
  title,
  subtitle,
  leftActions,
  rightActions,
  bottomActions,
  suggestions,
  recentActionCount,
  activeScreen,
  activeConversationUserId,
  activeBrowserUrl,
  activeSelectedContent,
  commandDraft,
  commandInputFocused,
  vaultLocked,
  commandActive,
  pendingResult,
  latestResult,
  onOrbTap,
  onRunCommand,
  onSaveToVault,
  children,
}: CanvasModeLayerProps) {
  const persistedCanvasState = readPersistedCanvasState();
  const [toolsVisible, setToolsVisible] = useState(false);
  const [showTaskStack, setShowTaskStack] = useState(false);
  const [showOverlays, setShowOverlays] = useState(true);
  const [showHints, setShowHints] = useState(true);
  const [showSuggestions, setShowSuggestions] = useState(true);
  const [showPanels, setShowPanels] = useState(true);
  const [activeFlowId, setActiveFlowId] = useState("");
  const [flowSteps, setFlowSteps] = useState<FlowStepState[]>([]);
  const [flowStatus, setFlowStatus] = useState<"idle" | "running" | "success" | "error">("idle");
  const [flowOutput, setFlowOutput] = useState("Ask Lilith for a result. Tasks run calmly in the background.");
  const [taskWindows, setTaskWindows] = useState<TaskWindow[]>(
    normalizeTaskWindows(persistedCanvasState.taskWindows, persistedCanvasState.focusedTaskId, "hard")
  );
  const [focusedTaskId, setFocusedTaskId] = useState(persistedCanvasState.focusedTaskId);
  const [gestureHint, setGestureHint] = useState("Tap to soft focus · Double tap or pinch out to bring forward · Swipe up for stack");
  const [activeCenterResult, setActiveCenterResult] = useState<CenterResultState | null>(null);
  const [resultStatus, setResultStatus] = useState<"idle" | "working" | "ready" | "error">("idle");
  const [voidState, setVoidState] = useState<VoidState>("idle");
  const [voidGravityLevel, setVoidGravityLevel] = useState(getVoidTargets("idle").gravity);
  const [predictiveGhost, setPredictiveGhost] = useState<PredictiveGhost>(detectPredictiveIntent(""));
  const [activeDockIndex, setActiveDockIndex] = useState<number | null>(null);

  const stackAnim = useRef(new Animated.Value(0)).current;
  const switchAnim = useRef(new Animated.Value(1)).current;
  const dragX = useRef(new Animated.Value(0)).current;
  const dragY = useRef(new Animated.Value(0)).current;
  const ambientPulse = useRef(new Animated.Value(0)).current;
  const orbBreath = useRef(new Animated.Value(0)).current;
  const orbNudgeX = useRef(new Animated.Value(0)).current;
  const orbNudgeY = useRef(new Animated.Value(0)).current;
  const orbAttention = useRef(new Animated.Value(0)).current;
  const orbThinking = useRef(new Animated.Value(0)).current;
  const orbExecution = useRef(new Animated.Value(0)).current;
  const orbResult = useRef(new Animated.Value(0)).current;
  const orbError = useRef(new Animated.Value(0)).current;
  const orbShimmer = useRef(new Animated.Value(0)).current;
  const intentPressure = useRef(new Animated.Value(0)).current;
  const anticipationRipple = useRef(new Animated.Value(0)).current;
  const voidRecovery = useRef(new Animated.Value(1)).current;
  const manifestationWake = useRef(new Animated.Value(0)).current;
  const settleDrift = useRef(new Animated.Value(0)).current;
  const voidIntensity = useRef(new Animated.Value(getVoidTargets("idle").intensity)).current;
  const voidDistortion = useRef(new Animated.Value(getVoidTargets("idle").distortion)).current;
  const voidGravity = useRef(new Animated.Value(getVoidTargets("idle").gravity)).current;
  const dragWake = useRef(new Animated.Value(0)).current;
  const ghostOpacity = useRef(new Animated.Value(0)).current;
  const ghostClarity = useRef(new Animated.Value(0)).current;
  const ghostMomentum = useRef(new Animated.Value(0)).current;
  const ghostAlignment = useRef(new Animated.Value(0)).current;
  const haloRotate = useRef(new Animated.Value(0)).current;
  const fluidRotateA = useRef(new Animated.Value(0)).current;
  const fluidRotateB = useRef(new Animated.Value(0)).current;
  const ghostAnim = useRef(new Animated.Value(0)).current;
  const idleReveal = useRef(new Animated.Value(1)).current;
  const hintsAnim = useRef(new Animated.Value(1)).current;
  const suggestionsAnim = useRef(new Animated.Value(1)).current;
  const panelsAnim = useRef(new Animated.Value(1)).current;
  const dockPulse = useRef(new Animated.Value(0)).current;
  const dismissTimersRef = useRef<{
    hints?: ReturnType<typeof setTimeout>;
    suggestions?: ReturnType<typeof setTimeout>;
    panels?: ReturnType<typeof setTimeout>;
  }>({});
  const resultTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const attentionTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const shimmerTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const settleTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const recoveryTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const prevFlowStatusRef = useRef(flowStatus);
  const predictiveGhostRef = useRef<PredictiveGhost>(detectPredictiveIntent(""));
  const lastTapRef = useRef<{ taskId: string; at: number }>({ taskId: "", at: 0 });
  const activePinchTaskRef = useRef<{ taskId: string; baselineScale: number } | null>(null);

  const visibleFlows = useMemo(() => DEFAULT_FLOWS.filter((flow) => flow.screens.includes(activeScreen)), [activeScreen]);

  const focusedTaskIndex = useMemo(() => taskWindows.findIndex((w) => w.id === focusedTaskId), [taskWindows, focusedTaskId]);
  const focusedTask = focusedTaskIndex >= 0 ? taskWindows[focusedTaskIndex] : null;
  const spatialWindows = useMemo<SpatialTaskViewModel[]>(
    () =>
      taskWindows.map((task, index) => {
        const side = index === 0 ? 0 : index % 2 === 0 ? 1 : -1;
        const ring = index === 0 ? 0 : Math.ceil(index / 2);
        const focusPull = task.focusState === "hard" ? 1 : task.focusState === "soft" ? 0.55 : 0;
        const gravityPull = focusedTaskId && task.id !== focusedTaskId ? Math.max(0, voidGravityLevel - index * 0.04) : 0;
        const layerBaseScale = task.depthLayer === "front" ? 1 : task.depthLayer === "mid" ? 0.9 : 0.8;
        const layerOpacity = task.depthLayer === "front" ? 0.97 : task.depthLayer === "mid" ? 0.82 : 0.62;
        const arcX = index === 0 ? 0 : side * (54 + ring * 66);
        const arcY = index === 0 ? 72 - focusPull * 52 : 74 + ring * 26 - focusPull * 12;
        const width = task.depthLayer === "front" ? 316 : task.depthLayer === "mid" ? 272 : 236;
        const minHeight = task.depthLayer === "front" ? 178 : task.depthLayer === "mid" ? 150 : 128;

        return {
          task,
          index,
          anchorX: arcX * (1 - gravityPull) + task.x * (task.depthLayer === "back" ? 0.74 : 1),
          anchorY: arcY - gravityPull * 18 + task.y + (task.depthLayer === "back" ? 18 : 0),
          scale: layerBaseScale * task.scale * (task.focusState === "hard" ? 1.14 : task.focusState === "soft" ? 1.05 : 1),
          opacity: layerOpacity + gravityPull * 0.04,
          width,
          minHeight,
          zIndex: 40 - index,
          shadowOpacity: task.depthLayer === "front" ? 0.42 : task.depthLayer === "mid" ? 0.28 : 0.16,
          shadowRadius: task.depthLayer === "front" ? 28 : task.depthLayer === "mid" ? 20 : 12,
          borderOpacity: task.focusState === "hard" ? 0.48 : task.focusState === "soft" ? 0.32 : 0.16,
          glowOpacity: task.focusState === "hard" ? 0.24 : task.focusState === "soft" ? 0.14 : 0.06,
          dimOpacity: task.focusState === "hard" ? 0 : task.focusState === "soft" ? 0.04 : task.depthLayer === "back" ? 0.22 : 0.12,
          verticalLift: task.focusState === "hard" ? -24 : task.focusState === "soft" ? -10 : 0,
        };
      }),
    [taskWindows, focusedTaskId, voidGravityLevel]
  );
  const isIdleState = useMemo(
    () => flowStatus === "idle" && taskWindows.length === 0 && !showTaskStack,
    [flowStatus, showTaskStack, taskWindows.length]
  );
  const currentPredictiveIntent = useMemo(() => detectPredictiveIntent(commandDraft), [commandDraft]);

  const transitionVoidState = useCallback(
    (nextState: VoidState, options?: { delay?: number }) => {
      const { intensity, distortion, gravity } = getVoidTargets(nextState);
      const delay = options?.delay || 0;
      setVoidState(nextState);
      setVoidGravityLevel(gravity);
      Animated.parallel([
        Animated.timing(voidIntensity, {
          toValue: intensity,
          duration: nextState === "recovering" || nextState === "idle" ? 1800 : 260,
          delay,
          useNativeDriver: true,
        }),
        Animated.timing(voidDistortion, {
          toValue: distortion,
          duration: nextState === "recovering" || nextState === "idle" ? 1600 : 240,
          delay,
          useNativeDriver: true,
        }),
        Animated.timing(voidGravity, {
          toValue: gravity,
          duration: nextState === "recovering" || nextState === "idle" ? 1900 : 280,
          delay,
          useNativeDriver: true,
        }),
      ]).start();
    },
    [voidDistortion, voidGravity, voidIntensity]
  );

  const clearDismissTimers = useCallback(() => {
    if (dismissTimersRef.current.hints) clearTimeout(dismissTimersRef.current.hints);
    if (dismissTimersRef.current.suggestions) clearTimeout(dismissTimersRef.current.suggestions);
    if (dismissTimersRef.current.panels) clearTimeout(dismissTimersRef.current.panels);
    dismissTimersRef.current = {};
  }, []);

  const syncLiveAudio = useCallback((primaryStreamId: string) => {
    setTaskWindows((prev) =>
      prev.map((task) =>
        task.contentKind === "live_stream"
          ? {
              ...task,
              muted: task.streamId !== primaryStreamId,
            }
          : task
      )
    );
  }, []);

  const animateCalmLayer = useCallback((value: Animated.Value, visible: boolean, delay = 0) => {
    Animated.timing(value, {
      toValue: visible ? 1 : 0,
      duration: visible ? 150 : 220,
      delay,
      useNativeDriver: true,
    }).start();
  }, []);

  const scheduleAutoDismiss = useCallback(() => {
    clearDismissTimers();
    dismissTimersRef.current.hints = setTimeout(() => {
      setShowHints(false);
      animateCalmLayer(hintsAnim, false);
    }, 2000);
    dismissTimersRef.current.suggestions = setTimeout(() => {
      setShowSuggestions(false);
      animateCalmLayer(suggestionsAnim, false);
    }, 3000);
    dismissTimersRef.current.panels = setTimeout(() => {
      if (flowStatus === "running") {
        scheduleAutoDismiss();
        return;
      }
      setShowPanels(false);
      setShowOverlays(false);
      setShowTaskStack(false);
      animateCalmLayer(panelsAnim, false);
      Animated.timing(stackAnim, { toValue: 0, duration: 140, useNativeDriver: true }).start();
    }, 4500);
  }, [animateCalmLayer, clearDismissTimers, flowStatus, hintsAnim, panelsAnim, stackAnim, suggestionsAnim]);

  const registerInteraction = useCallback(() => {
    if (!showHints) setShowHints(true);
    if (!showSuggestions) setShowSuggestions(true);
    if (!showPanels) {
      setShowPanels(true);
      setShowOverlays(true);
    }
    if (!showOverlays) setShowOverlays(true);
    animateCalmLayer(hintsAnim, true);
    animateCalmLayer(suggestionsAnim, true, 10);
    animateCalmLayer(panelsAnim, true, 20);
    scheduleAutoDismiss();
  }, [animateCalmLayer, hintsAnim, panelsAnim, scheduleAutoDismiss, showHints, showPanels, showSuggestions, suggestionsAnim]);

  React.useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(ambientPulse, { toValue: 1, duration: 2200, useNativeDriver: true }),
        Animated.timing(ambientPulse, { toValue: 0, duration: 2200, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [ambientPulse]);

  React.useEffect(() => {
    Animated.timing(orbThinking, {
      toValue: commandActive ? 1 : 0,
      duration: commandActive ? 220 : 340,
      useNativeDriver: true,
    }).start();
  }, [commandActive, orbThinking]);

  React.useEffect(() => {
    if (commandActive && !pendingResult) {
      transitionVoidState("anticipating");
      return;
    }
    if (!commandActive && !pendingResult && !activeCenterResult && flowStatus === "idle") {
      transitionVoidState("idle", { delay: 220 });
    }
  }, [activeCenterResult, commandActive, flowStatus, pendingResult, transitionVoidState]);

  React.useEffect(() => {
    const nextGhost = currentPredictiveIntent;
    const previous = predictiveGhostRef.current;
    const shouldShow = commandInputFocused || (nextGhost.type !== "none" && nextGhost.confidence > 0.3);
    const hasChanged =
      previous.type !== nextGhost.type || Math.abs(previous.confidence - nextGhost.confidence) > 0.08;

    if (!shouldShow) {
      Animated.parallel([
        Animated.timing(ghostOpacity, { toValue: pendingResult ? 0.08 : 0, duration: 220, useNativeDriver: true }),
        Animated.timing(ghostClarity, { toValue: 0, duration: 220, useNativeDriver: true }),
        Animated.timing(ghostAlignment, { toValue: 0, duration: 220, useNativeDriver: true }),
      ]).start(() => {
        if (!pendingResult) {
          const emptyGhost = detectPredictiveIntent("");
          predictiveGhostRef.current = emptyGhost;
          setPredictiveGhost(emptyGhost);
        }
      });
      return;
    }

    const targetOpacity = clamp(0.03 + nextGhost.confidence * 0.24 + (commandInputFocused ? 0.03 : 0), 0.05, 0.27);
    const targetClarity = clamp((nextGhost.confidence - 0.28) * 1.06, 0.02, 0.54);
    const targetAlignment = pendingResult ? 0.92 : clamp(nextGhost.confidence + (commandInputFocused ? 0.08 : 0.02), 0.08, 0.82);

    if (hasChanged && previous.type !== "none") {
      Animated.sequence([
        Animated.spring(ghostMomentum, {
          toValue: 1,
          damping: 12,
          stiffness: 130,
          mass: 0.8,
          useNativeDriver: true,
        }),
        Animated.spring(ghostMomentum, {
          toValue: 0,
          damping: 14,
          stiffness: 120,
          mass: 0.9,
          useNativeDriver: true,
        }),
      ]).start();
      Animated.parallel([
        Animated.timing(ghostOpacity, { toValue: 0.04, duration: 180, useNativeDriver: true }),
        Animated.timing(ghostClarity, { toValue: 0.02, duration: 180, useNativeDriver: true }),
        Animated.timing(ghostAlignment, { toValue: 0.08, duration: 180, useNativeDriver: true }),
      ]).start(() => {
        predictiveGhostRef.current = nextGhost;
        setPredictiveGhost(nextGhost);
        Animated.parallel([
          Animated.timing(ghostOpacity, { toValue: targetOpacity, duration: 260, useNativeDriver: true }),
          Animated.spring(ghostClarity, {
            toValue: targetClarity,
            damping: 16,
            stiffness: 120,
            mass: 0.9,
            useNativeDriver: true,
          }),
          Animated.spring(ghostAlignment, {
            toValue: targetAlignment,
            damping: 18,
            stiffness: 118,
            mass: 0.92,
            useNativeDriver: true,
          }),
        ]).start();
      });
      return;
    }

    predictiveGhostRef.current = nextGhost;
    setPredictiveGhost(nextGhost);
    Animated.parallel([
      Animated.timing(ghostOpacity, { toValue: targetOpacity, duration: 180, useNativeDriver: true }),
      Animated.spring(ghostClarity, {
        toValue: targetClarity,
        damping: 18,
        stiffness: 124,
        mass: 0.94,
        useNativeDriver: true,
      }),
      Animated.spring(ghostAlignment, {
        toValue: targetAlignment,
        damping: 18,
        stiffness: 118,
        mass: 0.92,
        useNativeDriver: true,
      }),
    ]).start();
  }, [commandInputFocused, currentPredictiveIntent, ghostAlignment, ghostClarity, ghostMomentum, ghostOpacity, pendingResult]);

  React.useEffect(() => {
    if (commandInputFocused && !commandDraft.trim() && !pendingResult) {
      transitionVoidState("anticipating");
    }
  }, [commandDraft, commandInputFocused, pendingResult, transitionVoidState]);

  React.useEffect(() => {
    Animated.timing(intentPressure, {
      toValue: commandInputFocused || commandActive || pendingResult ? 1 : 0,
      duration: commandInputFocused || commandActive || pendingResult ? 180 : 1800,
      useNativeDriver: true,
    }).start();
  }, [commandActive, commandInputFocused, intentPressure, pendingResult]);

  React.useEffect(() => {
    Animated.timing(orbExecution, {
      toValue: flowStatus === "running" ? 1 : 0,
      duration: flowStatus === "running" ? 180 : 260,
      useNativeDriver: true,
    }).start();
  }, [flowStatus, orbExecution]);

  React.useEffect(() => {
    Animated.timing(orbError, {
      toValue: flowStatus === "error" ? 1 : 0,
      duration: flowStatus === "error" ? 180 : 420,
      useNativeDriver: true,
    }).start();
  }, [flowStatus, orbError]);

  React.useEffect(() => {
    const halo = Animated.loop(
      Animated.timing(haloRotate, { toValue: 1, duration: 18000, useNativeDriver: true })
    );
    const fluidA = Animated.loop(
      Animated.timing(fluidRotateA, { toValue: 1, duration: 12000, useNativeDriver: true })
    );
    const fluidB = Animated.loop(
      Animated.timing(fluidRotateB, { toValue: 1, duration: 16000, useNativeDriver: true })
    );
    halo.start();
    fluidA.start();
    fluidB.start();
    return () => {
      halo.stop();
      fluidA.stop();
      fluidB.stop();
    };
  }, [fluidRotateA, fluidRotateB, haloRotate]);

  React.useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(orbBreath, { toValue: 1, duration: commandActive ? 1800 : 4200, useNativeDriver: true }),
        Animated.timing(orbBreath, { toValue: 0, duration: commandActive ? 1600 : 3800, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [commandActive, orbBreath]);

  React.useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(ghostAnim, { toValue: 1, duration: 3600, useNativeDriver: true }),
        Animated.timing(ghostAnim, { toValue: 0, duration: 1800, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [ghostAnim]);

  React.useEffect(() => {
    Animated.timing(idleReveal, {
      toValue: isIdleState ? 1 : 0,
      duration: isIdleState ? 280 : 170,
      useNativeDriver: true,
    }).start();
  }, [idleReveal, isIdleState]);

  React.useEffect(() => {
    scheduleAutoDismiss();
    return () => {
      clearDismissTimers();
      if (resultTimeoutRef.current) clearTimeout(resultTimeoutRef.current);
      if (attentionTimeoutRef.current) clearTimeout(attentionTimeoutRef.current);
      if (shimmerTimerRef.current) clearTimeout(shimmerTimerRef.current);
      if (settleTimeoutRef.current) clearTimeout(settleTimeoutRef.current);
      if (recoveryTimeoutRef.current) clearTimeout(recoveryTimeoutRef.current);
    };
  }, [clearDismissTimers, scheduleAutoDismiss]);

  React.useEffect(() => {
    persistCanvasState(taskWindows, focusedTaskId);
  }, [focusedTaskId, taskWindows]);

  React.useEffect(() => {
    if (taskWindows.length === 0 || taskWindows.some((task) => task.id === focusedTaskId)) return;
    const fallbackId = taskWindows[0].id;
    setFocusedTaskId(fallbackId);
    setTaskWindows((prev) => normalizeTaskWindows(prev, fallbackId, "soft"));
  }, [focusedTaskId, taskWindows]);

  React.useEffect(() => {
    if (!pendingResult) return;
    transitionVoidState("anticipating");
    Animated.sequence([
      Animated.timing(anticipationRipple, { toValue: 1, duration: 120, useNativeDriver: true }),
      Animated.timing(anticipationRipple, { toValue: 0, duration: 360, useNativeDriver: true }),
    ]).start();
    setResultStatus("working");
    setActiveCenterResult((prev) => ({
      id: pendingResult.operation_id || pendingResult.trace_id,
      title: pendingResult.title,
      subtitle: pendingResult.subtitle,
      resultType: prev?.resultType || "text",
      resultStatus: "working",
      assetUrl: prev?.assetUrl,
      assetId: prev?.assetId,
      previewUrl: prev?.previewUrl,
      textContent: prev?.textContent,
      payload: prev?.payload,
      cta: prev?.cta,
    }));
    Animated.parallel([
      Animated.timing(ghostOpacity, { toValue: Math.max(0.16, predictiveGhostRef.current.confidence * 0.26), duration: 180, useNativeDriver: true }),
      Animated.timing(ghostClarity, { toValue: 0.5, duration: 220, useNativeDriver: true }),
      Animated.timing(ghostAlignment, { toValue: 0.94, duration: 220, useNativeDriver: true }),
    ]).start();
  }, [pendingResult, transitionVoidState]);


  React.useEffect(() => {
    const cycleShimmer = () => {
      const wait = 8000 + Math.floor(Math.random() * 7000);
      shimmerTimerRef.current = setTimeout(() => {
        Animated.sequence([
          Animated.timing(orbShimmer, { toValue: 1, duration: 280, useNativeDriver: true }),
          Animated.timing(orbShimmer, { toValue: 0, duration: 1200, useNativeDriver: true }),
        ]).start(() => cycleShimmer());
      }, wait);
    };
    cycleShimmer();
    return () => {
      if (shimmerTimerRef.current) clearTimeout(shimmerTimerRef.current);
    };
  }, [orbShimmer]);

  React.useEffect(() => {
    if (prevFlowStatusRef.current !== "success" && flowStatus === "success") {
      transitionVoidState("manifesting");
      Animated.sequence([
        Animated.timing(orbResult, { toValue: 1, duration: 220, useNativeDriver: true }),
        Animated.timing(orbResult, { toValue: 0, duration: 950, useNativeDriver: true }),
      ]).start();
      Animated.sequence([
        Animated.timing(manifestationWake, { toValue: 1, duration: 180, useNativeDriver: true }),
        Animated.timing(manifestationWake, { toValue: 0, duration: 1800, useNativeDriver: true }),
      ]).start();
      Animated.sequence([
        Animated.timing(settleDrift, { toValue: 1, duration: 260, useNativeDriver: true }),
        Animated.timing(settleDrift, { toValue: 0, duration: 1400, useNativeDriver: true }),
      ]).start();
      if (resultTimeoutRef.current) clearTimeout(resultTimeoutRef.current);
      resultTimeoutRef.current = setTimeout(() => {
        resultTimeoutRef.current = null;
      }, 1200);
      if (settleTimeoutRef.current) clearTimeout(settleTimeoutRef.current);
      settleTimeoutRef.current = setTimeout(() => {
        transitionVoidState("settling");
        settleTimeoutRef.current = null;
      }, 260);
    }
    prevFlowStatusRef.current = flowStatus;
  }, [flowStatus, manifestationWake, orbResult, settleDrift, transitionVoidState]);

  React.useEffect(() => {
    Animated.timing(voidRecovery, {
      toValue: activeCenterResult || commandActive || pendingResult ? 0.22 : 1,
      duration: activeCenterResult || commandActive || pendingResult ? 220 : 2600,
      useNativeDriver: true,
    }).start();
  }, [activeCenterResult, commandActive, pendingResult, voidRecovery]);

  const reactOrbTouch = useCallback(() => {
    const nextX = (Math.random() - 0.5) * 10;
    const nextY = (Math.random() - 0.5) * 10;
    Animated.sequence([
      Animated.parallel([
        Animated.spring(orbNudgeX, { toValue: nextX, damping: 12, stiffness: 120, useNativeDriver: true }),
        Animated.spring(orbNudgeY, { toValue: nextY, damping: 12, stiffness: 120, useNativeDriver: true }),
      ]),
      Animated.parallel([
        Animated.spring(orbNudgeX, { toValue: 0, damping: 12, stiffness: 120, useNativeDriver: true }),
        Animated.spring(orbNudgeY, { toValue: 0, damping: 12, stiffness: 120, useNativeDriver: true }),
      ]),
    ]).start();
    Animated.timing(orbAttention, { toValue: 1, duration: 130, useNativeDriver: true }).start();
    if (attentionTimeoutRef.current) clearTimeout(attentionTimeoutRef.current);
    attentionTimeoutRef.current = setTimeout(() => {
      Animated.timing(orbAttention, { toValue: 0, duration: 420, useNativeDriver: true }).start();
      attentionTimeoutRef.current = null;
    }, 420);
  }, [orbAttention, orbNudgeX, orbNudgeY]);

  const executeFromOrb = useCallback(
    async (command: string) => {
      transitionVoidState("engaged");
      Animated.sequence([
        Animated.timing(orbExecution, { toValue: 1, duration: 130, useNativeDriver: true }),
        Animated.timing(orbExecution, { toValue: 0, duration: 180, useNativeDriver: true }),
      ]).start();
      const result = await onRunCommand(command);
      if (result?.ok) {
        Animated.sequence([
          Animated.timing(orbResult, { toValue: 1, duration: 190, useNativeDriver: true }),
          Animated.timing(orbResult, { toValue: 0, duration: 900, useNativeDriver: true }),
        ]).start();
      }
      return result;
    },
    [onRunCommand, orbExecution, orbResult, transitionVoidState]
  );

  const cycleTask = (direction: 1 | -1) => {
    if (taskWindows.length <= 1) return;
    const currentIndex = focusedTaskIndex >= 0 ? focusedTaskIndex : 0;
    const nextIndex = (currentIndex + direction + taskWindows.length) % taskWindows.length;
    const nextTask = taskWindows[nextIndex];
    configureSpatialSpring();
    setFocusedTaskId(nextTask.id);
    setTaskWindows((prev) => normalizeTaskWindows(prev, nextTask.id, "soft"));
    Animated.sequence([
      Animated.timing(switchAnim, { toValue: 0.92, duration: 110, useNativeDriver: true }),
      Animated.spring(switchAnim, { toValue: 1, damping: 11, stiffness: 140, useNativeDriver: true }),
    ]).start();
  };

  const updateTask = (taskId: string, patch: Partial<TaskWindow>) => {
    setTaskWindows((prev) => prev.map((task) => (task.id === taskId ? { ...task, ...patch } : task)));
  };

  const focusTask = useCallback(
    (taskId: string, focusState: TaskFocusState) => {
      registerInteraction();
      configureSpatialSpring();
      const now = Date.now();
      const targetTask = taskWindows.find((task) => task.id === taskId);
      setFocusedTaskId(taskId);
      setTaskWindows((prev) =>
        normalizeTaskWindows(
          prev.map((task) => (task.id === taskId ? { ...task, controlsVisible: focusState === "hard", lastFocusedAt: now } : task)),
          taskId,
          focusState
        )
      );
      if (targetTask?.contentKind === "live_stream" && targetTask.streamId && targetTask.mediaUrl) {
        setActiveCenterResult({
          id: targetTask.streamId,
          title: targetTask.title,
          subtitle: targetTask.providerName || "Licensed live stream",
          resultType: "live_tv",
          resultStatus: "ready",
          assetUrl: targetTask.mediaUrl,
          previewUrl: targetTask.posterUrl,
          payload: {
            live_tv: {
              primary_stream_id: targetTask.streamId,
              streams: [
                {
                  id: targetTask.streamId,
                  title: targetTask.title,
                  provider_id: "",
                  provider_name: targetTask.providerName || "",
                  stream_url: targetTask.mediaUrl,
                  poster_url: targetTask.posterUrl || "",
                  description: targetTask.subtitle,
                  licensed: true,
                  muted: false,
                },
              ],
            },
          },
        });
        syncLiveAudio(targetTask.streamId);
      }
      setGestureHint(focusState === "hard" ? "Window brought fully forward" : "Window softly emphasized");
      Animated.sequence([
        Animated.timing(switchAnim, { toValue: 0.95, duration: 100, useNativeDriver: true }),
        Animated.spring(switchAnim, { toValue: 1, damping: 10, stiffness: 150, useNativeDriver: true }),
      ]).start();
    },
    [registerInteraction, switchAnim, syncLiveAudio, taskWindows]
  );

  const promoteTask = useCallback(
    (taskId: string, hard = false) => {
      registerInteraction();
      configureSpatialSpring();
      setFocusedTaskId(taskId);
      setTaskWindows((prev) => {
        const next = prev.map((task) =>
          task.id === taskId
            ? {
                ...task,
                scale: clamp(task.scale + 0.08, 0.76, 1.24),
                depthLayer: promoteDepth(task.depthLayer),
                lastFocusedAt: Date.now(),
              }
            : task
        );
        return normalizeTaskWindows(next, taskId, hard ? "hard" : "soft");
      });
      setGestureHint(hard ? "Window promoted into hard focus" : "Window promoted");
    },
    [registerInteraction]
  );

  const sendTaskBack = useCallback(
    (taskId: string, dismiss = false) => {
      registerInteraction();
      configureSpatialSpring();
      if (dismiss) {
        transitionVoidState("recovering");
        closeTask(taskId);
        setGestureHint("Window returned to the void");
        return;
      }

      let nextFocusId = focusedTaskId;
      setTaskWindows((prev) => {
        const next = prev.map((task) =>
          task.id === taskId
            ? {
                ...task,
                scale: clamp(task.scale - 0.06, 0.72, 1.16),
                depthLayer: demoteDepth(task.depthLayer),
                focusState: "none" as const,
                controlsVisible: false,
              }
            : task
        );
        const ordered = normalizeTaskWindows(next, taskId === focusedTaskId ? next.find((task) => task.id !== taskId)?.id || "" : focusedTaskId, "soft");
        nextFocusId = ordered[0]?.id || "";
        return ordered;
      });
      setFocusedTaskId(nextFocusId);
      setGestureHint("Window drifted deeper into the field");
    },
    [focusedTaskId, registerInteraction, transitionVoidState]
  );

  const closeTask = (taskId: string) => {
    configureSpatialSpring();
    const remaining = taskWindows.filter((task) => task.id !== taskId);
    const nextFocusedId = focusedTaskId === taskId ? remaining[0]?.id || "" : focusedTaskId;
    setTaskWindows(normalizeTaskWindows(remaining, nextFocusedId, nextFocusedId ? "soft" : "none"));
    setFocusedTaskId(nextFocusedId);
  };

  const spawnTask = useCallback(
    (
      titleValue: string,
      subtitleValue: string,
      commandHint?: string,
      sourceOperationId?: string,
      extra?: Partial<TaskWindow>
    ) => {
      const id = `task_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      configureSpatialSpring();
      const window: TaskWindow = {
        id,
        title: titleValue,
        subtitle: subtitleValue,
        status: "running",
        x: 0,
        y: 0,
        scale: 1,
        depthLayer: "front",
        focusState: "hard",
        controlsVisible: false,
        commandHint,
        sourceOperationId,
        createdAt: Date.now(),
        lastFocusedAt: Date.now(),
        ...extra,
      };
      setTaskWindows((prev) => normalizeTaskWindows([window, ...prev].slice(0, 6), id, "hard"));
      setFocusedTaskId(id);
      return id;
    },
    []
  );

  React.useEffect(() => {
    if (!latestResult) return;
    const resolved = resolveCenterResult(latestResult);
    if (!resolved) return;
    configureSpatialSpring();
    transitionVoidState("manifesting");
    setResultStatus(latestResult.ok ? "ready" : "error");
    if (!latestResult.ok) return;
    Animated.parallel([
      Animated.timing(ghostOpacity, { toValue: 0.08, duration: 320, useNativeDriver: true }),
      Animated.timing(ghostClarity, { toValue: 0.72, duration: 260, useNativeDriver: true }),
      Animated.timing(ghostAlignment, { toValue: 1, duration: 260, useNativeDriver: true }),
    ]).start();
    const liveTv = (resolved.payload?.live_tv || null) as { command?: string; primary_stream_id?: string; streams?: LiveTvStream[]; channel?: string } | null;
    if (liveTv?.command === "mute_secondaries") {
      const currentPrimary =
        ((activeCenterResult?.payload?.live_tv as { primary_stream_id?: string } | undefined)?.primary_stream_id as string | undefined) ||
        taskWindows.find((task) => task.contentKind === "live_stream" && !task.muted)?.streamId ||
        "";
      if (currentPrimary) syncLiveAudio(currentPrimary);
      return;
    }
    if (liveTv?.command === "swap_main") {
      const liveTasks = taskWindows.filter((task) => task.contentKind === "live_stream");
      if (liveTasks.length === 0) return;
      const requested = liveTv.channel
        ? liveTasks.find((task) => task.title.toLowerCase().includes(liveTv.channel!.toLowerCase()))
        : undefined;
      const currentPrimary =
        ((activeCenterResult?.payload?.live_tv as { primary_stream_id?: string } | undefined)?.primary_stream_id as string | undefined) || "";
      const fallback = liveTasks.find((task) => task.streamId !== currentPrimary) || liveTasks[0];
      const nextPrimary = requested || fallback;
      if (nextPrimary?.streamId) focusTask(nextPrimary.id, "hard");
      return;
    }
    setActiveCenterResult(resolved);
    if (liveTv?.streams?.length) {
      const primaryId = liveTv.primary_stream_id || liveTv.streams[0].id;
      const secondaryStreams = liveTv.streams.filter((stream) => stream.id !== primaryId).slice(0, 3);
      setTaskWindows((prev) => {
        const base = prev.filter((task) => task.contentKind !== "live_stream");
        const created = secondaryStreams.map<TaskWindow>((stream) => ({
          id: `live_${stream.id}_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
          title: stream.title,
          subtitle: stream.description,
          status: "running",
          x: 0,
          y: 0,
          scale: 0.92,
          depthLayer: "mid",
          focusState: "none",
          controlsVisible: false,
          commandHint: "Licensed live secondary stream",
          sourceOperationId: latestResult.operation_id,
          contentKind: "live_stream",
          mediaUrl: stream.stream_url,
          posterUrl: stream.poster_url,
          providerName: stream.provider_name,
          streamId: stream.id,
          muted: true,
          createdAt: Date.now(),
          lastFocusedAt: Date.now(),
        }));
        return normalizeTaskWindows([...base, ...created].slice(0, 6), focusedTaskId, "soft");
      });
      syncLiveAudio(primaryId);
      return;
    }
    const matchingTask = taskWindows.find((task) => task.sourceOperationId === latestResult.operation_id);
    if (!matchingTask) {
      const id = spawnTask(
        resolved.title,
        resolved.subtitle || resolved.textContent || "Manifested in the center field.",
        resolved.assetUrl || resolved.assetId,
        latestResult.operation_id
      );
      focusTask(id, resolved.resultType === "image" || resolved.resultType === "video" ? "hard" : "soft");
    }
  }, [activeCenterResult, focusTask, focusedTaskId, ghostClarity, ghostOpacity, latestResult, syncLiveAudio, taskWindows, transitionVoidState]);

  const canvasGestureResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 30 || Math.abs(g.dy) > 30,
        onPanResponderRelease: (_, g) => {
          registerInteraction();
          if (g.dx > 80) {
            cycleTask(-1);
            setGestureHint("Switched to previous task");
            return;
          }
          if (g.dx < -80) {
            cycleTask(1);
            setGestureHint("Switched to next task");
            return;
          }
          if (g.dy < -80) {
            setShowTaskStack(true);
            Animated.spring(stackAnim, { toValue: 1, damping: 12, stiffness: 120, useNativeDriver: true }).start();
            setGestureHint("Task stack opened");
            return;
          }
          if (g.dy > 80) {
            setShowTaskStack(false);
            setShowOverlays(false);
            setToolsVisible(false);
            setTaskWindows((prev) => prev.map((task) => ({ ...task, controlsVisible: false })));
            Animated.timing(stackAnim, { toValue: 0, duration: 140, useNativeDriver: true }).start();
            setGestureHint("Overlays cleared");
            return;
          }
        },
      }),
    [focusedTaskIndex, registerInteraction, stackAnim, taskWindows]
  );

  const taskWindowResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 8 || Math.abs(g.dy) > 8,
        onPanResponderMove: (_, g) => {
          registerInteraction();
          if (!focusedTask) return;
          Animated.timing(dragWake, { toValue: 1, duration: 80, useNativeDriver: true }).start();
          if (g.numberActiveTouches >= 2) {
            if (!activePinchTaskRef.current || activePinchTaskRef.current.taskId !== focusedTask.id) {
              activePinchTaskRef.current = { taskId: focusedTask.id, baselineScale: focusedTask.scale };
            }
            const sizeDelta = -g.dy / 280;
            updateTask(focusedTask.id, {
              scale: clamp(activePinchTaskRef.current.baselineScale + sizeDelta, 0.72, 1.24),
            });
            return;
          }
          dragX.setValue(g.dx);
          dragY.setValue(g.dy);
          updateTask(focusedTask.id, {
            x: clamp(
              (focusedTask.x || 0) +
                g.dx * 0.015 * clamp(1 - Math.max(0, Math.abs(focusedTask.x || 0) - 72) / 156, 0.46, 1),
              -140,
              140
            ),
            y: clamp((focusedTask.y || 0) + g.dy * 0.015, -140, 140),
          });
        },
        onPanResponderRelease: (_, g) => {
          registerInteraction();
          if (!focusedTask) return;
          if (activePinchTaskRef.current?.taskId === focusedTask.id) {
            if (g.dy < -42) promoteTask(focusedTask.id, true);
            if (g.dy > 42) sendTaskBack(focusedTask.id, false);
            activePinchTaskRef.current = null;
          }
          if (Math.abs(g.dx) > 200 || Math.abs(g.vx) > 1.4) {
            sendTaskBack(focusedTask.id, true);
            return;
          }
          if (Math.abs(g.dx) > 110) {
            sendTaskBack(focusedTask.id, false);
            return;
          }
          Animated.parallel([
            Animated.spring(dragX, { toValue: 0, damping: 12, stiffness: 130, useNativeDriver: true }),
            Animated.spring(dragY, { toValue: 0, damping: 12, stiffness: 130, useNativeDriver: true }),
            Animated.timing(dragWake, { toValue: 0, duration: 520, useNativeDriver: true }),
          ]).start();
        },
      }),
    [dragWake, focusedTask, promoteTask, registerInteraction, sendTaskBack]
  );

  const runFlow = async (flow: FlowDef) => {
    registerInteraction();
    const ctx = { activeConversationUserId, activeBrowserUrl, activeSelectedContent };
    setActiveFlowId(flow.id);
    setFlowStatus("running");
    setFlowOutput(`Running ${flow.label}...`);
    setShowOverlays(true);

    const taskId = spawnTask(flow.label, flow.subtitle, flow.steps[0]?.kind === "command" ? flow.steps[0].run(ctx) : undefined, flow.id);
    const initial = flow.steps.map((s) => ({ id: s.id, label: s.label, status: "pending" as const }));
    setFlowSteps(initial);

    for (let i = 0; i < flow.steps.length; i += 1) {
      const step = flow.steps[i];
      setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "running", detail: "In progress..." } : s)));

      try {
        if (step.kind === "command") {
          const cmd = step.run(ctx);
          updateTask(taskId, { commandHint: cmd });
          if (isIdleState) {
            Animated.timing(idleReveal, { toValue: 0, duration: 180, useNativeDriver: true }).start();
          }
          const res = await executeFromOrb(cmd);
          if (!res || !res.ok) {
            const detail = res?.subtitle || "Command failed.";
            setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "error", detail } : s)));
            setFlowStatus("error");
            setFlowOutput(detail);
            updateTask(taskId, { status: "error", subtitle: detail });
            return;
          }
          setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "success", detail: res.subtitle } : s)));
          setFlowOutput(res.subtitle || `${step.label} complete.`);
          updateTask(taskId, { subtitle: res.subtitle || `${step.label} complete.` });
          continue;
        }

        if (vaultLocked) {
          const detail = "Vault is locked. Unlock before secure save.";
          setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "error", detail } : s)));
          setFlowStatus("error");
          setFlowOutput(detail);
          updateTask(taskId, { status: "error", subtitle: detail });
          return;
        }
        const secureContent = activeSelectedContent || flowOutput || "Canvas output";
        const saved = await onSaveToVault({
          title: `Canvas Flow: ${flow.label}`,
          content: secureContent,
        });
        if (!saved.ok) {
          setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "error", detail: saved.detail } : s)));
          setFlowStatus("error");
          setFlowOutput(saved.detail);
          updateTask(taskId, { status: "error", subtitle: saved.detail });
          return;
        }
        setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "success", detail: saved.detail } : s)));
        setFlowOutput(saved.detail);
        updateTask(taskId, { subtitle: saved.detail });
      } catch (error) {
        const detail = String(error);
        setFlowSteps((prev) => prev.map((s, idx) => (idx === i ? { ...s, status: "error", detail } : s)));
        setFlowStatus("error");
        setFlowOutput(detail);
        updateTask(taskId, { status: "error", subtitle: detail });
        return;
      }
    }

    setFlowStatus("success");
    setFlowOutput(`${flow.label} complete. Continue from bottom actions.`);
    updateTask(taskId, { status: "success", subtitle: `${flow.label} complete.` });
  };

  const runResultAction = async (action: "edit" | "save" | "send" | "publish") => {
    registerInteraction();
    if (isIdleState) {
      Animated.timing(idleReveal, { toValue: 0, duration: 180, useNativeDriver: true }).start();
    }
    if (action === "edit") {
      await executeFromOrb("edit this");
      return;
    }
    if (action === "save") {
      if (vaultLocked) {
        setFlowOutput("Vault is locked. Unlock vault before saving sensitive output.");
        return;
      }
      const saved = await onSaveToVault({
        title: `Lilith Result · ${activeFlowId || "canvas_result"}`,
        content: flowOutput || activeSelectedContent || "Canvas result",
      });
      setFlowOutput(saved.detail);
      return;
    }
    if (action === "send") {
      await executeFromOrb(`message ${activeConversationUserId || "last person"} ${flowOutput || "Result ready."}`);
      return;
    }
    await executeFromOrb("create a post from this and publish it");
  };

  const statusTone =
    flowStatus === "success" ? styles.statusSuccess : flowStatus === "error" ? styles.statusError : styles.statusRunning;
  const focusSignal = Animated.add(orbThinking, orbExecution);
  const fieldSignal = Animated.add(intentPressure, orbExecution);
  const depthDim = focusSignal.interpolate({ inputRange: [0, 2], outputRange: [0, 0.15] });
  const secondaryFade = focusSignal.interpolate({ inputRange: [0, 2], outputRange: [1, 0.86] });
  const centerFlash = orbExecution.interpolate({ inputRange: [0, 1], outputRange: [0, 0.42] });
  const resultEmerge = Animated.add(orbResult, orbExecution).interpolate({ inputRange: [0, 2], outputRange: [0, 1] });
  const centerResultVisible = Boolean(activeCenterResult && activeCenterResult.resultStatus !== "idle");
  const shellFade = Animated.multiply(secondaryFade, voidRecovery.interpolate({ inputRange: [0, 1], outputRange: [0.42, 1] }));
  const asymmetryX = haloRotate.interpolate({ inputRange: [0, 1], outputRange: ["-7deg", "11deg"] });
  const asymmetryY = fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: ["9deg", "-13deg"] });
  const ghostVisible = commandInputFocused || predictiveGhost.type !== "none" && (predictiveGhost.confidence > 0.3 || Boolean(pendingResult));
  const partialGhostVisible = predictiveGhost.confidence >= 0.3 && predictiveGhost.confidence < 0.6 && !pendingResult;
  const ghostWidth = clamp(170 * predictiveGhost.aspectRatio, 144, 308);
  const ghostHeight = clamp(ghostWidth / Math.max(predictiveGhost.aspectRatio, 0.64), 132, 224);
  const ghostTintOpacity = clamp(0.07 + predictiveGhost.confidence * 0.1, 0.08, 0.16);
  const ghostJitter = clamp((1 - predictiveGhost.stability) * 7, 1.2, 6.5);
  const particlePullX = clamp((ghostWidth - 210) * 0.08, -12, 12);
  const particlePullY = clamp((ghostHeight - 170) * 0.08, -10, 10);
  const leftRegionPresence = clamp(
    spatialWindows.reduce((max, model) => Math.max(max, clamp((-model.anchorX - 54) / 138, 0, 1)), 0) + (toolsVisible ? 0.2 : 0),
    0,
    1
  );
  const rightRegionPresence = clamp(
    spatialWindows.reduce((max, model) => Math.max(max, clamp((model.anchorX - 54) / 148, 0, 1)), 0) + (showPanels && showOverlays ? 0.16 : 0),
    0,
    1
  );
  const archSections = useMemo(() => {
    const left = [0, 0, 0];
    const right = [0, 0, 0];
    spatialWindows.forEach((model) => {
      const zoneIndex = model.anchorY < 96 ? 0 : model.anchorY < 182 ? 1 : 2;
      if (model.anchorX < -48) {
        left[zoneIndex] = Math.max(left[zoneIndex], clamp((-model.anchorX - 48) / 112, 0, 1));
      }
      if (model.anchorX > 48) {
        right[zoneIndex] = Math.max(right[zoneIndex], clamp((model.anchorX - 48) / 112, 0, 1));
      }
    });
    return { left, right };
  }, [spatialWindows]);
  const openCenterResult = async () => {
    const url = activeCenterResult?.assetUrl || activeCenterResult?.previewUrl || "";
    if (!url) return;
    try {
      await Linking.openURL(url);
    } catch {
      setActiveCenterResult((prev) =>
        prev
          ? {
              ...prev,
              resultType: "fallback",
              resultStatus: "error",
            }
          : prev
      );
      setResultStatus("error");
    }
  };
  const centerLinks = extractResultLinks(activeCenterResult?.payload);
  const primaryCenterLink = centerLinks[0]?.publicUrl || centerLinks[0]?.privateUrl || "";
  const copyCenterLink = async () => {
    if (!primaryCenterLink) return;
    if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(primaryCenterLink);
      } catch {
        // Non-blocking; opening remains available.
      }
    }
  };

  return (
    <View
      style={styles.canvasRoot}
      onTouchStart={() => {
        registerInteraction();
        reactOrbTouch();
      }}
    >
      <View style={styles.bgLayer}>
        <Animated.View
          style={[
            styles.bgHaloPrimary,
            {
              opacity: Animated.add(
                ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.08, 0.16] }),
                voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [0, 0.03] })
              ),
              transform: [
                { scale: voidRecovery.interpolate({ inputRange: [0, 1], outputRange: [1.06, 1] }) },
                { translateX: voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [-6, 4] }) },
                { translateY: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [5, -3] }) },
                { rotate: asymmetryX },
              ],
            },
          ]}
        />
        <Animated.View
          style={[
            styles.bgHaloSecondary,
            {
              opacity: Animated.add(
                ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.06, 0.12] }),
                voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0, 0.025] })
              ),
              transform: [
                { scale: intentPressure.interpolate({ inputRange: [0, 1], outputRange: [1, 0.97] }) },
                { translateX: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [8, -6] }) },
                { translateY: voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [-4, 6] }) },
                { rotate: asymmetryY },
              ],
            },
          ]}
        />
        <Animated.View
          style={[
            styles.bgParticleOne,
            {
              opacity: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.05, 0.12] }),
              transform: [{ translateY: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [8, -8] }) }],
            },
          ]}
        />
        <Animated.View
          style={[
            styles.bgParticleTwo,
            {
              opacity: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.04, 0.1] }),
              transform: [{ translateY: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [-6, 6] }) }],
            },
          ]}
        />
      </View>

      <Animated.View style={[styles.passiveLayer, { opacity: shellFade }]}>
        <Text style={styles.zoneHint}>Canvas · {activeScreen}</Text>
      </Animated.View>

      <View style={styles.activeLayer}>
        {toolsVisible ? (
          <Animated.View
            style={[
              styles.leftZone,
              {
                opacity: shellFade,
                transform: [
                  { translateY: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [4, -4] }) },
                  { translateX: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [-2, 3] }) },
                  { rotate: "-4deg" },
                  { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.992, 1.008] }) },
                ],
              },
            ]}
          >
            <View style={styles.panelHeaderRow}>
              <Text style={styles.panelEyebrow}>CONTROL</Text>
              <Text style={styles.panelMeta}>LIVE</Text>
            </View>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Tools</Text>
              <Text style={styles.panelSectionValue}>{leftActions.slice(0, 3).map((action) => action.label).join(" · ") || "Ready"}</Text>
            </View>
            <Text style={styles.zoneTitle}>Tools</Text>
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scrollCol}>
              {leftActions.slice(0, 6).map((action) => (
                <Pressable key={action.id} style={styles.orbitButton} onPress={action.onPress}>
                  <Text style={styles.orbitButtonText}>{action.label}</Text>
                </Pressable>
              ))}
            </ScrollView>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Commands</Text>
              <Text style={styles.panelSectionValue}>{suggestions.slice(0, 2).map((s) => s.label).join(" · ") || "Ready"}</Text>
            </View>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Processes</Text>
              <Text style={styles.panelSectionValue}>{taskWindows.length} active · {resultStatus}</Text>
            </View>
          </Animated.View>
        ) : null}

        <View style={styles.centerZone} {...canvasGestureResponder.panHandlers}>
          <View style={styles.centerHeader}>
            <View style={{ flex: 1 }}>
              <Text style={styles.centerTitle}>{title}</Text>
              <Text style={styles.centerSubtitle}>{subtitle}</Text>
              {showHints ? (
                <Animated.Text
                  style={[
                    styles.centerHint,
                    {
                      opacity: hintsAnim,
                      transform: [{ translateY: hintsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
                    },
                  ]}
                >
                  {gestureHint}
                </Animated.Text>
              ) : null}
            </View>
            <View style={styles.headerActions}>
              <Pressable
                style={styles.headerAction}
                onPress={() => {
                  registerInteraction();
                  setToolsVisible((v) => !v);
                }}
              >
                <Text style={styles.headerActionText}>{toolsVisible ? "Hide Tools" : "Show Tools"}</Text>
              </Pressable>
            </View>
          </View>

          <Animated.View style={[styles.focusSurface, { transform: [{ scale: switchAnim }] }]}>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.connectorLeft,
                {
                  opacity: Animated.add(
                    orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.06, 0.12] }),
                    orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.06] })
                  ),
                },
              ]}
            >
              <Animated.View
                style={[
                  styles.connectorPulse,
                  {
                    transform: [{ translateX: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [-54, 54] }) }],
                  },
                ]}
              />
            </Animated.View>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.connectorRight,
                {
                  opacity: Animated.add(
                    orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.05, 0.1] }),
                    orbExecution.interpolate({ inputRange: [0, 1], outputRange: [0, 0.06] })
                  ),
                },
              ]}
            >
              <Animated.View
                style={[
                  styles.connectorPulse,
                  {
                    transform: [{ translateX: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [52, -52] }) }],
                  },
                ]}
              />
            </Animated.View>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcLeft,
                {
                  opacity: Animated.add(
                    Animated.add(
                      orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.05] }),
                      intentPressure.interpolate({ inputRange: [0, 1], outputRange: [0, 0.04] })
                    ),
                    voidIntensity.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.18 + leftRegionPresence * 0.04, 0.24 + leftRegionPresence * 0.04],
                    })
                  ),
                  transform: [
                    { translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-10, 6] }) },
                    { translateY: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: [8, -6] }) },
                    { scaleX: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.99, 1.02] }) },
                    { scaleY: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [1.01, 0.98] }) },
                  ],
                },
              ]}
            >
              <LinearGradient
                colors={["rgba(92,146,204,0.16)", "rgba(30,54,82,0.08)", "rgba(4,8,14,0)"]}
                start={{ x: 0.08, y: 0.5 }}
                end={{ x: 1, y: 0.5 }}
                style={StyleSheet.absoluteFill}
              />
            </Animated.View>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcLeftRidge,
                {
                  opacity: Animated.add(
                    orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0.02, 0.08] }),
                    voidIntensity.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.12 + leftRegionPresence * 0.04, 0.18 + leftRegionPresence * 0.04],
                    })
                  ),
                  transform: [
                    { translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-6, 4] }) },
                    { scaleY: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.99, 1.02] }) },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcLeftCore,
                {
                  opacity: voidIntensity.interpolate({
                    inputRange: [0, 1],
                    outputRange: [0.16 + leftRegionPresence * 0.04, 0.22 + leftRegionPresence * 0.04],
                  }),
                  transform: [
                    { translateX: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: [-4, 10] }) },
                    { translateY: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [4, -4] }) },
                    { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.99, 1.02] }) },
                  ],
                },
              ]}
            />
            {archSections.left.map((value, index) => (
              <Animated.View
                key={`left-arch-section-${index}`}
                pointerEvents="none"
                style={[
                  styles.archSection,
                  styles.archSectionLeft,
                  index === 0 ? styles.archSectionTop : index === 1 ? styles.archSectionMid : styles.archSectionBottom,
                  {
                    opacity: 0.01 + value * 0.12,
                    transform: [{ translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-4 + index, 3 - index] }) }],
                  },
                ]}
              />
            ))}
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcRight,
                {
                  opacity: Animated.add(
                    Animated.add(
                      orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.03] }),
                      intentPressure.interpolate({ inputRange: [0, 1], outputRange: [0, 0.025] })
                    ),
                    voidIntensity.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.15 + rightRegionPresence * 0.03, 0.2 + rightRegionPresence * 0.03],
                    })
                  ),
                  transform: [
                    { translateX: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: [12, -8] }) },
                    { translateY: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-6, 10] }) },
                    { scaleX: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [1.01, 0.98] }) },
                    { scaleY: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0.99, 1.03] }) },
                  ],
                },
              ]}
            >
              <LinearGradient
                colors={["rgba(4,8,14,0)", "rgba(30,54,82,0.07)", "rgba(100,156,214,0.14)"]}
                start={{ x: 0, y: 0.5 }}
                end={{ x: 0.92, y: 0.5 }}
                style={StyleSheet.absoluteFill}
              />
            </Animated.View>
            {archSections.right.map((value, index) => (
              <Animated.View
                key={`right-arch-section-${index}`}
                pointerEvents="none"
                style={[
                  styles.archSection,
                  styles.archSectionRight,
                  index === 0 ? styles.archSectionTop : index === 1 ? styles.archSectionMid : styles.archSectionBottom,
                  {
                    opacity: 0.008 + value * 0.1,
                    transform: [{ translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [4 - index, -3 + index] }) }],
                  },
                ]}
              />
            ))}
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcRightRidge,
                {
                  opacity: Animated.add(
                    orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0.01, 0.05] }),
                    voidIntensity.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.09 + rightRegionPresence * 0.03, 0.13 + rightRegionPresence * 0.03],
                    })
                  ),
                  transform: [
                    { translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [6, -4] }) },
                    { scaleY: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.02] }) },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.regionArcRightCore,
                {
                  opacity: voidIntensity.interpolate({
                    inputRange: [0, 1],
                    outputRange: [0.13 + rightRegionPresence * 0.03, 0.18 + rightRegionPresence * 0.03],
                  }),
                  transform: [
                    { translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [6, -8] }) },
                    { translateY: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: [-8, 6] }) },
                    { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [1.01, 0.98] }) },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.focusDimmer,
                {
                  opacity: Animated.add(
                    depthDim,
                    Animated.add(
                      intentPressure.interpolate({ inputRange: [0, 1], outputRange: [0.02, 0.09] }),
                      voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [0.02, 0.12] })
                    )
                  ),
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.energySweepLeft,
                {
                  opacity: Animated.add(
                    ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.025, 0.05] }),
                    orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.022] })
                  ),
                  transform: [
                    { translateX: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-14, 18] }) },
                    { translateY: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: [6, -8] }) },
                    { rotate: "-9deg" },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.energySweepRight,
                {
                  opacity: Animated.add(
                    ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.02, 0.045] }),
                    orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0, 0.018] })
                  ),
                  transform: [
                    { translateX: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: [12, -14] }) },
                    { translateY: haloRotate.interpolate({ inputRange: [0, 1], outputRange: [-7, 6] }) },
                    { rotate: "11deg" },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.brokenArcOuter,
                {
                  opacity: Animated.add(
                    ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.02, 0.055] }),
                    voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [0, 0.018] })
                  ),
                  transform: [
                    { rotate: haloRotate.interpolate({ inputRange: [0, 1], outputRange: ["-12deg", "8deg"] }) },
                    { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.985, 1.015] }) },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.brokenArcInner,
                {
                  opacity: Animated.add(
                    ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [0.018, 0.04] }),
                    voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0, 0.014] })
                  ),
                  transform: [
                    { rotate: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: ["14deg", "-10deg"] }) },
                    { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [1.01, 0.992] }) },
                  ],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.centerFlash,
                { opacity: Animated.add(centerFlash, anticipationRipple.interpolate({ inputRange: [0, 1], outputRange: [0, 0.12] })) },
              ]}
            />
            <View pointerEvents="none" style={styles.voidParticleField}>
              {VOID_PARTICLES.map((particle, index) => (
                <Animated.View
                  key={particle.id}
                  style={[
                    styles.voidParticle,
                    {
                      width: particle.size,
                      height: particle.size,
                      borderRadius: particle.size,
                      opacity: Animated.add(
                        ambientPulse.interpolate({
                          inputRange: [0, 1],
                          outputRange: [particle.opacity * 0.45, particle.opacity],
                        }),
                        voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [0, 0.08] })
                      ),
                      transform: [
                        {
                          translateX: Animated.add(
                            intentPressure.interpolate({
                              inputRange: [0, 1],
                              outputRange: [particle.x + (particle.x > 0 ? -8 - index : 8 + index), particle.x],
                            }),
                            ghostOpacity.interpolate({
                              inputRange: [0, 1],
                              outputRange: [0, (particle.x > 0 ? -1 : 1) * (6 + index * 0.6 + particlePullX * 0.45)],
                            })
                          ),
                        },
                        {
                          translateY: Animated.add(
                            ambientPulse.interpolate({
                              inputRange: [0, 1],
                              outputRange: [particle.y + 6 + index * 0.5, particle.y - 4],
                            }),
                            Animated.add(
                              Animated.add(
                                fieldSignal.interpolate({
                                  inputRange: [0, 2],
                                  outputRange: [0, particle.y > 0 ? -10 - index : 7 + index * 0.6],
                                }),
                                voidGravity.interpolate({
                                  inputRange: [0, 1],
                                  outputRange: [0, particle.y > 0 ? -14 - index : 10 + index],
                                })
                              ),
                              ghostOpacity.interpolate({
                                inputRange: [0, 1],
                                outputRange: [0, particle.y > 0 ? -5 - index * 0.5 - particlePullY * 0.4 : 4 + index * 0.35 + particlePullY * 0.28],
                              })
                            )
                          ),
                        },
                        {
                          scale: Animated.add(
                            orbBreath.interpolate({
                              inputRange: [0, 1],
                              outputRange: [1, 0.92],
                            }),
                            voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [0, 0.06] })
                          ),
                        },
                      ],
                    },
                  ]}
                />
              ))}
            </View>
            <View pointerEvents="none" style={styles.voidMicroField}>
              {VOID_MICRO_FRAGMENTS.map((fragment, index) => (
                <Animated.View
                  key={fragment.id}
                  style={[
                    styles.voidMicroFragment,
                    {
                      width: fragment.w,
                      height: fragment.h,
                      borderRadius: fragment.h > 2 ? fragment.h / 2 : 999,
                      opacity: Animated.add(
                        ambientPulse.interpolate({
                          inputRange: [0, 1],
                          outputRange: [fragment.opacity * 0.6, fragment.opacity],
                        }),
                        orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.012] })
                      ),
                      transform: [
                        {
                          translateX: haloRotate.interpolate({
                            inputRange: [0, 1],
                            outputRange: [fragment.x - index * 0.6, fragment.x + index * 0.4],
                          }),
                        },
                        {
                          translateY: fluidRotateA.interpolate({
                            inputRange: [0, 1],
                            outputRange: [fragment.y + index * 0.4, fragment.y - index * 0.5],
                          }),
                        },
                        { rotate: fragment.rotate },
                      ],
                    },
                  ]}
                />
              ))}
            </View>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.activeVoidAnchor,
                  {
                    opacity: isIdleState ? 0 : 0.92,
                    transform: [
                    {
                      translateY: Animated.add(
                        orbExecution.interpolate({ inputRange: [0, 1], outputRange: [0, -3] }),
                        intentPressure.interpolate({ inputRange: [0, 1], outputRange: [0, -5] })
                      ),
                    },
                    { scale: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.985, 1.03] }) },
                    { scale: voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [1, 0.95] }) },
                    { scale: intentPressure.interpolate({ inputRange: [0, 1], outputRange: [1, 0.96] }) },
                    { scale: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [1, 0.975] }) },
                  ],
                },
              ]}
            >
              <Animated.View
                style={[
                  styles.hudCoreOuterRing,
                  {
                    opacity: Animated.add(
                      orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.16, 0.24] }),
                      orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0, 0.08] })
                    ),
                    transform: [{ rotate: haloRotate.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] }) }],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.hudCoreSegmentA,
                  {
                    opacity: orbExecution.interpolate({ inputRange: [0, 1], outputRange: [0.14, 0.26] }),
                    transform: [{ rotate: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] }) }],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.hudCoreSegmentB,
                  {
                    opacity: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.12, 0.22] }),
                    transform: [{ rotate: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: ["360deg", "0deg"] }) }],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.hudCoreInnerRing,
                  {
                    opacity: orbAttention.interpolate({ inputRange: [0, 1], outputRange: [0.16, 0.28] }),
                    transform: [{ rotate: haloRotate.interpolate({ inputRange: [0, 1], outputRange: ["360deg", "0deg"] }) }],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.hudCoreRipple,
                  {
                    opacity: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [0.2, 0] }),
                    transform: [{ scale: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [0.88, 1.26] }) }],
                  },
                ]}
              />
              <View pointerEvents="none" style={styles.hudRadialLines}>
                {[0, 1, 2, 3].map((line) => (
                  <Animated.View
                    key={`radial-${line}`}
                    style={[
                      styles.hudRadialLine,
                      {
                        transform: [{ rotate: `${line * 45}deg` }],
                        opacity: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.08, 0.16] }),
                      },
                    ]}
                  />
                ))}
              </View>
              <Animated.View
                style={[
                  styles.activeVoidPredictiveTint,
                  {
                    backgroundColor: predictiveGhost.tint,
                    opacity: Animated.multiply(
                      ghostOpacity,
                      ghostAlignment.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.42] })
                    ),
                    transform: [
                      { scaleX: ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] }) },
                      { scaleY: ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [1, 0.94] }) },
                    ],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.activeVoidFalloff,
                  {
                    opacity: Animated.add(
                      orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.2, 0.34] }),
                      Animated.add(
                        anticipationRipple.interpolate({ inputRange: [0, 1], outputRange: [0, 0.1] }),
                        voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0, 0.08] })
                      )
                    ),
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.activeVoidFieldA,
                  {
                    transform: [
                      { rotate: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] }) },
                      { scaleX: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [1.04, 0.97] }) },
                      { scaleY: intentPressure.interpolate({ inputRange: [0, 1], outputRange: [1.02, 0.94] }) },
                      { translateX: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [10, -6] }) },
                    ],
                  },
                ]}
              >
                <LinearGradient colors={["rgba(2,4,8,0.98)", "rgba(3,7,12,0.92)", "rgba(9,18,30,0.28)"]} style={StyleSheet.absoluteFill} />
              </Animated.View>
              <Animated.View
                style={[
                  styles.activeVoidFieldB,
                  {
                    opacity: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0.56, 0.74] }),
                    transform: [
                      { rotate: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: ["360deg", "0deg"] }) },
                      { scaleY: orbExecution.interpolate({ inputRange: [0, 1], outputRange: [1, 0.95] }) },
                      { scaleX: anticipationRipple.interpolate({ inputRange: [0, 1], outputRange: [1.06, 1] }) },
                      { translateY: voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [-8, 4] }) },
                    ],
                  },
                ]}
              >
                <LinearGradient colors={["rgba(0,0,0,0.94)", "rgba(4,8,14,0.88)", "rgba(24,48,72,0.12)"]} style={StyleSheet.absoluteFill} />
              </Animated.View>
              <Animated.View
                style={[
                  styles.activeVoidDistortion,
                  {
                    opacity: Animated.add(
                      orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.08, 0.18] }),
                      Animated.add(
                        manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [0, 0.12] }),
                        voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0, 0.1] })
                      )
                    ),
                    transform: [
                      { translateX: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [-16, 16] }) },
                      { scaleX: anticipationRipple.interpolate({ inputRange: [0, 1], outputRange: [1.16, 1] }) },
                    ],
                  },
                ]}
              />
              <Animated.View
                style={[
                  styles.activeVoidCore,
                  {
                    transform: [
                      { scale: intentPressure.interpolate({ inputRange: [0, 1], outputRange: [1, 0.9] }) },
                      { scaleX: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [1.08, 1] }) },
                      { scaleY: voidIntensity.interpolate({ inputRange: [0, 1], outputRange: [1, 0.88] }) },
                    ],
                  },
                ]}
              />
              <View style={styles.hudCoreBrightPoint} />
            </Animated.View>
            <Animated.View
              pointerEvents="none"
              style={[
                styles.energyLinkMain,
                {
                  opacity: focusSignal.interpolate({ inputRange: [0, 2], outputRange: [0.02, 0.08] }),
                  transform: [{ scaleX: resultEmerge.interpolate({ inputRange: [0, 1], outputRange: [0.7, 1] }) }],
                },
              ]}
            />
            <Animated.View
              pointerEvents="none"
              style={[
                styles.energyLinkSide,
                {
                  opacity: focusSignal.interpolate({ inputRange: [0, 2], outputRange: [0.02, 0.07] }),
                },
              ]}
            />
            {ghostVisible ? (
              <Animated.View
                pointerEvents="none"
                style={[
                  styles.predictiveGhostHost,
                  {
                    opacity: ghostOpacity,
                    transform: [
                      {
                        translateX: Animated.add(
                          ghostAnim.interpolate({
                            inputRange: [0, 1],
                            outputRange: [
                              -ghostJitter * predictiveGhost.motion,
                              ghostJitter * 0.55 * predictiveGhost.motion,
                            ],
                          }),
                          voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0, 2] })
                        ),
                      },
                      {
                        translateY: Animated.add(
                          anticipationRipple.interpolate({ inputRange: [0, 1], outputRange: [4, -3] }),
                          ghostAnim.interpolate({
                            inputRange: [0, 1],
                            outputRange: [
                              ghostJitter * 0.38 * predictiveGhost.motion,
                              -ghostJitter * 0.3 * predictiveGhost.motion,
                            ],
                          })
                        ),
                      },
                      {
                        scale: Animated.add(
                          ghostClarity.interpolate({ inputRange: [0, 1], outputRange: [0.94, 1.01] }),
                          ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [0.025, 0] })
                        ),
                      },
                      { scaleX: ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [1.08, 1] }) },
                      { scaleY: ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [0.95, 1] }) },
                    ],
                  },
                ]}
              >
                <Animated.View
                  pointerEvents="none"
                  style={[
                    styles.predictiveGhostTint,
                    {
                      width: ghostWidth + 26,
                      height: ghostHeight + 30,
                      borderRadius: ghostHeight * 0.18 + 24,
                      backgroundColor: predictiveGhost.tint,
                      opacity: ghostClarity.interpolate({
                        inputRange: [0, 1],
                        outputRange: [ghostTintOpacity * 0.38, ghostTintOpacity],
                      }),
                    },
                  ]}
                />
                {partialGhostVisible ? (
                  <View style={styles.predictiveGhostHintField}>
                    {[0, 1, 2].map((hint) => (
                      <Animated.View
                        key={`ghost-hint-${hint}`}
                        style={[
                          styles.predictiveGhostHintArc,
                          hint === 1 ? styles.predictiveGhostHintArcMid : null,
                          hint === 2 ? styles.predictiveGhostHintArcTight : null,
                          {
                            opacity: ghostClarity.interpolate({
                              inputRange: [0, 1],
                              outputRange: [0.08 + hint * 0.02, 0.22 + hint * 0.05],
                            }),
                            transform: [
                              { rotate: `${hint === 0 ? "-10deg" : hint === 1 ? "6deg" : "-4deg"}` },
                              {
                                translateX: ghostAnim.interpolate({
                                  inputRange: [0, 1],
                                  outputRange: [-4 + hint * 2, 4 - hint],
                                }),
                              },
                            ],
                          },
                        ]}
                      />
                    ))}
                  </View>
                ) : null}
                {predictiveGhost.type === "image" || predictiveGhost.type === "mixed" ? (
                  <Animated.View
                    style={[
                      styles.predictiveGhostFrame,
                      {
                        width: ghostWidth,
                        height: ghostHeight,
                        borderRadius: clamp(18 + predictiveGhost.aspectRatio * 8, 18, 30),
                        opacity: ghostClarity.interpolate({ inputRange: [0, 1], outputRange: [0.34, 0.62] }),
                        transform: [
                          { scaleX: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [1.04, 1] }) },
                          {
                            scaleY: Animated.add(
                              ghostOpacity.interpolate({ inputRange: [0, 1], outputRange: [predictiveGhost.motion, 1] }),
                              ghostMomentum.interpolate({ inputRange: [0, 1], outputRange: [0.04, 0] })
                            ),
                          },
                        ],
                      },
                    ]}
                  >
                    <View style={styles.predictiveGhostImageInner} />
                  </Animated.View>
                ) : null}
                {predictiveGhost.type === "video" ? (
                  <Animated.View
                    style={[
                      styles.predictiveGhostFrame,
                      styles.predictiveGhostVideo,
                      {
                        width: ghostWidth,
                        height: ghostHeight,
                        borderRadius: clamp(18 + predictiveGhost.aspectRatio * 8, 18, 30),
                      },
                    ]}
                  >
                    <Animated.View
                      style={[
                        styles.predictiveGhostShimmer,
                        {
                          opacity: ghostClarity.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.4] }),
                          transform: [{ translateX: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [-34, 34] }) }],
                        },
                      ]}
                    />
                  </Animated.View>
                ) : null}
                {predictiveGhost.type === "text" ? (
                  <View style={[styles.predictiveGhostTextBlock, predictiveGhost.semanticStructure === "chat" ? styles.predictiveGhostChatBlock : null]}>
                    {Array.from({ length: predictiveGhost.lineCount }).map((_, line) => (
                      <Animated.View
                        key={`ghost-line-${line}`}
                        style={[
                          styles.predictiveGhostTextLine,
                          predictiveGhost.semanticStructure === "list" ? styles.predictiveGhostListLine : null,
                          predictiveGhost.semanticStructure === "steps" ? styles.predictiveGhostStepLine : null,
                          predictiveGhost.semanticStructure === "chat"
                            ? line % 2 === 0
                              ? styles.predictiveGhostChatBubbleLeft
                              : styles.predictiveGhostChatBubbleRight
                            : null,
                          predictiveGhost.semanticStructure === "code" ? styles.predictiveGhostCodeLine : null,
                          {
                            width:
                              predictiveGhost.semanticStructure === "chat"
                                ? `${line % 2 === 0 ? 60 + (line % 3) * 7 : 56 + (line % 3) * 8}%`
                                : predictiveGhost.semanticStructure === "code"
                                  ? `${92 - (line % 4) * 9}%`
                                  : predictiveGhost.semanticStructure === "steps"
                                    ? `${84 - line * 5}%`
                                    : `${88 - line * 8}%`,
                            opacity: ghostClarity.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.46] }),
                          },
                        ]}
                      >
                        {predictiveGhost.semanticStructure === "list" ? <View style={styles.predictiveGhostListDot} /> : null}
                        {predictiveGhost.semanticStructure === "steps" ? <View style={styles.predictiveGhostStepBadge} /> : null}
                      </Animated.View>
                    ))}
                  </View>
                ) : null}
                {predictiveGhost.type === "payment" ? (
                  <View style={styles.predictiveGhostPayment}>
                    <View style={styles.predictiveGhostPill} />
                    <View style={[styles.predictiveGhostPill, styles.predictiveGhostPillSmall]} />
                  </View>
                ) : null}
                {predictiveGhost.type === "page" ? (
                  <View style={styles.predictiveGhostPage}>
                    <View style={styles.predictiveGhostPageBar} />
                    <View style={styles.predictiveGhostPageBody} />
                  </View>
                ) : null}
              </Animated.View>
            ) : null}
            {showOverlays &&
            !isIdleState &&
            !(centerResultVisible && activeCenterResult && ["image", "video", "mixed"].includes(activeCenterResult.resultType)) ? (
              <Animated.View
                style={[
                  styles.flowOverlay,
                  {
                    opacity: resultEmerge,
                    transform: [
                      { translateY: resultEmerge.interpolate({ inputRange: [0, 1], outputRange: [12, 0] }) },
                      { scale: resultEmerge.interpolate({ inputRange: [0, 1], outputRange: [0.94, 1] }) },
                    ],
                  },
                ]}
              >
                <View style={styles.flowOverlayHeader}>
                  <Text style={styles.flowOverlayTitle}>Start here.</Text>
                  <View style={[styles.flowStatusPill, statusTone]}>
                    <Text style={styles.flowStatusText}>{flowStatus.toUpperCase()}</Text>
                  </View>
                </View>
                <Text style={styles.flowOverlayBody}>{flowOutput}</Text>
                <Text style={styles.flowOverlayBodySecondary}>
                  {focusedTask ? `Primary: ${focusedTask.title}` : "No active task. Start from a flow or command."}
                </Text>
                {flowStatus === "success" ? (
                  <View style={styles.resultActionsRow}>
                    <Pressable style={styles.resultActionBtn} onPress={() => runResultAction("edit")}>
                      <Text style={styles.resultActionText}>Edit</Text>
                    </Pressable>
                    <Pressable style={styles.resultActionBtn} onPress={() => runResultAction("save")}>
                      <Text style={styles.resultActionText}>Save</Text>
                    </Pressable>
                    <Pressable style={styles.resultActionBtn} onPress={() => runResultAction("send")}>
                      <Text style={styles.resultActionText}>Send</Text>
                    </Pressable>
                    <Pressable style={styles.resultActionBtn} onPress={() => runResultAction("publish")}>
                      <Text style={styles.resultActionText}>Publish</Text>
                    </Pressable>
                  </View>
                ) : null}
              </Animated.View>
            ) : null}

            {centerResultVisible ? (
              <Animated.View
                style={[
                  styles.centerResultHost,
                  {
                    opacity: activeCenterResult?.resultStatus === "working" ? 0.86 : resultEmerge,
                    transform: [
                      {
                        translateY: Animated.add(
                          resultEmerge.interpolate({ inputRange: [0, 1], outputRange: [16, -2] }),
                          settleDrift.interpolate({ inputRange: [0, 1], outputRange: [-8, 0] })
                        ),
                      },
                      {
                        scale: Animated.add(
                          resultEmerge.interpolate({ inputRange: [0, 1], outputRange: [0.88, 1] }),
                          settleDrift.interpolate({ inputRange: [0, 1], outputRange: [0.03, 0] })
                        ),
                      },
                    ],
                  },
                ]}
              >
                <Animated.View
                  pointerEvents="none"
                  style={[
                    styles.centerResultHalo,
                    {
                      opacity: activeCenterResult?.resultStatus === "working" ? 0.22 : 0.16,
                      transform: [
                        { scale: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1.04] }) },
                        { scaleX: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [1.12, 1] }) },
                      ],
                    },
                  ]}
                />
                <View style={styles.centerResultCard}>
                  <Animated.View
                    pointerEvents="none"
                    style={[
                      styles.centerResultDistortion,
                      {
                        opacity: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [0, 0.14] }),
                        transform: [{ scale: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [1.08, 1] }) }],
                      },
                    ]}
                  />
                  <View style={styles.centerResultHeader}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.centerResultTitle}>{activeCenterResult?.title || "Manifesting result"}</Text>
                      {activeCenterResult?.subtitle ? <Text style={styles.centerResultSubtitle}>{activeCenterResult.subtitle}</Text> : null}
                    </View>
                    <Text style={styles.centerResultStatus}>{(activeCenterResult?.resultStatus || resultStatus).toUpperCase()}</Text>
                  </View>

                  {activeCenterResult?.resultStatus === "working" ? (
                    <View style={styles.centerWorkingState}>
                      <View style={styles.centerWorkingDot} />
                      <Text style={styles.centerWorkingText}>The void is shaping the result.</Text>
                    </View>
                  ) : null}

                  {(activeCenterResult?.resultType === "image" || activeCenterResult?.resultType === "mixed") && activeCenterResult.assetUrl ? (
                    <Image source={{ uri: activeCenterResult.assetUrl }} resizeMode="cover" style={styles.centerResultImage} />
                  ) : null}

                  {activeCenterResult?.resultType === "live_tv" && activeCenterResult.assetUrl ? (
                    <View style={styles.centerStreamWrap}>
                      <WebView
                        source={{ html: buildStreamPlayerHtml(activeCenterResult.assetUrl, activeCenterResult.previewUrl || "", false) }}
                        style={styles.centerStreamPlayer}
                        scrollEnabled={false}
                        allowsInlineMediaPlayback
                        mediaPlaybackRequiresUserAction={false}
                      />
                    </View>
                  ) : null}

                  {activeCenterResult?.resultType === "video" ? (
                    <View style={styles.centerFallbackCard}>
                      {activeCenterResult.previewUrl ? (
                        <Image source={{ uri: activeCenterResult.previewUrl }} resizeMode="cover" style={styles.centerFallbackThumb} />
                      ) : null}
                      <Text style={styles.centerFallbackText}>Video artifact is ready.</Text>
                    </View>
                  ) : null}

                  {(activeCenterResult?.resultType === "text" ||
                    activeCenterResult?.resultType === "page" ||
                    activeCenterResult?.resultType === "flow" ||
                    activeCenterResult?.resultType === "payment" ||
                    activeCenterResult?.resultType === "mixed") &&
                  activeCenterResult?.textContent ? (
                    <ScrollView style={styles.centerResultTextWrap} contentContainerStyle={styles.centerResultTextContent}>
                      <Text style={styles.centerResultText}>{activeCenterResult.textContent}</Text>
                    </ScrollView>
                  ) : null}

                  {activeCenterResult?.resultType === "fallback" ||
                  (activeCenterResult?.resultStatus === "error" && !activeCenterResult.assetUrl && !activeCenterResult.textContent) ? (
                    <View style={styles.centerFallbackCard}>
                      {activeCenterResult?.previewUrl ? (
                        <Image source={{ uri: activeCenterResult.previewUrl }} resizeMode="cover" style={styles.centerFallbackThumb} />
                      ) : null}
                      <Text style={styles.centerFallbackText}>Result exists, but the center renderer needs help.</Text>
                    </View>
                  ) : null}

                  <View style={styles.centerResultActions}>
                    {primaryCenterLink ? (
                      <Pressable
                        style={styles.resultActionBtn}
                        onPress={async () => {
                          try {
                            await Linking.openURL(primaryCenterLink);
                          } catch {
                            setResultStatus("error");
                          }
                        }}
                      >
                        <Text style={styles.resultActionText}>Open link</Text>
                      </Pressable>
                    ) : null}
                    {primaryCenterLink ? (
                      <Pressable style={styles.resultActionBtn} onPress={copyCenterLink}>
                        <Text style={styles.resultActionText}>Copy link</Text>
                      </Pressable>
                    ) : null}
                    {(activeCenterResult?.assetUrl || activeCenterResult?.previewUrl) ? (
                      <Pressable style={styles.resultActionBtn} onPress={openCenterResult}>
                        <Text style={styles.resultActionText}>Open result</Text>
                      </Pressable>
                    ) : null}
                    <Pressable
                      style={styles.resultActionBtn}
                      onPress={() => {
                        if (latestResult) {
                          const resolved = resolveCenterResult(latestResult);
                          if (resolved) {
                            setActiveCenterResult(resolved);
                            setResultStatus(resolved.resultStatus);
                          }
                        }
                      }}
                    >
                      <Text style={styles.resultActionText}>Retry render</Text>
                    </Pressable>
                    <Pressable
                      style={styles.resultActionBtn}
                      onPress={() => {
                        transitionVoidState("recovering");
                        setActiveCenterResult(null);
                        setResultStatus("idle");
                        if (recoveryTimeoutRef.current) clearTimeout(recoveryTimeoutRef.current);
                        recoveryTimeoutRef.current = setTimeout(() => {
                          transitionVoidState(commandActive ? "anticipating" : "idle");
                          recoveryTimeoutRef.current = null;
                        }, 1500);
                      }}
                    >
                      <Text style={styles.resultActionText}>Dismiss</Text>
                    </Pressable>
                  </View>
                </View>
              </Animated.View>
            ) : null}

            {isIdleState ? (
              <Animated.View
                style={[
                  styles.idlePresenceWrap,
                  {
                    opacity: idleReveal,
                    transform: [{ scale: idleReveal.interpolate({ inputRange: [0, 1], outputRange: [0.96, 1] }) }],
                  },
                ]}
              >
                <Pressable
                  onPress={() => {
                    registerInteraction();
                    reactOrbTouch();
                    onOrbTap?.();
                  }}
                  onLongPress={() => {
                    registerInteraction();
                    reactOrbTouch();
                    setToolsVisible(true);
                    setShowTaskStack(true);
                    setGestureHint("Advanced controls revealed");
                  }}
                  style={styles.idleVoidPressable}
                >
                  <Animated.View
                    style={[
                      styles.idleVoidFalloff,
                      {
                        opacity: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.14, 0.24] }),
                        transform: [
                          { scale: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1.03] }) },
                          { scale: orbResult.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] }) },
                        ],
                      },
                    ]}
                  />
                  <Animated.View
                    style={[
                      styles.idleVoidCore,
                      {
                        transform: [
                          { translateX: orbNudgeX },
                          { translateY: orbNudgeY },
                          { scale: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [0.985, 1.02] }) },
                          { scale: orbAttention.interpolate({ inputRange: [0, 1], outputRange: [1, 1.03] }) },
                          { scale: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [1, 0.98] }) },
                          { scale: orbExecution.interpolate({ inputRange: [0, 1], outputRange: [1, 0.95] }) },
                        ],
                      },
                      ]}
                    >
                    <Animated.View
                      style={[
                        styles.idleVoidFieldA,
                        {
                          transform: [{ rotate: fluidRotateA.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] }) }],
                        },
                      ]}
                    >
                      <LinearGradient colors={["rgba(1,2,5,0.99)", "rgba(3,6,10,0.95)", "rgba(8,16,26,0.38)"]} style={StyleSheet.absoluteFill} />
                    </Animated.View>
                    <Animated.View
                      style={[
                        styles.idleVoidFieldB,
                        {
                          transform: [{ rotate: fluidRotateB.interpolate({ inputRange: [0, 1], outputRange: ["360deg", "0deg"] }) }],
                        },
                      ]}
                    >
                      <LinearGradient colors={["rgba(1,2,5,0.92)", "rgba(5,10,16,0.82)", "rgba(18,36,56,0.18)"]} style={StyleSheet.absoluteFill} />
                    </Animated.View>
                    <Animated.View
                      style={[
                        styles.idleVoidThinkingTint,
                        { opacity: orbThinking.interpolate({ inputRange: [0, 1], outputRange: [0, 0.09] }) },
                      ]}
                    />
                    <Animated.View
                      style={[
                        styles.idleVoidExecutionTint,
                        { opacity: orbExecution.interpolate({ inputRange: [0, 1], outputRange: [0, 0.1] }) },
                      ]}
                    />
                    <Animated.View
                      style={[
                        styles.idleVoidErrorTint,
                        { opacity: orbError.interpolate({ inputRange: [0, 1], outputRange: [0, 0.08] }) },
                      ]}
                    />
                    <Animated.View
                      style={[
                        styles.idleVoidShimmer,
                        {
                          opacity: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [0, 0.14] }),
                          transform: [{ translateX: orbShimmer.interpolate({ inputRange: [0, 1], outputRange: [-58, 58] }) }],
                        },
                      ]}
                    />
                    <View style={styles.idleVoidCenter} />
                  </Animated.View>
                </Pressable>
                <Text style={styles.idlePromptText}>Tell me what you need.</Text>
                <Animated.View
                  style={[
                    styles.idleGhostRow,
                    {
                      opacity: ghostAnim.interpolate({ inputRange: [0, 1], outputRange: [0.16, 0.3] }),
                      transform: [{ translateY: ghostAnim.interpolate({ inputRange: [0, 1], outputRange: [6, 0] }) }],
                    },
                  ]}
                >
                  {GHOST_HINTS.map((hint) => (
                    <Text key={hint} style={styles.idleGhostHint}>
                      {hint}
                    </Text>
                  ))}
                </Animated.View>
              </Animated.View>
            ) : (
              children
            )}

            {spatialWindows.length > 0 ? (
              <View style={styles.windowField} pointerEvents="box-none">
                {spatialWindows
                  .slice()
                  .reverse()
                  .map((model) => {
                    const isFocusedWindow = model.task.id === focusedTaskId;
                    return (
                      <Animated.View
                        key={model.task.id}
                        {...(isFocusedWindow ? taskWindowResponder.panHandlers : {})}
                        style={[
                          styles.taskWindow,
                          {
                            width: model.width,
                            minHeight: model.minHeight,
                            opacity: model.opacity,
                            zIndex: model.zIndex,
                            borderColor: `rgba(143,191,233,${model.borderOpacity})`,
                            shadowOpacity: model.shadowOpacity,
                            shadowRadius: model.shadowRadius,
                            transform: [
                              { translateX: model.anchorX },
                              { translateY: model.anchorY + model.verticalLift },
                              { scale: model.scale },
                              { translateX: isFocusedWindow ? dragX.interpolate({ inputRange: [-120, 120], outputRange: [-6, 6] }) : 0 },
                              { translateY: isFocusedWindow ? dragY.interpolate({ inputRange: [-120, 120], outputRange: [-6, 6] }) : 0 },
                              { translateY: orbBreath.interpolate({ inputRange: [0, 1], outputRange: [1, 4 - model.index] }) },
                            ],
                          },
                        ]}
                      >
                        <Animated.View
                          pointerEvents="none"
                          style={[
                            styles.taskWindowWake,
                            {
                              opacity: dragWake.interpolate({ inputRange: [0, 1], outputRange: [0, 0.18] }),
                              transform: [{ scale: dragWake.interpolate({ inputRange: [0, 1], outputRange: [1.08, 1] }) }],
                            },
                          ]}
                        />
                        <View
                          pointerEvents="none"
                          style={[
                            styles.taskWindowGlow,
                            {
                              opacity: model.glowOpacity,
                              transform: [{ scaleX: manifestationWake.interpolate({ inputRange: [0, 1], outputRange: [1.05, 1] }) }],
                            },
                          ]}
                        />
                        <View
                          pointerEvents="none"
                          style={[
                            styles.taskWindowDimmer,
                            {
                              opacity: model.dimOpacity,
                              transform: [{ scale: intentPressure.interpolate({ inputRange: [0, 1], outputRange: [1.02, 1] }) }],
                            },
                          ]}
                        />
                        <Animated.View
                          pointerEvents="none"
                          style={[
                            styles.taskWindowPressure,
                            {
                              opacity: voidDistortion.interpolate({ inputRange: [0, 1], outputRange: [0.04, 0.16] }),
                              transform: [{ scaleY: voidGravity.interpolate({ inputRange: [0, 1], outputRange: [1.08, 0.94] }) }],
                            },
                          ]}
                        />
                        <Pressable
                          onPress={() => {
                            const now = Date.now();
                            const isDoubleTap =
                              lastTapRef.current.taskId === model.task.id && now - lastTapRef.current.at < TAP_WINDOW_MS;
                            lastTapRef.current = { taskId: model.task.id, at: now };
                            focusTask(model.task.id, isDoubleTap ? "hard" : "soft");
                          }}
                          onLongPress={() =>
                            updateTask(model.task.id, {
                              controlsVisible: !model.task.controlsVisible,
                            })
                          }
                          style={styles.taskWindowHeader}
                        >
                          <Text style={styles.taskWindowTitle}>{model.task.title}</Text>
                          <Text style={styles.taskWindowStatus}>{model.task.status.toUpperCase()}</Text>
                        </Pressable>
                        {model.task.contentKind === "live_stream" && model.task.mediaUrl ? (
                          <View style={styles.secondaryStreamWrap}>
                            <WebView
                              source={{ html: buildStreamPlayerHtml(model.task.mediaUrl, model.task.posterUrl || "", Boolean(model.task.muted)) }}
                              style={styles.secondaryStreamPlayer}
                              scrollEnabled={false}
                              allowsInlineMediaPlayback
                              mediaPlaybackRequiresUserAction={false}
                            />
                            <Text style={styles.taskWindowBody}>{model.task.providerName || model.task.subtitle}</Text>
                            <View style={styles.taskMetaRow}>
                              <Text style={styles.taskMetaText}>{model.task.muted ? "MUTED" : "AUDIO"}</Text>
                              <Text style={styles.taskMetaText}>{model.task.depthLayer.toUpperCase()}</Text>
                            </View>
                          </View>
                        ) : (
                          <>
                            <Text style={styles.taskWindowBody}>{model.task.subtitle}</Text>
                            {model.task.commandHint ? <Text style={styles.taskWindowHint}>Command: {model.task.commandHint}</Text> : null}
                            <View style={styles.taskMetaRow}>
                              <Text style={styles.taskMetaText}>{model.task.depthLayer.toUpperCase()}</Text>
                              <Text style={styles.taskMetaText}>{model.task.focusState === "none" ? "AMBIENT" : model.task.focusState.toUpperCase()}</Text>
                            </View>
                          </>
                        )}
                        {model.task.controlsVisible ? (
                          <View style={styles.taskControls}>
                            <Pressable style={styles.taskControlBtn} onPress={() => closeTask(model.task.id)}>
                              <Text style={styles.taskControlText}>Close</Text>
                            </Pressable>
                            <Pressable style={styles.taskControlBtn} onPress={() => promoteTask(model.task.id, true)}>
                              <Text style={styles.taskControlText}>Bring Forward</Text>
                            </Pressable>
                            <Pressable
                              style={styles.taskControlBtn}
                              onPress={() => {
                                updateTask(model.task.id, { scale: 1, x: 0, y: 0 });
                                focusTask(model.task.id, "soft");
                              }}
                            >
                              <Text style={styles.taskControlText}>Reset</Text>
                            </Pressable>
                          </View>
                        ) : null}
                      </Animated.View>
                    );
                  })}
              </View>
            ) : null}
          </Animated.View>

          {showTaskStack ? (
            <Animated.View
              style={[
                styles.taskStack,
                {
                  opacity: stackAnim,
                  transform: [{ translateY: stackAnim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }],
                },
              ]}
            >
              <Text style={styles.taskStackTitle}>Task Stack</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.taskStackRow}>
                {taskWindows.map((task) => (
                  <Pressable
                    key={task.id}
                    style={[styles.taskStackItem, focusedTaskId === task.id ? styles.taskStackItemFocused : null]}
                    onPress={() => {
                      focusTask(task.id, "hard");
                      setGestureHint(`Focused ${task.title}`);
                    }}
                  >
                    <Text style={styles.taskStackItemTitle}>{task.title}</Text>
                    <Text style={styles.taskStackItemSub}>
                      {task.status} · {task.depthLayer}
                    </Text>
                  </Pressable>
                ))}
              </ScrollView>
            </Animated.View>
          ) : null}
        </View>

        {showOverlays && showPanels && !toolsVisible && !isIdleState ? (
          <Animated.View
            style={[
              styles.rightZone,
              {
                opacity: Animated.multiply(panelsAnim, shellFade),
                transform: [
                  { translateY: Animated.add(panelsAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }), ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [-3, 3] })) },
                  { translateX: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [2, -3] }) },
                  { rotate: "3.5deg" },
                  { scale: ambientPulse.interpolate({ inputRange: [0, 1], outputRange: [1.008, 0.994] }) },
                ],
              },
            ]}
            pointerEvents={showPanels ? "auto" : "none"}
          >
            <View style={styles.panelHeaderRow}>
              <Text style={styles.panelEyebrow}>OUTPUT</Text>
              <Text style={styles.panelMeta}>SYNC</Text>
            </View>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Results</Text>
              <Text style={styles.panelSectionValue}>{activeCenterResult?.title || "Awaiting"}</Text>
            </View>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Browser</Text>
              <Text style={styles.panelSectionValue}>{activeBrowserUrl || "No page"}</Text>
            </View>
            <View style={styles.panelSeparator} />
            <View style={styles.panelSection}>
              <Text style={styles.panelSectionLabel}>Data</Text>
              <Text style={styles.panelSectionValue}>{focusedTask?.title || "No focused task"} · {recentActionCount} events</Text>
            </View>
            <View style={styles.panelSeparator} />
            <Text style={styles.zoneTitle}>Timeline</Text>
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scrollCol}>
              {flowSteps.length === 0 ? (
                <View style={styles.contentCard}>
                  <Text style={styles.contentCardTitle}>Idle</Text>
                  <Text style={styles.contentCardText}>Pick a flow below or run a command from the top bar.</Text>
                </View>
              ) : null}
              {flowSteps.map((step) => (
                <View key={step.id} style={styles.contentCard}>
                  <Text style={styles.contentCardTitle}>{step.label}</Text>
                  <Text style={styles.contentCardText}>
                    {step.status.toUpperCase()}
                    {step.detail ? ` · ${step.detail}` : ""}
                  </Text>
                </View>
              ))}
                {showSuggestions
                  ? suggestions.slice(0, 2).map((s) => (
                  <Pressable
                    key={s.id}
                    style={styles.contentCard}
                    onPress={() => {
                      registerInteraction();
                      if (isIdleState) {
                        Animated.timing(idleReveal, { toValue: 0, duration: 180, useNativeDriver: true }).start();
                      }
                      executeFromOrb(s.command);
                    }}
                  >
                    <Text style={styles.contentCardTitle}>Suggested</Text>
                    <Text style={styles.contentCardText}>{s.label}</Text>
                  </Pressable>
                    ))
                  : null}
              <View style={styles.contentCard}>
                <Text style={styles.contentCardTitle}>Session</Text>
                <Text style={styles.contentCardText}>
                  {recentActionCount} actions · {taskWindows.length} active tasks
                </Text>
              </View>
              {rightActions.slice(0, 2).map((action) => (
                <Pressable key={action.id} style={styles.contentCard} onPress={action.onPress}>
                  <Text style={styles.contentCardTitle}>Open</Text>
                  <Text style={styles.contentCardText}>{action.label}</Text>
                </Pressable>
              ))}
            </ScrollView>
          </Animated.View>
        ) : null}
      </View>

      {showSuggestions && !isIdleState ? (
        <Animated.View
          style={[
            styles.flowShelf,
            {
              opacity: Animated.multiply(suggestionsAnim, shellFade),
              transform: [
                { translateY: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) },
                { scale: suggestionsAnim.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1] }) },
              ],
            },
          ]}
          pointerEvents={showSuggestions ? "auto" : "none"}
        >
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.flowShelfRow}>
            {visibleFlows.slice(0, 3).map((flow) => (
              <Pressable key={flow.id} style={[styles.flowChip, activeFlowId === flow.id ? styles.flowChipActive : null]} onPress={() => runFlow(flow)}>
                <Text style={styles.flowChipTitle}>{flow.label}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </Animated.View>
      ) : null}

      <Animated.View style={[styles.bottomZone, { opacity: shellFade }]}>
        {bottomActions.slice(0, 4).map((action, index) => (
          <Pressable
            key={action.id}
            style={styles.bottomAction}
            onPressIn={() => {
              setActiveDockIndex(index);
              Animated.spring(dockPulse, {
                toValue: 1,
                damping: 16,
                stiffness: 180,
                mass: 0.8,
                useNativeDriver: true,
              }).start();
            }}
            onPressOut={() => {
              Animated.spring(dockPulse, {
                toValue: 0,
                damping: 18,
                stiffness: 170,
                mass: 0.82,
                useNativeDriver: true,
              }).start(() => setActiveDockIndex((current) => (current === index ? null : current)));
            }}
            onPress={action.onPress}
          >
            <Animated.View
              style={[
                styles.bottomActionInner,
                activeDockIndex === index
                  ? {
                      opacity: dockPulse.interpolate({ inputRange: [0, 1], outputRange: [0.16, 0.34] }),
                      transform: [{ scale: dockPulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] }) }],
                    }
                  : null,
              ]}
            />
            <Animated.View
              style={
                activeDockIndex === index
                  ? {
                      transform: [{ scale: dockPulse.interpolate({ inputRange: [0, 1], outputRange: [1, 0.96] }) }],
                    }
                  : null
              }
            >
            <Text style={styles.bottomActionGlyph}>{COMMAND_DOCK_LABELS[index]?.slice(0, 1) || action.label.slice(0, 1)}</Text>
            <Text style={styles.bottomActionText}>{COMMAND_DOCK_LABELS[index] || action.label}</Text>
            </Animated.View>
          </Pressable>
        ))}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  canvasRoot: {
    flex: 1,
    borderRadius: 24,
    overflow: "hidden",
    backgroundColor: "rgba(4,8,14,0.96)",
  },
  bgLayer: { ...StyleSheet.absoluteFillObject },
  bgHaloPrimary: {
    position: "absolute",
    width: 320,
    height: 320,
    borderRadius: 160,
    top: -96,
    left: -120,
    backgroundColor: "rgba(56,102,152,0.004)",
  },
  bgHaloSecondary: {
    position: "absolute",
    width: 260,
    height: 260,
    borderRadius: 130,
    right: -104,
    bottom: -88,
    backgroundColor: "rgba(70,98,136,0.003)",
  },
  bgParticleOne: {
    position: "absolute",
    width: 104,
    height: 1,
    borderRadius: 2,
    top: "32%",
    left: "16%",
    backgroundColor: "rgba(127,193,255,0.06)",
  },
  bgParticleTwo: {
    position: "absolute",
    width: 92,
    height: 1,
    borderRadius: 2,
    bottom: "24%",
    right: "14%",
    backgroundColor: "rgba(176,160,255,0.045)",
  },
  passiveLayer: { position: "absolute", top: 12, left: 16, zIndex: 2 },
  zoneHint: { color: "rgba(186,205,228,0.24)", fontSize: 10 },
  activeLayer: { flex: 1, flexDirection: "row", gap: 10, padding: 12, paddingBottom: 56, zIndex: 3 },
  leftZone: {
    width: 154,
    marginTop: 68,
    marginLeft: 18,
    borderRadius: 26,
    borderWidth: 1,
    borderColor: "rgba(118,184,244,0.12)",
    backgroundColor: "rgba(8,16,28,0.54)",
    padding: 8,
    gap: 8,
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 18 },
  },
  rightZone: {
    width: 196,
    marginTop: 112,
    marginRight: 12,
    borderRadius: 28,
    borderWidth: 1,
    borderColor: "rgba(112,176,236,0.1)",
    backgroundColor: "rgba(8,16,28,0.5)",
    padding: 8,
    gap: 8,
    shadowColor: "#000",
    shadowOpacity: 0.16,
    shadowRadius: 28,
    shadowOffset: { width: 0, height: 20 },
  },
  panelHeaderRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  panelEyebrow: {
    color: "rgba(152,212,255,0.68)",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 1.4,
  },
  panelMeta: {
    color: "rgba(188,220,248,0.58)",
    fontSize: 9,
    fontWeight: "700",
  },
  panelSeparator: {
    height: 1,
    backgroundColor: "rgba(110,172,232,0.12)",
  },
  panelSection: {
    gap: 4,
  },
  panelSectionLabel: {
    color: "rgba(150,206,252,0.52)",
    fontSize: 9,
    fontWeight: "800",
    letterSpacing: 1.1,
  },
  panelSectionValue: {
    color: "rgba(214,228,244,0.66)",
    fontSize: 10,
  },
  zoneTitle: { color: "rgba(224,236,250,0.74)", fontSize: 12, fontWeight: "700", letterSpacing: 0.3 },
  scrollCol: { gap: 7, paddingBottom: 8 },
  orbitButton: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "rgba(108,174,238,0.12)",
    backgroundColor: "rgba(18,34,54,0.88)",
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  orbitButtonText: { color: "rgba(222,236,250,0.76)", fontSize: 11, fontWeight: "700", letterSpacing: 0.2 },
  centerZone: { flex: 1, gap: 8 },
  centerHeader: {
    borderRadius: 18,
    backgroundColor: "rgba(8,15,24,0.03)",
    paddingHorizontal: 6,
    paddingVertical: 4,
    flexDirection: "row",
    gap: 10,
    alignItems: "center",
  },
  centerTitle: { color: "rgba(236,244,255,0.92)", fontSize: 16, fontWeight: "800", letterSpacing: 0.2 },
  centerSubtitle: { color: "rgba(186,204,224,0.54)", fontSize: 12, marginTop: 2, letterSpacing: 0.2 },
  centerHint: { color: browserTheme.textMuted, fontSize: 10, marginTop: 3 },
  headerActions: { gap: 7, alignItems: "flex-end" },
  headerAction: {
    borderRadius: 10,
    backgroundColor: "rgba(17,30,46,0.12)",
    paddingHorizontal: 8,
    paddingVertical: 5,
  },
  headerActionText: { color: "rgba(210,226,244,0.5)", fontSize: 10, fontWeight: "700" },
  focusSurface: {
    flex: 1,
    borderRadius: 0,
    backgroundColor: "transparent",
    overflow: "visible",
  },
  connectorLeft: {
    position: "absolute",
    left: 120,
    top: "49%",
    width: 176,
    height: 1,
    zIndex: 3,
    backgroundColor: "rgba(126,194,255,0.34)",
  },
  connectorRight: {
    position: "absolute",
    right: 144,
    top: "49%",
    width: 188,
    height: 1,
    zIndex: 3,
    backgroundColor: "rgba(126,194,255,0.3)",
  },
  connectorPulse: {
    position: "absolute",
    top: -1,
    width: 26,
    height: 3,
    borderRadius: 999,
    backgroundColor: "rgba(198,238,255,0.96)",
  },
  regionArcLeft: {
    position: "absolute",
    left: -134,
    top: "10%",
    width: 286,
    height: 632,
    borderRadius: 186,
    overflow: "hidden",
    zIndex: 1,
    shadowColor: "#7fbfff",
    shadowOpacity: 0.08,
    shadowRadius: 26,
    shadowOffset: { width: 0, height: 0 },
  },
  regionArcLeftRidge: {
    position: "absolute",
    left: 50,
    top: "18%",
    width: 36,
    height: 430,
    borderRadius: 28,
    zIndex: 1,
    backgroundColor: "rgba(162,208,255,0.14)",
    shadowColor: "#c3e2ff",
    shadowOpacity: 0.12,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 0 },
  },
  regionArcLeftCore: {
    position: "absolute",
    left: -62,
    top: "16%",
    width: 146,
    height: 492,
    borderRadius: 118,
    zIndex: 1,
    backgroundColor: "rgba(88,144,208,0.08)",
    shadowColor: "#90c6ff",
    shadowOpacity: 0.06,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 0 },
  },
  regionArcRight: {
    position: "absolute",
    right: -118,
    top: "14%",
    width: 252,
    height: 596,
    borderRadius: 174,
    overflow: "hidden",
    zIndex: 1,
    shadowColor: "#7fbfff",
    shadowOpacity: 0.06,
    shadowRadius: 22,
    shadowOffset: { width: 0, height: 0 },
  },
  regionArcRightRidge: {
    position: "absolute",
    right: 42,
    top: "21%",
    width: 28,
    height: 396,
    borderRadius: 24,
    zIndex: 1,
    backgroundColor: "rgba(122,176,228,0.1)",
    shadowColor: "#a9d1ff",
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 0 },
  },
  regionArcRightCore: {
    position: "absolute",
    right: -48,
    top: "20%",
    width: 118,
    height: 452,
    borderRadius: 96,
    zIndex: 1,
    backgroundColor: "rgba(90,146,206,0.06)",
    shadowColor: "#86c2ff",
    shadowOpacity: 0.05,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 0 },
  },
  focusDimmer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 2,
    backgroundColor: "rgba(2,5,10,0.06)",
  },
  centerFlash: {
    position: "absolute",
    width: 300,
    height: 300,
    borderRadius: 150,
    top: "39%",
    left: "50%",
    marginLeft: -150,
    marginTop: -150,
    zIndex: 4,
    backgroundColor: "rgba(98,154,212,0.015)",
  },
  energySweepLeft: {
    position: "absolute",
    left: -24,
    top: "26%",
    width: 240,
    height: 84,
    borderRadius: 80,
    zIndex: 4,
    borderWidth: 1,
    borderColor: "rgba(132,192,248,0.05)",
    backgroundColor: "rgba(84,144,206,0.01)",
  },
  energySweepRight: {
    position: "absolute",
    right: -18,
    top: "56%",
    width: 220,
    height: 72,
    borderRadius: 76,
    zIndex: 4,
    borderWidth: 1,
    borderColor: "rgba(118,178,236,0.04)",
    backgroundColor: "rgba(74,128,188,0.008)",
  },
  brokenArcOuter: {
    position: "absolute",
    left: "50%",
    top: "50%",
    marginLeft: -152,
    marginTop: -138,
    width: 304,
    height: 276,
    borderRadius: 168,
    zIndex: 4,
    borderTopWidth: 1,
    borderLeftWidth: 1,
    borderRightWidth: 0,
    borderBottomWidth: 0,
    borderColor: "rgba(146,204,255,0.05)",
    backgroundColor: "transparent",
  },
  brokenArcInner: {
    position: "absolute",
    left: "50%",
    top: "50%",
    marginLeft: -124,
    marginTop: -116,
    width: 248,
    height: 232,
    borderRadius: 144,
    zIndex: 4,
    borderTopWidth: 0,
    borderLeftWidth: 0,
    borderRightWidth: 1,
    borderBottomWidth: 1,
    borderColor: "rgba(126,188,244,0.04)",
    backgroundColor: "transparent",
  },
  voidParticleField: {
    position: "absolute",
    left: "50%",
    top: "50%",
    width: 0,
    height: 0,
    zIndex: 5,
  },
  voidParticle: {
    position: "absolute",
    backgroundColor: "rgba(182,220,255,0.74)",
  },
  voidMicroField: {
    position: "absolute",
    left: "50%",
    top: "50%",
    width: 0,
    height: 0,
    zIndex: 4,
  },
  voidMicroFragment: {
    position: "absolute",
    backgroundColor: "rgba(174,216,255,0.62)",
  },
  activeVoidAnchor: {
    position: "absolute",
    top: "49%",
    left: "50%",
    marginLeft: -92,
    marginTop: -92,
    width: 184,
    height: 184,
    zIndex: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  hudCoreOuterRing: {
    position: "absolute",
    width: 232,
    height: 232,
    borderRadius: 116,
    borderWidth: 2,
    borderColor: "rgba(150,212,255,0.34)",
  },
  hudCoreSegmentA: {
    position: "absolute",
    width: 248,
    height: 248,
    borderRadius: 124,
    borderTopWidth: 2,
    borderLeftWidth: 2,
    borderRightWidth: 0,
    borderBottomWidth: 0,
    borderColor: "rgba(142,208,255,0.3)",
  },
  hudCoreSegmentB: {
    position: "absolute",
    width: 214,
    height: 214,
    borderRadius: 107,
    borderTopWidth: 0,
    borderLeftWidth: 0,
    borderRightWidth: 2,
    borderBottomWidth: 2,
    borderColor: "rgba(132,194,250,0.26)",
  },
  hudCoreInnerRing: {
    position: "absolute",
    width: 152,
    height: 152,
    borderRadius: 76,
    borderWidth: 2,
    borderColor: "rgba(176,226,255,0.42)",
  },
  hudCoreRipple: {
    position: "absolute",
    width: 260,
    height: 260,
    borderRadius: 130,
    borderWidth: 1,
    borderColor: "rgba(166,218,255,0.22)",
  },
  hudRadialLines: {
    position: "absolute",
    width: 280,
    height: 280,
    alignItems: "center",
    justifyContent: "center",
  },
  hudRadialLine: {
    position: "absolute",
    width: 1,
    height: 138,
    backgroundColor: "rgba(138,200,255,0.2)",
  },
  activeVoidFalloff: {
    position: "absolute",
    width: 342,
    height: 342,
    borderRadius: 171,
    backgroundColor: "rgba(12,20,34,0.035)",
  },
  activeVoidPredictiveTint: {
    position: "absolute",
    width: 188,
    height: 166,
    borderRadius: 104,
  },
  activeVoidFieldA: {
    position: "absolute",
    width: 188,
    height: 176,
    borderRadius: 98,
    overflow: "hidden",
    opacity: 0.7,
  },
  activeVoidFieldB: {
    position: "absolute",
    width: 152,
    height: 184,
    borderRadius: 94,
    overflow: "hidden",
    opacity: 0.58,
  },
  activeVoidDistortion: {
    position: "absolute",
    width: 80,
    height: 210,
    borderRadius: 48,
    backgroundColor: "rgba(128,190,255,0.035)",
  },
  activeVoidCore: {
    width: 84,
    height: 84,
    borderRadius: 42,
    backgroundColor: "rgba(82,164,228,0.62)",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 0 },
  },
  hudCoreBrightPoint: {
    position: "absolute",
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: "rgba(194,238,255,0.96)",
    shadowColor: "#9fd8ff",
    shadowOpacity: 0.86,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 0 },
  },
  archSection: {
    position: "absolute",
    zIndex: 1,
    borderRadius: 26,
    backgroundColor: "rgba(170,214,255,0.08)",
  },
  archSectionLeft: {
    left: 32,
    width: 110,
  },
  archSectionRight: {
    right: 34,
    width: 96,
    backgroundColor: "rgba(134,188,236,0.2)",
  },
  archSectionTop: {
    top: "20%",
    height: 74,
  },
  archSectionMid: {
    top: "39%",
    height: 88,
  },
  archSectionBottom: {
    top: "61%",
    height: 82,
  },
  energyLinkMain: {
    position: "absolute",
    top: "45%",
    left: "50%",
    marginLeft: -1,
    width: 1,
    height: 190,
    zIndex: 6,
    backgroundColor: "rgba(102,175,232,0.2)",
    borderRadius: 2,
  },
  energyLinkSide: {
    position: "absolute",
    top: "47%",
    right: 56,
    width: 120,
    height: 1,
    zIndex: 6,
    backgroundColor: "rgba(102,175,232,0.16)",
    borderRadius: 2,
    transform: [{ rotate: "-20deg" }],
  },
  predictiveGhostHost: {
    position: "absolute",
    left: "50%",
    top: "50%",
    marginLeft: -138,
    marginTop: -96,
    width: 276,
    minHeight: 170,
    zIndex: 7,
    alignItems: "center",
    justifyContent: "center",
  },
  predictiveGhostTint: {
    position: "absolute",
    shadowColor: "#7bc4ff",
    shadowOpacity: 0.16,
    shadowRadius: 32,
    shadowOffset: { width: 0, height: 0 },
  },
  predictiveGhostHintField: {
    position: "absolute",
    width: 216,
    height: 156,
    alignItems: "center",
    justifyContent: "center",
    gap: 12,
  },
  predictiveGhostHintArc: {
    width: 168,
    height: 34,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "rgba(156,210,255,0.22)",
    backgroundColor: "rgba(122,184,236,0.05)",
  },
  predictiveGhostHintArcMid: {
    width: 136,
    height: 28,
  },
  predictiveGhostHintArcTight: {
    width: 104,
    height: 22,
  },
  predictiveGhostFrame: {
    width: "100%",
    height: 168,
    borderRadius: 26,
    backgroundColor: "rgba(118,180,238,0.08)",
    borderWidth: 1,
    borderColor: "rgba(146,198,247,0.16)",
    overflow: "hidden",
  },
  predictiveGhostImageInner: {
    position: "absolute",
    top: 18,
    left: 18,
    right: 18,
    bottom: 18,
    borderRadius: 18,
    backgroundColor: "rgba(150,205,255,0.08)",
  },
  predictiveGhostVideo: {
    backgroundColor: "rgba(118,180,238,0.06)",
  },
  predictiveGhostShimmer: {
    position: "absolute",
    top: 0,
    bottom: 0,
    width: 48,
    borderRadius: 24,
    backgroundColor: "rgba(196,230,255,0.22)",
  },
  predictiveGhostTextBlock: {
    width: "90%",
    gap: 10,
  },
  predictiveGhostChatBlock: {
    alignItems: "stretch",
    gap: 8,
  },
  predictiveGhostTextLine: {
    flexDirection: "row",
    alignItems: "center",
    height: 10,
    borderRadius: 999,
    backgroundColor: "rgba(159,210,255,0.22)",
  },
  predictiveGhostListLine: {
    height: 12,
    paddingLeft: 18,
  },
  predictiveGhostStepLine: {
    height: 13,
    paddingLeft: 20,
  },
  predictiveGhostCodeLine: {
    height: 12,
    borderRadius: 6,
    backgroundColor: "rgba(142,196,255,0.18)",
  },
  predictiveGhostChatBubbleLeft: {
    alignSelf: "flex-start",
    height: 18,
    borderRadius: 12,
  },
  predictiveGhostChatBubbleRight: {
    alignSelf: "flex-end",
    height: 18,
    borderRadius: 12,
  },
  predictiveGhostListDot: {
    position: "absolute",
    left: 0,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "rgba(186,223,255,0.28)",
  },
  predictiveGhostStepBadge: {
    position: "absolute",
    left: 0,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "rgba(186,223,255,0.24)",
  },
  predictiveGhostPayment: {
    alignItems: "center",
    gap: 12,
  },
  predictiveGhostPill: {
    width: 180,
    height: 58,
    borderRadius: 22,
    backgroundColor: "rgba(144,204,255,0.14)",
  },
  predictiveGhostPillSmall: {
    width: 112,
    height: 18,
    borderRadius: 10,
    opacity: 0.7,
  },
  predictiveGhostPage: {
    width: "100%",
    height: 174,
    borderRadius: 22,
    backgroundColor: "rgba(118,180,238,0.07)",
    overflow: "hidden",
    padding: 14,
    gap: 10,
  },
  predictiveGhostPageBar: {
    width: "48%",
    height: 16,
    borderRadius: 8,
    backgroundColor: "rgba(165,218,255,0.16)",
  },
  predictiveGhostPageBody: {
    flex: 1,
    borderRadius: 14,
    backgroundColor: "rgba(165,218,255,0.10)",
  },
  flowOverlay: {
    position: "absolute",
    left: 50,
    right: 50,
    top: 22,
    zIndex: 7,
    borderRadius: 18,
    backgroundColor: "rgba(7,13,22,0.42)",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 4,
  },
  centerResultHost: {
    position: "absolute",
    left: "50%",
    top: "50%",
    marginLeft: -170,
    marginTop: -136,
    width: 340,
    zIndex: 9,
    alignItems: "center",
    justifyContent: "center",
  },
  centerResultHalo: {
    position: "absolute",
    width: 404,
    height: 404,
    borderRadius: 202,
    backgroundColor: "rgba(45,88,132,0.1)",
  },
  centerResultCard: {
    width: "100%",
    minHeight: 248,
    borderRadius: 28,
    backgroundColor: "rgba(8,15,24,0.62)",
    padding: 14,
    gap: 10,
    overflow: "hidden",
    shadowColor: "#000",
    shadowOpacity: 0.32,
    shadowRadius: 34,
    shadowOffset: { width: 0, height: 26 },
  },
  centerResultDistortion: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(102,175,232,0.08)",
  },
  centerResultHeader: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 10,
  },
  centerResultTitle: { color: browserTheme.text, fontSize: 13, fontWeight: "800" },
  centerResultSubtitle: { color: browserTheme.textMuted, fontSize: 11, marginTop: 2 },
  centerResultStatus: {
    color: browserTheme.textSoft,
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 0.8,
  },
  centerWorkingState: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    borderRadius: 14,
    backgroundColor: "rgba(10,18,29,0.58)",
    paddingHorizontal: 10,
    paddingVertical: 9,
  },
  centerWorkingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "rgba(131,201,255,0.96)",
  },
  centerWorkingText: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" },
  centerResultImage: {
    width: "100%",
    height: 232,
    borderRadius: 22,
    backgroundColor: "rgba(6,12,18,0.92)",
  },
  centerStreamWrap: {
    width: "100%",
    height: 240,
    borderRadius: 22,
    overflow: "hidden",
    backgroundColor: "rgba(4,8,14,0.98)",
  },
  centerStreamPlayer: {
    flex: 1,
    backgroundColor: "rgba(4,8,14,0.98)",
  },
  centerResultTextWrap: {
    maxHeight: 220,
    borderRadius: 16,
    backgroundColor: "rgba(8,16,27,0.78)",
  },
  centerResultTextContent: {
    paddingHorizontal: 12,
    paddingVertical: 11,
  },
  centerResultText: { color: browserTheme.textSoft, fontSize: 11, lineHeight: 17 },
  centerFallbackCard: {
    borderRadius: 16,
    backgroundColor: "rgba(9,16,26,0.56)",
    padding: 10,
    gap: 8,
  },
  centerFallbackThumb: {
    width: "100%",
    height: 170,
    borderRadius: 14,
    backgroundColor: "rgba(6,12,18,0.92)",
  },
  centerFallbackText: { color: browserTheme.textSoft, fontSize: 11, lineHeight: 16 },
  centerResultActions: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 6,
  },
  idlePresenceWrap: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 6,
    alignItems: "center",
    justifyContent: "center",
    gap: 14,
  },
  idleVoidPressable: {
    width: 340,
    height: 340,
    alignItems: "center",
    justifyContent: "center",
  },
  idleVoidFalloff: {
    position: "absolute",
    width: 360,
    height: 360,
    borderRadius: 180,
    backgroundColor: "rgba(38,74,108,0.1)",
  },
  idleVoidCore: {
    width: 176,
    height: 176,
    borderRadius: 88,
    overflow: "hidden",
    backgroundColor: "rgba(1,2,5,0.98)",
    alignItems: "center",
    justifyContent: "center",
    shadowColor: "#000",
    shadowOpacity: 0.72,
    shadowRadius: 44,
    shadowOffset: { width: 0, height: 0 },
  },
  idleVoidFieldA: {
    position: "absolute",
    width: 214,
    height: 214,
    borderRadius: 107,
    opacity: 0.78,
  },
  idleVoidFieldB: {
    position: "absolute",
    width: 196,
    height: 196,
    borderRadius: 98,
    opacity: 0.64,
  },
  idleVoidThinkingTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(123,197,255,0.14)",
  },
  idleVoidExecutionTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(92,221,255,0.14)",
  },
  idleVoidErrorTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(224,172,98,0.14)",
  },
  idleVoidShimmer: {
    position: "absolute",
    top: 0,
    bottom: 0,
    width: 54,
    borderRadius: 26,
    backgroundColor: "rgba(171,218,255,0.18)",
  },
  idleVoidCenter: {
    width: 88,
    height: 88,
    borderRadius: 44,
    backgroundColor: "rgba(4,7,12,0.98)",
    shadowColor: "#000",
    shadowOpacity: 0.74,
    shadowRadius: 28,
    shadowOffset: { width: 0, height: 0 },
  },
  idlePromptText: {
    marginTop: 132,
    color: browserTheme.textSoft,
    fontSize: 14,
    fontWeight: "700",
    letterSpacing: 0.2,
  },
  idleGhostRow: {
    marginTop: 4,
    alignItems: "center",
    gap: 4,
  },
  idleGhostHint: { color: browserTheme.textMuted, fontSize: 12, fontWeight: "600" },
  flowOverlayHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  flowOverlayTitle: { color: browserTheme.text, fontSize: 11, fontWeight: "800", flex: 1 },
  flowOverlayBody: { color: browserTheme.textSoft, fontSize: 10 },
  flowOverlayBodySecondary: { color: browserTheme.textMuted, fontSize: 9 },
  resultActionsRow: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginTop: 4 },
  resultActionBtn: {
    borderRadius: 999,
    backgroundColor: "rgba(37,61,92,0.78)",
    paddingHorizontal: 9,
    paddingVertical: 5,
  },
  resultActionText: { color: browserTheme.textSoft, fontSize: 10, fontWeight: "700" },
  flowStatusPill: { borderRadius: 999, borderWidth: 1, paddingHorizontal: 8, paddingVertical: 3 },
  statusRunning: { borderColor: "rgba(87,160,255,0.5)", backgroundColor: "rgba(87,160,255,0.14)" },
  statusSuccess: { borderColor: "rgba(47,210,132,0.55)", backgroundColor: "rgba(47,210,132,0.14)" },
  statusError: { borderColor: "rgba(250,82,82,0.55)", backgroundColor: "rgba(250,82,82,0.15)" },
  flowStatusText: { color: browserTheme.textSoft, fontSize: 10, fontWeight: "800" },
  windowField: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  taskWindow: {
    position: "absolute",
    left: "50%",
    top: "50%",
    marginLeft: -158,
    marginTop: -90,
    borderRadius: 26,
    backgroundColor: "rgba(11,19,31,0.58)",
    padding: 12,
    gap: 6,
    overflow: "hidden",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 24 },
  },
  taskWindowGlow: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(94,168,232,0.08)",
  },
  taskWindowWake: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(109,181,242,0.10)",
  },
  taskWindowDimmer: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(2,6,12,0.46)",
  },
  taskWindowPressure: {
    position: "absolute",
    left: 20,
    right: 20,
    bottom: -22,
    height: 44,
    borderRadius: 24,
    backgroundColor: "rgba(0,0,0,0.34)",
  },
  taskWindowHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 8 },
  taskWindowTitle: { color: browserTheme.text, fontSize: 12, fontWeight: "800", flex: 1 },
  taskWindowStatus: { color: browserTheme.textMuted, fontSize: 10, fontWeight: "700" },
  secondaryStreamWrap: { gap: 8 },
  secondaryStreamPlayer: {
    width: "100%",
    height: 132,
    borderRadius: 16,
    overflow: "hidden",
    backgroundColor: "rgba(4,8,14,0.98)",
  },
  taskWindowBody: { color: browserTheme.textSoft, fontSize: 11 },
  taskWindowHint: { color: browserTheme.textMuted, fontSize: 10 },
  taskMetaRow: { flexDirection: "row", gap: 8, marginTop: 2 },
  taskMetaText: {
    color: "rgba(202,222,244,0.72)",
    fontSize: 9,
    fontWeight: "800",
    letterSpacing: 0.8,
  },
  taskControls: { flexDirection: "row", gap: 8, marginTop: 4 },
  taskControlBtn: {
    borderRadius: 8,
    backgroundColor: "rgba(10,18,29,0.72)",
    paddingHorizontal: 9,
    paddingVertical: 5,
  },
  taskControlText: { color: browserTheme.textSoft, fontSize: 10, fontWeight: "700" },
  taskStack: {
    borderRadius: 12,
    backgroundColor: "rgba(9,16,26,0.34)",
    paddingHorizontal: 10,
    paddingVertical: 8,
    gap: 6,
  },
  taskStackTitle: { color: browserTheme.text, fontSize: 11, fontWeight: "700" },
  taskStackRow: { gap: 8, paddingRight: 6 },
  taskStackItem: {
    minWidth: 120,
    borderRadius: 10,
    backgroundColor: "rgba(10,18,29,0.58)",
    paddingHorizontal: 8,
    paddingVertical: 7,
    gap: 2,
  },
  taskStackItemFocused: { backgroundColor: "rgba(18,30,48,0.68)" },
  taskStackItemTitle: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" },
  taskStackItemSub: { color: browserTheme.textMuted, fontSize: 10 },
  contentCard: {
    borderRadius: 14,
    backgroundColor: "rgba(9,16,26,0.3)",
    padding: 8,
    gap: 3,
  },
  contentCardTitle: { color: browserTheme.textSoft, fontSize: 11, fontWeight: "700" },
  contentCardText: { color: browserTheme.textMuted, fontSize: 10 },
  flowShelf: { position: "absolute", left: 22, right: 22, bottom: 30, zIndex: 5 },
  flowShelfRow: { gap: 8, paddingRight: 6 },
  flowChip: {
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "rgba(112,176,236,0.16)",
    backgroundColor: "rgba(10,18,28,0.52)",
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  flowChipActive: { backgroundColor: "rgba(20,34,52,0.8)" },
  flowChipTitle: { color: "rgba(220,234,248,0.72)", fontSize: 11, fontWeight: "700", letterSpacing: 0.2 },
  bottomZone: {
    position: "absolute",
    left: "50%",
    bottom: 14,
    marginLeft: -154,
    width: 292,
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 6,
    zIndex: 4,
  },
  bottomAction: {
    width: 64,
    height: 64,
    borderRadius: 32,
    borderWidth: 1,
    borderColor: "rgba(146,210,255,0.28)",
    backgroundColor: "rgba(12,22,34,0.82)",
    alignItems: "center",
    justifyContent: "center",
    shadowColor: "#000",
    shadowOpacity: 0.24,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 14 },
  },
  bottomActionInner: {
    position: "absolute",
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: "rgba(136,204,255,0.12)",
  },
  bottomActionGlyph: {
    color: "rgba(214,240,255,0.96)",
    fontSize: 14,
    fontWeight: "800",
    marginBottom: 2,
  },
  bottomActionText: { color: "rgba(228,240,252,0.82)", fontSize: 9, fontWeight: "700", textAlign: "center", letterSpacing: 0.25 },
});
