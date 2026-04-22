"""
Zeroconf/mDNS service registration for Lilith backend.

Registers a _http._tcp.local. service named "lilith" so iOS clients
can discover the local dev server via Bonjour (NWBrowser) instantly
without subnet scanning.

Usage:
    from backend.realtime.zeroconf_service import start_zeroconf, stop_zeroconf

    # Call start_zeroconf() when the app starts and stop_zeroconf() on shutdown.
    # Both are already wired into dev_ws_app.py via the FastAPI lifespan hook.

Requirements:
    pip install zeroconf
"""

from __future__ import annotations

import socket
import logging
from typing import Optional

try:
    from zeroconf import ServiceInfo, Zeroconf
    _ZEROCONF_AVAILABLE = True
except ImportError:
    _ZEROCONF_AVAILABLE = False

logger = logging.getLogger(__name__)

_zeroconf: Optional["Zeroconf"] = None
_service_info: Optional["ServiceInfo"] = None

SERVICE_TYPE = "_http._tcp.local."
SERVICE_NAME = "lilith._http._tcp.local."
SERVICE_PORT = 8000


def _resolve_local_ip() -> str:
    """Return the best non-loopback IPv4 address for this machine."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def start_zeroconf(port: int = SERVICE_PORT) -> None:
    """Register the Lilith Bonjour service on the local network."""
    global _zeroconf, _service_info

    if not _ZEROCONF_AVAILABLE:
        logger.warning(
            "zeroconf package not installed. "
            "Run `pip install zeroconf` to enable Bonjour discovery. "
            "iOS clients will fall back to cloud URL."
        )
        return

    ip = _resolve_local_ip()

    _service_info = ServiceInfo(
        SERVICE_TYPE,
        SERVICE_NAME,
        addresses=[socket.inet_aton(ip)],
        port=port,
        properties={"version": "1", "app": "lilith"},
        server=f"{socket.gethostname()}.local.",
    )

    _zeroconf = Zeroconf()
    _zeroconf.register_service(_service_info)
    logger.info("Bonjour: registered '%s' at %s:%d", SERVICE_NAME, ip, port)


def stop_zeroconf() -> None:
    """Unregister the Bonjour service on shutdown."""
    global _zeroconf, _service_info

    if _zeroconf is not None and _service_info is not None:
        try:
            _zeroconf.unregister_service(_service_info)
            _zeroconf.close()
            logger.info("Bonjour: service unregistered.")
        except Exception as exc:
            logger.warning("Bonjour: error during shutdown – %s", exc)
        finally:
            _zeroconf = None
            _service_info = None
