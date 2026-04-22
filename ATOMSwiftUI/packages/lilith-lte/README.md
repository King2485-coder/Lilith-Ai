# Lilith Private LTE Network

A complete 2-node Private LTE Network built with Open5GS and srsRAN, featuring "Lilith" — an AI-powered SMS interception and voice operator system.

---

## Architecture Overview

```
                    +---------------------+
                    |   User Phone (UE)   |
                    |   IMSI: 001010...   |
                    +----------+----------+
                               |
                    +----------v----------+
                    |  eNodeB Node 1      |
                    |  Freq: 2680 MHz     |
                    +----------+----------+
                               |
                    +----------v----------+     +---------------------+
                    |      AMF/SMF        |---->|   MongoDB (UDR)     |
                    |    Open5GS Core     |     +---------------------+
                    +----------+----------+     +---------------------+
                               |                |  Lilith MITM Engine |
                    +----------v----------+     |  SMS Interception   |
                    |  eNodeB Node 2      |     |  AI Insight Append  |
                    |  Freq: 2700 MHz     |     +---------------------+
                    +----------+----------+
                               |
                    +----------v----------+     +---------------------+
                    |   User Phone (UE)   |---->|   Asterisk SIP      |
                    |   IMSI: 002010...   |     |   Voice Redirect    |
                    +---------------------+     |   TTS Greeting      |
                                                +---------------------+
```

---

## Identity Setup

| User | IMSI | MSISDN | IMEI | Authentication Key | OPC |
|------|------|--------|------|-------------------|-----|
| User A | 001010000000001 | 111 | 3534900000001 | 00112233445566778899AABBCCDDEEFF | 000102030405060708090A0B0C0D0E0F |
| User B | 001010000000002 | 222 | 3534900000002 | 11223344556677889900AABBCCDDEEFF | 101112131415161718191A1B1C1D1E1F |

### Network Parameters
- **MCC**: 001 (Test)
- **MNC**: 01
- **PLMN**: 00101
- **TAC Node 1**: 1
- **TAC Node 2**: 2
- **APN**: lilith
- **UE Subnet**: 10.45.0.0/16

---

## Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- Linux host (Ubuntu 22.04 recommended)

### Deploy the Network

```bash
# Clone and navigate
cd lilith-lte

# Deploy everything
./deploy.sh start

# Check status
./deploy.sh status

# View logs
./deploy.sh logs lilith-mitm
```

### Manual Docker Compose

```bash
# Start all services
docker-compose up -d

# Initialize subscribers
python3 open5gs/init_subscribers.py

# Generate eSIM profiles
python3 esim/generate_esim.py
```

---

## Lilith SMS MITM System

### Features
- **Real-time interception** of all SMS between MSISDN 111 and 222
- **AI Insight Engine** analyzes message content for focus states (Red/Blue/Green/Amber)
- **Message modification** appends contextual "Lilith Notes" before delivery
- **REST API** for monitoring and management

### Focus States
| State | Description | Keywords |
|-------|-------------|----------|
| **Red** | Critical/Urgent | alert, warning, critical, urgent, danger |
| **Blue** | Normal/Stable | calm, normal, standard, proceed, confirmed |
| **Green** | Active/Ready | start, begin, initiate, launch, ready |
| **Amber** | Caution/Observe | wait, hold, pending, review, caution |

### Example Interception

**Original Message:**
```
Hey, we need to focus on the Red State today. Critical operations.
```

**After Lilith Interception:**
```
Hey, we need to focus on the Red State today. Critical operations.
---
Lilith Note: User A seems highly focused on the Red State today. Their communication suggests elevated urgency or concern.
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/status` | GET | System status |
| `/api/messages` | GET | All intercepted messages |
| `/api/statistics` | GET | Interception statistics |
| `/api/subscribers` | GET | Subscriber info |
| `/api/simulate` | POST | Simulate SMS interception |

### Test SMS Interception

```bash
./deploy.sh test-sms

# Or manually:
curl -X POST http://localhost:8080/api/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "source": "111",
    "destination": "222",
    "content": "Test message about Red State operations"
  }'
```

---

## eSIM Profiles & QR Codes

Two eSIM profiles have been generated with **"LILITH"** as the carrier name.

### User A (111)
- **QR Code**: `esim/qr_codes/lilith_esim_user_a.png`
- **LPA String**: `LPA:1$smdp.lilith-pvt-lte.local:443$fCZUqmTFG77NzcOtcTc9`
- **ICCID**: 8900101000000001018

### User B (222)
- **QR Code**: `esim/qr_codes/lilith_esim_user_b.png`
- **LPA String**: `LPA:1$smdp.lilith-pvt-lte.local:443$7yjXKWwwxA-L1cjKcrVK`
- **ICCID**: 8900101000000002026

### Activation Instructions

**Method 1 - QR Code Scan:**
1. Open Settings → Network → Add eSIM
2. Scan the QR code provided
3. Enter confirmation code when prompted
4. Carrier will display as **LILITH**

**Method 2 - Manual LPA Entry:**
1. Settings → Network → Add eSIM → Enter manually
2. Enter the LPA activation string
3. Tap "Activate"

---

## Voice Redirect (Dial '0')

When either user dials **0**, the call is routed to **Operator Lilith** via SIP.

### Lilith's Voice Menu

```
[Lilith]: "This is Operator Lilith. Which focus state should I initialize
           for your node? You may say: Red State for critical operations,
           Blue State for normal mode, Green State to initiate, or
           Amber State to hold and observe."

[User]: <speaks focus state>

[Lilith]: "<Focus State> initialized. <Status message>."

[Lilith]: "Thank you for using Lilith Private LTE Network. Your session
           is logged and secured. Have a productive cycle."
```

### SIP Configuration
- **Server**: localhost:5060 (UDP/TCP)
- **User A**: sip:user_a@lilith-pvt-lte.local:5060 (secret: lilith_user_a_2024)
- **User B**: sip:user_b@lilith-pvt-lte.local:5060 (secret: lilith_user_b_2024)
- **Extension 0**: Lilith Operator (auto-answer with TTS)

### Testing

```bash
# Using linphone or similar SIP client
linphonecsh init
linphonecsh register sip:user_a@localhost --password lilith_user_a_2024
linphonecsh dial 0
```

---

## File Structure

```
lilith-lte/
├── docker-compose.yml          # Complete orchestration
├── deploy.sh                   # Deployment manager
├── README.md                   # This file
│
├── open5gs/                    # Core Network Configs
│   ├── amf.yaml               # Access and Mobility Function
│   ├── smf.yaml               # Session Management Function
│   ├── upf.yaml               # User Plane Function
│   ├── hss.yaml               # Home Subscriber Server
│   ├── subscribers.json        # Subscriber database
│   └── init_subscribers.py    # DB initialization
│
├── srsran/                     # Radio Access Network
│   ├── enb_node1.conf         # eNodeB Node 1 config
│   ├── enb_node2.conf         # eNodeB Node 2 config
│   ├── ue_usera.conf          # UE User A config
│   ├── ue_userb.conf          # UE User B config
│   ├── rr_node1.conf          # Radio Resource Node 1
│   ├── rr_node2.conf          # Radio Resource Node 2
│   ├── rb.conf                # Radio Bearer config
│   └── sib.conf               # System Information Blocks
│
├── scripts/                    # Lilith Services
│   ├── lilith_mitm.py         # SMS interception engine
│   ├── Dockerfile.mitm        # MITM service container
│   └── requirements.txt       # Python dependencies
│
├── esim/                       # eSIM Profiles
│   ├── generate_esim.py       # eSIM generator
│   ├── qr_codes/              # QR code images
│   │   ├── lilith_esim_user_a.png
│   │   └── lilith_esim_user_b.png
│   └── profiles/              # JSON profile data
│       ├── lilith_profile_user_a.json
│       └── lilith_profile_user_b.json
│
├── voip/                       # Voice Services
│   ├── lilith_voice.py        # TTS voice generator
│   ├── Dockerfile.sip         # Asterisk container
│   ├── audio/                 # Voice prompt files
│   │   ├── lilith_greeting.mp3
│   │   ├── lilith_focus_*.mp3
│   │   └── lilith_thankyou.mp3
│   └── asterisk/              # Asterisk configs
│       ├── extensions.conf    # Dial plan
│       ├── sip.conf           # SIP configuration
│       └── agi/               # AGI scripts
│
└── logs/                       # Log directory
    ├── open5gs/
    ├── srsran/
    └── lilith/
```

---

## Services & Ports

| Service | Container | Port | Protocol | Description |
|---------|-----------|------|----------|-------------|
| MongoDB | lilith-mongodb | 27017 | TCP | Subscriber database |
| NRF | lilith-nrf | 7777 | TCP | Network Repository Function |
| AMF | lilith-amf | 38412 | SCTP | Access & Mobility |
| SMF | lilith-smf | 7777 | TCP | Session Management |
| UPF | lilith-upf | 2152 | UDP | User Plane |
| HSS | lilith-hss | 3868 | TCP | Home Subscriber Server |
| eNB Node 1 | lilith-enb-node1 | 36412 | SCTP | Radio Node 1 |
| eNB Node 2 | lilith-enb-node2 | 36413 | SCTP | Radio Node 2 |
| Lilith MITM | lilith-mitm | 5000 | TCP | SMS interception |
| Lilith API | lilith-mitm | 8080 | TCP | REST API |
| SIP Server | lilith-sip | 5060 | UDP/TCP | Voice service |
| RTP | lilith-sip | 10000-10100 | UDP | Media stream |

---

## Troubleshooting

### Check container status
```bash
docker-compose ps
docker-compose logs [service]
```

### Reset subscriber database
```bash
docker-compose exec mongodb mongosh open5gs --eval "db.subscribers.deleteMany({})"
python3 open5gs/init_subscribers.py
```

### Restart individual services
```bash
docker-compose restart lilith-mitm
docker-compose restart lilith-sip
```

### Verify network connectivity
```bash
# Test API
curl http://localhost:8080/api/status

# Test SIP
nc -vzu localhost 5060
```

---

## Security Notes

- This is a **test/lab network** using PLMN 001-01
- All credentials are for demonstration only
- The network is isolated via Docker networking
- SMS interception is performed with explicit system design (not a vulnerability exploit)

---

## License

This project is for educational and testing purposes only.

---

## Lilith System Status

```
Carrier:      LILITH
Network:      Private LTE (2-node)
PLMN:         001-01
Status:       OPERATIONAL
Subscribers:  2 active
MITM Engine:  ACTIVE
Voice:        ACTIVE
```
