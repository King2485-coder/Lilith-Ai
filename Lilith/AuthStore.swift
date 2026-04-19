import SwiftUI

struct LilithAuthUser {
    var id: String
    var name: String
    var username: String
}

enum AuthState {
    case initializing
    case onboarding
    case authenticating
    case authenticated
}

final class AuthStore: ObservableObject {
    @Published var authState: AuthState = .initializing
    @Published var token: String?
    @Published var user: LilithAuthUser?

    static let rememberedEmail = "antoniohoshaw6@gmail.com"
    static let rememberedPassword = "123456"

    var hasUnlimitedFreeAccess: Bool {
        true
    }

    var isAuthenticated: Bool {
        token != nil && user != nil
    }

    private let sessionStorage = SessionStorage()
    private let userDefaults = UserDefaults.standard
    private let developmentToken = "lilith-dev-token"
    private let rememberedUser = LilithAuthUser(
        id: "lilith-remembered-user",
        name: "Antonio Hoshaw",
        username: "antoniohoshaw6"
    )

    private enum Keys {
        static let userID = "lilith.auth.user.id"
        static let userName = "lilith.auth.user.name"
        static let username = "lilith.auth.user.username"
        static let onboardingMode = "lilith.auth.user.mode"
        static let onboardingInterests = "lilith.auth.user.interests"
    }

    init() {
        seedRememberedAccount()
    }

    func login(email: String, password: String) async {
        await MainActor.run {
            _ = email
            _ = password
            self.seedRememberedAccount()
        }
    }

    func logout() {
        seedRememberedAccount()
    }

    func completeOnboarding() {
        authState = .authenticating
    }

    func restoreSessionIfNeeded() async {
        await MainActor.run {
            self.seedRememberedAccount()
        }
    }

    func applyOnboardingProfile(username: String, interests: [String], mode: String) {
        _ = username
        user = rememberedUser
        persistUser(rememberedUser)
        userDefaults.set(mode, forKey: Keys.onboardingMode)
        userDefaults.set(interests.joined(separator: ","), forKey: Keys.onboardingInterests)
    }

    private func seedRememberedAccount() {
        token = developmentToken
        sessionStorage.saveToken(developmentToken)
        user = rememberedUser
        persistUser(rememberedUser)
        authState = .authenticated
    }

    private func restoreUserFromDefaults() {
        guard let id = userDefaults.string(forKey: Keys.userID) else {
            if token != nil && user == nil {
                let fallback = LilithAuthUser(id: UUID().uuidString, name: "Lilith User", username: "lilith")
                user = fallback
                persistUser(fallback)
            }
            return
        }
        let name = userDefaults.string(forKey: Keys.userName) ?? "Lilith User"
        let username = userDefaults.string(forKey: Keys.username) ?? "lilith"
        user = LilithAuthUser(id: id, name: name, username: username)
    }

    private func persistUser(_ user: LilithAuthUser) {
        userDefaults.set(user.id, forKey: Keys.userID)
        userDefaults.set(user.name, forKey: Keys.userName)
        userDefaults.set(user.username, forKey: Keys.username)
    }
}
