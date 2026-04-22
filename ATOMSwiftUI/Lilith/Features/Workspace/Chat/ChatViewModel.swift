import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessageItem] = []
    @Published var draft = ""
    @Published var conversationId: String?
    @Published var isSending = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    var onAssistantSpoken: ((String) -> Void)?

    private let apiClient = APIClient()

    func sendMessage(token: String, agent: AgentKind, mode: AgentMode, ultraThinking: Bool) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let outbound = ChatMessageItem(role: .user, content: trimmed, createdAt: .now, toolUsed: nil, preview: nil, approvalId: nil, plan: nil)
        messages.append(outbound)
        draft = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response: ChatResponsePayload = try await apiClient.request(
                "/chat",
                method: "POST",
                body: ChatRequestPayload(
                    message: trimmed,
                    conversationId: conversationId,
                    context: nil,
                    projectId: nil,
                    autoFix: false,
                    agent: agent.rawValue,
                    mode: mode.rawValue,
                    ultraThinking: ultraThinking
                ),
                token: token
            )
            if let cid = response.conversationId {
                conversationId = cid
            }
            try? await Task.sleep(for: .milliseconds(180)) // slight delay for assistant response feel
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: response.assistantText,
                    createdAt: .now,
                    toolUsed: response.toolUsed,
                    preview: response.preview ?? response.approvalRequest?.preview,
                    approvalId: response.approvalRequest?.approvalId,
                    plan: response.plan
                )
            )
            onAssistantSpoken?(response.assistantText)
        } catch {
            errorMessage = error.localizedDescription
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: "Request failed: \(error.localizedDescription)",
                    createdAt: .now,
                    toolUsed: nil,
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        }
    }

    func searchWeb(token: String, query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let response: BrowserSearchResponse = try await apiClient.request(
                "/browser/search",
                method: "POST",
                body: BrowserSearchRequest(query: trimmed),
                token: token
            )
            let bullets = response.results.prefix(3).map { "• \($0.title) — \($0.url)\n  \($0.snippet)" }.joined(separator: "\n")
            let summary = """
Lilith searched “\(response.query)”:
\(bullets.isEmpty ? "No results." : bullets)
"""
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: summary,
                    createdAt: .now,
                    toolUsed: "Search",
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: "Lilith search failed: \(error.localizedDescription)",
                    createdAt: .now,
                    toolUsed: nil,
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        }
    }

            func startNewConversation() {
                messages = []
                conversationId = nil
                errorMessage = nil
            }

            func loadConversation(id: String, token: String) async {
                do {
                    let detail: ConversationDetail = try await apiClient.request(
                        "/conversations/\(id)", token: token
                    )
                    conversationId = id
                    messages = detail.messages.map { msg in
                        ChatMessageItem(
                            role: msg.role == "user" ? .user : .assistant,
                            content: msg.content,
                            createdAt: .now,
                            toolUsed: nil,
                            preview: nil,
                            approvalId: nil,
                            plan: nil
                        )
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
}
