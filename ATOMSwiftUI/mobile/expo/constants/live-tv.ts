export type LicensedLiveProvider = {
  id: string;
  name: string;
  kind: "licensed_demo";
  trustLabel: string;
};

export type LicensedLiveChannel = {
  id: string;
  title: string;
  providerId: string;
  providerName: string;
  streamUrl: string;
  posterUrl: string;
  description: string;
};

export const LICENSED_LIVE_PROVIDERS: LicensedLiveProvider[] = [
  {
    id: "apple_hls_demo",
    name: "Apple HLS Demo",
    kind: "licensed_demo",
    trustLabel: "Official sample stream connector",
  },
  {
    id: "mux_demo",
    name: "Mux Demo",
    kind: "licensed_demo",
    trustLabel: "Official demo stream connector",
  },
];

export const LICENSED_LIVE_CHANNELS: LicensedLiveChannel[] = [
  {
    id: "world-feed",
    title: "World Feed",
    providerId: "apple_hls_demo",
    providerName: "Apple HLS Demo",
    streamUrl: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/master.m3u8",
    posterUrl: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80",
    description: "Licensed sample channel for live playback testing.",
  },
  {
    id: "news-desk",
    title: "News Desk",
    providerId: "mux_demo",
    providerName: "Mux Demo",
    streamUrl: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
    posterUrl: "https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=1200&q=80",
    description: "Licensed demo connector with continuous live playback.",
  },
  {
    id: "sport-view",
    title: "Sport View",
    providerId: "apple_hls_demo",
    providerName: "Apple HLS Demo",
    streamUrl: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
    posterUrl: "https://images.unsplash.com/photo-1547347298-4074fc3086f0?auto=format&fit=crop&w=1200&q=80",
    description: "Licensed sample sports-style feed for multiview testing.",
  },
  {
    id: "culture-live",
    title: "Culture Live",
    providerId: "mux_demo",
    providerName: "Mux Demo",
    streamUrl: "https://test-streams.mux.dev/test_001/stream.m3u8",
    posterUrl: "https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1200&q=80",
    description: "Licensed demo lifestyle feed for secondary windows.",
  },
];

export function resolveLicensedChannel(query?: string) {
  const normalized = (query || "").trim().toLowerCase();
  if (!normalized) return LICENSED_LIVE_CHANNELS[0];

  return (
    LICENSED_LIVE_CHANNELS.find((channel) => channel.title.toLowerCase() === normalized) ||
    LICENSED_LIVE_CHANNELS.find((channel) => channel.title.toLowerCase().includes(normalized)) ||
    LICENSED_LIVE_CHANNELS.find((channel) => normalized.includes(channel.title.toLowerCase()))
  );
}

export function buildLicensedLivePayload(mode: "single" | "multiview" = "single", preferredChannel?: string) {
  const primary = resolveLicensedChannel(preferredChannel) || LICENSED_LIVE_CHANNELS[0];
  const ordered = [primary, ...LICENSED_LIVE_CHANNELS.filter((channel) => channel.id !== primary.id)];
  const streams = (mode === "multiview" ? ordered.slice(0, 4) : ordered.slice(0, 1)).map((channel, index) => ({
    id: channel.id,
    title: channel.title,
    provider_id: channel.providerId,
    provider_name: channel.providerName,
    stream_url: channel.streamUrl,
    poster_url: channel.posterUrl,
    description: channel.description,
    licensed: true,
    muted: index !== 0,
  }));

  return {
    licensed_only: true,
    mode,
    providers: LICENSED_LIVE_PROVIDERS,
    primary_stream_id: streams[0]?.id || "",
    streams,
  };
}
