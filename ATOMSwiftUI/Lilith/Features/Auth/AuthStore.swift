import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: LilithUser?
    @Published private(set) var token: String?
    @Published private(set) var isRestoringSession = false
    @Published var authError: String?

    /// Optional master access for the owner: set `MASTER_EMAIL` in Info.plist to your email.
    private let masterToken = APIConfig.masterToken
    /// Disabled by default for live-only runs. Set MASTER_EMAIL in Info.plist to re-enable.
    private let fallbackMasterEmail = ""
    private var masterEmail: String? {
        if let plistEmail = Bundle.main.object(forInfoDictionaryKey: "MASTER_EMAIL") as? String,
           !plistEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistEmail
        }
        return fallbackMasterEmail
    }

    private let apiClient = APIClient()
    private let storage = SessionStorage()
    private let iso8601 = ISO8601DateFormatter()

    var isAuthenticated: Bool {
        token != nil && user != nil
    }

    func restoreSessionIfNeeded() async {
        guard !isRestoringSession, user == nil else { return }

        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let storedToken = storage.loadToken() else { return }

        if storedToken == masterToken, let masterEmail {
            APIConfig.useOfflineStubs = true
            token = storedToken
            user = makeMasterUser(email: masterEmail)
            return
        }

        token = storedToken

        do {
            if let me: V1AuthMeResponse = try? await apiClient.requestV1("/auth/me", token: storedToken) {
                self.user = mapV1User(
                    id: me.id,
                    email: me.email,
                    name: me.name,
                    profile: me.profile
                )
            } else {
                let user: LilithUser = try await apiClient.request("/auth/me", token: storedToken)
                self.user = user
            }
        } catch {
            storage.clear()
            token = nil
            user = nil
            APIConfig.useOfflineStubs = false
        }
    }

    func login(email: String, password: String) async -> Bool {
        authError = nil

        do {
            if let response: V1AuthSessionResponse = try? await apiClient.requestV1(
                "/auth/login",
                method: "POST",
                body: AuthPayload(email: email, password: password),
                token: nil
            ) {
                token = response.accessToken
                user = mapV1User(id: response.user.id, email: response.user.email, name: response.user.name, profile: response.profile)
                storage.saveToken(response.accessToken)
                return true
            }
            let response: AuthResponse = try await apiClient.request("/auth/login", method: "POST", body: AuthPayload(email: email, password: password), token: nil)
            let tokenValue = response.accessToken
            token = tokenValue
            user = response.user ?? LilithUser(
                id: UUID().uuidString,
                email: email,
                name: "Lilith User",
                createdAt: iso8601.string(from: Date()),
                role: "user",
                credits: nil,
                isSuperAdmin: false,
                username: nil,
                bio: nil
            )

            storage.saveToken(tokenValue)
            return true
        } catch {
            if grantMasterAccessIfNeeded(email: email) {
                APIConfig.useOfflineStubs = true
                return true
            }
            authError = connectionErrorMessage(for: error)
            return false
        }
    }

    func register(name: String, email: String, password: String) async -> Bool {
        authError = nil

        do {
            if let response: V1AuthSessionResponse = try? await apiClient.requestV1(
                "/auth/register",
                method: "POST",
                body: RegistrationPayload(email: email, password: password, name: name),
                token: nil
            ) {
                token = response.accessToken
                user = mapV1User(id: response.user.id, email: response.user.email, name: response.user.name, profile: response.profile)
                storage.saveToken(response.accessToken)
                return true
            }
            let response: AuthResponse = try await apiClient.request("/auth/register", method: "POST", body: RegistrationPayload(email: email, password: password, name: name), token: nil)
            token = response.accessToken
            user = response.user
            storage.saveToken(response.accessToken)
            return true
        } catch {
            authError = connectionErrorMessage(for: error)
            return false
        }
    }

    func logout() {
        storage.clear()
        token = nil
        user = nil
        authError = nil
        APIConfig.useOfflineStubs = false
    }

    func applyOnboardingProfile(username: String, interests: [String], mode: String) {
        guard var user else { return }
        let cleanedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        if !cleanedUsername.isEmpty {
            user.username = cleanedUsername
        }
        let interestLine = interests.prefix(3).joined(separator: ", ")
        if interestLine.isEmpty {
            user.bio = "Lilith profile configured (\(mode))."
        } else {
            user.bio = "Interested in \(interestLine). Lilith profile configured (\(mode))."
        }
        self.user = user
    }

    private func grantMasterAccessIfNeeded(email: String) -> Bool {
        guard let masterEmail,
              email.caseInsensitiveCompare(masterEmail) == .orderedSame else { return false }

        user = makeMasterUser(email: masterEmail)
        token = masterToken
        storage.saveToken(masterToken)
        return true
    }

    private func makeMasterUser(email: String) -> LilithUser {
        LilithUser(
            id: "master-\(email)",
            email: email,
            name: "Lilith Owner",
            createdAt: iso8601.string(from: Date()),
            role: "super_admin",
            credits: 9_999_999,
            isSuperAdmin: true,
            username: nil,
            bio: nil
        )
    }

    private func connectionErrorMessage(for error: Error) -> String {
        let backendURL = APIConfig.baseURLString
        let baseMessage: String

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .timedOut, .networkConnectionLost, .notConnectedToInternet:
                baseMessage = "Could not reach Lilith backend at \(backendURL)."
            default:
                baseMessage = error.localizedDescription
            }
        } else {
            baseMessage = error.localizedDescription
        }

        #if targetEnvironment(simulator)
        return "\(baseMessage) Make sure the backend is running and update Server Settings if it uses a different URL."
        #else
        return "\(baseMessage) If you are on a phone, 127.0.0.1 points to the device itself. Set your Mac or server LAN URL in Server Settings."
        #endif
    }

    private func mapV1User(id: Int, email: String, name: String, profile: V1AuthProfile?) -> LilithUser {
        LilithUser(
            id: String(id),
            email: email,
            name: profile?.displayName ?? name,
            createdAt: iso8601.string(from: Date()),
            role: "user",
            credits: nil,
            isSuperAdmin: false,
            username: profile?.username,
            bio: profile?.bio
        )
    }
}
