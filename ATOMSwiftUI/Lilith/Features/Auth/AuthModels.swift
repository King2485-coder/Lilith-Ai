import Foundation

struct AuthPayload: Encodable {
    let email: String
    let password: String
}

struct RegistrationPayload: Encodable {
    let email: String
    let password: String
    let name: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let tokenType: String?
    let user: LilithUser?
    let success: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case token
        case tokenType = "token_type"
        case user
        case success
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let token = try container.decodeIfPresent(String.self, forKey: .accessToken) {
            accessToken = token
        } else if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            accessToken = token
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.accessToken],
                                                    debugDescription: "Missing token/access_token"))
        }
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        user = try container.decodeIfPresent(LilithUser.self, forKey: .user)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct LilithUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let createdAt: String
    let role: String
    let credits: Double?
    let isSuperAdmin: Bool
    var username: String?
    var bio: String?

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Lilith User" : name
    }

    var lilithHandle: String {
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "@\(username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? "lilith"
        let sanitized = localPart
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        return "@\(sanitized.isEmpty ? "lilith" : sanitized)"
    }
}

struct V1AuthProfile: Decodable {
    let username: String
    let lilithId: String?
    let displayName: String?
    let bio: String?
}

struct V1AuthUser: Decodable {
    let id: Int
    let email: String
    let name: String
}

struct V1AuthSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let user: V1AuthUser
    let profile: V1AuthProfile?
}

struct V1AuthMeResponse: Decodable {
    let id: Int
    let email: String
    let name: String
    let profile: V1AuthProfile?
}
