import Foundation

struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let created_at: String
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
}

