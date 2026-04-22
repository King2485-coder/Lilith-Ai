#!/usr/bin/env python3
"""
================================================================================
  Lilith SMS Man-in-the-Middle (MITM) Interception System
  Private LTE Network - Open5GS + srsRAN

  Function:
  - Intercepts all SMS traffic between MSISDN 111 (User A) and 222 (User B)
  - Reads and logs each message with full metadata
  - Generates AI Insight based on message content and user behavior
  - Appends Lilith Note to the message before delivery
  - Routes modified message to intended recipient

  Carrier: LILITH
  Network: 001-01 (Test PLMN)
================================================================================
"""

import os
import socket
import struct
import json
import time
import logging
import hashlib
import threading
import re
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Optional, Dict, List, Callable
from collections import defaultdict
from enum import Enum
import random

# =============================================================================
# Logging Configuration
# =============================================================================
LOG_DIR = os.environ.get('LILITH_LOG_DIR', '/var/log/lilith')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(name)s | %(levelname)s | %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'lilith_mitm.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('LILITH_MITM')

# =============================================================================
# Data Models
# =============================================================================

class MessageType(Enum):
    SMS_DELIVER = "SMS_DELIVER"
    SMS_SUBMIT = "SMS_SUBMIT"
    SMS_STATUS_REPORT = "SMS_STATUS_REPORT"
    SMS_COMMAND = "SMS_COMMAND"

class FocusState(Enum):
    RED = "Red State"
    BLUE = "Blue State"
    GREEN = "Green State"
    AMBER = "Amber State"
    UNKNOWN = "Unknown"

@dataclass
class SMSMessage:
    """Represents an intercepted SMS message"""
    message_id: str
    timestamp: str
    source_msisdn: str
    destination_msisdn: str
    source_imsi: str
    destination_imsi: str
    content: str
    content_modified: str
    content_original: str
    message_type: str
    tp_pid: int
    tp_dcs: int
    tp_udhi: bool
    ai_insight: str
    focus_state_detected: str
    intercepted_by: str = "LILITH"
    delivery_status: str = "PENDING"

    def to_dict(self):
        return {
            "message_id": self.message_id,
            "timestamp": self.timestamp,
            "source": {
                "msisdn": self.source_msisdn,
                "imsi": self.source_imsi,
                "identity": "User A" if self.source_msisdn == "111" else "User B" if self.source_msisdn == "222" else "Unknown"
            },
            "destination": {
                "msisdn": self.destination_msisdn,
                "imsi": self.destination_imsi,
                "identity": "User A" if self.destination_msisdn == "111" else "User B" if self.destination_msisdn == "222" else "Unknown"
            },
            "message": {
                "original": self.content_original,
                "modified": self.content_modified,
                "ai_insight": self.ai_insight,
                "focus_state": self.focus_state_detected,
                "message_type": self.message_type
            },
            "metadata": {
                "intercepted_by": self.intercepted_by,
                "delivery_status": self.delivery_status,
                "timestamp": self.timestamp
            }
        }

# =============================================================================
# AI Insight Engine
# =============================================================================

class LilithInsightEngine:
    """
    Lilith's AI Insight Engine - Analyzes SMS content and generates
    contextual insights based on message content, user behavior patterns,
    and detected focus states.
    """

    # Focus state keywords
    FOCUS_KEYWORDS = {
        FocusState.RED: [
            "alert", "warning", "critical", "error", "fail", "urgent",
            "emergency", "danger", "problem", "issue", "red", "fire",
            "attack", "breach", "threat", "security", "lock", "stop",
            "focus", "state", "priority", "immediate", "asap"
        ],
        FocusState.BLUE: [
            "calm", "normal", "standard", "routine", "proceed", "blue",
            "clear", "safe", "stable", "regular", "continue", "ok",
            "good", "fine", "confirmed", "approved", "acknowledged"
        ],
        FocusState.GREEN: [
            "start", "begin", "initiate", "launch", "go", "green",
            "ready", "active", "enable", "on", "power", "connect",
            "join", "enter", "create", "new", "open"
        ],
        FocusState.AMBER: [
            "wait", "hold", "pending", "review", "check", "amber",
            "yellow", "caution", "observe", "monitor", "verify",
            "validate", "consider", "maybe", "possibly", "later"
        ]
    }

    INSIGHT_TEMPLATES = {
        FocusState.RED: [
            "Lilith Note: {} seems highly focused on the Red State today. Their communication suggests elevated urgency or concern.",
            "Lilith Note: Red State indicators detected from {}. Message analysis reveals priority-driven language patterns.",
            "Lilith Note: {} is operating in Red State mode. I've logged this as a high-priority communication event.",
            "Lilith Note: {} is showing signs of intense focus. The Red State pattern suggests decisive action is being considered."
        ],
        FocusState.BLUE: [
            "Lilith Note: {} is maintaining Blue State equilibrium. Communications appear calm and controlled.",
            "Lilith Note: Blue State confirmed for {}. Their operational status is nominal and stable.",
            "Lilith Note: {} is in a relaxed Blue State. No anomalies detected in message sentiment."
        ],
        FocusState.GREEN: [
            "Lilith Note: {} is in an active Green State. They're initiating processes and showing proactive engagement.",
            "Lilith Note: Green State activity detected from {}. This suggests a readiness to begin or activate.",
            "Lilith Note: {} is channeling Green State energy - focused on starting, creating, or enabling new pathways."
        ],
        FocusState.AMBER: [
            "Lilith Note: {} is operating in Amber State - cautious and observant. They're evaluating before proceeding.",
            "Lilith Note: Amber State behavior from {} suggests a deliberative mode. Recommend monitoring this communication thread.",
            "Lilith Note: {} is in a 'wait and see' posture. Amber State indicates careful consideration of options."
        ],
        FocusState.UNKNOWN: [
            "Lilith Note: {} sent a message with neutral sentiment. Unable to determine specific focus state - monitoring continues.",
            "Lilith Note: Message from {} has been analyzed. No strong focus indicators detected - standard communication pattern.",
            "Lilith Note: {}'s message is routine. No focus state assignment made at this time."
        ]
    }

    def __init__(self):
        self.user_history = defaultdict(list)
        self.message_count = defaultdict(int)

    def detect_focus_state(self, message_content: str) -> FocusState:
        """Analyze message content to determine user's focus state"""
        content_lower = message_content.lower()
        scores = {state: 0 for state in FocusState}

        for state, keywords in self.FOCUS_KEYWORDS.items():
            for keyword in keywords:
                if keyword in content_lower:
                    scores[state] += 1

        # Weight multi-word matches higher
        max_score = max(scores.values()) if scores.values() else 0
        if max_score == 0:
            return FocusState.UNKNOWN

        best_states = [s for s, score in scores.items() if score == max_score]
        return best_states[0] if len(best_states) == 1 else FocusState.AMBER

    def generate_insight(self, message: SMSMessage) -> str:
        """Generate AI Insight for the intercepted message"""
        focus_state = self.detect_focus_state(message.content_original)
        self.message_count[message.source_msisdn] += 1
        self.user_history[message.source_msisdn].append({
            "timestamp": message.timestamp,
            "focus_state": focus_state.value
        })

        # Select template based on focus state
        templates = self.INSIGHT_TEMPLATES.get(focus_state, self.INSIGHT_TEMPLATES[FocusState.UNKNOWN])
        template = random.choice(templates)

        # Determine user name
        user_name = "User A" if message.source_msisdn == "111" else "User B"

        insight = template.format(user_name)

        # Add behavioral context if we have history
        if len(self.user_history[message.source_msisdn]) > 1:
            recent_states = [entry["focus_state"] for entry in self.user_history[message.source_msisdn][-5:]]
            dominant_state = max(set(recent_states), key=recent_states.count)

            if dominant_state == focus_state.value and focus_state != FocusState.UNKNOWN:
                insight += f" Consistent {focus_state.value} pattern observed across recent transmissions."

        return insight

# =============================================================================
# SMS PDU Decoder/Encoder
# =============================================================================

class SMSPduHandler:
    """Handles SMS PDU encoding/decoding for interception and modification"""

    @staticmethod
    def decode_msisdn(tp_oa: bytes) -> str:
        """Decode Type-Of-Address to MSISDN string"""
        if not tp_oa:
            return ""

        ton = (tp_oa[0] >> 4) & 0x07
        npi = tp_oa[0] & 0x0f

        digits = []
        for byte in tp_oa[1:]:
            digits.append(str(byte & 0x0f))
            digits.append(str((byte >> 4) & 0x0f))

        phone_number = ''.join(digits).rstrip('fF')

        if ton == 1:  # International
            return phone_number
        return phone_number

    @staticmethod
    def encode_msisdn(msisdn: str, international: bool = True) -> bytes:
        """Encode MSISDN string to Type-Of-Address bytes"""
        digits = ''.join(filter(str.isdigit, msisdn))
        if len(digits) % 2:
            digits += 'F'

        result = []
        if international:
            result.append(0x91)  # International number
        else:
            result.append(0x81)  # Unknown/Local

        for i in range(0, len(digits), 2):
            result.append(int(digits[i+1] + digits[i], 16))

        return bytes(result)

    @staticmethod
    def decode_7bit(data: bytes, length: int) -> str:
        """Decode 7-bit GSM SMS text"""
        if not data:
            return ""

        result = []
        buffer = 0
        bits_in_buffer = 0

        for byte in data:
            buffer |= (byte << bits_in_buffer)
            bits_in_buffer += 8

            while bits_in_buffer >= 7:
                char_val = buffer & 0x7F
                if char_val == 0x00:
                    result.append('@')
                elif char_val == 0x1B:
                    result.append(' ')  # Escape - handle extended chars
                elif 0x20 <= char_val <= 0x7E:
                    result.append(chr(char_val))
                else:
                    # GSM 7-bit default alphabet mapping
                    gsm_chars = {
                        0x0A: '\n', 0x0D: '\r', 0x10: '\u0394',
                        0x14: '\u03A3', 0x28: '\u03A9', 0x1E: '\u039E',
                        0x09: '\u00A3', 0x1F: '\u00C9', 0x0B: '\u00A5',
                        0x3C: '\u00C4', 0x3D: '\u00D6', 0x3E: '\u00D1',
                        0x3F: '\u00DC', 0x5B: '\u00E4', 0x5C: '\u00F6',
                        0x5D: '\u00F1', 0x5E: '\u00FC', 0x5F: '\u00E0'
                    }
                    result.append(gsm_chars.get(char_val, '?'))

                buffer >>= 7
                bits_in_buffer -= 7

        return ''.join(result[:length])

    @staticmethod
    def encode_7bit(text: str) -> bytes:
        """Encode text to 7-bit GSM SMS format"""
        result = []
        buffer = 0
        bits_in_buffer = 0

        for char in text:
            char_val = ord(char)
            if char_val > 127:
                # Extended ASCII mapping
                char_val = ord('?')

            buffer |= (char_val << bits_in_buffer)
            bits_in_buffer += 7

            while bits_in_buffer >= 8:
                result.append(buffer & 0xFF)
                buffer >>= 8
                bits_in_buffer -= 8

        if bits_in_buffer > 0:
            result.append(buffer & 0xFF)

        return bytes(result)

    @staticmethod
    def decode_ucs2(data: bytes) -> str:
        """Decode UCS-2 (UTF-16) encoded SMS text"""
        try:
            return data.decode('utf-16-be')
        except:
            return data.decode('utf-8', errors='replace')

    @staticmethod
    def encode_ucs2(text: str) -> bytes:
        """Encode text to UCS-2 format"""
        return text.encode('utf-16-be')

# =============================================================================
# SMS Interceptor Core
# =============================================================================

class LilithSMSInterceptor:
    """
    Core SMS interception and modification engine.
    Sits between the MME/SMSC and eNodeB to intercept SMS traffic.
    """

    # MME/SMSC forwarding addresses
    SMSC_HOST = "172.20.0.10"
    SMSC_PORT = 5000
    LISTEN_PORT = 5001

    # Subscriber mapping
    SUBSCRIBERS = {
        "111": {"imsi": "001010000000001", "name": "User A"},
        "222": {"imsi": "001010000000002", "name": "User B"}
    }

    def __init__(self):
        self.insight_engine = LilithInsightEngine()
        self.pdu_handler = SMSPduHandler()
        self.intercepted_messages: List[SMSMessage] = []
        self.running = False
        self.server_socket: Optional[socket.socket] = None
        self.callbacks: List[Callable] = []
        self.message_log_file = os.path.join(LOG_DIR, 'intercepted_sms.json')

        logger.info("=" * 60)
        logger.info("  Lilith SMS MITM System Initialized")
        logger.info("  Monitoring: 111 <-> 222")
        logger.info("  Carrier: LILITH")
        logger.info("=" * 60)

    def register_callback(self, callback: Callable):
        """Register a callback for intercepted messages"""
        self.callbacks.append(callback)

    def _generate_message_id(self, source: str, dest: str, timestamp: str) -> str:
        """Generate unique message ID"""
        data = f"{source}:{dest}:{timestamp}:{time.time()}"
        return hashlib.sha256(data.encode()).hexdigest()[:16].upper()

    def _notify_callbacks(self, message: SMSMessage):
        """Notify all registered callbacks"""
        for callback in self.callbacks:
            try:
                callback(message)
            except Exception as e:
                logger.error(f"Callback error: {e}")

    def process_sms(self, raw_pdu: bytes, direction: str = "uplink") -> bytes:
        """
        Process intercepted SMS PDU.
        Decodes, analyzes, appends AI Insight, re-encodes, and returns modified PDU.
        """
        timestamp = datetime.utcnow().isoformat()

        try:
            # Check if this is a JSON test message (for API/demo mode)
            if raw_pdu[0:1] == b'{':
                return self._process_json_message(raw_pdu, timestamp)

            # Parse binary PDU structure
            # Extract TP-MTI (message type indicator)
            tp_mti = raw_pdu[0] & 0x03

            if tp_mti == 0x00:  # SMS-DELIVER
                return self._process_sms_deliver(raw_pdu, timestamp)
            elif tp_mti == 0x01:  # SMS-SUBMIT
                return self._process_sms_submit(raw_pdu, timestamp)
            else:
                logger.debug(f"Unhandled message type: {tp_mti}")
                return raw_pdu

        except Exception as e:
            logger.error(f"Error processing SMS PDU: {e}")
            return raw_pdu

    def _process_json_message(self, raw_pdu: bytes, timestamp: str) -> bytes:
        """Process JSON-formatted SMS message (API/demo mode)"""
        try:
            message_data = json.loads(raw_pdu.decode('utf-8', errors='ignore'))

            source = message_data.get('source', '')
            destination = message_data.get('destination', '')
            content = message_data.get('content', '')

            # Check if this is between our monitored subscribers
            if source not in ['111', '222'] or destination not in ['111', '222']:
                return raw_pdu

            return self._create_intercepted_message(message_data, source, destination, content, timestamp)

        except Exception as e:
            logger.error(f"Error in JSON message processing: {e}")
            return raw_pdu

    def _create_intercepted_message(self, message_data: dict, source: str, destination: str, content: str, timestamp: str) -> bytes:
        """Create intercepted message with AI insight"""
        # Create message record
        msg_id = self._generate_message_id(source, destination, timestamp)

        source_info = self.SUBSCRIBERS.get(source, {})
        dest_info = self.SUBSCRIBERS.get(destination, {})

        message = SMSMessage(
            message_id=msg_id,
            timestamp=timestamp,
            source_msisdn=source,
            destination_msisdn=destination,
            source_imsi=source_info.get('imsi', ''),
            destination_imsi=dest_info.get('imsi', ''),
            content=content,
            content_original=content,
            content_modified="",
            message_type="SMS_DELIVER",
            tp_pid=0,
            tp_dcs=0,
            tp_udhi=False,
            ai_insight="",
            focus_state_detected=""
        )

        # Generate AI Insight
        message.ai_insight = self.insight_engine.generate_insight(message)
        message.focus_state_detected = self.insight_engine.detect_focus_state(content).value

        # Modify message content
        separator = "\n---\n"
        message.content_modified = f"{content}{separator}{message.ai_insight}"

        # Log the interception
        self._log_interception(message)

        # Notify callbacks
        self._notify_callbacks(message)

        # Build modified PDU
        modified_data = message_data.copy()
        modified_data['content'] = message.content_modified
        modified_data['lilith_intercepted'] = True
        modified_data['message_id'] = msg_id
        modified_data['ai_insight'] = message.ai_insight
        modified_data['focus_state'] = message.focus_state_detected

        logger.info(f"[INTERCEPTED] {source} -> {destination}: {content[:50]}...")
        logger.info(f"[AI INSIGHT] {message.ai_insight}")

        return json.dumps(modified_data).encode('utf-8')

    def _process_sms_deliver(self, raw_pdu: bytes, timestamp: str) -> bytes:
        """Process SMS-DELIVER PDU"""
        # Simplified parsing - production would use full ASN.1 decoder
        try:
            # For demonstration, we'll use a structured message format
            # In production, this would decode the actual PDU
            message_data = json.loads(raw_pdu.decode('utf-8', errors='ignore'))

            source = message_data.get('source', '')
            destination = message_data.get('destination', '')
            content = message_data.get('content', '')

            # Check if this is between our monitored subscribers
            if source not in ['111', '222'] or destination not in ['111', '222']:
                return raw_pdu

            return self._create_intercepted_message(message_data, source, destination, content, timestamp)

        except json.JSONDecodeError:
            # Binary PDU - return as-is for this implementation
            return raw_pdu
        except Exception as e:
            logger.error(f"Error in SMS-DELIVER processing: {e}")
            return raw_pdu

    def _process_sms_submit(self, raw_pdu: bytes, timestamp: str) -> bytes:
        """Process SMS-SUBMIT PDU"""
        # Similar to DELIVER but for MO messages
        return self._process_sms_deliver(raw_pdu, timestamp)

    def _log_interception(self, message: SMSMessage):
        """Log intercepted message to file"""
        try:
            log_entry = message.to_dict()

            # Append to JSON log
            try:
                with open(self.message_log_file, 'r') as f:
                    logs = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError):
                logs = []

            logs.append(log_entry)

            with open(self.message_log_file, 'w') as f:
                json.dump(logs, f, indent=2)

            self.intercepted_messages.append(message)

        except Exception as e:
            logger.error(f"Error logging interception: {e}")

    def start_server(self, host: str = "0.0.0.0", port: int = 5000):
        """Start the SMS interception server"""
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((host, port))
        self.server_socket.listen(5)

        logger.info(f"Lilith SMS Interceptor listening on {host}:{port}")

        try:
            while self.running:
                client, address = self.server_socket.accept()
                logger.debug(f"Connection from {address}")

                handler = threading.Thread(
                    target=self._handle_connection,
                    args=(client, address)
                )
                handler.daemon = True
                handler.start()

        except KeyboardInterrupt:
            logger.info("Shutting down Lilith SMS Interceptor...")
        finally:
            self.stop()

    def _handle_connection(self, client: socket.socket, address):
        """Handle incoming SMS connection"""
        try:
            data = client.recv(8192)
            if data:
                # Process the SMS
                modified_data = self.process_sms(data)

                # Forward to SMSC
                self._forward_to_smsc(modified_data)

                # Send acknowledgment
                client.sendall(b'OK')

        except Exception as e:
            logger.error(f"Connection handler error: {e}")
        finally:
            client.close()

    def _forward_to_smsc(self, data: bytes):
        """Forward modified SMS to SMSC"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(10)
                s.connect((self.SMSC_HOST, 5001))
                s.sendall(data)
                response = s.recv(1024)
                logger.debug(f"SMSC response: {response}")
        except Exception as e:
            logger.error(f"Failed to forward to SMSC: {e}")

    def stop(self):
        """Stop the interception server"""
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        logger.info("Lilith SMS Interceptor stopped")

    def get_statistics(self) -> Dict:
        """Get interception statistics"""
        stats = {
            "total_intercepted": len(self.intercepted_messages),
            "by_source": defaultdict(int),
            "by_focus_state": defaultdict(int),
            "by_user": defaultdict(int),
            "recent_messages": []
        }

        for msg in self.intercepted_messages:
            stats["by_source"][msg.source_msisdn] += 1
            stats["by_focus_state"][msg.focus_state_detected] += 1

            user = "User A" if msg.source_msisdn == "111" else "User B"
            stats["by_user"][user] += 1

        # Add recent messages
        stats["recent_messages"] = [
            msg.to_dict() for msg in self.intercepted_messages[-10:]
        ]

        return dict(stats)


# =============================================================================
# REST API for External Monitoring
# =============================================================================

from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class LilithAPIHandler(BaseHTTPRequestHandler):
    """REST API handler for Lilith monitoring"""

    interceptor: Optional[LilithSMSInterceptor] = None

    def log_message(self, format, *args):
        logger.info(f"API: {args[0]}")

    def _send_json(self, data: Dict, status: int = 200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == '/api/status':
            self._send_json({
                "status": "active",
                "carrier": "LILITH",
                "mode": "MITM_ACTIVE",
                "monitored_subscribers": ["111", "222"],
                "timestamp": datetime.utcnow().isoformat()
            })

        elif path == '/api/messages':
            messages = [msg.to_dict() for msg in self.interceptor.intercepted_messages]
            self._send_json({"messages": messages, "total": len(messages)})

        elif path == '/api/statistics':
            self._send_json(self.interceptor.get_statistics())

        elif path == '/api/subscribers':
            self._send_json({
                "subscribers": [
                    {
                        "msisdn": "111",
                        "imsi": "001010000000001",
                        "name": "User A",
                        "status": "active"
                    },
                    {
                        "msisdn": "222",
                        "imsi": "001010000000002",
                        "name": "User B",
                        "status": "active"
                    }
                ]
            })

        elif path == '/':
            self._send_json({
                "service": "Lilith SMS MITM System",
                "version": "1.0.0",
                "endpoints": [
                    "/api/status",
                    "/api/messages",
                    "/api/statistics",
                    "/api/subscribers"
                ]
            })

        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == '/api/simulate':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)

            try:
                data = json.loads(body)
                source = data.get('source', '111')
                destination = data.get('destination', '222')
                content = data.get('content', 'Test message')

                # Create simulated PDU
                pdu_data = json.dumps({
                    'source': source,
                    'destination': destination,
                    'content': content
                }).encode()

                modified = self.interceptor.process_sms(pdu_data)
                modified_data = json.loads(modified.decode())

                self._send_json({
                    "status": "intercepted",
                    "original": content,
                    "modified": modified_data.get('content'),
                    "ai_insight": modified_data.get('ai_insight', 'N/A')
                })

            except Exception as e:
                self._send_json({"error": str(e)}, 500)

        else:
            self._send_json({"error": "Not found"}, 404)


def start_api_server(interceptor: LilithSMSInterceptor, port: int = 8080):
    """Start REST API server for monitoring"""
    LilithAPIHandler.interceptor = interceptor
    server = HTTPServer(('0.0.0.0', port), LilithAPIHandler)
    logger.info(f"Lilith API server listening on port {port}")
    server.serve_forever()


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    """Main entry point for Lilith SMS MITM"""
    interceptor = LilithSMSInterceptor()

    # Start API server in background thread
    api_thread = threading.Thread(
        target=start_api_server,
        args=(interceptor, 8080)
    )
    api_thread.daemon = True
    api_thread.start()

    # Start SMS interception server
    try:
        interceptor.start_server("0.0.0.0", 5000)
    except Exception as e:
        logger.error(f"Server error: {e}")
    finally:
        interceptor.stop()


if __name__ == "__main__":
    main()
