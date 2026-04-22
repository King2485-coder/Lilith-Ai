import React, { useCallback, useState } from "react";
import { Text, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, StatPill, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

type MetricState = {
  requests_total: number;
  errors_total: number;
  requests_per_second_1m: number;
  latency_avg_ms: number;
  latency_p95_ms: number;
  error_rate_percent: number;
};
type AlertItem = { id: string; title: string; level: string; source: string };
type LogItem = { timestamp: number; level: string; source: string; message: string };

export default function ObservabilityDashboardScreen() {
  const { apiBase, token } = useSession();
  const [metrics, setMetrics] = useState<MetricState | null>(null);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [logs, setLogs] = useState<LogItem[]>([]);
  const [status, setStatus] = useState("Waiting for telemetry.");

  const refresh = useCallback(async () => {
    try {
      const [m, a, l] = await Promise.all([
        apiRequest<MetricState>(apiBase, token, "/api/v1/system/metrics"),
        apiRequest<{ items: AlertItem[] }>(apiBase, token, "/api/v1/system/alerts"),
        apiRequest<{ items: LogItem[] }>(apiBase, token, "/api/v1/system/logs"),
      ]);
      setMetrics(m);
      setAlerts(a.items || []);
      setLogs(l.items || []);
      setStatus("Telemetry live.");
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token]);

  return (
    <EnvironmentShell
      screenKey="observability-dashboard"
      title="Observability"
      subtitle="Live metrics, logs, alerts, and event visibility for runtime control."
      leftActions={buildRailActions("left", "observability-dashboard")}
      rightActions={buildRailActions("right", "observability-dashboard")}
      bottomActions={buildRailActions("bottom", "observability-dashboard")}
    >
      <SurfaceScroll>
        <SectionCard title="Metrics" subtitle={status} right={<ActionChip label="Refresh" onPress={refresh} />}>
          <View style={ui.rowWrap}>
            <StatPill label="Req/s" value={`${metrics?.requests_per_second_1m ?? 0}`} />
            <StatPill label="Latency avg" value={`${metrics?.latency_avg_ms ?? 0}ms`} />
            <StatPill label="Latency p95" value={`${metrics?.latency_p95_ms ?? 0}ms`} />
            <StatPill label="Errors" value={`${metrics?.errors_total ?? 0}`} />
          </View>
        </SectionCard>

        <SectionCard title="Alerts">
          {alerts.length === 0 ? <Text style={ui.bodyText}>No active alerts.</Text> : null}
          {alerts.map((alert) => (
            <View key={alert.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>[{alert.level}] {alert.title}</Text>
              <Text style={ui.bodyText}>{alert.source}</Text>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Live Logs">
          {logs.slice(0, 18).map((log, idx) => (
            <View key={`${log.timestamp}-${idx}`} style={{ borderRadius: 10, padding: 9, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>[{log.level}] {log.source}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{log.message}</Text>
            </View>
          ))}
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
