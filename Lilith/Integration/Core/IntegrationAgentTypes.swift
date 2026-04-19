import Foundation

enum AgentKind: String, CaseIterable, Identifiable, Codable {
    case nova
    case pulse
    case verse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nova: return "Nova"
        case .pulse: return "Pulse"
        case .verse: return "Verse"
        }
    }

    var symbol: String {
        switch self {
        case .nova: return "sparkles"
        case .pulse: return "waveform"
        case .verse: return "text.quote"
        }
    }
}

enum AgentMode: String, CaseIterable, Identifiable, Codable {
    case e1
    case e2
    case turbo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .e1: return "E1"
        case .e2: return "E2"
        case .turbo: return "Turbo"
        }
    }
}

enum WorkspaceDestination: String, CaseIterable, Hashable, Codable, Identifiable {
    case assistant
    case messages
    case calls
    case social
    case finance
    case tools
    case inbox
    case account
    case documents
    case legal
    case web
    case media
    case video
    case image
    case clone
    case code
    case projects
    case history
    case activity
    case memory
    case vault

    var id: String { rawValue }

    static var primaryCases: [WorkspaceDestination] {
        [.assistant, .messages, .calls, .social, .finance, .tools, .inbox, .account]
    }

    static var utilityCases: [WorkspaceDestination] {
        [.documents, .legal, .web, .media, .clone, .code, .projects, .history, .activity, .memory, .vault]
    }

    static var compactCases: [WorkspaceDestination] {
        [.assistant, .messages, .calls, .social, .finance, .tools, .inbox, .account]
    }

    var icon: String {
        switch self {
        case .assistant: return "sparkles"
        case .messages: return "bubble.left.and.bubble.right"
        case .calls: return "phone"
        case .social: return "person.2"
        case .finance: return "dollarsign.circle"
        case .tools: return "wrench.and.screwdriver"
        case .inbox: return "tray"
        case .account: return "person.crop.circle"
        case .documents: return "doc.text"
        case .legal: return "doc.plaintext"
        case .web: return "globe"
        case .media: return "play.rectangle"
        case .video: return "video"
        case .image: return "photo"
        case .clone: return "square.on.square"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .projects: return "folder"
        case .history: return "clock.arrow.circlepath"
        case .activity: return "bolt"
        case .memory: return "brain"
        case .vault: return "lock.shield"
        }
    }

    var title: String {
        rawValue.capitalized
    }

    var subtitle: String {
        switch self {
        case .assistant: return "Ask Lilith"
        case .messages: return "Secure threads"
        case .calls: return "Voice and video"
        case .social: return "Posts and stories"
        case .finance: return "Money ops"
        case .tools: return "Marketplace"
        case .inbox: return "Unified updates"
        case .account: return "Identity"
        case .documents: return "Read and edit docs"
        case .legal: return "Clause analysis"
        case .web: return "Search and browse"
        case .media: return "Image/video generation"
        case .video: return "Video generation"
        case .image: return "Image generation"
        case .clone: return "Website clone"
        case .code: return "Code workspace"
        case .projects: return "Project explorer"
        case .history: return "Timeline"
        case .activity: return "Recent actions"
        case .memory: return "Settings and memory"
        case .vault: return "Secure vault"
        }
    }

    var shortLabel: String {
        switch self {
        case .assistant: return "Assist"
        case .messages: return "Msgs"
        case .calls: return "Calls"
        case .social: return "Social"
        case .finance: return "Finance"
        case .tools: return "Tools"
        case .inbox: return "Inbox"
        case .account: return "Account"
        case .documents: return "Docs"
        case .legal: return "Legal"
        case .web: return "Web"
        case .media: return "Media"
        case .video: return "Video"
        case .image: return "Image"
        case .clone: return "Clone"
        case .code: return "Code"
        case .projects: return "Projects"
        case .history: return "History"
        case .activity: return "Activity"
        case .memory: return "Memory"
        case .vault: return "Vault"
        }
    }
}
