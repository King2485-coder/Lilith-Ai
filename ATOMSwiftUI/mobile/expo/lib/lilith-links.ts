import { CommandExecutionResult, CommandRuntimeContext } from "../core/commands/types";

export type LilithLinkRoute = "view" | "run" | "session" | "site";
export type LilithLinkVisibility = "public" | "private";

export type LilithLinkRecord = {
  id: string;
  route: LilithLinkRoute;
  type: string;
  payload: Record<string, unknown>;
  metadata: Record<string, unknown>;
  permissions: {
    visibility: LilithLinkVisibility;
    allowAnonymous: boolean;
  };
  expiresAt?: number;
  createdAt: number;
};

export type LilithLinkBundle = {
  id: string;
  route: LilithLinkRoute;
  privateUrl: string;
  publicUrl: string;
  visibility: LilithLinkVisibility;
};

type LinkRegistry = Record<string, LilithLinkRecord>;

const LINK_STORAGE_KEY = "lilith.link.registry.v1";
const DEFAULT_ORIGIN = "http://127.0.0.1:8081";

function getStorage(): Storage | null {
  if (typeof globalThis === "undefined" || !("localStorage" in globalThis)) return null;
  return globalThis.localStorage;
}

function readRegistry(): LinkRegistry {
  const storage = getStorage();
  if (!storage) return {};
  try {
    const raw = storage.getItem(LINK_STORAGE_KEY);
    if (!raw) return {};
    return JSON.parse(raw) as LinkRegistry;
  } catch {
    return {};
  }
}

function writeRegistry(registry: LinkRegistry) {
  const storage = getStorage();
  if (!storage) return;
  try {
    storage.setItem(LINK_STORAGE_KEY, JSON.stringify(registry));
  } catch {
    // Ignore persistence failures; the current-session link can still render from URL data.
  }
}

function toRoutePath(route: LilithLinkRoute, id: string) {
  return `/${route}/${id}`;
}

function encodeSnapshot(record: LilithLinkRecord) {
  return encodeURIComponent(JSON.stringify(record));
}

function decodeSnapshot(value?: string | string[]) {
  if (!value) return null;
  const input = Array.isArray(value) ? value[0] : value;
  if (!input) return null;
  try {
    return JSON.parse(decodeURIComponent(input)) as LilithLinkRecord;
  } catch {
    return null;
  }
}

export function createLilithId(prefix: string) {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function getLilithOrigin() {
  if (typeof globalThis !== "undefined" && "location" in globalThis && globalThis.location?.origin) {
    return globalThis.location.origin;
  }
  return DEFAULT_ORIGIN;
}

export function storeLilithLinkRecord(record: LilithLinkRecord) {
  const registry = readRegistry();
  registry[record.id] = record;
  writeRegistry(registry);
  return record;
}

export function resolveLilithLinkRecord(route: LilithLinkRoute, id: string, snapshot?: string | string[]) {
  const registry = readRegistry();
  const stored = registry[id];
  if (stored && stored.route === route) {
    if (!stored.expiresAt || stored.expiresAt > Date.now()) return stored;
  }
  const decoded = decodeSnapshot(snapshot);
  if (decoded?.route === route && decoded.id === id) return decoded;
  return null;
}

export function buildLilithLinkBundle(record: LilithLinkRecord): LilithLinkBundle {
  const origin = getLilithOrigin();
  const path = toRoutePath(record.route, record.id);
  return {
    id: record.id,
    route: record.route,
    privateUrl: `${origin}${path}`,
    publicUrl: `${origin}${path}?data=${encodeSnapshot(record)}`,
    visibility: record.permissions.visibility,
  };
}

function normalizePayload(result: CommandExecutionResult) {
  if (!result.payload || typeof result.payload !== "object") return {};
  const payload = result.payload as Record<string, unknown>;
  if (payload.output_payload && typeof payload.output_payload === "object") {
    return { ...payload, ...(payload.output_payload as Record<string, unknown>) };
  }
  return payload;
}

function extractSitePayload(payload: Record<string, unknown>) {
  const html = payload.html as string | undefined;
  const pageUrl =
    (payload.page_url as string | undefined) ||
    (payload.pageUrl as string | undefined) ||
    (payload.url as string | undefined);
  return { html, pageUrl };
}

export function createLinksForResult(
  result: CommandExecutionResult,
  command: string,
  runtime: CommandRuntimeContext,
  sessionId: string
) {
  const payload = normalizePayload(result);
  const bundles: LilithLinkBundle[] = [];
  const baseMetadata = {
    title: result.title,
    subtitle: result.subtitle,
    trace_id: result.trace_id,
    operation_id: result.operation_id,
    command,
    screen: runtime.activeScreen,
    session_id: sessionId,
  };

  const viewRecord = storeLilithLinkRecord({
    id: createLilithId("view"),
    route: "view",
    type: result.type,
    payload,
    metadata: baseMetadata,
    permissions: { visibility: "private", allowAnonymous: false },
    createdAt: Date.now(),
  });
  bundles.push(buildLilithLinkBundle(viewRecord));

  if (result.type === "workflow.completed" || command.toLowerCase().includes("workflow")) {
    const runRecord = storeLilithLinkRecord({
      id: createLilithId("run"),
      route: "run",
      type: "workflow",
      payload: { ...payload, command },
      metadata: baseMetadata,
      permissions: { visibility: "private", allowAnonymous: false },
      createdAt: Date.now(),
    });
    bundles.push(buildLilithLinkBundle(runRecord));
  }

  const sitePayload = extractSitePayload(payload);
  if (sitePayload.html || sitePayload.pageUrl) {
    const siteRecord = storeLilithLinkRecord({
      id: createLilithId("site"),
      route: "site",
      type: "page",
      payload: { ...payload, ...sitePayload },
      metadata: baseMetadata,
      permissions: { visibility: "public", allowAnonymous: true },
      createdAt: Date.now(),
    });
    bundles.push(buildLilithLinkBundle(siteRecord));
  }

  const sessionRecord = storeLilithLinkRecord({
    id: createLilithId("session"),
    route: "session",
    type: "session",
    payload: {
      activeScreen: runtime.activeScreen,
      activeConversationUserId: runtime.activeConversationUserId,
      activeBrowserUrl: runtime.activeBrowserUrl,
      activeSelectedContent: runtime.activeSelectedContent,
      preferredCurrency: runtime.preferredCurrency,
      vaultLocked: runtime.vaultLocked,
      command,
    },
    metadata: {
      ...baseMetadata,
      label: `Session ${sessionId}`,
    },
    permissions: { visibility: "private", allowAnonymous: false },
    createdAt: Date.now(),
  });
  bundles.push(buildLilithLinkBundle(sessionRecord));

  return bundles;
}

export function mergeResultLinks(result: CommandExecutionResult, bundles: LilithLinkBundle[]) {
  const basePayload = result.payload && typeof result.payload === "object" ? (result.payload as Record<string, unknown>) : {};
  return {
    ...result,
    payload: {
      ...basePayload,
      lilith_links: bundles,
      primary_link: bundles[0]?.publicUrl || bundles[0]?.privateUrl || "",
    },
  };
}
