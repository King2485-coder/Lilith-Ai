import Foundation

struct RegisterPayload: Encodable {
    let username: String
    let password: String
    let email: String?
}

struct LoginPayload: Encodable {
    let username: String
    let password: String
}

final class AuthService {
    private let api = APIClient.shared

    func register(username: String, password: String, email: String?) async throws -> User {
        try await api.post("/api/v1/auth/register", body: RegisterPayload(username: username, password: password, email: email))
    }

    func login(username: String, password: String) async throws -> TokenResponse {
        let token: TokenResponse = try await api.post("/api/v1/auth/login", body: LoginPayload(username: username, password: password))
        api.token = token.access_token
        return token
    }

    func me() async throws -> User {
        try await api.get("/api/v1/auth/me")
    }
}

