import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var conversations: [ConversationListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func load(token: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [ConversationListItem] = try await apiClient.request("/conversations", token: token)
            conversations = result
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String, token: String) async {
        struct Empty: Decodable {}
        do {
            let _: Empty = try await apiClient.request("/conversations/\(id)", method: "DELETE", token: token)
            conversations.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
