import Foundation

struct ChatRequestPayload: Encodable {
    let message: String
    let conversationId: String?
    let context: String?
    let projectId: String?
    let autoFix: Bool
    let agent: String
    let mode: String
    let ultraThinking: Bool
}

struct ChatResponsePayload: Decodable {
    let response: String?
    let conversationId: String?
    let messageId: String?
    let message: String?
    let reply: String?
    let content: String?
    let text: String?
    let data: ChatContentBundle?
    let chat: ChatEntry?
    let messages: [ChatEntry]?
    let toolUsed: String?
    let preview: String?
    let tabHint: String?
    let plan: [PlannerStep]?
    let approvalRequest: ChatApprovalRequest?

    var assistantText: String {
        response
        ?? message
        ?? reply
        ?? content
        ?? text
        ?? data?.message
        ?? data?.reply
        ?? data?.content
        ?? data?.text
        ?? chat?.content
        ?? messages?.first?.content
        ?? "No response"
    }
}

struct ChatMessageItem: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let createdAt: Date
    let toolUsed: String?
    let preview: String?
    let approvalId: String?
    let plan: [PlannerStep]?

    enum Role {
        case user
        case assistant
    }
}

struct ChatContentBundle: Decodable {
    let message: String?
    let reply: String?
    let content: String?
    let text: String?
}

struct ChatEntry: Decodable {
    let id: String?
    let role: String?
    let message: String?
    let content: String?
}

struct PlannerStep: Decodable, Equatable, Identifiable {
    var id: String { step + status }
    let step: String
    let status: String
}

struct ChatApprovalRequest: Decodable {
    let status: String?
    let approvalId: String?
    let preview: String?
}

// MARK: - Lilith Search

struct BrowserSearchRequest: Encodable {
    let query: String
}

struct BrowserSearchResult: Decodable, Identifiable {
    var id = UUID()
    let title: String
    let url: String
    let snippet: String
}

struct BrowserSearchResponse: Decodable {
    let success: Bool
    let engine: String
    let query: String
    let results: [BrowserSearchResult]
}
