import SwiftUI

struct CombinedChatIDEView: View {
    @EnvironmentObject private var authStore: AuthStore

    @ObservedObject var chatViewModel: ChatViewModel
    @StateObject private var ideViewModel = IDEViewModel()

    @Binding var selectedAgent: AgentKind
    @Binding var selectedMode: AgentMode
    @Binding var ultraThinking: Bool
    @Binding var externalConversationId: String?

    var onCreditsChanged: (() async -> Void)?

    @State private var segment: Segment = .chat

    enum Segment: String, CaseIterable {
        case chat = "Chat"
        case code = "Code"
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Mode", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)

            Group {
                switch segment {
                case .chat:
                    ChatView(
                        viewModel: chatViewModel,
                        selectedAgent: $selectedAgent,
                        selectedMode: $selectedMode,
                        ultraThinking: $ultraThinking,
                        externalConversationId: $externalConversationId,
                        onCreditsChanged: onCreditsChanged
                    )
                case .code:
                    IDEView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
