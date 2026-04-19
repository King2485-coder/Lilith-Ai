import Foundation

struct FinanceBalanceResponse: Decodable, Hashable {
    var balance: Double
    var currency: String
}

struct FinanceTransactionItem: Decodable, Hashable, Identifiable {
    let id: String
    var amount: Double
    var type: String
    var description: String
    var createdAt: String
}

struct FinanceAnalysisResponse: Decodable, Hashable {
    var summary: String
    var insights: [String]
}

struct FinanceApprovalItem: Decodable, Hashable, Identifiable {
    let id: String
    var amount: Double
    var recipient: String
    var status: String
}

struct FinanceSimulationResponse: Decodable, Hashable {
    var result: String
    var details: String
}

struct FinanceTransferResponse: Decodable, Hashable {
    var transactionId: String
    var status: String
    var confirmationCode: String?
}

struct LegalClauseItem: Decodable, Hashable, Identifiable {
    let id: String
    var title: String
    var content: String
}

struct ToolRegistryItem: Decodable, Hashable, Identifiable {
    let id: String
    var name: String
    var description: String
    var isEnabled: Bool
}

struct ActivityItem: Decodable, Hashable, Identifiable {
    let id: String
    var title: String
    var status: String
    var createdAt: String
}

struct ConversationListItem: Decodable, Hashable, Identifiable {
    let id: String
    var title: String
    var messageCount: Int
    var updatedAt: String
}

struct ConversationDetail: Decodable, Hashable {
    struct Message: Decodable, Hashable {
        var role: String
        var content: String
    }

    var id: String
    var title: String
    var messages: [Message]
}

struct MemoryItemPayload: Codable, Hashable, Identifiable {
    let id: String
    var content: String
    var tags: [String]
    var createdAt: String
}

struct LilithSettings: Decodable, Hashable {
    var defaultAgent: String
    var defaultMode: String
    var theme: String
}

struct ProjectFile: Codable, Hashable, Identifiable {
    var id: String { path }
    var name: String
    var path: String
    var content: String
    var language: String
}

struct ProjectItem: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var description: String
    var files: [ProjectFile]
    var createdAt: String
    var updatedAt: String
}

struct CodeExecuteResponse: Decodable, Hashable {
    var success: Bool
    var output: String
}

struct AutoFixResponse: Decodable, Hashable {
    var success: Bool
    var fixedCode: String
    var explanation: String
}

struct AutoFixLoopResponse: Decodable, Hashable {
    var success: Bool
    var finalCode: String
    var output: String
    var totalAttempts: Int
}

struct CodeReviewSuggestion: Decodable, Hashable, Identifiable {
    var id: String { title + severity }
    var title: String
    var detail: String
    var severity: String
}

struct CodeReviewResponse: Decodable, Hashable {
    var summary: String
    var suggestions: [CodeReviewSuggestion]
}

struct CloneSiteResponse: Decodable, Hashable {
    var id: String
    var url: String
    var code: String
    var previewUrl: String
}

struct CheckoutResponse: Decodable, Hashable {
    var checkoutUrl: String
}

struct AnyDecodable: Decodable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = ""
        }
    }
}
