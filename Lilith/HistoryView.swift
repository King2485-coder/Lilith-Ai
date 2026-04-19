import SwiftUI

// MARK: - History View

struct HistoryView: View {
    var onLoadConversation: ((String) -> Void)? = nil

    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = HistoryViewModel()
    @State private var searchQuery = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                List {
                    ForEach(filteredConversations) { conversation in
                        Button(action: {
                            onLoadConversation?(conversation.id)
                        }) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(white: 0.1))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "bubble.left")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(Color(white: 0.6))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.9))

                                    Text("\(conversation.messageCount) messages · \(timeAgo(conversation.updatedAt))")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color(white: 0.45))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.3))
                            }
                        }
                        .listRowBackground(Color(white: 0.05))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: deleteConversations)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search conversations"
            )
            .task {
                await viewModel.load(token: authStore.token)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var filteredConversations: [ConversationListItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return viewModel.conversations }
        return viewModel.conversations.filter {
            $0.title.lowercased().contains(query)
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            viewModel.deleteConversation(id: conversation.id, token: authStore.token)
        }
    }

    private func timeAgo(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let df = DateFormatter()
        df.dateStyle = .short
        return df.string(from: date)
    }
}

// MARK: - History View Model

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var conversations: [ConversationListItem] = []
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func load(token: String?) async {
        guard let token = token else {
            conversations = []
            return
        }
        do {
            let response: [ConversationListItem] = try await apiClient.request("/conversations", token: token)
            conversations = response.sorted {
                ($0.updatedAt) > ($1.updatedAt)
            }
        } catch {
            errorMessage = error.localizedDescription
            conversations = []
        }
    }

    func deleteConversation(id: String, token: String?) {
        conversations.removeAll { $0.id == id }
        guard let token = token else { return }
        Task {
            let _: HistoryEmptyBody? = try? await apiClient.request(
                "/conversations/\(id)",
                method: "DELETE",
                body: HistoryEmptyBody(),
                token: token
            )
        }
    }
}

struct HistoryEmptyBody: Encodable, Decodable {}
