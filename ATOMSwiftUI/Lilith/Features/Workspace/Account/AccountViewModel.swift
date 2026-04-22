import Foundation

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var creditsSummary: CreditsSummary?
    @Published var subscription: SubscriptionResponse?
    @Published var adminStats: AdminStatsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func load(token: String, isSuperAdmin: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let credits: CreditsSummary = apiClient.request("/user/credits", token: token)
            async let subscription: SubscriptionResponse = apiClient.request("/subscription", token: token)

            self.creditsSummary = try await credits
            self.subscription = try await subscription

            if isSuperAdmin {
                self.adminStats = try await apiClient.request("/admin/stats", token: token)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
