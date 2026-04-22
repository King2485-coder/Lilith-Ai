import SwiftUI
import Combine

// MARK: - Tool Type

enum ToolType: String, CaseIterable, Identifiable {
    case imageGen  = "Image Gen"
    case summarize = "Summarize"
    case scanner   = "Scanner"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .imageGen:  return "photo.sparkles"
        case .summarize: return "doc.text.magnifyingglass"
        case .scanner:   return "viewfinder"
        }
    }
}

// MARK: - AppViewModel

final class AppViewModel: ObservableObject {
    @Published var selectedTool: ToolType? = nil
    @Published var conversationHistory: [ConversationEntry] = []

    func selectTool(_ tool: ToolType?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedTool = tool
        }
    }

    func clearHistory() {
        conversationHistory.removeAll()
    }
}

// MARK: - Conversation Entry (used by LeftPanel history)

struct ConversationEntry: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
}
