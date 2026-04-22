import Foundation

// MARK: - eSIM Profile

struct LTEeSIMProfile: Identifiable, Codable {
    var id: String
    var userName: String
    var msisdn: String
    var imsi: String
    var iccid: String
    var lpaString: String
    var carrier: String
    var qrCodeName: String    // asset name or filename for QR image
}

// MARK: - Network Node

enum LTENodeStatus: String, Codable, CaseIterable {
    case operational
    case degraded
    case offline
    case unknown

    var label: String {
        switch self {
        case .operational: return "Operational"
        case .degraded:    return "Degraded"
        case .offline:     return "Offline"
        case .unknown:     return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .degraded:    return "exclamationmark.triangle.fill"
        case .offline:     return "xmark.circle.fill"
        case .unknown:     return "questionmark.circle.fill"
        }
    }
}

struct LTENetworkNode: Identifiable, Codable {
    var id: String
    var name: String
    var type: String        // e.g. AMF, SMF, eNB, SIP
    var host: String
    var port: Int
    var protocol_: String   // TCP, UDP, SCTP
    var status: LTENodeStatus
    var lastChecked: Date?
}

// MARK: - Subscriber

struct LTESubscriber: Identifiable, Codable {
    var id: String
    var name: String
    var msisdn: String
    var imsi: String
    var imei: String
    var status: String      // active, inactive
    var apn: String
}

// MARK: - VoIP Call

enum LTECallDirection: String, Codable {
    case outgoing, incoming
}

struct LTECallRecord: Identifiable, Codable {
    var id: String
    var direction: LTECallDirection
    var number: String
    var displayName: String?
    var duration: TimeInterval
    var date: Date
}

// MARK: - Sample Data

extension LTEeSIMProfile {
    static let samples: [LTEeSIMProfile] = [
        LTEeSIMProfile(
            id: "esim-a",
            userName: "User A",
            msisdn: "111",
            imsi: "001010000000001",
            iccid: "8900101000000001018",
            lpaString: "LPA:1$smdp.lilith-pvt-lte.local:443$fCZUqmTFG77NzcOtcTc9",
            carrier: "LILITH",
            qrCodeName: "lilith_esim_user_a"
        ),
        LTEeSIMProfile(
            id: "esim-b",
            userName: "User B",
            msisdn: "222",
            imsi: "001010000000002",
            iccid: "8900101000000002026",
            lpaString: "LPA:1$smdp.lilith-pvt-lte.local:443$7yjXKWwwxA-L1cjKcrVK",
            carrier: "LILITH",
            qrCodeName: "lilith_esim_user_b"
        )
    ]
}

extension LTENetworkNode {
    static let samples: [LTENetworkNode] = [
        LTENetworkNode(id: "nrf",  name: "NRF",       type: "Network Repository", host: "localhost", port: 7777,  protocol_: "TCP",  status: .operational),
        LTENetworkNode(id: "amf",  name: "AMF",       type: "Access & Mobility",  host: "localhost", port: 38412, protocol_: "SCTP", status: .operational),
        LTENetworkNode(id: "smf",  name: "SMF",       type: "Session Management", host: "localhost", port: 7777,  protocol_: "TCP",  status: .operational),
        LTENetworkNode(id: "upf",  name: "UPF",       type: "User Plane",         host: "localhost", port: 2152,  protocol_: "UDP",  status: .operational),
        LTENetworkNode(id: "hss",  name: "HSS",       type: "Subscriber Server",  host: "localhost", port: 3868,  protocol_: "TCP",  status: .operational),
        LTENetworkNode(id: "enb1", name: "eNB Node 1",type: "Radio Node",         host: "localhost", port: 36412, protocol_: "SCTP", status: .operational),
        LTENetworkNode(id: "enb2", name: "eNB Node 2",type: "Radio Node",         host: "localhost", port: 36413, protocol_: "SCTP", status: .operational),
        LTENetworkNode(id: "sip",  name: "SIP Server",type: "Voice Gateway",      host: "localhost", port: 5060,  protocol_: "UDP",  status: .operational),
        LTENetworkNode(id: "db",   name: "MongoDB",   type: "Database",           host: "localhost", port: 27017, protocol_: "TCP",  status: .operational)
    ]
}

extension LTESubscriber {
    static let samples: [LTESubscriber] = [
        LTESubscriber(id: "sub-a", name: "User A", msisdn: "111", imsi: "001010000000001", imei: "3534900000001", status: "active", apn: "lilith"),
        LTESubscriber(id: "sub-b", name: "User B", msisdn: "222", imsi: "001010000000002", imei: "3534900000002", status: "active", apn: "lilith")
    ]
}
