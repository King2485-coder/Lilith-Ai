import SwiftUI

final class LilithUnifiedAppState: ObservableObject {
    @Published var currentScreen: LilithUnifiedScreen = .futuristic
    @Published var selectedTool: UnifiedLilithTool = .dashboard
    @Published var voidInput: String = ""
    @Published var conversation: [UnifiedLilithMessage] = [
        UnifiedLilithMessage(text: "Welcome back. Your workspace is ready.", isUser: false),
        UnifiedLilithMessage(text: "Choose a tool from the Tools screen or speak naturally in The Void.", isUser: false)
    ]

    @Published var showLeftPanel = true
    @Published var showRightPanel = true
    @Published var focusMode = false
}

enum LilithUnifiedScreen: Int, CaseIterable {
    case futuristic = 0
    case void = 1
    case tools = 2
}

enum UnifiedLilithTool: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case imageGen = "Image Generation"
    case summarize = "Summarize"
    case videoAnalyzer = "Video Analyzer"
    case scanner = "Scanner"
    case voice = "Voice"
    case gallery = "Gallery"
    case pay = "Pay"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "circle.grid.cross.fill"
        case .imageGen: return "sparkles"
        case .summarize: return "doc.text.magnifyingglass"
        case .videoAnalyzer: return "video.fill"
        case .scanner: return "viewfinder"
        case .voice: return "waveform"
        case .gallery: return "photo.on.rectangle"
        case .pay: return "creditcard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pay:
            return .orange
        case .scanner, .voice, .imageGen:
            return .cyan
        default:
            return .white
        }
    }
}

struct UnifiedLilithMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}
