import SwiftUI
import PhotosUI
import UIKit
import LocalAuthentication

struct WorkspaceShellView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var selectedDestination: WorkspaceDestination = .assistant
    @State private var chatConversationId: String?

    @StateObject private var mesh = LilithBluetoothMesh()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var financeViewModel = FinanceDashboardViewModel()
    @StateObject private var legalViewModel = LegalDashboardViewModel()
    @StateObject private var toolsViewModel = ToolsRegistryViewModel()
    @StateObject private var activityViewModel = ActivityDashboardViewModel()
    @StateObject private var inboxViewModel = InboxViewModel()
    @StateObject private var memoryViewModel = MemorySettingsViewModel()
    @StateObject private var communicationViewModel = CommunicationHubViewModel()

    @State private var selectedAgent: AgentKind = .nova
    @State private var selectedMode: AgentMode = .e1
    @State private var ultraThinking = false
    @State private var showAgentSelector = false

    @State private var credits: Double = 0
    @State private var isSuperAdmin = false
    @State private var currentPlan = "free"
    @State private var showSubscription = false

    @State private var sidebarPrimaryExpanded = true
    @State private var sidebarWorkspacesExpanded = true
    @State private var lilithOSInput = ""
    @State private var showGlobalActions = false
    @FocusState private var osInputFocused: Bool

    private let apiClient = APIClient()

    var body: some View {
        GeometryReader { proxy in
            let sidebarVisible = proxy.size.width >= 980

            ZStack {
                shellBackground

                if sidebarVisible {
                    HStack(spacing: 0) {
                        sidebar(width: min(300, max(260, proxy.size.width * 0.27)))
                        Divider().background(LilithTheme.border)
                        destinationSurface(sidebarVisible: true)
                    }
                } else {
                    VStack(spacing: 0) {
                        compactHeader
                        destinationSurface(sidebarVisible: false)
                        compactDock
                    }
                }

                lilithOSOverlay(sidebarVisible: sidebarVisible)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LilithTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showAgentSelector) {
            AgentSelectorSheet(
                selectedMode: $selectedMode,
                selectedAgent: $selectedAgent,
                ultraThinking: $ultraThinking,
                onDismiss: { showAgentSelector = false }
            )
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionSheet(
                currentPlan: currentPlan,
                credits: credits,
                isSuperAdmin: isSuperAdmin,
                onDismiss: { showSubscription = false },
                onPurchaseComplete: { Task { await loadChrome() } }
            )
        }
        .task {
            mesh.startMesh()
            await loadChrome()
            await preloadVisibleData()
        }
        .task(id: authStore.user?.id) {
            await communicationViewModel.bootstrap(user: authStore.user, token: authStore.token)
        }
        .onChange(of: selectedDestination) { _, _ in
            Task { await loadDataForCurrentDestination() }
        }
    }

    private func lilithOSOverlay(sidebarVisible: Bool) -> some View {
        VStack(spacing: 10) {
            Spacer()

            if showGlobalActions {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick actions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                            .textCase(.uppercase)
                        HStack(spacing: 8) {
                            osActionButton("Create", icon: "square.and.pencil") {
                                select(.social)
                                communicationViewModel.postDraft = "New post"
                                showGlobalActions = false
                            }
                            osActionButton("Message", icon: "bubble.left.and.bubble.right") {
                                select(.messages)
                                showGlobalActions = false
                            }
                            osActionButton("Pay", icon: "dollarsign.circle") {
                                select(.finance)
                                showGlobalActions = false
                            }
                            osActionButton("Ask Lilith", icon: "sparkles") {
                                select(.assistant)
                                osInputFocused = true
                                showGlobalActions = false
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.horizontal, sidebarVisible ? 26 : 14)
            }

            VStack(spacing: 8) {
                if !osContextHints.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(osContextHints, id: \.title) { hint in
                                Button {
                                    lilithOSInput = hint.prompt
                                    runLilithOSCommand()
                                } label: {
                                    Text(hint.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(LilithTheme.surface, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            showGlobalActions.toggle()
                        }
                    } label: {
                        Image(systemName: showGlobalActions ? "xmark" : "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(LilithTheme.elevated, in: Circle())
                    }
                    .buttonStyle(.plain)

                    TextField(osInputPlaceholder, text: $lilithOSInput)
                        .focused($osInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.sentences)

                    Button {
                        runLilithOSCommand()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(LilithTheme.accentA)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LilithTheme.background.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(LilithTheme.border, lineWidth: 1)
                    )
            )
            .padding(.horizontal, sidebarVisible ? 26 : 12)
            .padding(.bottom, sidebarVisible ? 16 : 72)
        }
        .animation(.easeInOut(duration: 0.2), value: showGlobalActions)
    }

    private var osInputPlaceholder: String {
        switch selectedDestination {
        case .messages: return "Ask Lilith: message @username, call @username, pay @username $20"
        case .social: return "Ask Lilith: create post, find people, message @username"
        case .finance: return "Ask Lilith: pay @username $20, split $120, summarize spending"
        case .tools: return "Ask Lilith: open PDF editor, website clone, reels generator"
        case .inbox: return "Ask Lilith: review unread, open transactions, mark all read"
        default: return "Ask Lilith: message @username, call @username, pay @username, create post"
        }
    }

    private var osContextHints: [LilithOSHint] {
        switch selectedDestination {
        case .messages:
            return [
                LilithOSHint(title: "Summarize thread", prompt: "summarize this conversation"),
                LilithOSHint(title: "Request payment", prompt: "request payment in this chat"),
                LilithOSHint(title: "Start call", prompt: "start a voice call")
            ]
        case .social:
            return [
                LilithOSHint(title: "New post", prompt: "create a new social post"),
                LilithOSHint(title: "Find people", prompt: "find people by username"),
                LilithOSHint(title: "Message author", prompt: "message this profile")
            ]
        case .finance:
            return [
                LilithOSHint(title: "Split bill", prompt: "split $96 between 3"),
                LilithOSHint(title: "Send money", prompt: "send $20"),
                LilithOSHint(title: "Generate invoice", prompt: "draft invoice for $240")
            ]
        case .tools:
            return [
                LilithOSHint(title: "Open PDF Editor", prompt: "open pdf editor"),
                LilithOSHint(title: "Open Video Editor", prompt: "open video editor"),
                LilithOSHint(title: "Prompt from Link", prompt: "open prompt from link")
            ]
        case .inbox:
            return [
                LilithOSHint(title: "Unread first", prompt: "show unread inbox"),
                LilithOSHint(title: "Open payments", prompt: "open transaction inbox items"),
                LilithOSHint(title: "Go to messages", prompt: "open messages")
            ]
        default:
            return [
                LilithOSHint(title: "Ask Lilith", prompt: "help me plan my day"),
                LilithOSHint(title: "Message", prompt: "open messages"),
                LilithOSHint(title: "Tools", prompt: "open tools")
            ]
        }
    }

    private func runLilithOSCommand() {
        let command = lilithOSInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        lilithOSInput = ""

        let lowered = command.lowercased()
        let handle = extractHandle(from: command)
        let amount = extractAmount(from: command)

        if (lowered.contains("message") || lowered.contains("dm") || lowered.contains("text")), let handle {
            let threadID = communicationViewModel.ensureThread(for: displayName(for: handle), handle: handle)
            communicationViewModel.openThread(id: threadID)
            select(.messages)
            return
        }

        if (lowered.contains("call") || lowered.contains("voice") || lowered.contains("video")), let handle {
            let threadID = communicationViewModel.ensureThread(for: displayName(for: handle), handle: handle)
            communicationViewModel.openThread(id: threadID)
            communicationViewModel.startCall(for: threadID, type: lowered.contains("video") ? .video : .voice)
            select(.messages)
            return
        }

        if lowered.contains("pay"), let handle {
            let paymentTarget = communicationViewModel.paymentProfile(forHandle: handle)
            let amountText = amount.map { String(format: "%.2f", $0) } ?? "20"
            Task {
                _ = await communicationViewModel.submitPayment(
                    to: paymentTarget,
                    amountText: amountText,
                    note: "Sent via Lilith OS command",
                    intent: .pay,
                    rail: .fiat
                )
            }
            let threadID = communicationViewModel.ensureThread(for: displayName(for: handle), handle: handle)
            communicationViewModel.openThread(id: threadID)
            select(.messages)
            return
        }

        if lowered.contains("message") || lowered.contains("chat") {
            select(.messages)
            return
        }
        if lowered.contains("inbox") || lowered.contains("notification") {
            select(.inbox)
            return
        }
        if lowered.contains("pay") || lowered.contains("wallet") || lowered.contains("invoice") {
            select(.finance)
            financeViewModel.aiPrompt = command
            financeViewModel.runAIFinanceAction()
            return
        }
        if lowered.contains("social") || lowered.contains("post") || lowered.contains("profile") {
            select(.social)
            if lowered.contains("post") {
                communicationViewModel.postDraft = "New post"
            }
            return
        }
        if lowered.contains("tool") || lowered.contains("pdf") || lowered.contains("video") || lowered.contains("reel") || lowered.contains("website") {
            select(.tools)
            return
        }

        // Default: route through assistant chat.
        select(.assistant)
        chatViewModel.draft = command
        if let token = authStore.token {
            Task {
                await chatViewModel.sendMessage(
                    token: token,
                    agent: selectedAgent,
                    mode: selectedMode,
                    ultraThinking: ultraThinking
                )
            }
        }
    }

    private func extractHandle(from command: String) -> String? {
        guard let match = command.split(separator: " ").first(where: { $0.hasPrefix("@") }) else { return nil }
        let cleaned = match
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0 == "@" || $0 == "_" || $0 == "." }
        return cleaned.count > 1 ? cleaned.lowercased() : nil
    }

    private func extractAmount(from command: String) -> Double? {
        let pattern = #"\$?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: command.utf16.count)
        guard let match = regex.firstMatch(in: command, range: range),
              let valueRange = Range(match.range(at: 1), in: command) else { return nil }
        return Double(command[valueRange])
    }

    private func displayName(for handle: String) -> String {
        handle
            .replacingOccurrences(of: "@", with: "")
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var shellBackground: some View {
        ZStack {
            LilithTheme.background

            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.06),
                    LilithTheme.background,
                    Color(red: 0.08, green: 0.07, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(LilithTheme.glowGradient)
                .frame(width: 600, height: 600)
                .offset(x: -200, y: -260)
                .blur(radius: 30)
        }
    }

    private func sidebar(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LilithTheme.heroGradient)
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lilith")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text("Chat-first shell for assistant, communication, and tools.")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                }

                Button {
                    chatViewModel.startNewConversation()
                    select(.assistant)
                } label: {
                    Label("New chat", systemImage: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(LilithTheme.accentA.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: Primary section
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarPrimaryExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Primary")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LilithTheme.textSecondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Image(systemName: sidebarPrimaryExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if sidebarPrimaryExpanded {
                            ForEach(WorkspaceDestination.primaryCases, id: \.self) { destination in
                                sidebarItem(destination)
                            }
                        }
                    }

                    // MARK: Workspaces section
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarWorkspacesExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Workspaces")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LilithTheme.textSecondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Image(systemName: sidebarWorkspacesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if sidebarWorkspacesExpanded {
                            ForEach(WorkspaceDestination.utilityCases, id: \.self) { destination in
                                sidebarItem(destination)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showAgentSelector = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedAgent.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedAgent.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(selectedMode.title)\(ultraThinking ? " · Ultra" : "")")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .padding(12)
                    .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Circle()
                        .fill(mesh.isScanning ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)

                    Text(mesh.isScanning ? "Mesh scanning" : "Mesh idle")
                        .font(.caption)
                        .foregroundStyle(.white)

                    if !mesh.discoveredDevices.isEmpty {
                        Text("Devices: \(mesh.discoveredDevices.count)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        if !isSuperAdmin {
                            showSubscription = true
                        }
                    } label: {
                        Label(
                            isSuperAdmin ? "Unlimited" : currencyLabel(credits),
                            systemImage: isSuperAdmin ? "bolt.fill" : "creditcard"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(LilithTheme.surface, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        select(.account)
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(LilithTheme.surface, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(width: width)
        .background(
            LilithTheme.background.opacity(0.7)
                .overlay(Color.black.opacity(0.08))
                .ignoresSafeArea()
        )
    }

    private func sidebarItem(_ destination: WorkspaceDestination) -> some View {
        let isSelected = selectedDestination == destination
        return Button {
            select(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black : .white)
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? Color.white : LilithTheme.elevated,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.shortLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(destination.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.74) : LilithTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let badge = sidebarBadge(for: destination) {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(LilithTheme.accentB, in: Capsule())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? LilithTheme.accentA.opacity(0.22) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? LilithTheme.accentA.opacity(0.34) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDestination.title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text(selectedDestination.subtitle)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showAgentSelector = true
            } label: {
                Image(systemName: selectedAgent.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LilithTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                if !isSuperAdmin {
                    showSubscription = true
                }
            } label: {
                Image(systemName: isSuperAdmin ? "bolt.fill" : "creditcard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LilithTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func sidebarBadge(for destination: WorkspaceDestination) -> String? {
        switch destination {
        case .messages:
            let unread = communicationViewModel.unreadCount
            return unread > 0 ? "\(unread)" : nil
        case .inbox:
            let unread = inboxViewModel.unreadCount
            return unread > 0 ? "\(unread)" : nil
        case .finance:
            let pending = financeViewModel.pendingApprovalsCount
            return pending > 0 ? "\(pending)" : nil
        case .activity:
            let pending = activityViewModel.items.filter { $0.status == "pending" }.count
            return pending > 0 ? "\(pending)" : nil
        default:
            return nil
        }
    }

    private func destinationSurface(sidebarVisible: Bool) -> some View {
        Group {
            if selectedDestination == .assistant || selectedDestination == .chat {
                ChatView(
                    viewModel: chatViewModel,
                    showHeader: sidebarVisible,
                    selectedAgent: $selectedAgent,
                    selectedMode: $selectedMode,
                    ultraThinking: $ultraThinking,
                    externalConversationId: $chatConversationId,
                    quickAccessCards: homeQuickAccessCards,
                    onOpenDestination: { destination in
                        select(destination)
                    },
                    onCreditsChanged: { await loadChrome() }
                )
            } else {
                VStack(spacing: 0) {
                    if sidebarVisible {
                        destinationHeader
                        Divider().background(LilithTheme.border)
                    }
                    destinationContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: sidebarVisible ? 32 : 0, style: .continuous)
                .fill(LilithTheme.background.opacity(sidebarVisible ? 0.84 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: sidebarVisible ? 32 : 0, style: .continuous)
                .stroke(sidebarVisible ? LilithTheme.border : Color.clear, lineWidth: 1)
        )
        .safeAreaInset(edge: .bottom) {
            if sidebarVisible {
                Color.clear.frame(height: 0)
            } else {
                Color.clear.frame(height: showGlobalActions ? 170 : 108)
            }
        }
        .padding(sidebarVisible ? 18 : 0)
    }

    private var destinationHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDestination.title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text(selectedDestination.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LilithTheme.textSecondary)
            }

            Spacer()

            if selectedDestination != .account {
                Button {
                    select(.account)
                } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(LilithTheme.surface, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch selectedDestination {
        case .assistant, .chat:
            EmptyView()
        case .messages:
            MessagesWorkspaceView(
                viewModel: communicationViewModel,
                onOpenSocial: { select(.social) },
                onOpenCalls: { select(.calls) }
            )
        case .inbox:
            InboxWorkspaceView(
                viewModel: inboxViewModel,
                onOpenMessages: { select(.messages) },
                onOpenDocuments: { select(.documents) },
                onOpenTools: { select(.tools) },
                onOpenFinance: { select(.finance) },
                onOpenActivity: { select(.activity) }
            )
        case .tools:
            ToolsHubView(
                viewModel: toolsViewModel,
                onOpenDestination: { destination in
                    select(destination)
                },
                onOpenChatPrompt: { prompt in
                    chatViewModel.draft = prompt
                    select(.assistant)
                }
            )
        case .finance:
            FinanceWorkspaceView(viewModel: financeViewModel) {
                select(.activity)
            }
        case .legal:
            LegalWorkspaceView(viewModel: legalViewModel)
        case .media:
            MediaWorkspaceHubView { destination in
                select(destination)
            }
        case .web:
            WebWorkspaceHubView { destination in
                select(destination)
            }
        case .social:
            SocialWorkspaceView(
                viewModel: communicationViewModel,
                onOpenMessages: { threadID in
                    communicationViewModel.openThread(id: threadID)
                    select(.messages)
                },
                onStartCall: { threadID, type in
                    communicationViewModel.openThread(id: threadID)
                    communicationViewModel.startCall(for: threadID, type: type)
                    select(.messages)
                }
            )
        case .calls:
            CallsWorkspaceView(viewModel: communicationViewModel) { threadID in
                communicationViewModel.openThread(id: threadID)
                select(.messages)
            }
        case .documents:
            DocumentsWorkspaceHubView(
                onOpenLegal: { select(.legal) },
                onOpenCode: { select(.code) },
                onOpenChatPrompt: { prompt in
                    chatViewModel.draft = prompt
                    select(.assistant)
                }
            )
        case .projects:
            ProjectsView()
        case .history:
            HistoryView { conversationId in
                chatConversationId = conversationId
                select(.assistant)
            }
        case .activity:
            ActivityWorkspaceView(viewModel: activityViewModel) { conversationId in
                chatConversationId = conversationId
                select(.assistant)
            }
        case .memory:
            MemoryWorkspaceView(
                viewModel: memoryViewModel,
                selectedAgent: $selectedAgent,
                selectedMode: $selectedMode,
                ultraThinking: $ultraThinking,
                onOpenAccount: { select(.account) },
                onLogout: { authStore.logout() }
            )
        case .code:
            IDEView()
        case .video:
            VideoView()
        case .image:
            ImageGenView()
        case .clone:
            CloneView()
        case .linux:
            LinuxMachinesView()
        case .lte:
            LTENetworkView()
        case .account:
            ProfileWorkspaceView(
                communicationViewModel: communicationViewModel,
                selectedAgent: $selectedAgent,
                selectedMode: $selectedMode,
                ultraThinking: $ultraThinking,
                onOpenMemory: { select(.memory) },
                onOpenActivity: { select(.activity) },
                onLogout: { authStore.logout() }
            )
        }
    }

    private var homeQuickAccessCards: [ChatQuickAccessCard] {
        [
            ChatQuickAccessCard(
                destination: .messages,
                title: "Secure messages",
                summary: "Encrypted conversations and calling stay inside Lilith.",
                badge: communicationViewModel.unreadCount > 0 ? "\(communicationViewModel.unreadCount)" : nil
            ),
            ChatQuickAccessCard(
                destination: .inbox,
                title: "Inbox",
                summary: "Unified requests, transactions, docs, and tool results.",
                badge: inboxViewModel.unreadCount > 0 ? "\(inboxViewModel.unreadCount)" : nil
            ),
            ChatQuickAccessCard(
                destination: .social,
                title: "Social",
                summary: "Profiles, discovery, stories, and the Lilith feed.",
                badge: nil
            ),
            ChatQuickAccessCard(
                destination: .tools,
                title: "Tools",
                summary: "Open Wealth Wizard, Legal Ease, builder, media, and more.",
                badge: nil
            ),
            ChatQuickAccessCard(
                destination: .activity,
                title: "Activity",
                summary: "Review approvals, tasks, and prior results.",
                badge: financeViewModel.pendingApprovalsCount > 0 ? "\(financeViewModel.pendingApprovalsCount) pending" : nil
            )
        ]
    }

    private var compactDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkspaceDestination.compactCases, id: \.self) { destination in
                    Button {
                        select(destination)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: destination.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(destination.shortLabel)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(selectedDestination == destination ? .white : LilithTheme.textSecondary)
                        .frame(minWidth: 64)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedDestination == destination ? LilithTheme.accentA.opacity(0.18) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(LilithTheme.background.opacity(0.97))
        .overlay(alignment: .top) {
            Divider().background(LilithTheme.border)
        }
    }

    private func osActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func select(_ destination: WorkspaceDestination) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedDestination = destination
    }

    private func loadChrome() async {
        guard let token = authStore.token else { return }
        do {
            let subscription: SubscriptionResponse = try await apiClient.request("/subscription", token: token)
            isSuperAdmin = subscription.isSuperAdmin
            currentPlan = subscription.subscription.plan
            credits = subscription.credits ?? credits
        } catch {
            // Keep existing chrome state if the request fails.
        }
    }

    private func preloadVisibleData() async {
        await loadDataForCurrentDestination()
        await communicationViewModel.bootstrap(user: authStore.user, token: authStore.token)
        guard let token = authStore.token else { return }
        await toolsViewModel.load(token: token)
        await activityViewModel.load(token: token)
        await inboxViewModel.load(token: token)
        await memoryViewModel.load(token: token)
        if let settings = memoryViewModel.settings {
            if let mappedAgent = AgentKind(rawValue: settings.defaultAgent) {
                selectedAgent = mappedAgent
            }
            if let mappedMode = AgentMode(rawValue: settings.defaultMode) {
                selectedMode = mappedMode
            }
        }
    }

    private func loadDataForCurrentDestination() async {
        guard let token = authStore.token else { return }
        switch selectedDestination {
        case .assistant, .chat:
            return
        case .messages, .social, .calls, .media, .web, .documents, .projects, .history:
            return
        case .inbox:
            await inboxViewModel.load(token: token)
        case .finance:
            await financeViewModel.load(token: token)
        case .legal:
            return
        case .tools:
            await toolsViewModel.load(token: token)
        case .activity:
            await activityViewModel.load(token: token)
            await communicationViewModel.markAllNotificationsRead()
        case .memory:
            await memoryViewModel.load(token: token)
        case .code, .video, .image, .clone, .account, .linux, .lte:
            return
        }
    }

    private func currencyLabel(_ amount: Double) -> String {
        amount >= 1000 ? String(format: "$%.0fk", amount / 1000) : String(format: "$%.0f", amount)
    }
}

private struct MessagesWorkspaceView: View {
    @ObservedObject var viewModel: CommunicationHubViewModel
    var onOpenSocial: () -> Void
    var onOpenCalls: () -> Void

    @State private var showCompactThread = false

    var body: some View {
        GeometryReader { proxy in
            let splitLayout = proxy.size.width >= 960

            Group {
                if splitLayout {
                    HStack(spacing: 0) {
                        threadList
                            .frame(width: min(340, max(290, proxy.size.width * 0.32)))
                        Divider().background(LilithTheme.border)
                        threadDetail(compact: false)
                    }
                } else if showCompactThread, viewModel.selectedThread != nil {
                    threadDetail(compact: true)
                } else {
                    threadList
                }
            }
            .background(Color.clear)
            .sheet(isPresented: $viewModel.isPresentingCallSheet) {
                ActiveCallSheet(viewModel: viewModel)
                    .presentationDetents([.fraction(0.54), .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: viewModel.selectedThreadID) { _, newValue in
                if !splitLayout {
                    showCompactThread = newValue != nil
                }
            }
        }
        .keyboardAdaptive()
    }

    private var threadList: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Secure communication")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("One place for encrypted chat, username lookup, and calling inside Lilith.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                if viewModel.unreadCount > 0 {
                                    Text("\(viewModel.unreadCount) unread")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(LilithTheme.accentB, in: Capsule())
                                }

                                Text("\(viewModel.connectedCount) connected")
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                        }

                        TextField("Search chats or Lilith IDs", text: $viewModel.threadSearch)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack(spacing: 10) {
                            TextField("Connect by Lilith ID", text: $viewModel.handleDraft)
                                .padding(14)
                                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Button("Add") {
                                viewModel.connectByHandle()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        HStack(spacing: 10) {
                            quickAction("Feed", systemImage: "person.2.wave.2", action: onOpenSocial)
                            quickAction("Calls", systemImage: "phone.connection", action: onOpenCalls)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.filteredThreads.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No secure threads yet")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Search for a Lilith ID or open the Social tab to start a conversation from a profile.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(viewModel.filteredThreads) { thread in
                        Button {
                            viewModel.openThread(id: thread.id)
                            showCompactThread = true
                        } label: {
                            ThreadRow(thread: thread, isSelected: viewModel.selectedThreadID == thread.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func threadDetail(compact: Bool) -> some View {
        if let thread = viewModel.selectedThread {
            ThreadDetailView(
                viewModel: viewModel,
                thread: thread,
                compact: compact,
                onBack: {
                    showCompactThread = false
                    viewModel.selectedThreadID = nil
                }
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose a conversation")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Select a chat to keep secure messaging and calling anchored inside Lilith.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !viewModel.callHistory.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent calls")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                ForEach(viewModel.callHistory.prefix(4)) { record in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.peerName)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(record.peerHandle)
                                                .font(.caption)
                                                .foregroundStyle(LilithTheme.textSecondary)
                                        }
                                        Spacer()
                                        Text(record.type == .video ? "Video" : "Voice")
                                            .font(.caption)
                                            .foregroundStyle(LilithTheme.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryLilithButtonStyle())
    }
}

private struct ThreadRow: View {
    let thread: LilithSecureThread
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ConversationAvatar(title: thread.title, isGroup: thread.isGroup)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(thread.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if thread.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(LilithTheme.accentB)
                    }
                    Spacer()
                    Text(thread.lastMessageAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                HStack {
                    Text(thread.handle)
                        .font(.caption)
                        .foregroundStyle(thread.presence == .online ? LilithTheme.accentA : LilithTheme.textSecondary)
                    Spacer()
                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LilithTheme.accentB, in: Capsule())
                    }
                }

                Text(thread.lastMessagePreview)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? LilithTheme.accentA.opacity(0.16) : LilithTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isSelected ? LilithTheme.accentA.opacity(0.35) : LilithTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct ThreadDetailView: View {
    @ObservedObject var viewModel: CommunicationHubViewModel
    let thread: LilithSecureThread
    let compact: Bool
    let onBack: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var paymentIntent: PaymentFlowIntent = .pay
    @State private var paymentTarget: LilithBusinessProfile?
    @State private var aiDraftInput = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(LilithTheme.border)
            messageScroll
        }
        .background(Color.clear)
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.sendImageAttachment(data: data, to: thread.id)
                        selectedPhoto = nil
                    }
                }
            }
        }
        .sheet(item: $paymentTarget) { target in
            PaymentFlowSheet(viewModel: viewModel, business: target, intent: paymentIntent)
                .presentationDetents([.fraction(0.58), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if compact {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LilithTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }

            ConversationAvatar(title: thread.title, isGroup: thread.isGroup)

            VStack(alignment: .leading, spacing: 3) {
                Text(thread.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("\(thread.handle) · \(thread.presence.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(thread.presence == .online ? LilithTheme.accentA : LilithTheme.textSecondary)
                Text("Lilith keeps calling, attachments, and secure message history in this thread.")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    paymentIntent = .pay
                    paymentTarget = viewModel.paymentProfile(for: thread)
                } label: {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LilithTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.startCall(for: thread.id, type: .voice)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LilithTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.startCall(for: thread.id, type: .video)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LilithTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, compact ? 16 : 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.aiSuggestions(for: thread, draft: aiDraftInput).isEmpty {
                        aiSuggestionsBar
                    }
                    if !viewModel.toolSuggestions(for: thread, draft: aiDraftInput).isEmpty {
                        toolSuggestionsBar
                    }
                    if let aiStatus = viewModel.aiStatusMessage, !aiStatus.isEmpty {
                        HStack {
                            Text(aiStatus)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LilithTheme.accentA)
                            Spacer()
                        }
                    }

                    if let call = viewModel.activeCall, call.chatID == thread.id {
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(call.type == .video ? "Video call active" : "Voice call active")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("\(call.state.rawValue.capitalized) · started \(call.startedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                Spacer()
                                Button("Open controls") {
                                    viewModel.reopenActiveCall()
                                }
                                .buttonStyle(SecondaryLilithButtonStyle())
                            }
                        }
                    }

                    ForEach(thread.messages) { message in
                        HStack {
                            if message.direction == .incoming {
                                SecureMessageBubble(message: message, isIncoming: true)
                                Spacer(minLength: 42)
                            } else {
                                Spacer(minLength: 42)
                                SecureMessageBubble(message: message, isIncoming: false)
                            }
                        }
                        .contextMenu {
                            Button {
                                Task { await viewModel.runAIMessageAction(.improve, message: message, threadID: thread.id) }
                            } label: {
                                Label("Improve text", systemImage: MessageAIAction.improve.icon)
                            }
                            Button {
                                Task { await viewModel.runAIMessageAction(.summarize, message: message, threadID: thread.id) }
                            } label: {
                                Label("Summarize", systemImage: MessageAIAction.summarize.icon)
                            }
                            Button {
                                Task { await viewModel.runAIMessageAction(.translate, message: message, threadID: thread.id) }
                            } label: {
                                Label("Translate", systemImage: MessageAIAction.translate.icon)
                            }
                            Button {
                                Task { await viewModel.runAIMessageAction(.createVideo, message: message, threadID: thread.id) }
                            } label: {
                                Label("Create video", systemImage: MessageAIAction.createVideo.icon)
                            }
                            Button {
                                Task { await viewModel.runAIMessageAction(.analyze, message: message, threadID: thread.id) }
                            } label: {
                                Label("Analyze", systemImage: MessageAIAction.analyze.icon)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, compact ? 16 : 22)
                .padding(.vertical, 20)
            }
            .onChange(of: thread.messages.count) { _, _ in
                if let last = thread.messages.last {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var aiSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.aiSuggestions(for: thread, draft: aiDraftInput)) { suggestion in
                    Button {
                        Task {
                            await viewModel.runAIMessageAction(
                                suggestion.action,
                                message: thread.messages.last,
                                threadID: thread.id,
                                fallbackInput: aiDraftInput
                            )
                        }
                    } label: {
                        Label(suggestion.label, systemImage: suggestion.action.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LilithTheme.elevated, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var toolSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.toolSuggestions(for: thread, draft: aiDraftInput), id: \.id) { listing in
                    Button {
                        Task { await viewModel.runMarketplaceToolInThread(listing, threadID: thread.id, inputText: aiDraftInput) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Try \(listing.name)")
                                .font(.caption.weight(.semibold))
                            Text(listing.pricingModel == "free" ? "Free" : "\(listing.currency) \(String(format: "%.2f", listing.priceAmount))")
                                .font(.caption2)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LilithTheme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            Divider().background(LilithTheme.border)

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(LilithTheme.elevated, in: Circle())
                }

                TextField("Message \(thread.title)", text: $viewModel.messageDraft, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.white)
                    .lineLimit(1 ... 5)
                    .onChange(of: viewModel.messageDraft) { _, newValue in
                        aiDraftInput = newValue
                    }

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 46, height: 46)
                        .background(LilithTheme.accentA, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(LilithTheme.background.opacity(0.96))
    }
}

private struct SecureMessageBubble: View {
    let message: LilithSecureMessage
    let isIncoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = message.attachmentData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 280, minHeight: 120, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let attachmentName = message.attachmentName {
                Label(attachmentName, systemImage: "paperclip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isIncoming ? LilithTheme.accentA : Color.black.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isIncoming ? LilithTheme.elevated : Color.white.opacity(0.18))
                    )
            }

            if !message.body.isEmpty {
                Text(message.body)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(LilithTheme.textSecondary)

                if !isIncoming {
                    Text(message.deliveryStatus.rawValue.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(message.deliveryStatus == .failed ? LilithTheme.accentB : LilithTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isIncoming ? LilithTheme.surface : Color(red: 0.13, green: 0.21, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LilithTheme.border, lineWidth: 1)
                )
        )
        .frame(maxWidth: 340, alignment: isIncoming ? .leading : .trailing)
    }
}

private struct CallsWorkspaceView: View {
    @ObservedObject var viewModel: CommunicationHubViewModel
    var onOpenThread: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let call = viewModel.activeCall {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active call")
                                .font(.headline)
                                .foregroundStyle(.white)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(call.title)
                                        .font(.system(size: 20, weight: .semibold, design: .serif))
                                        .foregroundStyle(.white)
                                    Text("\(call.type == .video ? "Video" : "Voice") · \(call.state.rawValue.capitalized)")
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                Spacer()
                                Button("Open thread") {
                                    onOpenThread(call.chatID)
                                }
                                .buttonStyle(SecondaryLilithButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent calls")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if viewModel.callHistory.isEmpty {
                            Text("No calls yet.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                        } else {
                            ForEach(viewModel.callHistory) { record in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.peerName)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("\(record.peerHandle) · \(record.type == .video ? "Video" : "Voice")")
                                            .font(.caption)
                                            .foregroundStyle(LilithTheme.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(LilithTheme.textSecondary)
                                        Text(record.wasMissed ? "Missed" : "\(max(record.durationSeconds / 60, 1)) min")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(record.wasMissed ? LilithTheme.accentB : LilithTheme.accentA)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }
}

private enum PaymentFlowIntent: String {
    case pay = "Pay"
    case request = "Request"
}

private enum MessageAIAction: String, CaseIterable, Identifiable {
    case improve
    case summarize
    case translate
    case createVideo
    case analyze

    var id: String { rawValue }

    var title: String {
        switch self {
        case .improve: return "Improve text"
        case .summarize: return "Summarize"
        case .translate: return "Translate"
        case .createVideo: return "Create video"
        case .analyze: return "Analyze"
        }
    }

    var apiAction: String {
        switch self {
        case .improve: return "improve"
        case .summarize: return "summarize"
        case .translate: return "translate"
        case .createVideo: return "create_video"
        case .analyze: return "analyze"
        }
    }

    var icon: String {
        switch self {
        case .improve: return "wand.and.stars"
        case .summarize: return "text.alignleft"
        case .translate: return "globe"
        case .createVideo: return "video.badge.plus"
        case .analyze: return "chart.bar.doc.horizontal"
        }
    }
}

private struct MessageAISuggestion: Identifiable {
    let id = UUID()
    let action: MessageAIAction
    let label: String
}

private enum PaymentRailOption: String, CaseIterable, Identifiable {
    case fiat = "Fiat"
    case usdc = "USDC"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .fiat: return "fiat"
        case .usdc: return "stablecoin_usdc"
        }
    }
}

private struct SocialWorkspaceView: View {
    @ObservedObject var viewModel: CommunicationHubViewModel
    var onOpenMessages: (UUID) -> Void
    var onStartCall: (UUID, LilithCallType) -> Void

    @State private var selectedPostPhoto: PhotosPickerItem?
    @State private var selectedBusinessForPayment: LilithBusinessProfile?
    @State private var paymentIntent: PaymentFlowIntent = .pay
    @State private var selectedBusinessForProfile: LilithBusinessProfile?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                storiesCard
                composerCard
                suggestedPeopleCard
                businessDirectoryCard
                feedCard
            }
            .padding(20)
        }
        .keyboardAdaptive()
        .onChange(of: selectedPostPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.postDraftImageData = data
                        selectedPostPhoto = nil
                    }
                }
            }
        }
        .task {
            await viewModel.refreshFromBackend()
        }
        .refreshable {
            await viewModel.refreshFromBackend()
        }
        .sheet(item: $selectedBusinessForPayment) { business in
            PaymentFlowSheet(
                viewModel: viewModel,
                business: business,
                intent: paymentIntent
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBusinessForProfile) { business in
            BusinessProfileSheet(
                viewModel: viewModel,
                business: business,
                onMessage: {
                    onOpenMessages(viewModel.ensureThread(for: business.businessName, handle: business.handle))
                },
                onCall: {
                    onStartCall(viewModel.ensureThread(for: business.businessName, handle: business.handle), .voice)
                },
                onPay: {
                    paymentIntent = .pay
                    selectedBusinessForPayment = business
                },
                onRequest: {
                    paymentIntent = .request
                    selectedBusinessForPayment = business
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lilith social")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Profiles, discovery, stories, and messaging all map back to Lilith IDs so the social layer and the communication layer stay unified.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LilithTheme.textSecondary)

                HStack(spacing: 10) {
                    TextField("Find a Lilith ID", text: $viewModel.handleDraft)
                        .padding(14)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Connect") {
                        viewModel.connectByHandle()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var storiesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Stories")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Post story") {
                        viewModel.publishStory()
                    }
                    .buttonStyle(SecondaryLilithButtonStyle())
                }

                TextField("Share a quick update", text: $viewModel.storyDraft)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.stories) { story in
                            VStack(alignment: .leading, spacing: 8) {
                                ConversationAvatar(title: story.authorName, isGroup: false)
                                Text(story.authorName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(story.caption)
                                    .font(.caption2)
                                    .foregroundStyle(LilithTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .frame(width: 120, height: 132, alignment: .topLeading)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var composerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Create post")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Audience", selection: $viewModel.postAudience) {
                        ForEach(LilithPostAudience.allCases) { audience in
                            Text(audience.rawValue).tag(audience)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }

                TextField("Share something with your network", text: $viewModel.postDraft, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                    .lineLimit(3 ... 8)

                if let data = viewModel.postDraftImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPostPhoto, matching: .images) {
                        Label("Add photo", systemImage: "photo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(LilithTheme.elevated, in: Capsule())
                    }

                    Button("Publish") {
                        viewModel.publishPost()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var suggestedPeopleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested people")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(viewModel.suggestedConnections) { connection in
                    HStack(spacing: 12) {
                        ConversationAvatar(title: connection.displayName, isGroup: false)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(connection.displayName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(connection.handle) · \(connection.about)")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Connect") {
                            viewModel.connect(handle: connection.handle)
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var businessDirectoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Business profiles")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(viewModel.businessProfiles.prefix(4)) { business in
                    HStack(spacing: 12) {
                        ConversationAvatar(title: business.businessName, isGroup: false)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(business.businessName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                if business.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.accentA)
                                }
                            }
                            Text("\(business.handle) · \(business.category.rawValue)")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                            Text(business.tagline)
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Open") {
                            selectedBusinessForProfile = business
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    }
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var feedCard: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.posts) { post in
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            ConversationAvatar(title: post.authorName, isGroup: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(post.authorName)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(post.authorHandle) · \(post.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Text(post.audience.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(LilithTheme.accentB, in: Capsule())
                        }

                        Text(post.body)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        if let data = post.mediaData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        if !post.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(post.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(LilithTheme.accentA)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(LilithTheme.accentA.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Button(post.likedByMe ? "Liked" : "Like") {
                                viewModel.toggleLike(postID: post.id)
                            }
                            .buttonStyle(SecondaryLilithButtonStyle())

                            Button("Message") {
                                onOpenMessages(viewModel.ensureThread(for: post.authorName, handle: post.authorHandle))
                            }
                            .buttonStyle(SecondaryLilithButtonStyle())

                            Button("Call") {
                                onStartCall(viewModel.ensureThread(for: post.authorName, handle: post.authorHandle), .voice)
                            }
                            .buttonStyle(SecondaryLilithButtonStyle())

                            if let business = viewModel.businessProfile(forHandle: post.authorHandle) {
                                Button("Pay") {
                                    paymentIntent = .pay
                                    selectedBusinessForPayment = business
                                }
                                .buttonStyle(SecondaryLilithButtonStyle())
                            }
                            if let tool = viewModel.chatToolSuggestions.first {
                                Button("Try Tool") {
                                    let threadID = viewModel.ensureThread(for: post.authorName, handle: post.authorHandle)
                                    Task { await viewModel.runMarketplaceToolInThread(tool, threadID: threadID, inputText: post.body) }
                                    onOpenMessages(threadID)
                                }
                                .buttonStyle(SecondaryLilithButtonStyle())
                            }
                        }

                        HStack(spacing: 10) {
                            TextField(
                                "Reply to \(post.authorName)",
                                text: Binding(
                                    get: { viewModel.commentDrafts[post.id] ?? "" },
                                    set: { viewModel.commentDrafts[post.id] = $0 }
                                )
                            )
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)

                            Button("Send") {
                                viewModel.addComment(to: post.id)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        if !post.comments.isEmpty {
                            ForEach(post.comments.prefix(3)) { comment in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(comment.authorName) · \(comment.authorHandle)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(comment.body)
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ProfileWorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject var communicationViewModel: CommunicationHubViewModel

    @Binding var selectedAgent: AgentKind
    @Binding var selectedMode: AgentMode
    @Binding var ultraThinking: Bool

    var onOpenMemory: () -> Void
    var onOpenActivity: () -> Void
    var onLogout: () -> Void

    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var guardianViewModel = GuardianDashboardViewModel()
    @State private var selectedBusinessForPayment: LilithBusinessProfile?
    @State private var paymentIntent: PaymentFlowIntent = .pay
    @State private var showGuardianDashboard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                identityCard
                socialStatsCard
                businessIdentityCard
                paymentsCard
                linkedMethodsCard
                sessionsCard
                preferencesCard
                if authStore.user?.isSuperAdmin == true {
                    adminCard
                }
                actionCard
            }
            .padding(20)
        }
        .task {
            guard let token = authStore.token, let user = authStore.user else { return }
            await accountViewModel.load(token: token, isSuperAdmin: user.isSuperAdmin)
        }
        .sheet(item: $selectedBusinessForPayment) { business in
            PaymentFlowSheet(
                viewModel: communicationViewModel,
                business: business,
                intent: paymentIntent
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGuardianDashboard) {
            GuardianDashboardView(viewModel: guardianViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ConversationAvatar(title: communicationViewModel.profile.displayName, isGroup: false, large: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(communicationViewModel.profile.displayName)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text(communicationViewModel.profile.handle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.accentA)
                        Text(communicationViewModel.profile.bio)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    Spacer()
                }

                TextField(
                    "Display name",
                    text: Binding(
                        get: { communicationViewModel.profile.displayName },
                        set: { communicationViewModel.updateDisplayName($0) }
                    )
                )
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)

                TextField(
                    "About you",
                    text: Binding(
                        get: { communicationViewModel.profile.bio },
                        set: { communicationViewModel.updateBio($0) }
                    ),
                    axis: .vertical
                )
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
                .lineLimit(2 ... 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var socialStatsCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                profileMetric(value: "\(communicationViewModel.profile.followerCount)", label: "Followers")
                profileMetric(value: "\(communicationViewModel.profile.followingCount)", label: "Following")
                profileMetric(value: "\(communicationViewModel.profile.connectionCount)", label: "Connections")
            }
        }
    }

    private var businessIdentityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Business identity")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let mine = communicationViewModel.businessProfiles.first(where: { $0.handle.lowercased() == communicationViewModel.profile.handle.lowercased() }) {
                    detailRow("Business", mine.businessName)
                    detailRow("Category", mine.category.rawValue)
                    detailRow("Verification", mine.isVerified ? "Verified" : "Standard")
                    detailRow("Response time", mine.responseTime)
                    detailRow("Accepts payments", mine.acceptsPayments ? "Yes" : "No")
                } else {
                    Text("No business profile is linked to this Lilith ID yet.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var paymentsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Business payments")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(communicationViewModel.businessProfiles.prefix(3)) { business in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(business.businessName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(business.handle)
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        Spacer()
                        Button("Request") {
                            paymentIntent = .request
                            selectedBusinessForPayment = business
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                        Button("Pay") {
                            paymentIntent = .pay
                            selectedBusinessForPayment = business
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let status = communicationViewModel.paymentStatusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var linkedMethodsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Identity and recovery")
                    .font(.headline)
                    .foregroundStyle(.white)
                detailRow("Recovery email", communicationViewModel.profile.recoveryEmail ?? authStore.user?.email ?? "Not set")
                detailRow("Phone number", communicationViewModel.profile.phoneNumber ?? "Optional only")
                detailRow("Privacy", communicationViewModel.profile.visibility.rawValue.capitalized)
                detailRow("Current plan", accountViewModel.subscription?.subscription.plan.capitalized ?? "Free")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sessionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sessions and security")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Link device") {
                        communicationViewModel.linkDesktopSession()
                    }
                    .buttonStyle(SecondaryLilithButtonStyle())
                }

                ForEach(communicationViewModel.deviceSessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.deviceName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(session.isCurrent ? "Current device" : session.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        Spacer()
                        if session.isCurrent {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(LilithTheme.accentA, in: Capsule())
                        }
                    }
                }

                Button("Revoke other sessions") {
                    communicationViewModel.revokeOtherSessions()
                }
                .buttonStyle(SecondaryLilithButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferences and billing")
                    .font(.headline)
                    .foregroundStyle(.white)
                detailRow("Assistant", selectedAgent.title)
                detailRow("Mode", selectedMode.title)
                detailRow("Ultra thinking", ultraThinking ? "Enabled" : "Off")
                detailRow("Credits", accountViewModel.creditsSummary?.unlimited == true ? "Unlimited" : String(format: "%.0f", accountViewModel.creditsSummary?.credits ?? 0))
                if let errorMessage = accountViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var adminCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Admin snapshot")
                    .font(.headline)
                    .foregroundStyle(.white)
                if let stats = accountViewModel.adminStats {
                    detailRow("Users", "\(stats.users.total) total · \(stats.users.active) active")
                    detailRow("Projects", "\(stats.content.projects)")
                    detailRow("Conversations", "\(stats.content.conversations)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workspace controls")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button("Open memory and settings", action: onOpenMemory)
                    .buttonStyle(SecondaryLilithButtonStyle())
                Button("Open activity", action: onOpenActivity)
                    .buttonStyle(SecondaryLilithButtonStyle())
                Button("Guardian dashboard") {
                    showGuardianDashboard = true
                }
                .buttonStyle(SecondaryLilithButtonStyle())

                Button("Log out", role: .destructive, action: onLogout)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func profileMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(LilithTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
    }
}

private struct BusinessProfileSheet: View {
    @ObservedObject var viewModel: CommunicationHubViewModel
    let business: LilithBusinessProfile
    var onMessage: () -> Void
    var onCall: () -> Void
    var onPay: () -> Void
    var onRequest: () -> Void

    @State private var tab = 0
    @State private var requestNote = ""
    @State private var selectedService: LilithBusinessService?
    @State private var offerAccepted = false
    @State private var reviewRating = 5
    @State private var reviewComment = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                Picker("Section", selection: $tab) {
                    Text("Overview").tag(0)
                    Text("Services").tag(1)
                    Text("Posts").tag(2)
                    Text("Reviews").tag(3)
                }
                .pickerStyle(.segmented)

                switch tab {
                case 0:
                    overview
                case 1:
                    services
                case 2:
                    posts
                default:
                    reviews
                }
            }
            .padding(20)
        }
        .background(LilithTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ConversationAvatar(title: business.businessName, isGroup: false, large: true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(business.businessName)
                                .font(.system(size: 24, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                            if business.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(LilithTheme.accentA)
                            }
                        }
                        Text("\(business.handle) · \(business.category.rawValue)")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                        Text(business.tagline)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button("Message", action: onMessage)
                        .buttonStyle(SecondaryLilithButtonStyle())
                    Button("Call", action: onCall)
                        .buttonStyle(SecondaryLilithButtonStyle())
                    Button("Request", action: onRequest)
                        .buttonStyle(SecondaryLilithButtonStyle())
                    Button("Pay", action: onPay)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                detail("Response", business.responseTime)
                detail("Payments", business.acceptsPayments ? "Enabled" : "Disabled")
                detail("Average rating", String(format: "%.1f/5", business.averageRating))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var services: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.services(for: business.id)) { service in
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(service.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(service.description)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                        HStack {
                            Text(currency(service.price))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LilithTheme.accentA)
                            Spacer()
                            Button("Request") {
                                selectedService = service
                                offerAccepted = false
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let service = selectedService {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Request \(service.title)")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextField("What do you need?", text: $requestNote, axis: .vertical)
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            Button("Send request") {
                                Task {
                                    await viewModel.submitBusinessServiceRequest(service, note: requestNote)
                                    offerAccepted = true
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            Button("Clear") {
                                requestNote = ""
                                selectedService = nil
                            }
                            .buttonStyle(SecondaryLilithButtonStyle())
                        }

                        if offerAccepted {
                            HStack(spacing: 10) {
                                Text("Offer received for \(currency(service.price)).")
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.accentA)
                                Spacer()
                                Button("Accept offer") {
                                    Task { await viewModel.respondToServiceOffer(service: service, business: business, accept: true) }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                Button("Decline") {
                                    Task { await viewModel.respondToServiceOffer(service: service, business: business, accept: false) }
                                }
                                .buttonStyle(SecondaryLilithButtonStyle())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var posts: some View {
        let items = viewModel.posts.filter { $0.authorHandle.lowercased() == business.handle.lowercased() }
        return VStack(spacing: 12) {
            if items.isEmpty {
                GlassCard {
                    Text("No business posts yet.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(items.prefix(3)) { post in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.body)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                            Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var reviews: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.reviews(for: business.id)) { review in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(String(repeating: "★", count: review.rating)) \(review.authorName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(review.comment)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Leave a review")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Picker("Rating", selection: $reviewRating) {
                        ForEach(1...5, id: \.self) { score in
                            Text("\(score)★").tag(score)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Write a review", text: $reviewComment, axis: .vertical)
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)

                    Button("Post review") {
                        viewModel.addReview(for: business, rating: reviewRating, comment: reviewComment)
                        reviewComment = ""
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(LilithTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

private struct PaymentFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CommunicationHubViewModel
    let business: LilithBusinessProfile
    let intent: PaymentFlowIntent

    @State private var amount = ""
    @State private var note = ""
    @State private var selectedRail: PaymentRailOption = .fiat
    @State private var isProcessing = false
    @State private var didSucceed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(intent == .pay ? "Confirm payment" : "Request payment")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(SecondaryLilithButtonStyle())
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(business.businessName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(business.handle)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                        TextField("$120", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                        TextField("Optional note", text: $note, axis: .vertical)
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)

                        Picker("Settlement rail", selection: $selectedRail) {
                            ForEach(PaymentRailOption.allCases) { rail in
                                Text(rail.rawValue).tag(rail)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Protected with Face ID / passkey step-up for sensitive payment actions.")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if didSucceed {
                    GlassCard {
                        Text(intent == .pay ? "Payment complete. Conversation updated." : "Payment request sent. Conversation updated.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.accentA)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if let status = viewModel.paymentStatusMessage {
                    GlassCard {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button(isProcessing ? "Processing..." : intent.rawValue) {
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        let success = await viewModel.submitPayment(
                            to: business,
                            amountText: amount,
                            note: note,
                            intent: intent,
                            rail: selectedRail
                        )
                        await MainActor.run {
                            didSucceed = success
                            isProcessing = false
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isProcessing)
            }
            .padding(20)
        }
        .background(LilithTheme.background.ignoresSafeArea())
    }
}

private enum GuardianDashboardTab: String, CaseIterable, Identifiable {
    case activity = "Activity"
    case controls = "Controls"
    case connections = "Connections"
    case safety = "Safety"
    case reports = "Reports"

    var id: String { rawValue }
}

private struct GuardianChildProfile: Identifiable, Equatable {
    let id: String
    var name: String
    var ageLabel: String
    var status: String
    var safetyScore: Int
}

private struct GuardianActivityEntry: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String
    var timeLabel: String
}

private struct GuardianConnectionRequest: Identifiable, Equatable {
    let id: UUID
    var name: String
    var handle: String
}

private struct GuardianContact: Identifiable, Equatable {
    let id: UUID
    var name: String
    var handle: String
}

private struct GuardianWeeklyReport: Identifiable, Equatable {
    let id: UUID
    var weekLabel: String
    var summary: String
    var insight: String
}

@MainActor
private final class GuardianDashboardViewModel: ObservableObject {
    @Published var children: [GuardianChildProfile] = [
        .init(id: "child-ava", name: "Ava", ageLabel: "Age 11", status: "All clear", safetyScore: 92),
        .init(id: "child-jay", name: "Jay", ageLabel: "Age 13", status: "Needs review", safetyScore: 81)
    ]
    @Published var selectedChildID: String?
    @Published var timeline: [GuardianActivityEntry] = [
        .init(id: UUID(), title: "Opened Messages", detail: "Started a chat with @maya", timeLabel: "10 min ago"),
        .init(id: UUID(), title: "Used Tool", detail: "Prompt from Screenshot", timeLabel: "24 min ago"),
        .init(id: UUID(), title: "Posted Update", detail: "Shared a social post", timeLabel: "1 hr ago")
    ]
    @Published var allowedInterests: [String] = ["Science", "Drawing", "Robotics"]
    @Published var blockedInterests: [String] = ["Gambling", "Adult content"]
    @Published var communicationLimitedToApproved = true
    @Published var toolsRestricted = false
    @Published var dailyTimeLimitHours = 3
    @Published var pendingConnections: [GuardianConnectionRequest] = [
        .init(id: UUID(), name: "Nora Wells", handle: "@nora"),
        .init(id: UUID(), name: "Team Science Club", handle: "@scienceclub")
    ]
    @Published var activeContacts: [GuardianContact] = [
        .init(id: UUID(), name: "Maya Reed", handle: "@maya"),
        .init(id: UUID(), name: "Alex Mercer", handle: "@alex")
    ]
    @Published var contentFilterEnabled = true
    @Published var alertsEnabled = true
    @Published var trustedCreators: [String] = ["@natgeo", "@khanacademy"]
    @Published var reports: [GuardianWeeklyReport] = [
        .init(id: UUID(), weekLabel: "Apr 7 - Apr 13", summary: "Healthy communication and tool usage.", insight: "Most activity happened after school between 4-6 PM."),
        .init(id: UUID(), weekLabel: "Mar 31 - Apr 6", summary: "No safety incidents detected.", insight: "Creative tools usage increased 18% week-over-week.")
    ]
    @Published var draftTrustedCreator = ""

    var selectedChild: GuardianChildProfile? {
        children.first(where: { $0.id == selectedChildID })
    }

    func selectChild(_ id: String) {
        selectedChildID = id
    }

    func approveConnection(_ id: UUID) {
        guard let index = pendingConnections.firstIndex(where: { $0.id == id }) else { return }
        let item = pendingConnections.remove(at: index)
        activeContacts.insert(.init(id: UUID(), name: item.name, handle: item.handle), at: 0)
    }

    func denyConnection(_ id: UUID) {
        pendingConnections.removeAll { $0.id == id }
    }

    func removeContact(_ id: UUID) {
        activeContacts.removeAll { $0.id == id }
    }

    func addTrustedCreator() {
        let value = draftTrustedCreator.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return }
        let normalized = value.hasPrefix("@") ? value : "@\(value)"
        guard !trustedCreators.contains(normalized) else { return }
        trustedCreators.append(normalized)
        draftTrustedCreator = ""
    }
}

private struct GuardianDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GuardianDashboardViewModel
    @State private var selectedTab: GuardianDashboardTab = .activity

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.selectedChild == nil {
                        childSelection
                    } else {
                        dashboardHeader
                        tabPicker
                        tabContent
                    }
                }
                .padding(20)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Guardian")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var childSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select child profile")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text("Choose who you want to monitor and control.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(LilithTheme.textSecondary)

            ForEach(viewModel.children) { child in
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(child.name)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(child.ageLabel) · \(child.status)")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        Spacer()
                        Button("Open") {
                            viewModel.selectChild(child.id)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dashboardHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedChild?.name ?? "Child")
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text(viewModel.selectedChild?.ageLabel ?? "")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    Spacer()
                    Circle()
                        .fill((viewModel.selectedChild?.safetyScore ?? 0) >= 85 ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                        .frame(width: 12, height: 12)
                    Text(viewModel.selectedChild?.status ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    summaryCard(title: "Safety", value: "\(viewModel.selectedChild?.safetyScore ?? 0)%")
                    summaryCard(title: "Pending", value: "\(viewModel.pendingConnections.count)")
                    summaryCard(title: "Time Limit", value: "\(viewModel.dailyTimeLimitHours)h")
                }

                HStack(spacing: 10) {
                    Button("Review Alerts") {
                        selectedTab = .safety
                    }
                    .buttonStyle(SecondaryLilithButtonStyle())
                    Button("Edit Controls") {
                        selectedTab = .controls
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tabPicker: some View {
        Picker("Guardian tabs", selection: $selectedTab) {
            ForEach(GuardianDashboardTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .activity:
            activityTab
        case .controls:
            controlsTab
        case .connections:
            connectionsTab
        case .safety:
            safetyTab
        case .reports:
            reportsTab
        }
    }

    private var activityTab: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity timeline")
                    .font(.headline)
                    .foregroundStyle(.white)
                ForEach(viewModel.timeline) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.timeLabel)
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controlsTab: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Controls")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Toggle("Approved contacts only", isOn: $viewModel.communicationLimitedToApproved)
                        .tint(LilithTheme.accentA)
                        .foregroundStyle(.white)
                    Toggle("Restrict advanced tools", isOn: $viewModel.toolsRestricted)
                        .tint(LilithTheme.accentA)
                        .foregroundStyle(.white)
                    Stepper("Daily time limit: \(viewModel.dailyTimeLimitHours) hours", value: $viewModel.dailyTimeLimitHours, in: 1...8)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interests")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Allowed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                    chips(viewModel.allowedInterests, tint: LilithTheme.accentA.opacity(0.2))
                    Text("Blocked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                    chips(viewModel.blockedInterests, tint: Color.red.opacity(0.18))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var connectionsTab: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pending approvals")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if viewModel.pendingConnections.isEmpty {
                        Text("No pending connection requests.")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    } else {
                        ForEach(viewModel.pendingConnections) { request in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(request.name)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(request.handle)
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                Spacer()
                                Button("Deny") { viewModel.denyConnection(request.id) }
                                    .buttonStyle(SecondaryLilithButtonStyle())
                                Button("Approve") { viewModel.approveConnection(request.id) }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Active contacts")
                        .font(.headline)
                        .foregroundStyle(.white)
                    ForEach(viewModel.activeContacts) { contact in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(contact.handle)
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Button("Remove") { viewModel.removeContact(contact.id) }
                                .buttonStyle(SecondaryLilithButtonStyle())
                        }
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var safetyTab: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Safety rules")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Toggle("Content filters", isOn: $viewModel.contentFilterEnabled)
                        .tint(LilithTheme.accentA)
                        .foregroundStyle(.white)
                    Toggle("Alert me on risky activity", isOn: $viewModel.alertsEnabled)
                        .tint(LilithTheme.accentA)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trusted creators")
                        .font(.headline)
                        .foregroundStyle(.white)
                    chips(viewModel.trustedCreators, tint: LilithTheme.elevated)
                    HStack(spacing: 8) {
                        TextField("@creator", text: $viewModel.draftTrustedCreator)
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Add") { viewModel.addTrustedCreator() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var reportsTab: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly summaries")
                    .font(.headline)
                    .foregroundStyle(.white)
                ForEach(viewModel.reports) { report in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(report.weekLabel)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(report.summary)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                        Text("Insight: \(report.insight)")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.accentA)
                    }
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chips(_ values: [String], tint: Color) -> some View {
        FlexibleChips(values: values, tint: tint)
    }
}

private struct FlexibleChips: View {
    let values: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = chunked(values, size: 3)
            ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                let row = entry.element
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(tint, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ values: [String], size: Int) -> [[String]] {
        stride(from: 0, to: values.count, by: size).map { index in
            Array(values[index ..< min(index + size, values.count)])
        }
    }
}

private struct ActiveCallSheet: View {
    @ObservedObject var viewModel: CommunicationHubViewModel

    var body: some View {
        VStack(spacing: 20) {
            if let call = viewModel.activeCall {
                VStack(spacing: 8) {
                    ConversationAvatar(title: call.title, isGroup: false, large: true)
                    Text(call.title)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text("\(call.type == .video ? "Video" : "Voice") · \(call.state.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                HStack(spacing: 16) {
                    controlButton(title: call.muted ? "Unmute" : "Mute", systemImage: call.muted ? "mic.slash.fill" : "mic.fill") {
                        viewModel.toggleMute()
                    }
                    controlButton(title: call.speakerOn ? "Speaker Off" : "Speaker", systemImage: "speaker.wave.2.fill") {
                        viewModel.toggleSpeaker()
                    }
                    if call.type == .video {
                        controlButton(title: call.cameraOn ? "Camera Off" : "Camera", systemImage: "video.fill") {
                            viewModel.toggleCamera()
                        }
                    }
                }

                if call.state == .ringing {
                    HStack(spacing: 12) {
                        Button("Decline") {
                            viewModel.declineIncomingCall()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button("Accept") {
                            viewModel.acceptIncomingCall()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                Button(role: .destructive) {
                    viewModel.endActiveCall()
                } label: {
                    Text("End call")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LilithTheme.background.ignoresSafeArea())
    }

    private func controlButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ConversationAvatar: View {
    let title: String
    let isGroup: Bool
    var large = false

    var body: some View {
        let size: CGFloat = large ? 72 : 46

        ZStack {
            RoundedRectangle(cornerRadius: large ? 24 : 16, style: .continuous)
                .fill(LilithTheme.heroGradient)
            Text(initials)
                .font(.system(size: large ? 26 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if isGroup {
                Image(systemName: "person.3.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: large ? 22 : 18, height: large ? 22 : 18)
                    .background(LilithTheme.accentB, in: Circle())
                    .offset(x: 5, y: 5)
            }
        }
    }

    private var initials: String {
        let pieces = title
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let value = String(pieces)
        return value.isEmpty ? "L" : value.uppercased()
    }
}

private struct LilithOSHint {
    let title: String
    let prompt: String
}

private struct FinanceWorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject var viewModel: FinanceDashboardViewModel
    var onOpenActivity: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 430

            ScrollView {
                VStack(spacing: 16) {
                    walletHomeCard
                    walletQuickActionsCard(isCompact: isCompact)
                    aiFinanceCard(isCompact: isCompact)
                    balanceSummary
                    subscriptionsCard
                    invoicesCard
                    simulationCard(isCompact: isCompact)
                    transferCard(isCompact: isCompact)
                    approvalsCard
                    transactionsCard
                }
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isCompact ? 14 : 20)
                .padding(.vertical, 20)
            }
        }
        .refreshable {
            guard let token = authStore.token else { return }
            await viewModel.load(token: token)
        }
    }

    private var walletHomeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lilith Wallet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        Text(currency(viewModel.walletFiatBalance))
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("USDC")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        Text(String(format: "%.2f", viewModel.walletUSDCBalance))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(LilithTheme.accentA)
                    }
                }
                Text("Simple balance view. Settlement rails stay hidden unless needed.")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func walletQuickActionsCard(isCompact: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick actions")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isCompact {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            walletQuickActionButton(.send, title: "Send", icon: "arrow.up.right")
                            walletQuickActionButton(.request, title: "Request", icon: "arrow.down.left")
                        }
                        HStack(spacing: 10) {
                            walletQuickActionButton(.addFunds, title: "Add Funds", icon: "plus.circle")
                            walletQuickActionButton(.withdraw, title: "Withdraw", icon: "banknote")
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        walletQuickActionButton(.send, title: "Send", icon: "arrow.up.right")
                        walletQuickActionButton(.request, title: "Request", icon: "arrow.down.left")
                        walletQuickActionButton(.addFunds, title: "Add Funds", icon: "plus.circle")
                        walletQuickActionButton(.withdraw, title: "Withdraw", icon: "banknote")
                    }
                }
                if let message = viewModel.walletActionMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func aiFinanceCard(isCompact: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI finance actions")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Try: split $96 between 3, summarize my spending, draft invoice for $240", text: $viewModel.aiPrompt)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                if isCompact {
                    VStack(spacing: 10) {
                        Button("Run AI action") {
                            viewModel.runAIFinanceAction()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Split bill") {
                            viewModel.aiPrompt = "split $120 between 4"
                            viewModel.runAIFinanceAction()
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    }
                } else {
                    HStack(spacing: 10) {
                        Button("Run AI action") {
                            viewModel.runAIFinanceAction()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Split bill") {
                            viewModel.aiPrompt = "split $120 between 4"
                            viewModel.runAIFinanceAction()
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    }
                }

                if !viewModel.aiOutput.isEmpty {
                    Text(viewModel.aiOutput)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var balanceSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total balance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        Text(currency(viewModel.balance?.totalBalance ?? 0))
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.load(token: token)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.accentA)
                }

                if let analysis = viewModel.analysis {
                    HStack(spacing: 14) {
                        metricPill(title: "Spent \(analysis.periodDays)d", value: currency(analysis.spent))
                        metricPill(title: "Change", value: String(format: "%.1f%%", analysis.percentChange))
                        metricPill(title: "Transactions", value: "\(analysis.transactionCount)")
                    }
                }

                if let accounts = viewModel.balance?.accounts, !accounts.isEmpty {
                    ForEach(accounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(account.kind.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Text(currency(account.balance))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }

                if let categories = viewModel.analysis?.topCategories, !categories.isEmpty {
                    Divider().background(LilithTheme.border)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top categories")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        ForEach(categories) { item in
                            HStack {
                                Text(item.category.capitalized)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(currency(item.amount))
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                }
            }
        }
    }

    private var subscriptionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Subscriptions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(viewModel.subscriptions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                if viewModel.subscriptions.isEmpty {
                    Text("No active subscriptions yet.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(viewModel.subscriptions.prefix(4), id: \.id) { subscription in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Creator #\(subscription.creatorUserId)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(subscription.status.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Text(subscription.cancelAtPeriodEnd ? "Ends soon" : "Active")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(subscription.cancelAtPeriodEnd ? LilithTheme.accentB : LilithTheme.accentA, in: Capsule())
                        }
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var invoicesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Invoices")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(viewModel.invoices.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                if viewModel.invoices.isEmpty {
                    Text("No invoices available.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(viewModel.invoices.prefix(4), id: \.id) { invoice in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invoice.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(invoice.status.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Text(currency(invoice.amount))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func simulationCard(isCompact: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Affordability check")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isCompact {
                    VStack(spacing: 12) {
                        TextField("$200", text: $viewModel.simulationAmount)
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)

                        TextField("Merchant", text: $viewModel.simulationMerchant)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 12) {
                        TextField("$200", text: $viewModel.simulationAmount)
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)

                        TextField("Merchant", text: $viewModel.simulationMerchant)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }

                Button("Simulate purchase") {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.simulate(token: token)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let result = viewModel.simulationResult {
                    Text(result.message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func transferCard(isCompact: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Transfer funds")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("$150", text: $viewModel.transferAmount)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                if isCompact {
                    VStack(spacing: 12) {
                        accountPicker(title: "From", selection: $viewModel.transferSourceAccount)
                        accountPicker(title: "To", selection: $viewModel.transferDestinationAccount)
                    }
                } else {
                    HStack(spacing: 12) {
                        accountPicker(title: "From", selection: $viewModel.transferSourceAccount)
                        accountPicker(title: "To", selection: $viewModel.transferDestinationAccount)
                    }
                }

                Button("Preview transfer and request approval") {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.transfer(token: token)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let transfer = viewModel.transferResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transfer.preview ?? "Transfer request prepared.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        if let approvalId = transfer.approvalId {
                            Text("Approval ID: \(approvalId)")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var approvalsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Pending approvals")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if viewModel.pendingApprovalsCount > 0 {
                        Button("Open activity") {
                            onOpenActivity()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentA)
                    }
                }

                if viewModel.approvals.isEmpty {
                    Text("No finance approvals are waiting right now.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(viewModel.approvals.filter { $0.status == "pending" }) { approval in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(approval.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(approval.preview)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                            Button("Approve transfer") {
                                Task {
                                    guard let token = authStore.token else { return }
                                    await viewModel.approve(approvalId: approval.id, token: token)
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(LilithTheme.accentB, in: Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private var transactionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recent transactions")
                    .font(.headline)
                    .foregroundStyle(.white)

                if viewModel.transactions.isEmpty {
                    Text("No transactions to display.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(viewModel.transactions.prefix(8)) { transaction in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(transaction.amount < 0 ? LilithTheme.accentB.opacity(0.72) : LilithTheme.accentA.opacity(0.82))
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.merchant)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(transaction.category.capitalized) · \(transaction.occurredAt.prefix(10))")
                                    .font(.caption)
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            Spacer()
                            Text(currency(abs(transaction.amount)))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(transaction.amount < 0 ? .white : LilithTheme.accentA)
                        }
                    }
                }
            }
        }
    }

    private func accountPicker(title: String, selection: Binding<String>) -> some View {
        Menu {
            ForEach(viewModel.balance?.accounts ?? []) { account in
                Button(account.name) {
                    selection.wrappedValue = account.name
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                    Text(selection.wrappedValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .padding(14)
            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func walletActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func walletQuickActionButton(_ action: WalletQuickAction, title: String, icon: String) -> some View {
        walletActionButton(title, icon: icon) {
            Task {
                guard let token = authStore.token else { return }
                await viewModel.runWalletQuickAction(action, token: token)
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

private struct LegalWorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject var viewModel: LegalDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sourceCard
                draftCard
                if let error = viewModel.errorMessage {
                    GlassCard {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
        }
    }

    private var sourceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Summaries and clause extraction")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextEditor(text: $viewModel.sourceText)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    Button("Summarize") {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.summarize(token: token)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Extract clauses") {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.extractClauses(token: token)
                        }
                    }
                    .buttonStyle(SecondaryLilithButtonStyle())
                }

                if !viewModel.summaryText.isEmpty {
                    outputCard(title: "Summary", body: viewModel.summaryText)
                }

                if !viewModel.clauses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Clauses")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        ForEach(viewModel.clauses) { clause in
                            HStack {
                                Text(clause.label)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(clause.confidence * 100, specifier: "%.0f")%")
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var draftCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Draft a document")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Document type", text: $viewModel.documentType)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                TextField("Parties (comma-separated)", text: $viewModel.partiesText)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                TextEditor(text: $viewModel.documentPrompt)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)

                Button("Generate draft") {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.generateDraft(token: token)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if !viewModel.draftOutput.isEmpty {
                    outputCard(title: "Draft", body: viewModel.draftOutput)
                }
            }
        }
    }

    private func outputCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ToolsHubView: View {
    @ObservedObject var viewModel: ToolsRegistryViewModel
    var onOpenDestination: (WorkspaceDestination) -> Void
    var onOpenChatPrompt: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @AppStorage("lilith.tools.favorites") private var favoritesRaw = ""
    @AppStorage("lilith.tools.recent") private var recentRaw = ""

    private let catalog: [ToolCatalogItem] = [
        .init(id: "assistant_chat", title: "Assistant Chat", summary: "Primary Lilith conversation interface.", category: "Create", destination: .assistant, chatPrompt: nil),
        .init(id: "messages_secure", title: "Secure Messages", summary: "Encrypted direct and group messaging.", category: "Communication", destination: .messages, chatPrompt: nil),
        .init(id: "calls_voice_video", title: "Voice & Video Calls", summary: "Start internet-native calls from Lilith IDs.", category: "Communication", destination: .calls, chatPrompt: nil),
        .init(id: "social_feed", title: "Social Feed", summary: "Profiles, stories, and network discovery.", category: "Communication", destination: .social, chatPrompt: nil),

        .init(id: "pdf_editor", title: "PDF Editor / Adobe Clone", summary: "Document editing and legal drafting workflow.", category: "Documents", destination: .documents, chatPrompt: "Open documents workspace for PDF editing and contract flow."),
        .init(id: "legal_ease", title: "Legal Tools", summary: "Draft, summarize, and extract clauses.", category: "Legal", destination: .legal, chatPrompt: nil),
        .init(id: "prompt_from_link", title: "Prompt From Link", summary: "Ingest a URL and generate prompts from web content.", category: "Web", destination: .web, chatPrompt: "Use prompt-from-link flow. I will paste a URL to convert into prompts."),
        .init(id: "prompt_from_screenshot", title: "Prompt From Screenshot", summary: "Upload a screenshot and turn it into actionable prompts.", category: "Media", destination: .media, chatPrompt: "Use screenshot prompt flow. I will upload an image to convert into prompts."),

        .init(id: "website_clone", title: "Website Clone", summary: "Clone and preview page structure from a URL.", category: "Web", destination: .clone, chatPrompt: nil),
        .init(id: "web_workspace", title: "Web Workspace", summary: "Link import and clone tools in one place.", category: "Web", destination: .web, chatPrompt: nil),
        .init(id: "code_workspace", title: "Code Workspace", summary: "IDE, execute, review, and auto-fix code.", category: "Create", destination: .code, chatPrompt: nil),
        .init(id: "projects", title: "Projects", summary: "Project and file management.", category: "Automation", destination: .projects, chatPrompt: nil),
        .init(id: "history", title: "History", summary: "Conversation recall and relaunch.", category: "Automation", destination: .history, chatPrompt: nil),

        .init(id: "video_reels", title: "Long-form to Reels", summary: "Upload media and convert to short video cuts.", category: "Media", destination: .video, chatPrompt: "Convert long-form video into reels with punchy cut points."),
        .init(id: "video_editor", title: "Video Editor / CapCut Clone", summary: "Prompt + upload remix pipeline for editing.", category: "Media", destination: .video, chatPrompt: "Open video editor workflow for timeline-style edits."),
        .init(id: "image_generation", title: "Image Studio", summary: "Generate and save images from prompts.", category: "Media", destination: .image, chatPrompt: nil),
        .init(id: "media_workspace", title: "Media Workspace", summary: "Image, video, and remix launchers.", category: "Media", destination: .media, chatPrompt: nil),

        .init(id: "wealth_wizard", title: "Wealth Wizard", summary: "Balances, spending analysis, and approvals.", category: "Finance", destination: .finance, chatPrompt: nil),
        .init(id: "activity", title: "Activity", summary: "Tasks, approvals, and execution timeline.", category: "Automation", destination: .activity, chatPrompt: nil),
        .init(id: "memory_settings", title: "Memory & Settings", summary: "Preferences, permissions, and learned context.", category: "Automation", destination: .memory, chatPrompt: nil),
        .init(id: "linux_machines", title: "Linux Machines", summary: "SSH terminal, system monitor, and file manager for remote Linux servers.", category: "Automation", destination: .linux, chatPrompt: nil),
        .init(id: "lte_network", title: "Private LTE", summary: "Lilith Private LTE: eSIM profiles, network node status, VoIP dialer, and subscriber management.", category: "Automation", destination: .lte, chatPrompt: nil)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lilith tool catalog")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Search, pin, and launch all capabilities from one place. Nothing is hidden behind a finance-only shell.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LilithTheme.textSecondary)

                        TextField("Search tools, workflows, or categories", text: $searchText)
                            .padding(14)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                categoryStrip
                recentToolsCard
                favoritesCard
                marketplaceDiscoveryCard
                creatorStudioCard

                ForEach(filteredCatalog) { item in
                    toolCard(item)
                }

                if !viewModel.tools.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active services")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(viewModel.tools) { tool in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(tool.title)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(tool.category.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .foregroundStyle(LilithTheme.textSecondary)
                                    }
                                    Text(tool.summary)
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
        }
        .task {
            await viewModel.loadMarketplaceIfNeeded()
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                ? AnyShapeStyle(LilithTheme.accentB)
                                : AnyShapeStyle(LilithTheme.elevated)
                            , in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                if recentTools.isEmpty {
                    Text("No recent launches yet.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(recentTools) { item in
                        HStack {
                            Label(item.title, systemImage: item.destination.icon)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Open") {
                                launch(item)
                            }
                            .buttonStyle(SecondaryLilithButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var favoritesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pinned favorites")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(favoriteIds.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                if favoriteTools.isEmpty {
                    Text("Pin tools from any card to build your quick-access set.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(favoriteTools) { item in
                        Button {
                            launch(item)
                        } label: {
                            HStack {
                                Label(item.title, systemImage: item.destination.icon)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(LilithTheme.textSecondary)
                            }
                            .padding(12)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toolCard(_ item: ToolCatalogItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LilithTheme.heroGradient)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: item.destination.icon)
                                .foregroundStyle(.white)
                                .font(.caption.weight(.bold))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(LilithTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        toggleFavorite(item.id)
                    } label: {
                        Image(systemName: favoriteIds.contains(item.id) ? "star.fill" : "star")
                            .foregroundStyle(favoriteIds.contains(item.id) ? LilithTheme.accentB : LilithTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)

                HStack(spacing: 8) {
                    Button("Launch") {
                        launch(item)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if item.chatPrompt != nil {
                        Button("Open in Chat") {
                            launchInChat(item)
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var marketplaceDiscoveryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Marketplace")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Trending + Personalized")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                if viewModel.trendingTools.isEmpty && viewModel.personalizedTools.isEmpty {
                    Text("No marketplace tools published yet.")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    if !viewModel.trendingTools.isEmpty {
                        Text("Trending")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                        ForEach(viewModel.trendingTools.prefix(4), id: \.id) { listing in
                            marketplaceToolCard(listing)
                        }
                    }
                    if !viewModel.personalizedTools.isEmpty {
                        Text("For you")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LilithTheme.textSecondary)
                            .padding(.top, 4)
                        ForEach(viewModel.personalizedTools.prefix(4), id: \.id) { listing in
                            marketplaceToolCard(listing)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var creatorStudioCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Creator Studio")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Build AI tools, set pricing, and publish to Lilith Marketplace.")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)

                TextField("Tool ID (e.g. creator_summary_tool)", text: $viewModel.creatorToolID)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)

                TextField("Tool name", text: $viewModel.creatorToolName)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)

                TextField("Description", text: $viewModel.creatorToolDescription, axis: .vertical)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .lineLimit(2 ... 4)

                HStack(spacing: 10) {
                    Menu {
                        ForEach(["Create", "Media", "Documents", "Web", "Finance", "Legal", "Communication", "Automation"], id: \.self) { category in
                            Button(category) { viewModel.creatorToolCategory = category }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.creatorToolCategory)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Menu {
                        Button("Free") { viewModel.creatorPricingModel = "free" }
                        Button("Paid Per Use") { viewModel.creatorPricingModel = "per_use" }
                        Button("Subscription") { viewModel.creatorPricingModel = "subscription" }
                    } label: {
                        HStack {
                            Text(viewModel.creatorPricingModel.replacingOccurrences(of: "_", with: " ").capitalized)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if viewModel.creatorPricingModel != "free" {
                    TextField("$5.00", text: $viewModel.creatorPriceText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }

                Button("Publish Tool") {
                    Task { await viewModel.publishCreatorTool() }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func marketplaceToolCard(_ listing: V1MarketplaceToolItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(listing.description)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "★ %.1f", listing.rating))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(listing.usage) uses")
                        .font(.caption2)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
            }
            HStack {
                Text(listing.pricingModel == "free" ? "Free" : "\(listing.currency) \(String(format: "%.2f", listing.priceAmount))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(listing.pricingModel == "free" ? LilithTheme.accentA : LilithTheme.accentB)
                Spacer()
                Button("Try") {
                    Task {
                        _ = await viewModel.tryMarketplaceTool(listing)
                    }
                }
                .buttonStyle(SecondaryLilithButtonStyle())
                Button("Open in Chat") {
                    onOpenChatPrompt("Run marketplace tool '\(listing.name)' and return the result here.")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(12)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var categories: [String] {
        ["All", "Create", "Media", "Documents", "Web", "Finance", "Legal", "Communication", "Automation"]
    }

    private var filteredCatalog: [ToolCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.filter { item in
            let matchesCategory = selectedCategory == "All" || item.category == selectedCategory
            let matchesQuery = query.isEmpty
            || item.title.lowercased().contains(query)
            || item.summary.lowercased().contains(query)
            || item.category.lowercased().contains(query)
            return matchesCategory && matchesQuery
        }
    }

    private var favoriteIds: [String] {
        favoritesRaw
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private var recentIds: [String] {
        recentRaw
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private var recentTools: [ToolCatalogItem] {
        recentIds.compactMap { id in catalog.first(where: { $0.id == id }) }
    }

    private var favoriteTools: [ToolCatalogItem] {
        favoriteIds.compactMap { id in catalog.first(where: { $0.id == id }) }
    }

    private func toggleFavorite(_ id: String) {
        var ids = favoriteIds
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.insert(id, at: 0)
        }
        favoritesRaw = ids.prefix(12).joined(separator: ",")
    }

    private func trackRecent(_ id: String) {
        var ids = recentIds.filter { $0 != id }
        ids.insert(id, at: 0)
        recentRaw = ids.prefix(12).joined(separator: ",")
    }

    private func launch(_ item: ToolCatalogItem) {
        trackRecent(item.id)
        onOpenDestination(item.destination)
    }

    private func launchInChat(_ item: ToolCatalogItem) {
        trackRecent(item.id)
        if let prompt = item.chatPrompt {
            onOpenChatPrompt(prompt)
        } else {
            onOpenDestination(item.destination)
        }
    }
}

private struct ToolCatalogItem: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let destination: WorkspaceDestination
    let chatPrompt: String?
}

private struct MediaWorkspaceHubView: View {
    var onOpen: (WorkspaceDestination) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Media workspace")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Video editing, reels conversion, prompt-from-screenshot flow, and image generation all route here.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                mediaCard(
                    title: "Video Editor / CapCut Clone",
                    summary: "Upload media and apply prompt-driven edit/remix workflow.",
                    destination: .video
                )
                mediaCard(
                    title: "Long-form Video to Reels",
                    summary: "Use the upload mode in Video Studio to convert long footage into short cuts.",
                    destination: .video
                )
                mediaCard(
                    title: "Prompt From Screenshot",
                    summary: "Use photo upload in Video Studio to derive prompts and visual edits.",
                    destination: .video
                )
                mediaCard(
                    title: "Image Studio",
                    summary: "Generate image concepts and export to photos.",
                    destination: .image
                )
            }
            .padding(20)
        }
    }

    private func mediaCard(title: String, summary: String, destination: WorkspaceDestination) -> some View {
        Button {
            onOpen(destination)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LilithTheme.heroGradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: destination.icon)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .padding(16)
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WebWorkspaceHubView: View {
    var onOpen: (WorkspaceDestination) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Web workspace")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Website clone, prompt-from-link, and web-to-builder workflows stay visible here.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                webCard(
                    title: "Website Clone",
                    summary: "Clone and preview site structure from a live URL.",
                    destination: .clone
                )
                webCard(
                    title: "Prompt From Link",
                    summary: "Start with Site Clone, then hand the output to Chat/Code for prompt generation.",
                    destination: .clone
                )
                webCard(
                    title: "Builder Workspace",
                    summary: "Move cloned structures into the code workspace for edits.",
                    destination: .code
                )
            }
            .padding(20)
        }
    }

    private func webCard(title: String, summary: String, destination: WorkspaceDestination) -> some View {
        Button {
            onOpen(destination)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LilithTheme.heroGradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: destination.icon)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .padding(16)
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DocumentsWorkspaceHubView: View {
    var onOpenLegal: () -> Void
    var onOpenCode: () -> Void
    var onOpenChatPrompt: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Documents workspace")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("PDF/editor workflows, legal drafting, and document intelligence are grouped here.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(LilithTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                documentCard(
                    title: "PDF Editor / Adobe Clone",
                    summary: "Use Legal drafting and extraction flow for document edits and structured output.",
                    primaryActionTitle: "Open Legal",
                    secondaryActionTitle: "Open in Chat",
                    primaryAction: onOpenLegal,
                    secondaryAction: {
                        onOpenChatPrompt("Open PDF editing workflow. I want to draft, summarize, and extract clauses from a document.")
                    }
                )
                documentCard(
                    title: "Contract Drafting",
                    summary: "Generate NDA, agreements, and legal summaries.",
                    primaryActionTitle: "Open Legal",
                    secondaryActionTitle: "Open Builder",
                    primaryAction: onOpenLegal,
                    secondaryAction: onOpenCode
                )
            }
            .padding(20)
        }
    }

    private func documentCard(
        title: String,
        summary: String,
        primaryActionTitle: String,
        secondaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)

                HStack(spacing: 8) {
                    Button(primaryActionTitle, action: primaryAction)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(secondaryActionTitle, action: secondaryAction)
                        .buttonStyle(SecondaryLilithButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum InboxFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case messages = "Messages"
    case business = "Business"
    case requests = "Requests"
    case transactions = "Transactions"
    case documents = "Documents"

    var id: String { rawValue }
}

private enum InboxCardKind {
    case message
    case business
    case request
    case transaction
    case document
    case toolResult
}

private struct InboxWorkspaceView: View {
    @ObservedObject var viewModel: InboxViewModel
    var onOpenMessages: () -> Void
    var onOpenDocuments: () -> Void
    var onOpenTools: () -> Void
    var onOpenFinance: () -> Void
    var onOpenActivity: () -> Void

    @State private var selectedFilter: InboxFilter = .all
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                topBar
                filterRow
                if !priorityItems.isEmpty {
                    sectionHeader("Priority")
                    cardStack(priorityItems)
                }
                sectionHeader("Recent")
                cardStack(recentItems)
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.reload()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: selectedFilter)
        .animation(.easeInOut(duration: 0.2), value: viewModel.items.count)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Inbox")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Spacer()
            Button {
                // Search is inline via query field below.
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(LilithTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                onOpenActivity()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(LilithTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var filterRow: some View {
        VStack(spacing: 10) {
            TextField("Search inbox", text: $query)
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InboxFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedFilter == filter ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    selectedFilter == filter
                                    ? LilithTheme.accentB
                                    : LilithTheme.surface,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var filteredItems: [InboxUIItem] {
        let byFilter = viewModel.items.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .messages:
                return item.kind == .message
            case .business:
                return item.kind == .business || item.kind == .toolResult
            case .requests:
                return item.kind == .request
            case .transactions:
                return item.kind == .transaction
            case .documents:
                return item.kind == .document
            }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byFilter }
        return byFilter.filter {
            $0.title.lowercased().contains(q)
                || ($0.body?.lowercased().contains(q) ?? false)
                || ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    private var priorityItems: [InboxUIItem] {
        filteredItems.filter { $0.status == "unread" || $0.kind == .request || $0.kind == .transaction }.prefix(8).map { $0 }
    }

    private var recentItems: [InboxUIItem] {
        filteredItems.filter { item in !priorityItems.contains(where: { $0.id == item.id }) }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func cardStack(_ items: [InboxUIItem]) -> some View {
        VStack(spacing: 12) {
            if items.isEmpty {
                GlassCard {
                    Text("No inbox items in this view.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(items) { item in
                    inboxCard(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Read") {
                                Task { await viewModel.markRead(itemID: item.id) }
                            }
                            .tint(LilithTheme.accentA)
                            Button("Archive") {
                                withAnimation {
                                    viewModel.archive(itemID: item.id)
                                }
                            }
                            .tint(.gray)
                        }
                        .contextMenu {
                            Button("Mark read") {
                                Task { await viewModel.markRead(itemID: item.id) }
                            }
                            Button("Archive") {
                                withAnimation {
                                    viewModel.archive(itemID: item.id)
                                }
                            }
                            if item.kind == .request {
                                Button("Accept request") {
                                    Task { await viewModel.respondExchange(item: item, response: "accept") }
                                }
                                Button("Decline request") {
                                    Task { await viewModel.respondExchange(item: item, response: "decline") }
                                }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func inboxCard(_ item: InboxUIItem) -> some View {
        let accent: Color = item.status == "unread" ? LilithTheme.accentB : LilithTheme.textSecondary
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: icon(for: item.kind))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if item.status == "unread" {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                    }
                }

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentA)
                }

                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Button("Open") {
                        handleOpen(item)
                    }
                    .buttonStyle(SecondaryLilithButtonStyle())
                    if item.kind == .request {
                        Button("Accept") {
                            Task { await viewModel.respondExchange(item: item, response: "accept") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Decline") {
                            Task { await viewModel.respondExchange(item: item, response: "decline") }
                        }
                        .buttonStyle(SecondaryLilithButtonStyle())
                    } else if item.kind == .toolResult {
                        Button("Open Tool") {
                            onOpenTools()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
        .onTapGesture {
            handleOpen(item)
        }
    }

    private func handleOpen(_ item: InboxUIItem) {
        Task { await viewModel.markRead(itemID: item.id) }
        switch item.kind {
        case .message:
            onOpenMessages()
        case .document:
            onOpenDocuments()
        case .toolResult:
            onOpenTools()
        case .transaction:
            onOpenFinance()
        case .business, .request:
            onOpenActivity()
        }
    }

    private func icon(for kind: InboxCardKind) -> String {
        switch kind {
        case .message: return "bubble.left.and.bubble.right.fill"
        case .business: return "building.2.fill"
        case .request: return "person.badge.plus"
        case .transaction: return "arrow.left.arrow.right.square.fill"
        case .document: return "doc.text.fill"
        case .toolResult: return "wand.and.stars"
        }
    }
}

private struct ActivityWorkspaceView: View {
    @ObservedObject var viewModel: ActivityDashboardViewModel
    var onOpenConversation: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent activity")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if viewModel.items.isEmpty {
                            Text("No recorded activity yet.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                        } else {
                            ForEach(viewModel.items.prefix(12)) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.title)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(item.createdAt.prefix(10))
                                            .font(.caption)
                                            .foregroundStyle(LilithTheme.textSecondary)
                                    }
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                    Text(item.status.capitalized)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(item.status == "pending" ? LilithTheme.accentB : LilithTheme.accentA)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent conversations")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if viewModel.conversations.isEmpty {
                            Text("No conversations saved yet.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(LilithTheme.textSecondary)
                        } else {
                            ForEach(viewModel.conversations.prefix(10)) { conversation in
                                Button {
                                    onOpenConversation(conversation.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(conversation.title)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(String(conversation.updatedAt?.prefix(10) ?? ""))
                                                .font(.caption)
                                                .foregroundStyle(LilithTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundStyle(LilithTheme.textSecondary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }
}

private struct MemoryWorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject var viewModel: MemorySettingsViewModel
    @Binding var selectedAgent: AgentKind
    @Binding var selectedMode: AgentMode
    @Binding var ultraThinking: Bool
    var onOpenAccount: () -> Void
    var onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                preferencesCard
                memoryCaptureCard
                memoryListCard
                accountCard
            }
            .padding(20)
        }
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Workspace preferences")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Menu {
                        ForEach(AgentKind.allCases) { agent in
                            Button(agent.title) { selectedAgent = agent }
                        }
                    } label: {
                        preferenceField(title: "Agent", value: selectedAgent.title)
                    }

                    Menu {
                        ForEach(AgentMode.allCases) { mode in
                            Button(mode.title) { selectedMode = mode }
                        }
                    } label: {
                        preferenceField(title: "Mode", value: selectedMode.title)
                    }
                }

                Toggle("Ultra Thinking", isOn: $ultraThinking)
                    .tint(LilithTheme.accentA)
                    .foregroundStyle(.white)

                if viewModel.settings != nil {
                    Toggle("Memory enabled", isOn: Binding(
                        get: { viewModel.settings?.memoryEnabled ?? false },
                        set: { newValue in viewModel.settings?.memoryEnabled = newValue }
                    ))
                    .tint(LilithTheme.accentA)
                    .foregroundStyle(.white)

                    Toggle("Show tool hints", isOn: Binding(
                        get: { viewModel.settings?.toolHints ?? false },
                        set: { newValue in viewModel.settings?.toolHints = newValue }
                    ))
                    .tint(LilithTheme.accentA)
                    .foregroundStyle(.white)

                    Menu {
                        Button("Confirm sensitive actions") {
                            viewModel.settings?.approvalMode = "confirm_sensitive"
                        }
                        Button("Always ask") {
                            viewModel.settings?.approvalMode = "always_ask"
                        }
                    } label: {
                        preferenceField(
                            title: "Approvals",
                            value: viewModel.settings?.approvalMode.replacingOccurrences(of: "_", with: " ").capitalized ?? "Confirm Sensitive"
                        )
                    }
                }

                Button("Save settings") {
                    Task {
                        guard let token = authStore.token else { return }
                        viewModel.settings?.defaultAgent = selectedAgent.rawValue
                        viewModel.settings?.defaultMode = selectedMode.rawValue
                        await viewModel.saveSettings(token: token)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var memoryCaptureCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Teach Lilith")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Label", text: $viewModel.newMemoryLabel)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                TextField("Preference or fact to remember", text: $viewModel.newMemoryValue, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)

                Button("Save memory") {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.saveMemory(token: token)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var memoryListCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Learned behavior")
                    .font(.headline)
                    .foregroundStyle(.white)

                if viewModel.memories.isEmpty {
                    Text("Lilith has not stored any custom memories yet.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    ForEach(viewModel.memories.prefix(10)) { memory in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(memory.label)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(memory.value)
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accountCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account and permissions")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button("Open account") {
                    onOpenAccount()
                }
                .buttonStyle(SecondaryLilithButtonStyle())

                Button("Log out") {
                    onLogout()
                }
                .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func preferenceField(title: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(LilithTheme.textSecondary)
        }
        .padding(14)
        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@MainActor
private final class FinanceDashboardViewModel: ObservableObject {
    @Published var balance: FinanceBalanceResponse?
    @Published var transactions: [FinanceTransactionItem] = []
    @Published var analysis: FinanceAnalysisResponse?
    @Published var approvals: [FinanceApprovalItem] = []

    @Published var simulationAmount = ""
    @Published var simulationMerchant = "Purchase"
    @Published var transferAmount = ""
    @Published var transferSourceAccount = "Checking"
    @Published var transferDestinationAccount = "Savings"

    @Published var simulationResult: FinanceSimulationResponse?
    @Published var transferResult: FinanceTransferResponse?
    @Published var errorMessage: String?
    @Published var walletFiatBalance: Double = 0
    @Published var walletUSDCBalance: Double = 0
    @Published var walletActionMessage: String?
    @Published var subscriptions: [V1SubscriptionItem] = []
    @Published var invoices: [V1InvoiceItem] = []
    @Published var aiPrompt = ""
    @Published var aiOutput = ""

    private let apiClient = APIClient()

    var pendingApprovalsCount: Int {
        approvals.filter { $0.status == "pending" }.count
    }

    func load(token: String) async {
        do {
            async let balance: FinanceBalanceResponse = apiClient.request("/finance/balance", token: token)
            async let transactions: FinanceTransactionsResponse = apiClient.request("/finance/transactions", token: token)
            async let analysis: FinanceAnalysisResponse = apiClient.request("/finance/analyze", token: token)
            async let approvals: FinanceApprovalsResponse = apiClient.request("/finance/approvals", token: token)

            let balanceResponse = try await balance
            let transactionsResponse = try await transactions
            let analysisResponse = try await analysis
            let approvalsResponse = try await approvals
            self.balance = balanceResponse
            self.transferSourceAccount = balanceResponse.accounts.first?.name ?? transferSourceAccount
            self.transferDestinationAccount = balanceResponse.accounts.dropFirst().first?.name ?? transferDestinationAccount
            self.transactions = transactionsResponse.transactions
            self.analysis = analysisResponse
            self.approvals = approvalsResponse.approvals
            await loadWallet(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func simulate(token: String) async {
        guard let amount = Double(simulationAmount.replacingOccurrences(of: "$", with: "")) else {
            errorMessage = "Enter a valid simulation amount."
            return
        }
        do {
            simulationResult = try await apiClient.request(
                "/finance/simulate",
                method: "POST",
                body: FinanceSimulationPayload(amount: amount, merchant: simulationMerchant, sourceAccount: transferSourceAccount),
                token: token
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transfer(token: String) async {
        guard let amount = Double(transferAmount.replacingOccurrences(of: "$", with: "")) else {
            errorMessage = "Enter a valid transfer amount."
            return
        }
        do {
            transferResult = try await apiClient.request(
                "/finance/transfer",
                method: "POST",
                body: FinanceTransferPayload(amount: amount, sourceAccount: transferSourceAccount, destinationAccount: transferDestinationAccount),
                token: token
            )
            await load(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approve(approvalId: String, token: String) async {
        do {
            let _: FinanceApprovalExecutionResponse = try await apiClient.request(
                "/finance/approvals/\(approvalId)/approve",
                method: "POST",
                body: EmptyRequest(),
                token: token
            )
            await load(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadWallet(token: String) async {
        do {
            let history: V1PaymentHistoryResponse = try await apiClient.requestV1("/payments/history", token: token)
            let subscriptionsResponse: V1SubscriptionsResponse = try await apiClient.requestV1("/subscriptions", token: token)
            let invoicesResponse: V1InvoicesResponse = try await apiClient.requestV1("/invoices", token: token)

            subscriptions = subscriptionsResponse.items
            invoices = invoicesResponse.items
            walletFiatBalance = history.intents
                .filter { $0.status == "succeeded" && $0.currency.uppercased() == "USD" }
                .reduce(0) { $0 + $1.amount }
            walletUSDCBalance = history.intents
                .filter { $0.status == "succeeded" && ($0.stablecoin?.lowercased() == "usdc" || $0.rail == "stablecoin_usdc") }
                .reduce(0) { $0 + $1.amount }
        } catch {
            // Keep legacy finance data visible even if wallet endpoints fail.
        }
    }

    func runWalletQuickAction(_ action: WalletQuickAction, token: String) async {
        do {
            switch action {
            case .send:
                let intent = V1PaymentIntentBody(
                    amount: 12,
                    currency: "USD",
                    intentType: "tip",
                    payeeUserId: nil,
                    rail: "fiat",
                    stablecoin: nil,
                    network: nil,
                    paymentMethodId: nil,
                    idempotencyKey: "send-\(UUID().uuidString.lowercased())",
                    metadata: ["source": "wallet_quick_action"]
                )
                let created: V1PaymentIntentCreateResponse = try await apiClient.requestV1("/payments/intents", method: "POST", body: intent, token: token)
                let _: V1PaymentIntentCreateResponse = try await apiClient.requestV1(
                    "/payments/intents/\(created.paymentIntent.id)/confirm",
                    method: "POST",
                    body: V1PaymentConfirmBody(paymentMethodId: nil, passkeyAssertion: nil, passkeyChallengeId: nil),
                    token: token
                )
                walletActionMessage = "Sent \(currency(12)) in seconds."
            case .request:
                walletActionMessage = "Payment request prepared. Share in chat or inbox."
            case .addFunds:
                walletActionMessage = "Add funds is ready for linked methods."
            case .withdraw:
                let request = V1PayoutRequestBody(
                    amount: 15,
                    currency: "USD",
                    rail: "fiat",
                    stablecoin: nil,
                    network: nil,
                    destination: nil,
                    passkeyAssertion: nil,
                    passkeyChallengeId: nil,
                    metadata: ["source": "wallet_quick_action"]
                )
                let _: V1PayoutRequestResponse = try await apiClient.requestV1("/payouts/request", method: "POST", body: request, token: token)
                walletActionMessage = "Withdrawal request submitted."
            }
            await loadWallet(token: token)
        } catch {
            walletActionMessage = error.localizedDescription
        }
    }

    func runAIFinanceAction() {
        let query = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return }

        if query.contains("split"), let amount = firstAmount(in: query), let people = firstInt(in: query) {
            let each = amount / Double(max(people, 1))
            aiOutput = "Split result: \(currency(amount)) across \(people) people is \(currency(each)) each."
            return
        }
        if query.contains("summary") || query.contains("spending") {
            let spent = transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
            aiOutput = "Spending summary: \(currency(spent)) across \(transactions.count) recent transactions."
            return
        }
        if query.contains("invoice"), let amount = firstAmount(in: query) {
            aiOutput = "Draft invoice ready: Amount \(currency(amount)), due in 7 days, includes service line items."
            return
        }
        if let amount = firstAmount(in: query) {
            aiOutput = "Quick math: \(currency(amount)) remains payable. You can send or request this from Wallet actions."
            return
        }
        aiOutput = "Try requests like: split $120 between 4, summarize my spending, draft invoice for $240."
    }

    private func firstAmount(in text: String) -> Double? {
        let pattern = #"\$?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[valueRange])
    }

    private func firstInt(in text: String) -> Int? {
        let pattern = #"([0-9]{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.matches(in: text, range: range).last,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[valueRange])
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

private enum WalletQuickAction {
    case send
    case request
    case addFunds
    case withdraw
}

@MainActor
private final class LegalDashboardViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var summaryText = ""
    @Published var clauses: [LegalClauseItem] = []
    @Published var documentPrompt = ""
    @Published var documentType = "General Agreement"
    @Published var partiesText = "Party A, Party B"
    @Published var draftOutput = ""
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func summarize(token: String) async {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter source text first."
            return
        }
        do {
            let response: LegalSummaryResponse = try await apiClient.request(
                "/legal/summary",
                method: "POST",
                body: LegalSummaryPayload(text: sourceText, title: "Legal summary"),
                token: token
            )
            summaryText = response.summary
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func extractClauses(token: String) async {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter source text first."
            return
        }
        do {
            let response: LegalClauseResponse = try await apiClient.request(
                "/legal/clauses",
                method: "POST",
                body: LegalSummaryPayload(text: sourceText, title: "Clause extraction"),
                token: token
            )
            clauses = response.clauses
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateDraft(token: String) async {
        guard !documentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Describe the document you want Lilith to draft."
            return
        }
        do {
            let response: LegalDraftResponse = try await apiClient.request(
                "/legal/draft",
                method: "POST",
                body: LegalDraftPayload(
                    prompt: documentPrompt,
                    documentType: documentType,
                    parties: partiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                ),
                token: token
            )
            draftOutput = response.document
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class ToolsRegistryViewModel: ObservableObject {
    @Published var tools: [ToolRegistryItem] = []
    @Published var marketplaceAll: [V1MarketplaceToolItem] = []
    @Published var trendingTools: [V1MarketplaceToolItem] = []
    @Published var personalizedTools: [V1MarketplaceToolItem] = []
    @Published var creatorToolID = ""
    @Published var creatorToolName = ""
    @Published var creatorToolDescription = ""
    @Published var creatorToolCategory = "Automation"
    @Published var creatorPricingModel = "free"
    @Published var creatorPriceText = "0"
    @Published var statusMessage: String?

    private let apiClient = APIClient()
    private var activeToken: String?

    func load(token: String) async {
        activeToken = token
        do {
            if let response: V1ToolsCatalogResponse = try? await apiClient.requestV1("/tools/catalog", token: token) {
                tools = response.items
            } else {
                let response: ToolRegistryResponse = try await apiClient.request("/tools", token: token)
                tools = response.tools
            }
            await loadMarketplace(token: token)
        } catch {
            tools = []
            marketplaceAll = []
            trendingTools = []
            personalizedTools = []
            statusMessage = error.localizedDescription
        }
    }

    func loadMarketplace(token: String) async {
        do {
            let response: V1MarketplaceResponse = try await apiClient.requestV1("/tools/marketplace", token: token)
            marketplaceAll = response.items
            trendingTools = response.sections?.trending ?? Array(response.items.prefix(8))
            personalizedTools = response.sections?.personalized ?? Array(response.items.prefix(8))
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func loadMarketplaceIfNeeded() async {
        guard let token = activeToken else { return }
        if marketplaceAll.isEmpty {
            await loadMarketplace(token: token)
        }
    }

    func publishCreatorTool() async {
        guard let token = activeToken else { return }
        let id = creatorToolID.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = creatorToolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = creatorToolDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !name.isEmpty, !description.isEmpty else {
            statusMessage = "Fill tool ID, name, and description."
            return
        }
        let amount = Double(creatorPriceText.replacingOccurrences(of: "$", with: "")) ?? 0
        do {
            let payload = V1MarketplacePublishBody(
                toolId: id,
                name: name,
                description: description,
                category: creatorToolCategory,
                pricingModel: creatorPricingModel,
                priceAmount: max(amount, 0),
                currency: "USD",
                tags: [creatorToolCategory.lowercased(), "creator"],
                publish: true
            )
            let _: V1MarketplacePublishResponse = try await apiClient.requestV1(
                "/tools/marketplace",
                method: "POST",
                body: payload,
                token: token
            )
            statusMessage = "Tool published."
            await loadMarketplace(token: token)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func tryMarketplaceTool(_ listing: V1MarketplaceToolItem, conversationId: String? = nil) async -> V1MarketplaceRunResponse? {
        guard let token = activeToken else { return nil }
        do {
            if listing.pricingModel == "subscription" {
                let _: V1MarketplaceSubscribeResponse = try await apiClient.requestV1(
                    "/tools/marketplace/\(listing.id)/subscribe",
                    method: "POST",
                    body: V1MarketplaceSubscribeBody(billingInterval: "monthly"),
                    token: token
                )
            }
            let payload = V1MarketplaceRunBody(
                input: ["prompt": "Run \(listing.name) from marketplace"],
                conversationId: conversationId,
                shareResultInChat: conversationId != nil
            )
            let response: V1MarketplaceRunResponse = try await apiClient.requestV1(
                "/tools/marketplace/\(listing.id)/run",
                method: "POST",
                body: payload,
                token: token
            )
            statusMessage = "\(listing.name) finished."
            await loadMarketplace(token: token)
            return response
        } catch {
            statusMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
private final class ActivityDashboardViewModel: ObservableObject {
    @Published var items: [ActivityItem] = []
    @Published var conversations: [ConversationListItem] = []

    private let apiClient = APIClient()

    func load(token: String) async {
        do {
            async let activity: ActivityResponse = apiClient.request("/activity", token: token)
            async let conversations: [ConversationListItem] = apiClient.request("/conversations", token: token)
            let activityResponse = try await activity
            let conversationsResponse = try await conversations
            items = activityResponse.items
            self.conversations = conversationsResponse
        } catch {
            items = []
            conversations = []
        }
    }
}

private struct InboxUIItem: Identifiable, Equatable {
    let id: String
    let kind: InboxCardKind
    let title: String
    let subtitle: String?
    let body: String?
    let status: String
    let sourceType: String?
    let sourceID: String?
    let createdAt: String?
}

@MainActor
private final class InboxViewModel: ObservableObject {
    @Published var items: [InboxUIItem] = []
    @Published var unreadCount = 0

    private var archivedIDs: Set<String> = []
    private var activeToken: String?
    private let apiClient = APIClient()

    func load(token: String) async {
        activeToken = token
        await reload()
    }

    func reload() async {
        guard let token = activeToken else { return }
        do {
            let response: V1InboxResponse = try await apiClient.requestV1("/inbox", token: token)
            unreadCount = response.unread
            items = response.items
                .filter { !archivedIDs.contains($0.id) }
                .map(mapItem(_:))
        } catch {
            items = []
        }
    }

    func markRead(itemID: String) async {
        guard let token = activeToken else { return }
        let _: V1SimpleSuccess? = try? await apiClient.requestV1(
            "/inbox/\(itemID)/read",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            let current = items[index]
            items[index] = InboxUIItem(
                id: current.id,
                kind: current.kind,
                title: current.title,
                subtitle: current.subtitle,
                body: current.body,
                status: "read",
                sourceType: current.sourceType,
                sourceID: current.sourceID,
                createdAt: current.createdAt
            )
        }
        unreadCount = max(0, items.filter { $0.status == "unread" }.count)
    }

    func archive(itemID: String) {
        archivedIDs.insert(itemID)
        items.removeAll { $0.id == itemID }
        unreadCount = max(0, items.filter { $0.status == "unread" }.count)
    }

    func respondExchange(item: InboxUIItem, response: String) async {
        guard let token = activeToken,
              let sourceType = item.sourceType,
              sourceType == "exchange_request",
              let requestID = item.sourceID else { return }
        let _: V1SimpleSuccess? = try? await apiClient.requestV1(
            "/exchange/respond",
            method: "POST",
            body: V1ExchangeRespondBody(
                exchangeRequestID: requestID,
                response: response,
                message: nil,
                transactionStatus: response == "accept" ? "processing" : "cancelled"
            ),
            token: token
        )
        await markRead(itemID: item.id)
    }

    private func mapItem(_ row: V1InboxItem) -> InboxUIItem {
        let loweredTitle = row.title.lowercased()
        let kind: InboxCardKind
        switch row.itemType {
        case "message":
            kind = .message
        case "exchange_request":
            kind = .request
        case "transaction":
            kind = .transaction
        case "document":
            kind = .document
        case "tool_result":
            kind = .toolResult
        default:
            if loweredTitle.contains("request") || loweredTitle.contains("exchange") {
                kind = .request
            } else if loweredTitle.contains("invoice") || loweredTitle.contains("payment") || loweredTitle.contains("transaction") {
                kind = .transaction
            } else if loweredTitle.contains("document") || loweredTitle.contains("pdf") || loweredTitle.contains("contract") {
                kind = .document
            } else {
                kind = .business
            }
        }
        return InboxUIItem(
            id: row.id,
            kind: kind,
            title: row.title,
            subtitle: row.itemType.replacingOccurrences(of: "_", with: " ").capitalized,
            body: row.body,
            status: row.status,
            sourceType: row.sourceType,
            sourceID: row.sourceId,
            createdAt: row.createdAt
        )
    }
}

@MainActor
private final class MemorySettingsViewModel: ObservableObject {
    @Published var memories: [MemoryItemPayload] = []
    @Published var settings: LilithSettings?
    @Published var newMemoryLabel = ""
    @Published var newMemoryValue = ""

    private let apiClient = APIClient()

    func load(token: String) async {
        do {
            async let memory: MemoryResponse = apiClient.request("/memory", token: token)
            async let settings: LilithSettings = apiClient.request("/settings", token: token)
            let memoryResponse = try await memory
            let settingsResponse = try await settings
            self.memories = memoryResponse.items
            self.settings = settingsResponse
        } catch {
            memories = []
        }
    }

    func saveMemory(token: String) async {
        let value = newMemoryValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            let _: MemoryItemPayload = try await apiClient.request(
                "/memory",
                method: "POST",
                body: MemoryCreatePayload(
                    label: newMemoryLabel.isEmpty ? "preference" : newMemoryLabel,
                    value: value,
                    source: "manual"
                ),
                token: token
            )
            newMemoryLabel = ""
            newMemoryValue = ""
            await load(token: token)
        } catch {
            return
        }
    }

    func saveSettings(token: String) async {
        guard let settings else { return }
        do {
            let _: LilithSettings = try await apiClient.request(
                "/settings",
                method: "PUT",
                body: settings,
                token: token
            )
        } catch {
            return
        }
    }
}

private struct EmptyRequest: Encodable {}

private struct FinanceApprovalExecutionResponse: Decodable {
    let status: String
}

private struct V1SimpleSuccess: Decodable {
    let success: Bool
}

private struct V1InboxResponse: Decodable {
    let unread: Int
    let items: [V1InboxItem]
}

private struct V1InboxItem: Decodable {
    let id: String
    let itemType: String
    let sourceType: String?
    let sourceId: String?
    let title: String
    let body: String?
    let status: String
    let createdAt: String?
}

private struct V1ExchangeRespondBody: Encodable {
    let exchangeRequestID: String
    let response: String
    let message: String?
    let transactionStatus: String?
}

private struct V1ExchangeRequestBody: Encodable {
    let recipientUserId: Int
    let requestType: String
    let title: String
    let body: String?
    let sourceToolResultId: String?
}

private struct V1ExchangeRequestResponse: Decodable {
    let requestId: String
    let status: String
    let transactionId: String?
    let inboxItemId: String?
    let notificationId: String?
}

private struct V1PaymentIntent: Decodable {
    let id: String
    let amount: Double
    let currency: String
    let rail: String
    let stablecoin: String?
    let network: String?
    let intentType: String
    let status: String
    let paymentMethodId: String?
}

private struct V1PaymentIntentCreateResponse: Decodable {
    let paymentIntent: V1PaymentIntent
    let idempotent: Bool?
    let alreadyFinalized: Bool?
    let attemptId: String?
}

private struct V1PaymentIntentBody: Encodable {
    let amount: Double
    let currency: String
    let intentType: String
    let payeeUserId: Int?
    let rail: String
    let stablecoin: String?
    let network: String?
    let paymentMethodId: String?
    let idempotencyKey: String
    let metadata: [String: String]
}

private struct V1PaymentConfirmBody: Encodable {
    let paymentMethodId: String?
    let passkeyAssertion: String?
    let passkeyChallengeId: String?
}

private struct V1PaymentHistoryResponse: Decodable {
    let intents: [V1PaymentIntent]
}

private struct V1SubscriptionItem: Decodable {
    let id: String
    let subscriberUserId: Int
    let creatorUserId: Int
    let planId: String?
    let status: String
    let cancelAtPeriodEnd: Bool
}

private struct V1SubscriptionsResponse: Decodable {
    let items: [V1SubscriptionItem]
}

private struct V1InvoiceItem: Decodable {
    let id: String
    let issuerUserId: Int
    let recipientUserId: Int
    let title: String
    let amount: Double
    let currency: String
    let status: String
}

private struct V1InvoicesResponse: Decodable {
    let items: [V1InvoiceItem]
}

private struct V1CreateInvoiceBody: Encodable {
    let recipientUserId: Int
    let title: String
    let description: String?
    let amount: Double
    let currency: String
    let dueAt: String?
    let exchangeRequestId: String?
    let metadata: [String: String]
}

private struct V1CreateInvoiceResponse: Decodable {
    let invoiceId: String
    let status: String
}

private struct V1PayoutRequestBody: Encodable {
    let amount: Double
    let currency: String
    let rail: String
    let stablecoin: String?
    let network: String?
    let destination: String?
    let passkeyAssertion: String?
    let passkeyChallengeId: String?
    let metadata: [String: String]
}

private struct V1PayoutRequestResponse: Decodable {
    let payoutId: String
    let status: String
}

private struct V1AIJobCreateBody: Encodable {
    let action: String
    let inputText: String
    let conversationId: String?
    let messageId: String?
    let metadata: [String: String]
}

private struct V1AIJobResultPayload: Decodable {
    let id: String
    let outputText: String
    let outputKind: String
}

private struct V1AIJobCreateResponse: Decodable {
    struct JobPayload: Decodable {
        let id: String
        let status: String
        let action: String
        let conversationId: String?
        let messageId: String?
    }

    let job: JobPayload
    let result: V1AIJobResultPayload
}

private struct V1ToolsCatalogResponse: Decodable {
    let items: [ToolRegistryItem]
}

private struct V1MarketplaceToolItem: Decodable {
    let id: String
    let creatorUserId: Int
    let toolId: String
    let name: String
    let description: String
    let category: String
    let pricingModel: String
    let priceAmount: Double
    let currency: String
    let rating: Double
    let usage: Int
    let published: Bool
    let tags: [String]
}

private struct V1MarketplaceSections: Decodable {
    let trending: [V1MarketplaceToolItem]
    let personalized: [V1MarketplaceToolItem]
    let mine: [V1MarketplaceToolItem]
}

private struct V1MarketplaceResponse: Decodable {
    let items: [V1MarketplaceToolItem]
    let sections: V1MarketplaceSections?
}

private struct V1MarketplacePublishBody: Encodable {
    let toolId: String
    let name: String
    let description: String
    let category: String
    let pricingModel: String
    let priceAmount: Double
    let currency: String
    let tags: [String]
    let publish: Bool
}

private struct V1MarketplacePublishResponse: Decodable {
    struct ListingPayload: Decodable {
        let id: String
        let toolId: String
    }
    let listing: ListingPayload
}

private struct V1MarketplaceRunBody: Encodable {
    let input: [String: String]
    let conversationId: String?
    let shareResultInChat: Bool
}

private struct V1MarketplaceRunResponse: Decodable {
    struct JobPayload: Decodable {
        let id: String
        let status: String
    }
    struct ResultPayload: Decodable {
        let id: String
        let summary: String
        let result: [String: AnyDecodable]
    }
    let job: JobPayload
    let result: ResultPayload
}

private struct V1MarketplaceSubscribeBody: Encodable {
    let billingInterval: String
}

private struct V1MarketplaceSubscribeResponse: Decodable {
    let subscriptionId: String
    let status: String
}

private struct V1ProfileStats: Decodable {
    let posts: Int
    let followers: Int
    let following: Int
}

private struct V1ProfileData: Decodable {
    let userId: Int
    let username: String
    let lilithId: String
    let displayName: String
    let bio: String
    let discoverable: Bool
    let isPrivate: Bool
    let stats: V1ProfileStats
}

private struct V1ProfileMeResponse: Decodable {
    let profile: V1ProfileData
}

private struct V1PatchProfileBody: Encodable {
    let displayName: String
    let bio: String
    let discoverable: Bool
    let isPrivate: Bool
    let username: String
}

private struct V1SearchUserItem: Decodable {
    let userId: Int
    let username: String
    let displayName: String
    let lilithId: String
}

private struct V1SearchUsersResponse: Decodable {
    let items: [V1SearchUserItem]
}

private struct V1ConversationListItem: Decodable {
    let conversationId: String
    let title: String
    let lastMessage: String
    let lastMessageAt: String?
    let unread: Int
}

private struct V1ConversationListResponse: Decodable {
    let items: [V1ConversationListItem]
}

private struct V1ConversationMessage: Decodable {
    let id: String
    let role: String
    let content: String
    let createdAt: String?
}

private struct V1ConversationDetailResponse: Decodable {
    let conversationId: String
    let messages: [V1ConversationMessage]
}

private struct V1CreateConversationBody: Encodable {
    let title: String?
    let participantUserIds: [Int]
    let isGroup: Bool
}

private struct V1CreateConversationResponse: Decodable {
    let conversationId: String
}

private struct V1SendMessageBody: Encodable {
    let content: String
    let mediaAssetIds: [String]
    let encryptedPayload: String?
    let keyEnvelope: String?
    let nonce: String?
}

private struct V1SendMessageResponse: Decodable {
    let messageId: String
    let createdAt: String?
}

private struct V1ReadBody: Encodable {
    let messageIds: [String]
}

private struct V1FeedAuthor: Decodable {
    let username: String
    let displayName: String
    let lilithId: String?
}

private struct V1FeedEngagement: Decodable {
    let reactions: Int
    let comments: Int
    let saves: Int
    let viewerReacted: Bool
}

private struct V1FeedCommentPreview: Decodable {
    let id: String
    let authorUserId: Int
    let body: String
    let createdAt: String?
}

private struct V1FeedPostItem: Decodable {
    let id: String
    let authorUserId: Int
    let author: V1FeedAuthor
    let body: String
    let visibility: String
    let createdAt: String?
    let updatedAt: String?
    let media: [V1FeedMediaItem]
    let engagement: V1FeedEngagement
    let commentsPreview: [V1FeedCommentPreview]
}

private struct V1FeedMediaItem: Decodable {
    let assetId: String
    let kind: String
    let storageKey: String
}

private struct V1FeedHomeResponse: Decodable {
    let items: [V1FeedPostItem]
    let nextCursor: String?
}

private struct V1CreatePostBody: Encodable {
    let body: String
    let visibility: String
    let mediaAssetIds: [String]
}

private struct V1CreatePostResponse: Decodable {
    let post: V1FeedPostItem
}

private struct V1ReactBody: Encodable {
    let reaction: String
}

private struct V1CommentBody: Encodable {
    let body: String
}

private struct V1CommentResponse: Decodable {
    let id: String
    let postId: String
    let body: String
    let createdAt: String?
}

private struct V1NotificationItem: Decodable {
    let id: String
    let eventType: String
    let text: String
    let deepLink: String?
    let targetType: String?
    let targetId: String?
    let actorUserId: Int?
    let read: Bool
    let createdAt: String?
}

private struct V1NotificationsResponse: Decodable {
    let unread: Int
    let items: [V1NotificationItem]
}

private struct V1CallHistoryItem: Decodable {
    let callId: String
    let callerUserId: Int
    let callType: String
    let status: String
    let startedAt: String?
    let endedAt: String?
}

private struct V1CallHistoryResponse: Decodable {
    let items: [V1CallHistoryItem]
}

private struct V1CallStartBody: Encodable {
    let participantUserIds: [Int]
    let callType: String
    let offerSdp: String?
    let iceCandidates: [String]
}

private struct V1CallStartResponse: Decodable {
    let callId: String
    let status: String
}

private struct V1CallStateBody: Encodable {
    let answerSdp: String? = nil
    let iceCandidates: [String] = []
    let reason: String?
}

private struct V1CallStateResponse: Decodable {
    let callId: String
    let status: String
    let participantState: String
}

private struct V1CallConfigTurn: Decodable {
    let url: String
    let username: String
    let credential: String
    let configured: Bool
}

private struct V1CallConfigResponse: Decodable {
    let stunServers: [String]
    let turn: V1CallConfigTurn
}

private struct V1CallIceBody: Encodable {
    let candidates: [String]
    let sdpMid: String?
    let sdpMlineIndex: Int?
}

private struct V1ShareToolResultBody: Encodable {
    let caption: String?
    let conversationId: String?
}

private struct V1ShareResultPostResponse: Decodable {
    let success: Bool
    let postId: String
}

private struct V1ShareResultMessageResponse: Decodable {
    let success: Bool
    let messageId: String
}

@MainActor
private final class CommunicationHubViewModel: ObservableObject {
    @Published var profile = LilithIdentityProfile(
        id: "guest",
        username: "lilith",
        displayName: "Lilith User",
        bio: "Secure communication, social discovery, and tools live together here.",
        recoveryEmail: nil,
        phoneNumber: nil,
        location: "Protected",
        visibility: .publicProfile,
        followerCount: 0,
        followingCount: 0,
        connectionCount: 0,
        avatarSeed: 1
    )
    @Published var threads: [LilithSecureThread] = []
    @Published var selectedThreadID: UUID?
    @Published var activeCall: LilithCallSession?
    @Published var isPresentingCallSheet = false
    @Published var callHistory: [LilithCallRecord] = []
    @Published var connections: [LilithConnectionProfile] = []
    @Published var stories: [LilithStory] = []
    @Published var posts: [LilithSocialPost] = []
    @Published var deviceSessions: [LilithDeviceSession] = []
    @Published var businessProfiles: [LilithBusinessProfile] = []
    @Published var businessServices: [LilithBusinessService] = []
    @Published var businessReviews: [LilithBusinessReview] = []
    @Published var chatToolSuggestions: [V1MarketplaceToolItem] = []

    @Published var threadSearch = ""
    @Published var handleDraft = ""
    @Published var messageDraft = ""
    @Published var storyDraft = ""
    @Published var postDraft = ""
    @Published var postAudience: LilithPostAudience = .publicFeed
    @Published var postDraftImageData: Data?
    @Published var commentDrafts: [UUID: String] = [:]
    @Published var notificationsUnreadCount = 0
    @Published var paymentStatusMessage: String?
    @Published var aiStatusMessage: String?

    private var activeUserID: String?
    private var authToken: String?
    private var discoveryPool: [LilithConnectionProfile] = []
    private var threadIDByConversationID: [String: UUID] = [:]
    private var conversationIDByThreadID: [UUID: String] = [:]
    private var postIDByServerID: [String: UUID] = [:]
    private var serverIDByPostID: [UUID: String] = [:]
    private var userIDByHandle: [String: Int] = [:]
    private var messageIDByServerID: [String: UUID] = [:]
    private var latestCallIDByThreadID: [UUID: String] = [:]

    private var socketTask: URLSessionWebSocketTask?
    private var socketReconnectTask: Task<Void, Never>?
    private var socketToken: String?
    private var shouldReconnectSocket = false

    private let apiClient = APIClient()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var unreadCount: Int {
        threads.reduce(0) { $0 + $1.unreadCount }
    }

    var connectedCount: Int {
        connections.filter { $0.status == .connected }.count
    }

    var filteredThreads: [LilithSecureThread] {
        let query = threadSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return threads
            .filter { !$0.isArchived }
            .filter { thread in
                guard !query.isEmpty else { return true }
                return thread.title.lowercased().contains(query)
                    || thread.handle.lowercased().contains(query)
                    || thread.lastMessagePreview.lowercased().contains(query)
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.lastMessageAt > rhs.lastMessageAt
            }
    }

    var selectedThread: LilithSecureThread? {
        guard let selectedThreadID else { return nil }
        return threads.first(where: { $0.id == selectedThreadID })
    }

    var suggestedConnections: [LilithConnectionProfile] {
        let existing = Set(connections.map { $0.handle.lowercased() })
        return discoveryPool
            .filter { !existing.contains($0.handle.lowercased()) }
            .prefix(4)
            .map { $0 }
    }

    func businessProfile(forHandle handle: String) -> LilithBusinessProfile? {
        businessProfiles.first(where: { $0.handle.lowercased() == normalizeHandle(handle).lowercased() })
    }

    func aiSuggestions(for thread: LilithSecureThread, draft: String) -> [MessageAISuggestion] {
        let source = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (thread.messages.last?.body ?? "")
            : draft
        let lowered = source.lowercased()
        var output: [MessageAISuggestion] = []
        if lowered.contains("http") || lowered.contains("link") {
            output.append(.init(action: .summarize, label: "Summarize link text"))
            output.append(.init(action: .analyze, label: "Analyze context"))
        }
        if lowered.contains("video") || lowered.contains("reel") || lowered.contains("clip") {
            output.append(.init(action: .createVideo, label: "Create video"))
        }
        if lowered.contains("translate") || lowered.contains("spanish") || lowered.contains("french") {
            output.append(.init(action: .translate, label: "Translate this"))
        }
        if source.count > 80 {
            output.append(.init(action: .summarize, label: "Quick summary"))
        }
        if output.isEmpty {
            output = [
                .init(action: .improve, label: "Improve reply"),
                .init(action: .summarize, label: "Summarize"),
                .init(action: .createVideo, label: "Text → Video")
            ]
        }
        return Array(output.prefix(4))
    }

    func toolSuggestions(for thread: LilithSecureThread, draft: String) -> [V1MarketplaceToolItem] {
        let source = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (thread.messages.last?.body ?? "")
            : draft
        let lowered = source.lowercased()
        if chatToolSuggestions.isEmpty { return [] }
        let filtered = chatToolSuggestions.filter { listing in
            let haystack = "\(listing.name) \(listing.description) \(listing.category) \(listing.tags.joined(separator: " "))".lowercased()
            if lowered.isEmpty { return false }
            return haystack.contains("video") && (lowered.contains("video") || lowered.contains("reel") || lowered.contains("clip"))
                || haystack.contains("pdf") && (lowered.contains("pdf") || lowered.contains("document") || lowered.contains("contract"))
                || haystack.contains("web") && (lowered.contains("website") || lowered.contains("link") || lowered.contains("url"))
                || lowered.split(separator: " ").contains(where: { haystack.contains($0) })
        }
        return Array((filtered.isEmpty ? chatToolSuggestions : filtered).prefix(3))
    }

    func services(for businessID: String) -> [LilithBusinessService] {
        businessServices.filter { $0.businessID == businessID }
    }

    func reviews(for businessID: String) -> [LilithBusinessReview] {
        businessReviews.filter { $0.businessID == businessID }.sorted { $0.createdAt > $1.createdAt }
    }

    func paymentProfile(for thread: LilithSecureThread) -> LilithBusinessProfile {
        if let known = businessProfile(forHandle: thread.handle) {
            return known
        }
        return LilithBusinessProfile(
            id: "temp-\(thread.id.uuidString.lowercased())",
            businessName: thread.title,
            handle: normalizeHandle(thread.handle),
            tagline: "Secure payments inside Lilith chat.",
            category: .professionalServices,
            isVerified: false,
            acceptsPayments: true,
            responseTime: "Realtime",
            averageRating: 5.0
        )
    }

    func paymentProfile(forHandle handle: String) -> LilithBusinessProfile {
        if let known = businessProfile(forHandle: handle) {
            return known
        }
        let normalized = normalizeHandle(handle)
        return LilithBusinessProfile(
            id: "temp-\(normalized.replacingOccurrences(of: "@", with: ""))",
            businessName: displayName(from: normalized),
            handle: normalized,
            tagline: "Lilith username payment target.",
            category: .professionalServices,
            isVerified: false,
            acceptsPayments: true,
            responseTime: "Realtime",
            averageRating: 5.0
        )
    }

    func submitBusinessServiceRequest(_ service: LilithBusinessService, note: String) async {
        guard let business = businessProfiles.first(where: { $0.id == service.businessID }) else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestTitle = "Service request · \(service.title)"
        let requestDetail = cleanNote.isEmpty ? "Requested from Lilith Business profile." : cleanNote

        await submitExchange(
            title: requestTitle,
            details: requestDetail,
            amount: service.price,
            targetHandle: business.handle
        )

        let threadID = ensureThread(for: business.businessName, handle: business.handle)
        await sendMessageLive(
            threadID: threadID,
            body: "Request sent for \(service.title) (\(currency(service.price))). \(requestDetail)",
            attachmentName: nil,
            attachmentData: nil
        )
        paymentStatusMessage = "Request sent to \(business.businessName)."
    }

    func respondToServiceOffer(service: LilithBusinessService, business: LilithBusinessProfile, accept: Bool) async {
        let threadID = ensureThread(for: business.businessName, handle: business.handle)
        let message = accept
            ? "Accepted offer for \(service.title). Ready to proceed."
            : "Declined offer for \(service.title)."
        await sendMessageLive(threadID: threadID, body: message, attachmentName: nil, attachmentData: nil)
        paymentStatusMessage = accept ? "Offer accepted." : "Offer declined."
    }

    func submitPayment(to business: LilithBusinessProfile, amountText: String, note: String, intent: PaymentFlowIntent, rail: PaymentRailOption) async -> Bool {
        let amountValue = Double(amountText.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard amountValue > 0 else {
            paymentStatusMessage = "Enter a valid amount."
            return false
        }
        guard let token = authToken else {
            paymentStatusMessage = "Session unavailable."
            return false
        }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetUserID = await resolveUserID(forHandle: business.handle)
        let actionLine = intent == .pay
            ? "Paid \(currency(amountValue)) to \(business.businessName)"
            : "Requested \(currency(amountValue)) from \(business.businessName)"

        do {
            if intent == .pay {
                let assertion = await stepUpAssertion(reason: "Authorize payment to \(business.businessName)")
                guard assertion != nil else {
                    paymentStatusMessage = "Face ID or passkey verification was cancelled."
                    return false
                }
                let body = V1PaymentIntentBody(
                    amount: amountValue,
                    currency: "USD",
                    intentType: "business_quote_payment",
                    payeeUserId: targetUserID,
                    rail: rail.apiValue,
                    stablecoin: rail == .usdc ? "usdc" : nil,
                    network: rail == .usdc ? "base" : nil,
                    paymentMethodId: nil,
                    idempotencyKey: "ui-\(UUID().uuidString.lowercased())",
                    metadata: [
                        "source": "conversation_payment",
                        "businessHandle": business.handle,
                        "note": cleanNote
                    ]
                )
                let created: V1PaymentIntentCreateResponse = try await apiClient.requestV1(
                    "/payments/intents",
                    method: "POST",
                    body: body,
                    token: token
                )
                let _: V1PaymentIntentCreateResponse = try await apiClient.requestV1(
                    "/payments/intents/\(created.paymentIntent.id)/confirm",
                    method: "POST",
                    body: V1PaymentConfirmBody(
                        paymentMethodId: nil,
                        passkeyAssertion: assertion,
                        passkeyChallengeId: "lilith-pay-\(UUID().uuidString.prefix(8))"
                    ),
                    token: token
                )
            } else {
                if let recipient = targetUserID {
                    let invoice = V1CreateInvoiceBody(
                        recipientUserId: recipient,
                        title: "Payment request from \(profile.displayName)",
                        description: cleanNote.isEmpty ? "Requested in Lilith chat." : cleanNote,
                        amount: amountValue,
                        currency: "USD",
                        dueAt: nil,
                        exchangeRequestId: nil,
                        metadata: ["source": "chat_request", "requesterHandle": profile.handle]
                    )
                    let _: V1CreateInvoiceResponse = try await apiClient.requestV1(
                        "/invoices",
                        method: "POST",
                        body: invoice,
                        token: token
                    )
                }
            }
        } catch {
            paymentStatusMessage = error.localizedDescription
            return false
        }

        let threadID = ensureThread(for: business.businessName, handle: business.handle)
        await sendMessageLive(
            threadID: threadID,
            body: cleanNote.isEmpty ? actionLine : "\(actionLine). Note: \(cleanNote)",
            attachmentName: nil,
            attachmentData: nil
        )
        await submitExchange(
            title: intent == .pay ? "Payment · \(business.businessName)" : "Payment request · \(business.businessName)",
            details: cleanNote.isEmpty ? actionLine : cleanNote,
            amount: amountValue,
            targetHandle: business.handle
        )
        paymentStatusMessage = intent == .pay ? "Payment successful." : "Payment request sent."
        return true
    }

    func addReview(for business: LilithBusinessProfile, rating: Int, comment: String) {
        let cleanComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanComment.isEmpty else { return }
        let clamped = min(max(rating, 1), 5)
        businessReviews.insert(
            LilithBusinessReview(
                id: UUID(),
                businessID: business.id,
                authorName: profile.displayName,
                rating: clamped,
                comment: cleanComment,
                createdAt: .now
            ),
            at: 0
        )
        paymentStatusMessage = "Review posted."
    }

    func runAIMessageAction(
        _ action: MessageAIAction,
        message: LilithSecureMessage?,
        threadID: UUID,
        fallbackInput: String? = nil
    ) async {
        guard let token = authToken else { return }
        let input = (message?.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                     ? message?.body
                     : fallbackInput)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !input.isEmpty else {
            aiStatusMessage = "Type a message first."
            return
        }
        guard let conversationID = conversationIDByThreadID[threadID] else {
            aiStatusMessage = "Conversation unavailable."
            return
        }

        do {
            let payload = V1AIJobCreateBody(
                action: action.apiAction,
                inputText: input,
                conversationId: conversationID,
                messageId: nil,
                metadata: ["source": "chat_inline_action"]
            )
            let response: V1AIJobCreateResponse = try await apiClient.requestV1(
                "/ai/jobs",
                method: "POST",
                body: payload,
                token: token
            )
            let rendered = response.result.outputKind == "video"
                ? "Lilith AI created a video from your message prompt.\n\(response.result.outputText)"
                : response.result.outputText
            let prefix = action == .createVideo ? "AI Video" : "AI \(action.title)"
            await sendMessageLive(
                threadID: threadID,
                body: "\(prefix):\n\(rendered)",
                attachmentName: response.result.outputKind == "video" ? "Generated video preview" : nil,
                attachmentData: nil
            )
            aiStatusMessage = "\(action.title) complete."
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func runMarketplaceToolInThread(_ listing: V1MarketplaceToolItem, threadID: UUID, inputText: String) async {
        guard let token = authToken else { return }
        guard let conversationID = conversationIDByThreadID[threadID] else { return }
        do {
            let payload = V1MarketplaceRunBody(
                input: ["prompt": inputText.isEmpty ? "Run \(listing.name)" : inputText],
                conversationId: conversationID,
                shareResultInChat: true
            )
            let response: V1MarketplaceRunResponse = try await apiClient.requestV1(
                "/tools/marketplace/\(listing.id)/run",
                method: "POST",
                body: payload,
                token: token
            )
            await sendMessageLive(
                threadID: threadID,
                body: "Tool result • \(listing.name): \(response.result.summary)",
                attachmentName: nil,
                attachmentData: nil
            )
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func bootstrap(user: LilithUser?, token: String?) async {
        let seededProfile = makeProfile(from: user)
        authToken = token

        if activeUserID == seededProfile.id, !threads.isEmpty, token == socketToken {
            profile.recoveryEmail = seededProfile.recoveryEmail
            if profile.displayName == "Lilith User" {
                profile.displayName = seededProfile.displayName
            }
            return
        }

        activeUserID = seededProfile.id
        profile = seededProfile
        discoveryPool = makeDiscoveryPool(for: seededProfile)
        businessProfiles = seedBusinessProfiles(for: seededProfile)
        businessServices = seedBusinessServices(from: businessProfiles)
        businessReviews = seedBusinessReviews(from: businessProfiles)
        deviceSessions = [LilithDeviceSession(id: UUID(), deviceName: "Current device", lastSeenAt: .now, isCurrent: true)]

        if let token {
            await refreshFromBackend()
            connectRealtime(token: token)
        } else {
            disconnectRealtime()
            let snapshot = seedSnapshot(for: seededProfile)
            threads = snapshot.threads
            connections = snapshot.connections
            stories = snapshot.stories
            posts = snapshot.posts
            callHistory = snapshot.callHistory
            profile.connectionCount = connectedCount
            selectedThreadID = filteredThreads.first?.id
        }
    }

    func openThread(id: UUID) {
        selectedThreadID = id
        if let index = threads.firstIndex(where: { $0.id == id }) {
            threads[index].unreadCount = 0
        }
        Task {
            await loadMessagesIfNeeded(for: id)
            await markThreadRead(threadID: id)
        }
    }

    func ensureThread(for name: String, handle: String) -> UUID {
        let normalized = normalizeHandle(handle)
        if let existing = threads.first(where: { $0.handle.lowercased() == normalized.lowercased() }) {
            return existing.id
        }

        let member = LilithMiniProfile(id: normalized, displayName: name, handle: normalized)
        let thread = LilithSecureThread(
            id: UUID(),
            title: name,
            handle: normalized,
            lastMessagePreview: "Say hello from Lilith.",
            lastMessageAt: .now,
            unreadCount: 0,
            presence: .online,
            isPinned: false,
            isMuted: false,
            isArchived: false,
            isGroup: false,
            topic: nil,
            members: [member],
            messages: []
        )
        threads.insert(thread, at: 0)
        Task { await createConversationIfNeeded(for: thread.id, preferredTitle: name) }
        return thread.id
    }

    func connectByHandle() {
        let value = handleDraft
        handleDraft = ""
        connect(handle: value)
    }

    func connect(handle: String) {
        Task { await connectLive(handle: handle) }
    }

    func sendMessage() {
        let body = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedThreadID else { return }
        guard !body.isEmpty else { return }
        messageDraft = ""
        Task { await sendMessageLive(threadID: selectedThreadID, body: body, attachmentName: nil, attachmentData: nil) }
    }

    func sendImageAttachment(data: Data, to threadID: UUID) {
        openThread(id: threadID)
        Task { await sendMessageLive(threadID: threadID, body: "Shared a photo.", attachmentName: "Photo attachment", attachmentData: data) }
    }

    func startCall(for threadID: UUID, type: LilithCallType) {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return }
        selectedThreadID = threadID

        let session = LilithCallSession(
            id: UUID(),
            chatID: threadID,
            title: thread.title,
            handle: thread.handle,
            type: type,
            state: .ringing,
            startedAt: .now,
            muted: false,
            speakerOn: type == .video,
            cameraOn: type == .video
        )

        activeCall = session
        isPresentingCallSheet = true

        Task { @MainActor in
            await startCallLive(threadID: threadID, type: type, localSessionID: session.id)
        }
    }

    func reopenActiveCall() {
        if activeCall != nil {
            isPresentingCallSheet = true
        }
    }

    func acceptIncomingCall() {
        guard let activeCall,
              let token = authToken,
              let serverCallID = latestCallIDByThreadID[activeCall.chatID] else { return }
        Task {
            let _: V1CallStateResponse? = try? await apiClient.requestV1(
                "/calls/\(serverCallID)/accept",
                method: "POST",
                body: V1CallStateBody(reason: nil),
                token: token
            )
            if var current = self.activeCall {
                current.state = .connected
                self.activeCall = current
            }
        }
    }

    func declineIncomingCall() {
        guard let activeCall,
              let token = authToken,
              let serverCallID = latestCallIDByThreadID[activeCall.chatID] else { return }
        Task {
            let _: V1CallStateResponse? = try? await apiClient.requestV1(
                "/calls/\(serverCallID)/decline",
                method: "POST",
                body: V1CallStateBody(reason: "declined"),
                token: token
            )
            self.activeCall = nil
            self.isPresentingCallSheet = false
        }
    }

    func toggleMute() {
        guard var activeCall else { return }
        activeCall.muted.toggle()
        self.activeCall = activeCall
    }

    func toggleSpeaker() {
        guard var activeCall else { return }
        activeCall.speakerOn.toggle()
        self.activeCall = activeCall
    }

    func toggleCamera() {
        guard var activeCall else { return }
        activeCall.cameraOn.toggle()
        self.activeCall = activeCall
    }

    func endActiveCall() {
        guard let activeCall else { return }
        let duration = max(Int(Date().timeIntervalSince(activeCall.startedAt)), 1)
        callHistory.insert(
            LilithCallRecord(
                id: UUID(),
                peerName: activeCall.title,
                peerHandle: activeCall.handle,
                type: activeCall.type,
                startedAt: activeCall.startedAt,
                durationSeconds: duration,
                wasMissed: false
            ),
            at: 0
        )
        if let serverCallID = latestCallIDByThreadID[activeCall.chatID], let token = authToken {
            Task {
                let _: V1CallStateResponse = (try? await apiClient.requestV1("/calls/\(serverCallID)/end", method: "POST", body: V1CallStateBody(reason: "user_ended"), token: token)) ?? V1CallStateResponse(callId: serverCallID, status: "ended", participantState: "ended")
            }
        }
        self.activeCall = nil
        isPresentingCallSheet = false
    }

    func publishStory() {
        let caption = storyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !caption.isEmpty else { return }
        stories.removeAll { $0.authorHandle == profile.handle }
        stories.insert(
            LilithStory(
                id: UUID(),
                authorName: profile.displayName,
                authorHandle: profile.handle,
                caption: caption,
                createdAt: .now,
                expiresAt: Date().addingTimeInterval(60 * 60 * 24)
            ),
            at: 0
        )
        storyDraft = ""
    }

    func publishPost() {
        let body = postDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || postDraftImageData != nil else { return }
        let draftBody = body
        let draftImage = postDraftImageData
        postDraft = ""
        postDraftImageData = nil
        Task { await publishPostLive(body: draftBody, imageData: draftImage) }
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].likedByMe.toggle()
        posts[index].likeCount += posts[index].likedByMe ? 1 : -1
        Task { await reactToPostLive(postID: postID) }
    }

    func addComment(to postID: UUID) {
        let draft = (commentDrafts[postID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }

        posts[index].comments.append(
            LilithSocialComment(
                id: UUID(),
                authorName: profile.displayName,
                authorHandle: profile.handle,
                body: draft,
                createdAt: .now
            )
        )
        commentDrafts[postID] = ""
        Task { await commentPostLive(postID: postID, body: draft) }
    }

    func updateDisplayName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.displayName = trimmed
        Task { await patchProfileLive() }
    }

    func updateBio(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.bio = trimmed.isEmpty ? "Lilith profile ready for private communication and tools." : trimmed
        Task { await patchProfileLive() }
    }

    func linkDesktopSession() {
        deviceSessions.append(
            LilithDeviceSession(
                id: UUID(),
                deviceName: "MacBook Session",
                lastSeenAt: .now,
                isCurrent: false
            )
        )
    }

    func revokeOtherSessions() {
        deviceSessions = deviceSessions.filter(\.isCurrent)
    }
    
    func refreshFromBackend() async {
        guard let token = authToken else { return }
        await loadProfileLive(token: token)
        await loadConversationsLive(token: token)
        await loadFeedLive(token: token)
        await loadNotificationsLive(token: token)
        await loadCallHistoryLive(token: token)
        await loadMarketplaceSuggestionsLive(token: token)
    }

    func markAllNotificationsRead() async {
        guard let token = authToken else { return }
        let _: V1SimpleSuccess? = try? await apiClient.requestV1(
            "/notifications/read-all",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
        notificationsUnreadCount = 0
    }

    func shareToolResultToPost(resultID: String, caption: String?) async {
        guard let token = authToken else { return }
        let _: V1ShareResultPostResponse? = try? await apiClient.requestV1(
            "/tools/results/\(resultID)/post",
            method: "POST",
            body: V1ShareToolResultBody(caption: caption, conversationId: nil),
            token: token
        )
        await loadFeedLive(token: token)
    }

    func shareToolResultToMessage(resultID: String, threadID: UUID, caption: String?) async {
        guard let token = authToken,
              let conversationID = conversationIDByThreadID[threadID] else { return }
        let _: V1ShareResultMessageResponse? = try? await apiClient.requestV1(
            "/tools/results/\(resultID)/message",
            method: "POST",
            body: V1ShareToolResultBody(caption: caption, conversationId: conversationID),
            token: token
        )
        await loadMessagesIfNeeded(for: threadID)
    }

    private func submitExchange(title: String, details: String, amount: Double, targetHandle: String) async {
        guard let token = authToken else { return }
        let targetUserId = await resolveUserID(forHandle: targetHandle)
        guard let targetUserId else { return }

        let _: V1ExchangeRequestResponse? = try? await apiClient.requestV1(
            "/exchange/request",
            method: "POST",
            body: V1ExchangeRequestBody(
                recipientUserId: targetUserId,
                requestType: "service_payment",
                title: title,
                body: "\(details)\nAmount: \(currency(amount))",
                sourceToolResultId: nil
            ),
            token: token
        )
    }

    private func resolveUserID(forHandle handle: String) async -> Int? {
        guard let token = authToken else { return nil }
        let normalized = normalizeHandle(handle).lowercased()
        if let cached = userIDByHandle[normalized] {
            return cached
        }
        let query = normalized.replacingOccurrences(of: "@", with: "")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let search: V1SearchUsersResponse = try? await apiClient.requestV1("/search/users?q=\(encoded)", token: token),
           let first = search.items.first {
            userIDByHandle[normalized] = first.userId
            return first.userId
        }
        return nil
    }

    private func stepUpAssertion(reason: String) async -> String? {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if !canEvaluate {
            return "passkey-fallback-\(UUID().uuidString.lowercased())"
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? "faceid-\(UUID().uuidString.lowercased())" : nil
        } catch {
            return nil
        }
    }

    private func makeProfile(from user: LilithUser?) -> LilithIdentityProfile {
        let id = user?.id ?? "guest"
        let displayName = user?.displayName ?? "Lilith User"
        let storedUsername = UserDefaults.standard.string(forKey: "lilith.onboarding.username.\(id)")
        let username = sanitizeUsername(storedUsername ?? user?.username ?? user?.email.split(separator: "@").first.map(String.init) ?? displayName)
        let onboardingMode = UserDefaults.standard.string(forKey: "lilith.onboarding.mode.\(id)") ?? "adult"
        let interests = onboardingList(for: id, suffix: "interests")
        let defaultBio = interests.isEmpty
            ? "AI-native profile ready for secure chat, calls, social discovery, and tools."
            : "Focused on \(interests.prefix(3).joined(separator: ", ")). \(onboardingMode.capitalized) profile ready for Lilith."
        return LilithIdentityProfile(
            id: id,
            username: username,
            displayName: displayName,
            bio: user?.bio ?? defaultBio,
            recoveryEmail: user?.email,
            phoneNumber: nil,
            location: "Protected",
            visibility: .publicProfile,
            followerCount: 184,
            followingCount: 62,
            connectionCount: 3,
            avatarSeed: abs(id.hashValue) % 7 + 1
        )
    }

    private func seedSnapshot(for profile: LilithIdentityProfile) -> LilithCommunicationSnapshot {
        let alex = LilithConnectionProfile(id: "alex", displayName: "Alex Mercer", handle: "@alex", about: "Product and infra.", status: .connected)
        let priya = LilithConnectionProfile(id: "priya", displayName: "Priya Shah", handle: "@priya", about: "Design systems and launch planning.", status: .connected)
        let maya = LilithConnectionProfile(id: "maya", displayName: "Maya Reed", handle: "@maya", about: "Media and creator partnerships.", status: .connected)

        let directAlexID = UUID()
        let directPriyaID = UUID()
        let groupID = UUID()

        let threads = [
            LilithSecureThread(
                id: directAlexID,
                title: alex.displayName,
                handle: alex.handle,
                lastMessagePreview: "I can jump on a secure call whenever you're ready.",
                lastMessageAt: Date().addingTimeInterval(-60 * 11),
                unreadCount: 2,
                presence: .online,
                isPinned: true,
                isMuted: false,
                isArchived: false,
                isGroup: false,
                topic: nil,
                members: [LilithMiniProfile(id: alex.id, displayName: alex.displayName, handle: alex.handle)],
                messages: [
                    LilithSecureMessage(id: UUID(), chatID: directAlexID, body: "Morning. The new shell feels much calmer.", sentAt: Date().addingTimeInterval(-60 * 38), direction: .incoming, deliveryStatus: .read, attachmentName: nil, attachmentKind: nil, attachmentData: nil, replyToMessageID: nil, reactions: [], isPinned: false, isStarred: false, editedAt: nil),
                    LilithSecureMessage(id: UUID(), chatID: directAlexID, body: "I can jump on a secure call whenever you're ready.", sentAt: Date().addingTimeInterval(-60 * 11), direction: .incoming, deliveryStatus: .read, attachmentName: nil, attachmentKind: nil, attachmentData: nil, replyToMessageID: nil, reactions: [], isPinned: false, isStarred: false, editedAt: nil)
                ]
            ),
            LilithSecureThread(
                id: directPriyaID,
                title: priya.displayName,
                handle: priya.handle,
                lastMessagePreview: "Finance looks native now.",
                lastMessageAt: Date().addingTimeInterval(-60 * 44),
                unreadCount: 0,
                presence: .away,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isGroup: false,
                topic: nil,
                members: [LilithMiniProfile(id: priya.id, displayName: priya.displayName, handle: priya.handle)],
                messages: [
                    LilithSecureMessage(id: UUID(), chatID: directPriyaID, body: "Finance looks native now.", sentAt: Date().addingTimeInterval(-60 * 44), direction: .incoming, deliveryStatus: .read, attachmentName: nil, attachmentKind: nil, attachmentData: nil, replyToMessageID: nil, reactions: [], isPinned: false, isStarred: false, editedAt: nil)
                ]
            ),
            LilithSecureThread(
                id: groupID,
                title: "Lilith Core",
                handle: "#lilith-core",
                lastMessagePreview: "Launch review in fifteen.",
                lastMessageAt: Date().addingTimeInterval(-60 * 92),
                unreadCount: 5,
                presence: .online,
                isPinned: false,
                isMuted: false,
                isArchived: false,
                isGroup: true,
                topic: "Product, security, and launch operations",
                members: [
                    LilithMiniProfile(id: alex.id, displayName: alex.displayName, handle: alex.handle),
                    LilithMiniProfile(id: priya.id, displayName: priya.displayName, handle: priya.handle),
                    LilithMiniProfile(id: maya.id, displayName: maya.displayName, handle: maya.handle)
                ],
                messages: [
                    LilithSecureMessage(id: UUID(), chatID: groupID, body: "Launch review in fifteen.", sentAt: Date().addingTimeInterval(-60 * 92), direction: .incoming, deliveryStatus: .read, attachmentName: nil, attachmentKind: nil, attachmentData: nil, replyToMessageID: nil, reactions: [], isPinned: false, isStarred: false, editedAt: nil),
                    LilithSecureMessage(id: UUID(), chatID: groupID, body: "I pushed the last UI polish pass.", sentAt: Date().addingTimeInterval(-60 * 80), direction: .outgoing, deliveryStatus: .read, attachmentName: nil, attachmentKind: nil, attachmentData: nil, replyToMessageID: nil, reactions: [], isPinned: false, isStarred: false, editedAt: nil)
                ]
            )
        ]

        let stories = [
            LilithStory(id: UUID(), authorName: alex.displayName, authorHandle: alex.handle, caption: "Morning run before reviews.", createdAt: Date().addingTimeInterval(-60 * 18), expiresAt: Date().addingTimeInterval(60 * 60 * 18)),
            LilithStory(id: UUID(), authorName: priya.displayName, authorHandle: priya.handle, caption: "Design tokens are locked.", createdAt: Date().addingTimeInterval(-60 * 40), expiresAt: Date().addingTimeInterval(60 * 60 * 16)),
            LilithStory(id: UUID(), authorName: profile.displayName, authorHandle: profile.handle, caption: "Lilith shell is finally feeling cohesive.", createdAt: Date().addingTimeInterval(-60 * 7), expiresAt: Date().addingTimeInterval(60 * 60 * 23))
        ]

        var posts = [
            LilithSocialPost(
                id: UUID(),
                authorName: maya.displayName,
                authorHandle: maya.handle,
                body: "Pushing a cleaner post composer made the whole feed feel more premium.",
                createdAt: Date().addingTimeInterval(-60 * 26),
                audience: .publicFeed,
                likeCount: 18,
                likedByMe: false,
                mediaLabel: nil,
                mediaData: nil,
                tags: ["#design", "#lilith"],
                comments: [
                    LilithSocialComment(id: UUID(), authorName: "Alex Mercer", authorHandle: "@alex", body: "The spacing pass helped a lot.", createdAt: Date().addingTimeInterval(-60 * 14))
                ]
            ),
            LilithSocialPost(
                id: UUID(),
                authorName: profile.displayName,
                authorHandle: profile.handle,
                body: "Lilith ID routing is live. You can search, connect, message, and call without centering everything on a phone number.",
                createdAt: Date().addingTimeInterval(-60 * 58),
                audience: .connections,
                likeCount: 12,
                likedByMe: true,
                mediaLabel: nil,
                mediaData: nil,
                tags: ["#identity", "#communication"],
                comments: []
            )
        ]

        let interests = onboardingList(for: profile.id, suffix: "interests")
        if !interests.isEmpty {
            posts.insert(
                LilithSocialPost(
                    id: UUID(),
                    authorName: "Lilith",
                    authorHandle: "@lilith",
                    body: "Personalized for you: \(interests.prefix(3).joined(separator: ", ")). Your feed and tools are tuned.",
                    createdAt: Date().addingTimeInterval(-60 * 12),
                    audience: .publicFeed,
                    likeCount: 3,
                    likedByMe: false,
                    mediaLabel: nil,
                    mediaData: nil,
                    tags: ["#onboarding", "#personalized"],
                    comments: []
                ),
                at: 0
            )
        }

        let callHistory = [
            LilithCallRecord(id: UUID(), peerName: alex.displayName, peerHandle: alex.handle, type: .voice, startedAt: Date().addingTimeInterval(-60 * 140), durationSeconds: 780, wasMissed: false)
        ]

        let deviceSessions = [
            LilithDeviceSession(id: UUID(), deviceName: "iPhone 16 Pro", lastSeenAt: .now, isCurrent: true),
            LilithDeviceSession(id: UUID(), deviceName: "MacBook Air", lastSeenAt: Date().addingTimeInterval(-60 * 95), isCurrent: false)
        ]

        return LilithCommunicationSnapshot(
            profile: profile,
            threads: threads,
            connections: [alex, priya, maya],
            stories: stories,
            posts: posts,
            callHistory: callHistory,
            deviceSessions: deviceSessions
        )
    }

    private func seedBusinessProfiles(for profile: LilithIdentityProfile) -> [LilithBusinessProfile] {
        [
            LilithBusinessProfile(
                id: "biz-legal-ease",
                businessName: "Legal Ease Studio",
                handle: "@legalease",
                tagline: "Contracts, clause review, and fast legal drafting.",
                category: .legal,
                isVerified: true,
                acceptsPayments: true,
                responseTime: "Responds in 10 min",
                averageRating: 4.9
            ),
            LilithBusinessProfile(
                id: "biz-wealth-wizard",
                businessName: "Wealth Wizard Advisors",
                handle: "@wealthwizard",
                tagline: "Budget strategy, spending plans, and portfolio coaching.",
                category: .finance,
                isVerified: true,
                acceptsPayments: true,
                responseTime: "Responds in 20 min",
                averageRating: 4.8
            ),
            LilithBusinessProfile(
                id: "biz-lilith-creator",
                businessName: "\(profile.displayName) Studio",
                handle: profile.handle,
                tagline: "Creator services and collaboration powered by Lilith.",
                category: .creatorStudio,
                isVerified: false,
                acceptsPayments: true,
                responseTime: "Responds in 30 min",
                averageRating: 5.0
            )
        ]
    }

    private func seedBusinessServices(from businesses: [LilithBusinessProfile]) -> [LilithBusinessService] {
        guard businesses.count >= 2 else { return [] }
        return [
            LilithBusinessService(id: "svc-contract-review", businessID: businesses[0].id, title: "Contract Review", price: 149, description: "Line-by-line contract review with risk notes."),
            LilithBusinessService(id: "svc-nda-draft", businessID: businesses[0].id, title: "NDA Draft", price: 89, description: "Custom NDA draft prepared for your use case."),
            LilithBusinessService(id: "svc-budget-plan", businessID: businesses[1].id, title: "Monthly Budget Plan", price: 99, description: "Personalized spending framework and targets."),
            LilithBusinessService(id: "svc-cashflow-audit", businessID: businesses[1].id, title: "Cashflow Audit", price: 129, description: "Audit recurring spend and identify leaks.")
        ]
    }

    private func seedBusinessReviews(from businesses: [LilithBusinessProfile]) -> [LilithBusinessReview] {
        guard businesses.count >= 2 else { return [] }
        return [
            LilithBusinessReview(id: UUID(), businessID: businesses[0].id, authorName: "Maya Reed", rating: 5, comment: "Very fast turnaround and clear legal notes.", createdAt: .now.addingTimeInterval(-60 * 60 * 7)),
            LilithBusinessReview(id: UUID(), businessID: businesses[1].id, authorName: "Alex Mercer", rating: 5, comment: "The budget plan was practical and easy to follow.", createdAt: .now.addingTimeInterval(-60 * 60 * 19))
        ]
    }

    private func makeDiscoveryPool(for profile: LilithIdentityProfile) -> [LilithConnectionProfile] {
        let base = [
            LilithConnectionProfile(id: "rowan", displayName: "Rowan Vale", handle: "@rowan", about: "Security and trust systems.", status: .pending),
            LilithConnectionProfile(id: "jules", displayName: "Jules Hart", handle: "@jules", about: "Creator tools and media pilots.", status: .pending),
            LilithConnectionProfile(id: "kai", displayName: "Kai Benson", handle: "@kai", about: "Community ops and moderation hooks.", status: .pending)
        ]
        let restricted = UserDefaults.standard.bool(forKey: "lilith.onboarding.discoveryRestricted.\(profile.id)")
        return restricted ? Array(base.prefix(1)) : base
    }

    private func sanitizeUsername(_ value: String) -> String {
        let cleaned = value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        return cleaned.isEmpty ? "lilith" : cleaned
    }

    private func normalizeHandle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    private func onboardingList(for userID: String, suffix: String) -> [String] {
        let key = "lilith.onboarding.\(suffix).\(userID)"
        guard let raw = UserDefaults.standard.string(forKey: key), !raw.isEmpty else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func displayName(from handle: String) -> String {
        handle
            .replacingOccurrences(of: "@", with: "")
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func parseDate(_ iso: String?) -> Date {
        guard let iso else { return .now }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso) ?? .now
    }

    private func threadID(for conversationID: String) -> UUID {
        if let existing = threadIDByConversationID[conversationID] { return existing }
        let generated = UUID()
        threadIDByConversationID[conversationID] = generated
        conversationIDByThreadID[generated] = conversationID
        return generated
    }

    private func postID(for serverPostID: String) -> UUID {
        if let existing = postIDByServerID[serverPostID] { return existing }
        let generated = UUID()
        postIDByServerID[serverPostID] = generated
        serverIDByPostID[generated] = serverPostID
        return generated
    }

    private func connectLive(handle: String) async {
        let normalized = normalizeHandle(handle)
        guard normalized.count > 1, let token = authToken else { return }
        if let activeUserID,
           UserDefaults.standard.bool(forKey: "lilith.onboarding.commApprovedOnly.\(activeUserID)") {
            return
        }
        do {
            let query = normalized.replacingOccurrences(of: "@", with: "")
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let search: V1SearchUsersResponse = try await apiClient.requestV1("/search/users?q=\(encoded)", token: token)
            guard let match = search.items.first else { return }
            let _: V1SimpleSuccess = try await apiClient.requestV1("/social/follow/\(match.userId)", method: "POST", body: EmptyRequest(), token: token)
            userIDByHandle["@\(match.username.lowercased())"] = match.userId
            if !connections.contains(where: { $0.handle.lowercased() == "@\(match.username.lowercased())" }) {
                connections.insert(
                    LilithConnectionProfile(
                        id: String(match.userId),
                        displayName: match.displayName,
                        handle: "@\(match.username.lowercased())",
                        about: "Connected through Lilith.",
                        status: .connected
                    ),
                    at: 0
                )
            }
            profile.connectionCount = connectedCount
            profile.followerCount = max(profile.followerCount + 1, profile.followerCount)
            _ = ensureThread(for: match.displayName, handle: "@\(match.username.lowercased())")
            await loadProfileLive(token: token)
        } catch {
            return
        }
    }

    private func createConversationIfNeeded(for threadID: UUID, preferredTitle: String) async {
        guard let token = authToken else { return }
        if conversationIDByThreadID[threadID] != nil { return }
        guard let thread = threads.first(where: { $0.id == threadID }) else { return }

        let normalizedHandle = thread.handle.lowercased()
        var peerUserID = userIDByHandle[normalizedHandle]
        if peerUserID == nil {
            let query = normalizedHandle.replacingOccurrences(of: "@", with: "")
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            if let search: V1SearchUsersResponse = try? await apiClient.requestV1("/search/users?q=\(encoded)", token: token),
               let match = search.items.first {
                peerUserID = match.userId
                userIDByHandle[normalizedHandle] = match.userId
            }
        }
        guard let peerUserID else { return }
        let payload = V1CreateConversationBody(title: preferredTitle, participantUserIds: [peerUserID], isGroup: false)
        if let response: V1CreateConversationResponse = try? await apiClient.requestV1("/messages/conversations", method: "POST", body: payload, token: token) {
            threadIDByConversationID[response.conversationId] = threadID
            conversationIDByThreadID[threadID] = response.conversationId
        }
    }

    private func sendMessageLive(threadID: UUID, body: String, attachmentName: String?, attachmentData: Data?) async {
        guard let token = authToken else { return }
        if conversationIDByThreadID[threadID] == nil {
            await createConversationIfNeeded(for: threadID, preferredTitle: threads.first(where: { $0.id == threadID })?.title ?? "Direct message")
        }
        guard let conversationID = conversationIDByThreadID[threadID],
              let index = threads.firstIndex(where: { $0.id == threadID }) else { return }

        let optimistic = LilithSecureMessage(
            id: UUID(),
            chatID: threadID,
            body: body,
            sentAt: .now,
            direction: .outgoing,
            deliveryStatus: .sending,
            attachmentName: attachmentName,
            attachmentKind: attachmentData == nil ? nil : "image",
            attachmentData: attachmentData,
            replyToMessageID: nil,
            reactions: [],
            isPinned: false,
            isStarred: false,
            editedAt: nil
        )
        threads[index].messages.append(optimistic)
        threads[index].lastMessagePreview = attachmentName ?? body
        threads[index].lastMessageAt = optimistic.sentAt
        threads[index].unreadCount = 0

        do {
            let payload = V1SendMessageBody(
                content: body,
                mediaAssetIds: [],
                encryptedPayload: nil,
                keyEnvelope: nil,
                nonce: nil
            )
            let response: V1SendMessageResponse = try await apiClient.requestV1(
                "/messages/conversations/\(conversationID)/send",
                method: "POST",
                body: payload,
                token: token
            )
            if let localIndex = threads[index].messages.firstIndex(where: { $0.id == optimistic.id }) {
                threads[index].messages[localIndex].deliveryStatus = .delivered
            }
            messageIDByServerID[response.messageId] = optimistic.id
        } catch {
            if let localIndex = threads[index].messages.firstIndex(where: { $0.id == optimistic.id }) {
                threads[index].messages[localIndex].deliveryStatus = .failed
            }
        }
    }

    private func publishPostLive(body: String, imageData: Data?) async {
        guard let token = authToken else { return }
        do {
            let visibility: String
            switch postAudience {
            case .publicFeed: visibility = "public"
            case .connections: visibility = "followers"
            case .privateNote: visibility = "private"
            }
            let payload = V1CreatePostBody(body: body.isEmpty ? "Shared an update." : body, visibility: visibility, mediaAssetIds: [])
            let response: V1CreatePostResponse = try await apiClient.requestV1("/posts", method: "POST", body: payload, token: token)
            let post = mapPost(response.post)
            posts.insert(post, at: 0)
        } catch {
            let fallback = LilithSocialPost(
                id: UUID(),
                authorName: profile.displayName,
                authorHandle: profile.handle,
                body: body.isEmpty ? "Shared an update." : body,
                createdAt: .now,
                audience: postAudience,
                likeCount: 0,
                likedByMe: false,
                mediaLabel: imageData == nil ? nil : "Photo",
                mediaData: imageData,
                tags: [],
                comments: []
            )
            posts.insert(fallback, at: 0)
        }
    }

    private func reactToPostLive(postID: UUID) async {
        guard let token = authToken,
              let serverID = serverIDByPostID[postID] else { return }
        _ = try? await apiClient.requestV1(
            "/posts/\(serverID)/react",
            method: "POST",
            body: V1ReactBody(reaction: "like"),
            token: token
        ) as V1SimpleSuccess
    }

    private func commentPostLive(postID: UUID, body: String) async {
        guard let token = authToken,
              let serverID = serverIDByPostID[postID] else { return }
        _ = try? await apiClient.requestV1(
            "/posts/\(serverID)/comment",
            method: "POST",
            body: V1CommentBody(body: body),
            token: token
        ) as V1CommentResponse
    }

    private func patchProfileLive() async {
        guard let token = authToken else { return }
        let payload = V1PatchProfileBody(
            displayName: profile.displayName,
            bio: profile.bio,
            discoverable: true,
            isPrivate: profile.visibility == .privateProfile,
            username: profile.username
        )
        _ = try? await apiClient.requestV1("/profiles/me", method: "PATCH", body: payload, token: token) as V1SimpleSuccess
    }

    private func startCallLive(threadID: UUID, type: LilithCallType, localSessionID: UUID) async {
        guard let token = authToken else { return }
        var participantIDs: [Int] = []
        if let thread = threads.first(where: { $0.id == threadID }) {
            let normalized = thread.handle.lowercased()
            if let known = userIDByHandle[normalized] {
                participantIDs = [known]
            } else {
                let query = normalized.replacingOccurrences(of: "@", with: "")
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                if let search: V1SearchUsersResponse = try? await apiClient.requestV1("/search/users?q=\(encoded)", token: token),
                   let first = search.items.first {
                    participantIDs = [first.userId]
                    userIDByHandle[normalized] = first.userId
                }
            }
        }
        do {
            let response: V1CallStartResponse = try await apiClient.requestV1(
                "/calls/start",
                method: "POST",
                body: V1CallStartBody(participantUserIds: participantIDs, callType: type.rawValue, offerSdp: nil, iceCandidates: []),
                token: token
            )
            latestCallIDByThreadID[threadID] = response.callId
            let _: V1CallConfigResponse? = try? await apiClient.requestV1("/calls/config", token: token)
            let _: V1SimpleSuccess? = try? await apiClient.requestV1(
                "/calls/\(response.callId)/ice",
                method: "POST",
                body: V1CallIceBody(candidates: [], sdpMid: nil, sdpMlineIndex: nil),
                token: token
            )
            if var call = activeCall, call.id == localSessionID {
                call.state = .connected
                activeCall = call
            }
        } catch {
            if var call = activeCall, call.id == localSessionID {
                call.state = .ended
                activeCall = call
            }
        }
    }

    private func loadProfileLive(token: String) async {
        do {
            let response: V1ProfileMeResponse = try await apiClient.requestV1("/profiles/me", token: token)
            profile.username = response.profile.username
            profile.displayName = response.profile.displayName
            profile.bio = response.profile.bio
            profile.visibility = response.profile.isPrivate ? .privateProfile : .publicProfile
            profile.followerCount = response.profile.stats.followers
            profile.followingCount = response.profile.stats.following
            profile.connectionCount = connectedCount
        } catch {
            return
        }
    }

    private func loadConversationsLive(token: String) async {
        do {
            let response: V1ConversationListResponse = try await apiClient.requestV1("/messages/conversations", token: token)
            var updated: [LilithSecureThread] = []
            for item in response.items {
                let localID = threadID(for: item.conversationId)
                let existing = threads.first(where: { $0.id == localID })
                let thread = LilithSecureThread(
                    id: localID,
                    title: item.title,
                    handle: existing?.handle ?? "@\(sanitizeUsername(item.title))",
                    lastMessagePreview: item.lastMessage,
                    lastMessageAt: parseDate(item.lastMessageAt),
                    unreadCount: item.unread,
                    presence: existing?.presence ?? .online,
                    isPinned: existing?.isPinned ?? false,
                    isMuted: existing?.isMuted ?? false,
                    isArchived: existing?.isArchived ?? false,
                    isGroup: existing?.isGroup ?? false,
                    topic: existing?.topic,
                    members: existing?.members ?? [],
                    messages: existing?.messages ?? []
                )
                updated.append(thread)
            }
            threads = updated.sorted(by: { $0.lastMessageAt > $1.lastMessageAt })
            if selectedThreadID == nil {
                selectedThreadID = threads.first?.id
            }
            if let selectedThreadID {
                await loadMessagesIfNeeded(for: selectedThreadID)
            }
        } catch {
            return
        }
    }

    private func loadMessagesIfNeeded(for threadID: UUID) async {
        guard let token = authToken,
              let conversationID = conversationIDByThreadID[threadID] else { return }
        do {
            let detail: V1ConversationDetailResponse = try await apiClient.requestV1("/messages/conversations/\(conversationID)", token: token)
            guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
            threads[index].messages = detail.messages.map { message in
                let messageID = messageIDByServerID[message.id] ?? UUID()
                messageIDByServerID[message.id] = messageID
                return LilithSecureMessage(
                    id: messageID,
                    chatID: threadID,
                    body: message.content,
                    sentAt: parseDate(message.createdAt),
                    direction: message.role == "user" ? .outgoing : .incoming,
                    deliveryStatus: message.role == "user" ? .delivered : .read,
                    attachmentName: nil,
                    attachmentKind: nil,
                    attachmentData: nil,
                    replyToMessageID: nil,
                    reactions: [],
                    isPinned: false,
                    isStarred: false,
                    editedAt: nil
                )
            }
        } catch {
            return
        }
    }

    private func markThreadRead(threadID: UUID) async {
        guard let token = authToken,
              let conversationID = conversationIDByThreadID[threadID] else { return }
        let _: V1SimpleSuccess? = try? await apiClient.requestV1(
            "/messages/conversations/\(conversationID)/read",
            method: "POST",
            body: V1ReadBody(messageIds: []),
            token: token
        )
    }

    private func loadFeedLive(token: String) async {
        do {
            let response: V1FeedHomeResponse = try await apiClient.requestV1("/feed/home", token: token)
            posts = response.items.map(mapPost)
        } catch {
            return
        }
    }

    private func loadNotificationsLive(token: String) async {
        do {
            let response: V1NotificationsResponse = try await apiClient.requestV1("/notifications", token: token)
            notificationsUnreadCount = response.unread
        } catch {
            notificationsUnreadCount = 0
        }
    }

    private func loadCallHistoryLive(token: String) async {
        do {
            let response: V1CallHistoryResponse = try await apiClient.requestV1("/calls/history", token: token)
            callHistory = response.items.map { item in
                LilithCallRecord(
                    id: UUID(),
                    peerName: "Lilith contact",
                    peerHandle: "@user\(item.callerUserId)",
                    type: item.callType == "video" ? .video : .voice,
                    startedAt: parseDate(item.startedAt),
                    durationSeconds: max(1, Int(parseDate(item.endedAt).timeIntervalSince(parseDate(item.startedAt)))),
                    wasMissed: item.status == "missed"
                )
            }
        } catch {
            return
        }
    }

    private func loadMarketplaceSuggestionsLive(token: String) async {
        do {
            let response: V1MarketplaceResponse = try await apiClient.requestV1("/tools/marketplace?section=personalized", token: token)
            chatToolSuggestions = response.items
        } catch {
            chatToolSuggestions = []
        }
    }

    private func mapPost(_ item: V1FeedPostItem) -> LilithSocialPost {
        let id = postID(for: item.id)
        let comments = item.commentsPreview.map {
            LilithSocialComment(
                id: UUID(),
                authorName: "User \($0.authorUserId)",
                authorHandle: "@user\($0.authorUserId)",
                body: $0.body,
                createdAt: parseDate($0.createdAt)
            )
        }
        return LilithSocialPost(
            id: id,
            authorName: item.author.displayName,
            authorHandle: "@\(item.author.username)",
            body: item.body,
            createdAt: parseDate(item.createdAt),
            audience: item.visibility == "public" ? .publicFeed : (item.visibility == "followers" ? .connections : .privateNote),
            likeCount: item.engagement.reactions,
            likedByMe: item.engagement.viewerReacted,
            mediaLabel: item.media.isEmpty ? nil : "Media",
            mediaData: nil,
            tags: [],
            comments: comments
        )
    }

    private func connectRealtime(token: String) {
        if socketToken == token, socketTask != nil { return }
        disconnectRealtime()
        guard let url = apiClient.realtimeWebSocketURL(token: token) else { return }
        shouldReconnectSocket = true
        socketToken = token
        let task = URLSession.shared.webSocketTask(with: url)
        socketTask = task
        task.resume()
        receiveRealtime(task: task)
    }

    private func disconnectRealtime() {
        shouldReconnectSocket = false
        socketReconnectTask?.cancel()
        socketReconnectTask = nil
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        socketToken = nil
    }

    private func receiveRealtime(task: URLSessionWebSocketTask) {
        Task { [weak self] in
            guard let self else { return }
            while self.socketTask === task {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.handleRealtimeFrame(text: text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleRealtimeFrame(text: text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    break
                }
            }
            await self.scheduleRealtimeReconnect()
        }
    }

    private func scheduleRealtimeReconnect() async {
        guard shouldReconnectSocket, let token = authToken else { return }
        socketReconnectTask?.cancel()
        socketReconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                self?.connectRealtime(token: token)
            }
        }
    }

    private func handleRealtimeFrame(text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["event"] as? String else { return }
        let payload = object["payload"] as? [String: Any] ?? [:]

        switch event {
        case "message.new":
            guard let conversationID = payload["conversationId"] as? String,
                  let body = payload["content"] as? String else { return }
            let threadID = threadID(for: conversationID)
            if let index = threads.firstIndex(where: { $0.id == threadID }) {
                let message = LilithSecureMessage(
                    id: UUID(),
                    chatID: threadID,
                    body: body,
                    sentAt: .now,
                    direction: .incoming,
                    deliveryStatus: .read,
                    attachmentName: nil,
                    attachmentKind: nil,
                    attachmentData: nil,
                    replyToMessageID: nil,
                    reactions: [],
                    isPinned: false,
                    isStarred: false,
                    editedAt: nil
                )
                threads[index].messages.append(message)
                threads[index].lastMessagePreview = body
                threads[index].lastMessageAt = .now
                if selectedThreadID != threadID {
                    threads[index].unreadCount += 1
                }
            } else {
                let newThread = LilithSecureThread(
                    id: threadID,
                    title: "Conversation",
                    handle: "@conversation",
                    lastMessagePreview: body,
                    lastMessageAt: .now,
                    unreadCount: 1,
                    presence: .online,
                    isPinned: false,
                    isMuted: false,
                    isArchived: false,
                    isGroup: false,
                    topic: nil,
                    members: [],
                    messages: []
                )
                threads.insert(newThread, at: 0)
            }
        case "message.read":
            guard let conversationID = payload["conversationId"] as? String,
                  let threadID = threadIDByConversationID[conversationID],
                  let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
            for messageIndex in threads[index].messages.indices where threads[index].messages[messageIndex].direction == .outgoing {
                threads[index].messages[messageIndex].deliveryStatus = .read
            }
        case "notification.new":
            notificationsUnreadCount += 1
        case "presence.update":
            guard let userID = payload["userId"] as? Int else { return }
            for index in threads.indices {
                if userIDByHandle[threads[index].handle.lowercased()] == userID {
                    let isOnline = (payload["online"] as? Bool) ?? false
                    threads[index].presence = isOnline ? .online : .offline
                }
            }
        case "call.invite":
            guard let callID = payload["callId"] as? String else { return }
            if let selectedThreadID {
                latestCallIDByThreadID[selectedThreadID] = callID
                if let thread = threads.first(where: { $0.id == selectedThreadID }) {
                    activeCall = LilithCallSession(
                        id: UUID(),
                        chatID: selectedThreadID,
                        title: thread.title,
                        handle: thread.handle,
                        type: (payload["callType"] as? String) == "video" ? .video : .voice,
                        state: .ringing,
                        startedAt: .now,
                        muted: false,
                        speakerOn: false,
                        cameraOn: false
                    )
                    isPresentingCallSheet = true
                }
            }
        default:
            break
        }
    }
}

private struct SecondaryLilithButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LilithTheme.elevated.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LilithTheme.border, lineWidth: 1)
            )
    }
}
