from __future__ import annotations

import statistics
import threading
import time
from collections import deque
from typing import Any


class ObservabilityState:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.started_at = time.time()
        self.total_requests = 0
        self.error_requests = 0
        self.request_latencies_ms: deque[int] = deque(maxlen=4000)
        self.recent_requests: deque[tuple[float, int]] = deque(maxlen=4000)  # (timestamp, status_code)
        self.logs: deque[dict[str, Any]] = deque(maxlen=1000)

    def add_request(self, *, status_code: int, latency_ms: int) -> None:
        now = time.time()
        with self._lock:
            self.total_requests += 1
            if status_code >= 400:
                self.error_requests += 1
            self.request_latencies_ms.append(latency_ms)
            self.recent_requests.append((now, status_code))

    def add_log(self, *, level: str, message: str, source: str, context: dict[str, Any] | None = None) -> None:
        with self._lock:
            self.logs.appendleft(
                {
                    "timestamp": time.time(),
                    "level": level.upper(),
                    "message": message[:500],
                    "source": source[:120],
                    "context": context or {},
                }
            )

    def _last_minute_rps(self) -> float:
        now = time.time()
        window_start = now - 60
        count = 0
        for ts, _ in self.recent_requests:
            if ts >= window_start:
                count += 1
        return round(count / 60.0, 3)

    def _error_rate_percent(self) -> float:
        recent = list(self.recent_requests)[-300:]
        if not recent:
            return 0.0
        errors = len([1 for _, code in recent if code >= 400])
        return round((errors / len(recent)) * 100, 2)

    def metrics_snapshot(self) -> dict[str, Any]:
        with self._lock:
            latencies = list(self.request_latencies_ms)
            avg_latency = round(statistics.fmean(latencies), 2) if latencies else 0.0
            p95_latency = round(float(statistics.quantiles(latencies, n=100)[94]), 2) if len(latencies) >= 100 else (max(latencies) if latencies else 0.0)
            return {
                "uptime_seconds": int(time.time() - self.started_at),
                "requests_total": self.total_requests,
                "errors_total": self.error_requests,
                "error_rate_percent": self._error_rate_percent(),
                "requests_per_second_1m": self._last_minute_rps(),
                "latency_avg_ms": avg_latency,
                "latency_p95_ms": p95_latency,
            }

    def logs_snapshot(self, limit: int = 200) -> list[dict[str, Any]]:
        with self._lock:
            return list(self.logs)[: max(1, min(limit, 500))]


observability_state = ObservabilityState()

