import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var currentUser: User?
    @Published var error: String?

    private let service = AuthService()

    func login() async {
        do {
            _ = try await service.login(username: username, password: password)
            currentUser = try await service.me()
            error = nil
        } catch {
            error = String(describing: error)
        }
    }
}

