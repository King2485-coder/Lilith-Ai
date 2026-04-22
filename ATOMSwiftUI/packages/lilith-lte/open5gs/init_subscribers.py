#!/usr/bin/env python3
"""
Lilith Private LTE Network - Open5GS Subscriber Initialization
Registers User A (111) and User B (222) in the HSS/UDM
"""

import json
import subprocess
import sys

def init_subscribers():
    """Initialize subscribers in Open5GS HSS/UDM using the DBCTL or direct MongoDB"""

    subscribers = [
        {
            "imsi": "001010000000001",
            "msisdn": ["111"],
            "key": "00112233445566778899AABBCCDDEEFF",
            "opc": "000102030405060708090A0B0C0D0E0F",
            "amf": "9001",
            "network_access_mode": 0,
            "subscriber_status": 0,
            "access_restriction_data": 32,
            "slice": [
                {
                    "sst": 1,
                    "default_indicator": True,
                    "session": [
                        {
                            "name": "lilith",
                            "type": 3,
                            "pcc_rule": [],
                            "ambr": {
                                "uplink": {"value": 1, "unit": 3},
                                "downlink": {"value": 1, "unit": 3}
                            },
                            "qos": {
                                "index": 9,
                                "arp": {
                                    "priority_level": 8,
                                    "pre_emption_capability": 1,
                                    "pre_emption_vulnerability": 1
                                }
                            }
                        }
                    ]
                }
            ],
            "ambr": {
                "uplink": {"value": 1, "unit": 3},
                "downlink": {"value": 1, "unit": 3}
            },
            "security": {
                "k": "00112233445566778899AABBCCDDEEFF",
                "amf": "9001",
                "op": None,
                "opc": "000102030405060708090A0B0C0D0E0F"
            },
            "schema_version": 1
        },
        {
            "imsi": "001010000000002",
            "msisdn": ["222"],
            "key": "11223344556677889900AABBCCDDEEFF",
            "opc": "101112131415161718191A1B1C1D1E1F",
            "amf": "9001",
            "network_access_mode": 0,
            "subscriber_status": 0,
            "access_restriction_data": 32,
            "slice": [
                {
                    "sst": 1,
                    "default_indicator": True,
                    "session": [
                        {
                            "name": "lilith",
                            "type": 3,
                            "pcc_rule": [],
                            "ambr": {
                                "uplink": {"value": 1, "unit": 3},
                                "downlink": {"value": 1, "unit": 3}
                            },
                            "qos": {
                                "index": 9,
                                "arp": {
                                    "priority_level": 8,
                                    "pre_emption_capability": 1,
                                    "pre_emption_vulnerability": 1
                                }
                            }
                        }
                    ]
                }
            ],
            "ambr": {
                "uplink": {"value": 1, "unit": 3},
                "downlink": {"value": 1, "unit": 3}
            },
            "security": {
                "k": "11223344556677889900AABBCCDDEEFF",
                "amf": "9001",
                "op": None,
                "opc": "101112131415161718191A1B1C1D1E1F"
            },
            "schema_version": 1
        }
    ]

    print("=" * 60)
    print("  Lilith Private LTE - Subscriber Registration")
    print("=" * 60)

    for sub in subscribers:
        imsi = sub["imsi"]
        msisdn = sub["msisdn"][0]
        print(f"\n[REGISTER] IMSI: {imsi} -> MSISDN: {msisdn}")
        print(f"  K: {sub['key']}")
        print(f"  OPC: {sub['opc']}")
        print(f"  APN: lilith")
        print(f"  Network: PLMN 001/01 (TEST)")

    # Write to JSON for MongoDB import
    with open('/mnt/agents/output/lilith-lte/open5gs/open5gs_subscribers.json', 'w') as f:
        json.dump(subscribers, f, indent=2)

    print("\n" + "=" * 60)
    print("  Subscribers exported to open5gs_subscribers.json")
    print("  Use: mongosh open5gs --eval 'db.subscribers.insertMany(...)")
    print("=" * 60)

    return subscribers

if __name__ == "__main__":
    init_subscribers()
