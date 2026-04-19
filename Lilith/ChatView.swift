import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var manager: LilithStateManager
    @EnvironmentObject private var speech: LilithSpeechManager

    @ObservedObject var viewModel: ChatViewModel
    var showComposer: Bool = true
    var showHeader: Bool = true

    @Binding var selectedAgent: AgentKind
    @Binding var selectedMode: AgentMode
    @Binding var ultraThinking: Bool
    @Binding var externalConversationId: String?
    var quickAccessCards: [ChatQuickAccessCard] = []
    var onOpenDestination: ((WorkspaceDestination) -> Void)?
    var onCreditsChanged: (() async -> Void)?

    private let quickPrompts = [
        "How much did I spend this week?",
        "Can I afford $200 right now?",
        "Draft a contractor NDA.",
        "Start a secure message with my team."
    ]

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                chatHeader
                Divider().background(LilithTheme.border)
            }
            messagesList
        }
        .background(chatBackground)
        .safeAreaInset(edge: .bottom) {
            if showComposer {
                composer
                    .background(.clear)
            }
        }
        .task(id: externalConversationId) {
            if let cid = externalConversationId {
                guard let token = authStore.token else { return }
                await viewModel.loadConversation(id: cid, token: token)
                externalConversationId = nil
            }
        }
        .task {
            viewModel.onAssistantSpoken = { text in
                speech.speak(text)
            }
        }
        .onChange(of: speech.transcript) { newValue in
            if speech.isListening {
                viewModel.draft = newValue
            }
        }
        .onChange(of: viewModel.isSending) { newValue in
            if newValue {
                manager.set(.thinking)
            }
        }
        .onChange(of: viewModel.isSearching) { newValue in
            if newValue {
                manager.set(.thinking)
            }
        }
        .onChange(of: viewModel.activeResult) { newValue in
            if newValue == nil && !viewModel.isSending && !viewModel.isSearching {
                manager.set(.idle)
            } else if newValue?.status == .complete {
                manager.set(.responding)
            }
        }
    }

    private var chatBackground: some View {
        ZStack {
            LilithTheme.background
            LinearGradient(
                colors: [
                    Color.clear,
                    LilithTheme.accentA.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            Circle()
                .fill(LilithTheme.glowGradient)
                .frame(width: 520, height: 520)
                .offset(x: 180, y: -240)
                .blur(radius: 24)
        }
        .ignoresSafeArea()
    }

    private var chatHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LilithTheme.heroGradient)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: selectedAgent.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Lilith")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("\(selectedAgent.title) · \(selectedMode.title)\(ultraThinking ? " · Ultra Thinking" : "")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LilithTheme.textSecondary)
                Text("Ask naturally. Lilith can route through finance, legal, planning, secure messages, calls, memory, builder tools, and the rest of the active capability graph.")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                viewModel.startNewConversation()
            } label: {
                Label("New chat", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LilithTheme.surface, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        // Filter out high-value outputs - they manifest in center
                        let displayMessages = viewModel.messages.filter { message in
                            // Don't show "Generated result" placeholder messages
                            if message.content == "Generated result" {
                                return false
                            }
                            return true
                        }

                        ForEach(displayMessages) { message in
                            messageRow(message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    if viewModel.isSending || viewModel.isSearching {
                        if viewModel.activeResult?.status == .pending {
                            creatingIndicator
                        } else {
                            typingIndicator
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("One chat. All of Lilith.")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("Chat first. Secure messages, calls, Wealth Wizard, Legal Ease, planning, approvals, memory, device control, and the builder stack stay reachable behind one clean conversation surface.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(LilithTheme.textSecondary)
                    .frame(maxWidth: 620, alignment: .leading)
            }

            if !quickAccessCards.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Open directly")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(quickAccessCards) { card in
                            Button {
                                onOpenDestination?(card.destination)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: card.destination.icon)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 34, height: 34)
                                            .background(LilithTheme.heroGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        Spacer()
                                        if let badge = card.badge, !badge.isEmpty {
                                            Text(badge)
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(LilithTheme.accentB, in: Capsule())
                                        }
                                    }

                                    Text(card.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(card.summary)
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(LilithTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(LilithTheme.border, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Try asking")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary)
                    .textCase(.uppercase)

                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.draft = prompt
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LilithTheme.accentA)
                            Text(prompt)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LilithTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(LilithTheme.border, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 32)
    }

    private func messageRow(_ message: ChatMessageItem) -> some View {
        HStack {
            if message.role == .assistant {
                assistantBubble(message)
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                userBubble(message)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func userBubble(_ message: ChatMessageItem) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Text("You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary)
                copyButton(for: message.content)
            }

            Text(message.content)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.13, green: 0.21, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LilithTheme.border, lineWidth: 1)
        )
        .frame(maxWidth: 520, alignment: .trailing)
    }

    private func assistantBubble(_ message: ChatMessageItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(message.toolUsed ?? selectedAgent.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.accentA)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LilithTheme.accentA.opacity(0.12), in: Capsule())

                if let approvalId = message.approvalId, !approvalId.isEmpty {
                    Text("Approval \(approvalId.prefix(8))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentB)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LilithTheme.accentB.opacity(0.12), in: Capsule())
                }

                Spacer()
                copyButton(for: message.content)
            }

            codeFormattedText(message.content)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white)

            if let preview = message.preview, !preview.isEmpty {
                metaCard(title: "Preview", body: preview)
            }

            if let plan = message.plan, !plan.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                    ForEach(plan) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(item.status == "completed" ? LilithTheme.accentA : LilithTheme.accentB.opacity(0.7))
                                .frame(width: 8, height: 8)
                            Text(item.step)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LilithTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LilithTheme.border, lineWidth: 1)
        )
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var typingIndicator: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LilithTheme.heroGradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: selectedAgent.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

            Text(viewModel.isSearching ? "Lilith is searching…" : "Lilith is thinking…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(LilithTheme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var creatingIndicator: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LilithTheme.heroGradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: selectedAgent.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

            Text("Lilith is creating...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(LilithTheme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $viewModel.draft)
                    .frame(minHeight: 44, maxHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .foregroundStyle(.white)
                    .overlay(alignment: .topLeading) {
                        if viewModel.draft.isEmpty {
                            Text("Message Lilith")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                                .padding(.leading, 18)
                                .padding(.top, 14)
                        }
                    }
                    .onTapGesture {
                        manager.set(.interacting)
                    }

                HStack(spacing: 8) {
                    roundControl(systemName: speech.isListening ? "mic.fill" : "mic") {
                        if speech.isListening {
                            speech.stopListening()
                        } else {
                            Task { await speech.requestPermissions() }
                            speech.startListening()
                            manager.set(.listening)
                        }
                    }

                    roundControl(systemName: "magnifyingglass") {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.searchWeb(token: token, query: viewModel.draft.isEmpty ? "Lilith capabilities" : viewModel.draft)
                        }
                    }
                    .disabled(viewModel.isSearching)

                    Button {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.sendMessage(token: token, agent: selectedAgent, mode: selectedMode, ultraThinking: ultraThinking)
                            if let onCreditsChanged {
                                await onCreditsChanged()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 46, height: 46)
                            .background(
                                viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
                                    ? Color.white.opacity(0.2)
                                    : LilithTheme.accentA,
                                in: Circle()
                            )
                    }
                    .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(LilithTheme.background.opacity(0.96))
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Divider().background(LilithTheme.border)
        }
    }

    private func roundControl(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(LilithTheme.elevated, in: Circle())
                .overlay(Circle().stroke(LilithTheme.border, lineWidth: 1))
        }
    }

    private func copyButton(for text: String) -> some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.04), in: Circle())
        }
    }

    private func metaCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func codeFormattedText(_ content: String) -> some View {
        let segments = splitCodeBlocks(content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isCode {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(segment.language.isEmpty ? "code" : segment.language)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(LilithTheme.textSecondary)
                            Spacer()
                            copyButton(for: segment.text)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(segment.text)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(red: 0.78, green: 0.90, blue: 0.84))
                                .padding(12)
                        }
                    }
                    .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(segment.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func splitCodeBlocks(_ content: String) -> [TextSegment] {
        let pattern = "```([\\w]*)\\n?([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [TextSegment(text: content, isCode: false, language: "")]
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        var segments: [TextSegment] = []
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let plain = nsContent.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(TextSegment(text: plain, isCode: false, language: ""))
                }
            }

            let language = match.range(at: 1).location == NSNotFound ? "" : nsContent.substring(with: match.range(at: 1))
            let code = match.range(at: 2).location == NSNotFound ? "" : nsContent.substring(with: match.range(at: 2))
            segments.append(TextSegment(text: code, isCode: true, language: language))
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsContent.length {
            let remainder = nsContent.substring(from: lastEnd)
            if !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(TextSegment(text: remainder, isCode: false, language: ""))
            }
        }

        return segments.isEmpty ? [TextSegment(text: content, isCode: false, language: "")] : segments
    }

    private struct TextSegment {
        let text: String
        let isCode: Bool
        let language: String
    }
}

struct ChatQuickAccessCard: Identifiable {
    let id = UUID()
    let destination: WorkspaceDestination
    let title: String
    let summary: String
    let badge: String?
}
