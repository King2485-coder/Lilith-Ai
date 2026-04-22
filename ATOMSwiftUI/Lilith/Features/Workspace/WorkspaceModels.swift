import Foundation

enum WorkspaceDestination: String, CaseIterable, Hashable {
    case assistant
    case messages
    case inbox
    case tools
    case finance
    case legal
    case media
    case web
    case activity
    case account

    case chat
    case social
    case calls
    case memory
    case documents
    case projects
    case history
    case code
    case video
    case image
    case clone
    case linux
    case lte

    static var primaryCases: [WorkspaceDestination] {
        [.assistant, .messages, .inbox, .tools, .finance, .legal, .media, .web, .activity, .account]
    }

    static var compactCases: [WorkspaceDestination] {
        [.assistant, .messages, .inbox, .tools, .account]
    }

    static var utilityCases: [WorkspaceDestination] {
        [.chat, .social, .calls, .memory, .documents, .projects, .history, .code, .video, .image, .clone, .linux, .lte]
    }

    var title: String {
        switch self {
        case .assistant: return "Home"
        case .messages: return "Messages"
        case .inbox: return "Inbox"
        case .tools: return "Tools"
        case .finance: return "Finance"
        case .legal: return "Legal"
        case .media: return "Media"
        case .web: return "Web"
        case .activity: return "Activity"
        case .account: return "Profile"
        case .chat: return "Chat"
        case .social: return "Social"
        case .calls: return "Calls"
        case .memory: return "Memory & Settings"
        case .documents: return "Documents"
        case .projects: return "Projects"
        case .history: return "History"
        case .code: return "Code Workspace"
        case .video: return "Video Studio"
        case .image: return "Image Studio"
        case .clone: return "Site Clone"
        case .linux: return "Linux Machines"
        case .lte:   return "Private LTE"
        }
    }

    var subtitle: String {
        switch self {
        case .assistant: return "Chat with Lilith across tools, memory, and planning"
        case .messages: return "Secure direct and group chat with calling built in"
        case .inbox: return "Unified exchange for messages, business, requests, transactions, documents, and tool results"
        case .tools: return "Central hub for every active Lilith capability"
        case .finance: return "Wealth Wizard balances, analysis, and approvals"
        case .legal: return "Legal Ease drafts, summaries, and clauses"
        case .media: return "Image, video, remix, reels, and editing workflows"
        case .web: return "Website clone, link intake, and prompt extraction"
        case .activity: return "Tasks, approvals, results, and conversation history"
        case .account: return "Lilith ID, profile, security, and billing"
        case .chat: return "Direct chat-first assistant interface"
        case .social: return "Profiles, stories, discovery, and the Lilith feed"
        case .calls: return "Recent calls, live sessions, and instant call access"
        case .memory: return "Preferences, permissions, and learned context"
        case .documents: return "PDF/editor workflows, drafting, and document intelligence"
        case .projects: return "Project storage and file organization"
        case .history: return "Conversation history and recall"
        case .code: return "Builder for files, code review, and execution"
        case .video: return "Prompt and media-driven video generation"
        case .image: return "Prompt-driven image generation"
        case .clone: return "Fetch and preview site structure"
        case .linux: return "Manage and monitor Linux machines via SSH"
        case .lte:   return "Lilith Private LTE: eSIM, network nodes, VoIP, and subscribers"
        }
    }

    var icon: String {
        switch self {
        case .assistant: return "message"
        case .messages: return "bubble.left.and.bubble.right"
        case .inbox: return "tray.full"
        case .tools: return "square.grid.2x2"
        case .finance: return "chart.line.uptrend.xyaxis"
        case .legal: return "doc.text.magnifyingglass"
        case .media: return "film.stack"
        case .web: return "globe"
        case .activity: return "clock.arrow.circlepath"
        case .account: return "person.crop.circle"
        case .chat: return "message"
        case .social: return "person.2.wave.2"
        case .calls: return "phone.connection"
        case .memory: return "brain.head.profile"
        case .documents: return "doc.richtext"
        case .projects: return "folder"
        case .history: return "clock"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .video: return "video"
        case .image: return "photo"
        case .linux: return "server.rack"
        case .lte:   return "antenna.radiowaves.left.and.right"
        case .clone: return "doc.on.doc"
        }
    }

    var shortLabel: String {
        switch self {
        case .assistant: return "Home"
        case .messages: return "Messages"
        case .inbox: return "Inbox"
        case .tools: return "Tools"
        case .finance: return "Finance"
        case .legal: return "Legal"
        case .media: return "Media"
        case .web: return "Web"
        case .activity: return "Activity"
        case .account: return "Profile"
        case .chat: return "Chat"
        case .social: return "Social"
        case .calls: return "Calls"
        case .memory: return "Memory"
        case .documents: return "Docs"
        case .projects: return "Projects"
        case .history: return "History"
        case .code: return "Code"
        case .video: return "Video"
        case .image: return "Image"
        case .clone: return "Clone"
        case .linux: return "Linux"
        case .lte:   return "LTE"
        }
    }
}

enum AgentMode: String, CaseIterable, Identifiable {
    case e1
    case e2
    case prototype
    case mobile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .e1: return "E-1"
        case .e2: return "E-2"
        case .prototype: return "Prototype"
        case .mobile: return "Mobile"
        }
    }

    var summary: String {
        switch self {
        case .e1: return "Stable and thorough"
        case .e2: return "Relentless deeper reasoning"
        case .prototype: return "Experimental ideas"
        case .mobile: return "Mobile-first thinking"
        }
    }
}

enum AgentKind: String, CaseIterable, Identifiable {
    case nova
    case forge
    case sentinel
    case atlas
    case pulse

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var detail: String {
        switch self {
        case .nova: return "Lead Architect and Developer"
        case .forge: return "Infrastructure and DevOps"
        case .sentinel: return "Security and Trust"
        case .atlas: return "Analytics and Intelligence"
        case .pulse: return "Growth and Marketing"
        }
    }

    var symbol: String {
        switch self {
        case .nova: return "chevron.left.forwardslash.chevron.right"
        case .forge: return "gearshape.2.fill"
        case .sentinel: return "shield.fill"
        case .atlas: return "chart.xyaxis.line"
        case .pulse: return "rocket.fill"
        }
    }
}

struct CreditsSummary: Decodable {
    let credits: Double?
    let isSuperAdmin: Bool
    let unlimited: Bool
}

struct SubscriptionDetails: Decodable {
    let plan: String
    let status: String
    let currentPeriodStart: String?
    let currentPeriodEnd: String?
}

struct SubscriptionResponse: Decodable {
    let subscription: SubscriptionDetails
    let credits: Double?
    let isSuperAdmin: Bool
}

struct AdminStatsResponse: Decodable {
    struct UserStats: Decodable {
        let total: Int
        let active: Int
        let premium: Int
        let free: Int
    }

    struct ContentStats: Decodable {
        let conversations: Int
        let projects: Int
        let videos: Int
        let images: Int
    }

    let users: UserStats
    let content: ContentStats
}

// MARK: - Conversation History

struct ConversationListItem: Decodable, Identifiable {
    let id: String
    let title: String
    let messageCount: Int?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, updatedAt
        case messageCount = "messages"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        // backend may return messages as array or int count
        if let count = try? container.decode(Int.self, forKey: .messageCount) {
            messageCount = count
        } else if let arr = try? container.decode([AnyDecodable].self, forKey: .messageCount) {
            messageCount = arr.count
        } else {
            messageCount = nil
        }
    }
}

struct AnyDecodable: Decodable {}

struct ConversationMessage: Decodable {
    let role: String
    let content: String
}

struct ConversationDetail: Decodable {
    let id: String
    let title: String
    let messages: [ConversationMessage]
}

// MARK: - Tools / Activity / Memory

struct ToolRegistryItem: Decodable, Identifiable {
    let id: String
    let title: String
    let category: String
    let status: String
    let summary: String
}

struct ToolRegistryResponse: Decodable {
    let tools: [ToolRegistryItem]
}

struct ActivityItem: Decodable, Identifiable {
    let id: String
    let kind: String
    let title: String
    let detail: String
    let status: String
    let createdAt: String
}

struct ActivityResponse: Decodable {
    let items: [ActivityItem]
}

struct MemoryItemPayload: Decodable, Identifiable {
    let id: String
    let label: String
    let value: String
    let source: String
    let createdAt: String
    let updatedAt: String
}

struct MemoryResponse: Decodable {
    let items: [MemoryItemPayload]
}

struct MemoryCreatePayload: Encodable {
    let label: String
    let value: String
    let source: String
}

struct LilithSettings: Codable {
    var defaultAgent: String
    var defaultMode: String
    var approvalMode: String
    var memoryEnabled: Bool
    var toolHints: Bool
}

// MARK: - Finance

struct FinanceAccountSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let balance: Double
    let currency: String
    let updatedAt: String
}

struct FinanceBalanceResponse: Decodable {
    let currency: String
    let totalBalance: Double
    let accounts: [FinanceAccountSummary]
}

struct FinanceTransactionItem: Decodable, Identifiable {
    let id: String
    let accountId: String
    let merchant: String
    let category: String
    let amount: Double
    let direction: String
    let note: String
    let occurredAt: String
}

struct FinanceTransactionsResponse: Decodable {
    let days: Int
    let transactions: [FinanceTransactionItem]
}

struct FinanceCategorySpend: Decodable, Identifiable {
    var id: String { category }
    let category: String
    let amount: Double
}

struct FinanceMerchantSpend: Decodable, Identifiable {
    var id: String { merchant }
    let merchant: String
    let amount: Double
}

struct FinanceAnalysisResponse: Decodable {
    let periodDays: Int
    let spent: Double
    let previousSpent: Double
    let delta: Double
    let percentChange: Double
    let topCategories: [FinanceCategorySpend]
    let topMerchants: [FinanceMerchantSpend]
    let transactionCount: Int
}

struct FinanceSimulationPayload: Encodable {
    let amount: Double
    let merchant: String
    let sourceAccount: String
}

struct FinanceSimulationResponse: Decodable {
    let account: String
    let merchant: String
    let amount: Double
    let currentBalance: Double
    let remainingBalance: Double
    let canAfford: Bool
    let message: String
}

struct FinanceTransferPayload: Encodable {
    let amount: Double
    let sourceAccount: String
    let destinationAccount: String
}

struct FinanceApprovalItem: Decodable, Identifiable {
    let id: String
    let domain: String
    let title: String
    let preview: String
    let status: String
    let createdAt: String
    let resolvedAt: String?
}

struct FinanceApprovalsResponse: Decodable {
    let approvals: [FinanceApprovalItem]
}

struct FinanceTransferResponse: Decodable {
    let status: String
    let approvalId: String?
    let preview: String?
}

// MARK: - Legal

struct LegalSummaryPayload: Encodable {
    let text: String
    let title: String
}

struct LegalSummaryResponse: Decodable {
    let summary: String
    let artifactId: String
}

struct LegalDraftPayload: Encodable {
    let prompt: String
    let documentType: String
    let parties: [String]
}

struct LegalDraftResponse: Decodable {
    let document: String
    let artifactId: String
}

struct LegalClauseItem: Decodable, Identifiable {
    var id: String { label }
    let label: String
    let confidence: Double
}

struct LegalClauseResponse: Decodable {
    let clauses: [LegalClauseItem]
    let artifactId: String
}

// MARK: - Code Execution

struct CodeExecutePayload: Encodable {
    let code: String
    let language: String
    let projectId: String?
}

struct CodeExecuteResponse: Decodable {
    let success: Bool
    let output: String?
    let error: String?
}

struct AutoFixPayload: Encodable {
    let code: String
    let language: String
    let error: String
    let projectId: String?
}

struct AutoFixResponse: Decodable {
    let success: Bool
    let fixedCode: String?
    let explanation: String?
}

struct AutoFixLoopPayload: Encodable {
    let code: String
    let language: String
    let projectId: String?
}

struct AutoFixLoopResponse: Decodable {
    let success: Bool
    let finalCode: String?
    let output: String?
    let totalAttempts: Int?
}

// MARK: - Code Review

struct CodeReviewPayload: Encodable {
    let code: String
    let language: String
    let projectId: String?
}

struct CodeReviewSuggestion: Decodable, Identifiable {
    var id: String { title + detail }
    let title: String
    let detail: String
    let severity: String?
}

struct CodeReviewResponse: Decodable {
    let summary: String
    let suggestions: [CodeReviewSuggestion]
}

// MARK: - Site Clone

struct CloneSitePayload: Encodable {
    let url: String
}

struct CloneSiteResponse: Decodable {
    let id: String
    let url: String
    let code: String
    let previewUrl: String
}

// MARK: - Subscription & Credits

struct SubscriptionCheckoutPayload: Encodable {
    let planId: String
    let originUrl: String
}

struct CreditsCheckoutPayload: Encodable {
    let packageId: String
    let originUrl: String
}

struct CheckoutResponse: Decodable {
    let checkoutUrl: String
}

struct AddFilePayload: Encodable {
    let name: String
    let content: String
    let language: String?
}

struct UpdateFilePayload: Encodable {
    let content: String
}

// MARK: - Lilith Communication

enum LilithPresenceState: String, CaseIterable, Codable {
    case online
    case away
    case offline
}

enum LilithMessageDirection: String, Codable {
    case incoming
    case outgoing
}

enum LilithMessageDeliveryStatus: String, CaseIterable, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum LilithCallType: String, CaseIterable, Codable {
    case voice
    case video
}

enum LilithCallConnectionState: String, CaseIterable, Codable {
    case ringing
    case connecting
    case connected
    case ended
    case missed
}

enum LilithConnectionStatus: String, CaseIterable, Codable {
    case pending
    case connected
}

enum LilithProfileVisibility: String, CaseIterable, Codable {
    case publicProfile = "public"
    case connectionsOnly = "connections"
    case privateProfile = "private"
}

enum LilithPostAudience: String, CaseIterable, Codable, Identifiable {
    case publicFeed = "Public"
    case connections = "Connections"
    case privateNote = "Private"

    var id: String { rawValue }
}

struct LilithMiniProfile: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var handle: String
}

struct LilithIdentityProfile: Identifiable, Codable, Equatable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var recoveryEmail: String?
    var phoneNumber: String?
    var location: String
    var visibility: LilithProfileVisibility
    var followerCount: Int
    var followingCount: Int
    var connectionCount: Int
    var avatarSeed: Int

    var handle: String {
        "@\(username)"
    }
}

struct LilithSecureMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let chatID: UUID
    var body: String
    var sentAt: Date
    var direction: LilithMessageDirection
    var deliveryStatus: LilithMessageDeliveryStatus
    var attachmentName: String?
    var attachmentKind: String?
    var attachmentData: Data?
    var replyToMessageID: UUID?
    var reactions: [String]
    var isPinned: Bool
    var isStarred: Bool
    var editedAt: Date?
}

struct LilithSecureThread: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var handle: String
    var lastMessagePreview: String
    var lastMessageAt: Date
    var unreadCount: Int
    var presence: LilithPresenceState
    var isPinned: Bool
    var isMuted: Bool
    var isArchived: Bool
    var isGroup: Bool
    var topic: String?
    var members: [LilithMiniProfile]
    var messages: [LilithSecureMessage]
}

struct LilithConnectionProfile: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var handle: String
    var about: String
    var status: LilithConnectionStatus
}

enum LilithBusinessCategory: String, CaseIterable, Codable, Identifiable {
    case professionalServices = "Professional Services"
    case creatorStudio = "Creator Studio"
    case legal = "Legal"
    case finance = "Finance"
    case retail = "Retail"
    case wellness = "Wellness"
    case technology = "Technology"

    var id: String { rawValue }
}

struct LilithBusinessProfile: Identifiable, Codable, Equatable {
    let id: String
    var businessName: String
    var handle: String
    var tagline: String
    var category: LilithBusinessCategory
    var isVerified: Bool
    var acceptsPayments: Bool
    var responseTime: String
    var averageRating: Double
}

struct LilithBusinessService: Identifiable, Codable, Equatable {
    let id: String
    var businessID: String
    var title: String
    var price: Double
    var description: String
}

struct LilithBusinessReview: Identifiable, Codable, Equatable {
    let id: UUID
    var businessID: String
    var authorName: String
    var rating: Int
    var comment: String
    var createdAt: Date
}

struct LilithStory: Identifiable, Codable, Equatable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var caption: String
    var createdAt: Date
    var expiresAt: Date
}

struct LilithSocialComment: Identifiable, Codable, Equatable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var body: String
    var createdAt: Date
}

struct LilithSocialPost: Identifiable, Codable, Equatable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var body: String
    var createdAt: Date
    var audience: LilithPostAudience
    var likeCount: Int
    var likedByMe: Bool
    var mediaLabel: String?
    var mediaData: Data?
    var tags: [String]
    var comments: [LilithSocialComment]
}

struct LilithCallSession: Identifiable, Codable, Equatable {
    let id: UUID
    let chatID: UUID
    var title: String
    var handle: String
    var type: LilithCallType
    var state: LilithCallConnectionState
    var startedAt: Date
    var muted: Bool
    var speakerOn: Bool
    var cameraOn: Bool
}

struct LilithCallRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var peerName: String
    var peerHandle: String
    var type: LilithCallType
    var startedAt: Date
    var durationSeconds: Int
    var wasMissed: Bool
}

struct LilithDeviceSession: Identifiable, Codable, Equatable {
    let id: UUID
    var deviceName: String
    var lastSeenAt: Date
    var isCurrent: Bool
}

struct LilithCommunicationSnapshot: Codable {
    var profile: LilithIdentityProfile
    var threads: [LilithSecureThread]
    var connections: [LilithConnectionProfile]
    var stories: [LilithStory]
    var posts: [LilithSocialPost]
    var callHistory: [LilithCallRecord]
    var deviceSessions: [LilithDeviceSession]
}
