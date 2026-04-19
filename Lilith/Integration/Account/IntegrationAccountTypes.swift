import Foundation
import SwiftUI

struct SubscriptionWindow: Decodable, Hashable {
    let plan: String
    let status: String
    let currentPeriodStart: String?
    let currentPeriodEnd: String?
}

struct SubscriptionResponse: Decodable, Hashable {
    let subscription: SubscriptionWindow
    let credits: Double
    let isSuperAdmin: Bool
}

struct CreditsSummary: Decodable, Hashable {
    let credits: Double
    let isSuperAdmin: Bool
    let unlimited: Bool
}

struct AdminStatsResponse: Decodable, Hashable {
    struct Users: Decodable, Hashable {
        let total: Int
        let active: Int
        let premium: Int
        let free: Int
    }

    struct Content: Decodable, Hashable {
        let conversations: Int
        let projects: Int
        let videos: Int
        let images: Int
    }

    let users: Users
    let content: Content
}

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var subscription: SubscriptionWindow?
    @Published var creditsSummary: CreditsSummary?
    @Published var errorMessage: String?
    @Published var adminStats: AdminStatsResponse?

    private let apiClient = APIClient()

    func load(token: String?, isSuperAdmin: Bool) async {
        guard let token else { return }

        do {
            let sub: SubscriptionResponse = try await apiClient.request("/subscription", token: token)
            let credits: CreditsSummary = try await apiClient.request("/credits", token: token)
            subscription = sub.subscription
            creditsSummary = credits

            if isSuperAdmin {
                let stats: AdminStatsResponse = try await apiClient.request("/admin/stats", token: token)
                adminStats = stats
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
