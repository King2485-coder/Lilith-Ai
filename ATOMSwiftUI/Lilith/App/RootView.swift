import SwiftUI

enum AppRoute {
    case auth
    case onboarding
    case main
}

private enum OnboardingAccountType: String, CaseIterable, Identifiable {
    case me = "For me"
    case child = "For my child"

    var id: String { rawValue }
}

private enum OnboardingPersona: String, CaseIterable, Identifiable {
    case adult = "Adult"
    case teen = "Teen"
    case childGuardian = "Child + Guardian"

    var id: String { rawValue }
}

private struct LilithOnboardingDraft {
    var accountType: OnboardingAccountType = .me
    var persona: OnboardingPersona = .adult
    var interests: Set<String> = []
    var goals: Set<String> = []
    var username: String = ""
    var blockedTopics: Set<String> = []
    var communicationApprovedOnly = false
    var discoveryRestricted = false
    var toolsRestricted = false
    var timeLimitHours = 3
    var safetyMode = "balanced"
    var childPreferences: Set<String> = []
}

private enum OnboardingScreen {
    static let setup = 6
    static let completion = 7
}

private struct OnboardingPersistencePayload: Codable {
    var mode: String
    var interests: [String]
    var goals: [String]
    var username: String
    var blockedTopics: [String]
    var communicationApprovedOnly: Bool
    var discoveryRestricted: Bool
    var toolsRestricted: Bool
    var timeLimitHours: Int
    var safetyMode: String
    var childPreferences: [String]
}

private enum OnboardingPersistence {
    private static let base = "lilith.onboarding"

    static func isComplete(userID: String) -> Bool {
        UserDefaults.standard.bool(forKey: "\(base).completed.\(userID)")
    }

    static func save(draft: LilithOnboardingDraft, userID: String) {
        let payload = OnboardingPersistencePayload(
            mode: draft.persona.rawValue.lowercased(),
            interests: Array(draft.interests).sorted(),
            goals: Array(draft.goals).sorted(),
            username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            blockedTopics: Array(draft.blockedTopics).sorted(),
            communicationApprovedOnly: draft.communicationApprovedOnly,
            discoveryRestricted: draft.discoveryRestricted,
            toolsRestricted: draft.toolsRestricted,
            timeLimitHours: draft.timeLimitHours,
            safetyMode: draft.safetyMode,
            childPreferences: Array(draft.childPreferences).sorted()
        )
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "\(base).completed.\(userID)")
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: "\(base).payload.\(userID)")
        }
        defaults.set(payload.username, forKey: "\(base).username.\(userID)")
        defaults.set(payload.mode, forKey: "\(base).mode.\(userID)")
        defaults.set(payload.interests.joined(separator: ","), forKey: "\(base).interests.\(userID)")
        defaults.set(payload.goals.joined(separator: ","), forKey: "\(base).goals.\(userID)")
        defaults.set(payload.blockedTopics.joined(separator: ","), forKey: "\(base).blocked.\(userID)")
        defaults.set(payload.communicationApprovedOnly, forKey: "\(base).commApprovedOnly.\(userID)")
        defaults.set(payload.discoveryRestricted, forKey: "\(base).discoveryRestricted.\(userID)")
        defaults.set(payload.toolsRestricted, forKey: "\(base).toolsRestricted.\(userID)")
        defaults.set(payload.timeLimitHours, forKey: "\(base).timeLimitHours.\(userID)")
        defaults.set(payload.safetyMode, forKey: "\(base).safetyMode.\(userID)")
        defaults.set(payload.childPreferences.joined(separator: ","), forKey: "\(base).childPreferences.\(userID)")
    }
}

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var route: AppRoute = .auth
    @State private var showBottomPanel = false

    var body: some View {
        ZStack {
            switch route {
            case .auth:
                LandingView()
                    .transition(.opacity)
            case .onboarding:
                LilithOnboardingView(
                    displayName: authStore.user?.name ?? "there",
                    onComplete: { draft in
                        guard let userID = authStore.user?.id else { return }
                        OnboardingPersistence.save(draft: draft, userID: userID)
                        authStore.applyOnboardingProfile(username: draft.username, interests: Array(draft.interests), mode: draft.persona.rawValue)
                        applyToolFavorites(for: draft)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            route = .main
                            showBottomPanel = true
                        }
                    }
                )
                .transition(.opacity)
            case .main:
                WorkspaceShellView()
                    .transition(.opacity)
            }

            if route == .main && showBottomPanel {
                Color.clear
                    .transition(.move(edge: .bottom))
            }
        }
        .background(LilithTheme.background.ignoresSafeArea())
        .onAppear {
            updateRoute()
            Task { await authStore.restoreSessionIfNeeded(); updateRoute() }
        }
        .onChange(of: authStore.isAuthenticated) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                updateRoute()
                showBottomPanel = (route == .main)
            }
        }
        .onChange(of: authStore.user?.id) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                updateRoute()
                showBottomPanel = (route == .main)
            }
        }
    }

    private func updateRoute() {
        guard authStore.isAuthenticated, let userID = authStore.user?.id else {
            route = .auth
            return
        }
        route = OnboardingPersistence.isComplete(userID: userID) ? .main : .onboarding
    }

    private func applyToolFavorites(for draft: LilithOnboardingDraft) {
        var favorites = ["assistant_chat", "social_feed", "messages_secure"]
        if draft.goals.contains("Manage money") {
            favorites.append("wealth_wizard")
        }
        if draft.goals.contains("Create content") {
            favorites.append(contentsOf: ["video_editor", "image_generation"])
        }
        if draft.goals.contains("School support") {
            favorites.append(contentsOf: ["prompt_from_link", "prompt_from_screenshot"])
        }
        if draft.toolsRestricted {
            favorites = favorites.filter { $0 != "code_workspace" && $0 != "clone" }
        }
        let unique = Array(Set(favorites)).sorted()
        UserDefaults.standard.set(unique.joined(separator: ","), forKey: "lilith.tools.favorites")
    }
}

private struct LilithOnboardingView: View {
    let displayName: String
    var onComplete: (LilithOnboardingDraft) -> Void

    @State private var screen: Int = 0
    @State private var draft = LilithOnboardingDraft()
    @State private var setupProgress: Double = 0.0

    private let interestOptions = ["Music", "Gaming", "Sports", "Science", "Design", "Finance", "Coding", "Wellness"]
    private let goalOptions = ["Create content", "Learn faster", "Manage money", "Stay organized", "School support", "Build projects"]
    private let blockedTopicOptions = ["Adult content", "Gambling", "Violence", "Scams", "Explicit language"]
    private let childPreferenceOptions = ["Drawing", "Math games", "Stories", "Nature", "Robotics", "Language"]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    progressBar
                    screenBody(proxy: proxy)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.25), value: screen)
        }
        .onChange(of: screen) { _, newValue in
            if newValue == OnboardingScreen.setup {
                startSetupFlowIfNeeded()
            }
        }
    }

    private var setupScreenIndex: Int {
        OnboardingScreen.setup
    }

    private var completionScreenIndex: Int {
        OnboardingScreen.completion
    }

    private var stepCount: Int {
        draft.persona == .childGuardian ? 7 : 8
    }

    private var normalizedProgress: Double {
        min(max(Double(screen + 1) / Double(stepCount), 0.05), 1.0)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Onboarding")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            ProgressView(value: normalizedProgress)
                .tint(LilithTheme.accentA)
        }
    }

    @ViewBuilder
    private func screenBody(proxy: GeometryProxy) -> some View {
        switch screen {
        case 0:
            welcomeCard
        case 1:
            accountTypeCard
        case 2:
            personaCard
        case 3:
            interestsCard
        case 4:
            if draft.persona == .childGuardian {
                guardianControlsCard
            } else {
                goalsCard
            }
        case 5:
            if draft.persona == .childGuardian {
                childPreferencesCard
            } else {
                usernameCard
            }
        case 6:
            if draft.persona == .childGuardian {
                setupCard
            } else {
                setupCard
            }
        default:
            completionCard
        }
    }

    private var welcomeCard: some View {
        onboardingCard(
            title: "Welcome to Lilith",
            subtitle: "Fast setup. Personalized feed, inbox, tools, and safety in under a minute."
        ) {
            Button("Get started") {
                screen = 1
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var accountTypeCard: some View {
        onboardingCard(
            title: "Who is this for?",
            subtitle: "Choose your onboarding path."
        ) {
            HStack(spacing: 12) {
                selectionCard(
                    title: "Me",
                    subtitle: "Adult or teen setup",
                    selected: draft.accountType == .me
                ) {
                    draft.accountType = .me
                    screen = 2
                }
                selectionCard(
                    title: "My Child",
                    subtitle: "Guardian + child setup",
                    selected: draft.accountType == .child
                ) {
                    draft.accountType = .child
                    draft.persona = .childGuardian
                    screen = 3
                }
            }
        }
    }

    private var personaCard: some View {
        onboardingCard(
            title: "Select profile type",
            subtitle: "Lilith will auto-apply the right defaults."
        ) {
            HStack(spacing: 12) {
                selectionCard(title: "Adult", subtitle: "Open defaults", selected: draft.persona == .adult) {
                    draft.persona = .adult
                    screen = 3
                }
                selectionCard(title: "Teen", subtitle: "Safer defaults", selected: draft.persona == .teen) {
                    draft.persona = .teen
                    draft.communicationApprovedOnly = true
                    draft.discoveryRestricted = true
                    draft.toolsRestricted = true
                    draft.safetyMode = "strict"
                    screen = 3
                }
            }
        }
    }

    private var interestsCard: some View {
        onboardingCard(
            title: "Pick interests",
            subtitle: "Tap what matters. We’ll tune feed and recommendations."
        ) {
            chipGrid(options: interestOptions, selection: $draft.interests)
            Button("Continue") {
                screen = 4
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var goalsCard: some View {
        onboardingCard(
            title: "Choose goals",
            subtitle: "This sets your tools and startup shortcuts."
        ) {
            chipGrid(options: goalOptions, selection: $draft.goals)
            Button("Continue") {
                screen = 5
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var usernameCard: some View {
        onboardingCard(
            title: "Choose your username",
            subtitle: "This is your Lilith ID for messaging and discovery."
        ) {
            TextField("username", text: $draft.username)
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Auto setup") {
                if draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft.username = sanitized(displayName)
                }
                screen = 6
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var guardianControlsCard: some View {
        onboardingCard(
            title: "Guardian controls",
            subtitle: "Set safety first. Keep it simple."
        ) {
            Text("Blocked topics")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            chipGrid(options: blockedTopicOptions, selection: $draft.blockedTopics)

            Toggle("Approved contacts only", isOn: $draft.communicationApprovedOnly)
                .tint(LilithTheme.accentA)
                .foregroundStyle(.white)
            Toggle("Restrict advanced tools", isOn: $draft.toolsRestricted)
                .tint(LilithTheme.accentA)
                .foregroundStyle(.white)
            Toggle("Restricted discovery", isOn: $draft.discoveryRestricted)
                .tint(LilithTheme.accentA)
                .foregroundStyle(.white)

            Stepper("Daily time limit: \(draft.timeLimitHours) hours", value: $draft.timeLimitHours, in: 1...8)
                .foregroundStyle(.white)

            Picker("Safety mode", selection: $draft.safetyMode) {
                Text("Balanced").tag("balanced")
                Text("Strict").tag("strict")
                Text("Relaxed").tag("relaxed")
            }
            .pickerStyle(.segmented)

            Button("Continue") {
                screen = 5
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var childPreferencesCard: some View {
        onboardingCard(
            title: "Child preferences",
            subtitle: "Child picks only from approved interests."
        ) {
            chipGrid(options: childPreferenceOptions, selection: $draft.childPreferences)
            Button("Auto setup") {
                if draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft.username = "family_" + String(Int.random(in: 100...999))
                }
                screen = 6
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var setupCard: some View {
        onboardingCard(
            title: "Setting up Lilith",
            subtitle: "Personalizing feed, inbox, tools, and safety."
        ) {
            ProgressView(value: setupProgress)
                .tint(LilithTheme.accentA)
            Text("Applying profile settings...")
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)

            Button("Continue") {
                screen = completionScreenIndex
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .onAppear {
            startSetupFlowIfNeeded()
        }
    }

    private var completionCard: some View {
        onboardingCard(
            title: "All set",
            subtitle: "Lilith is ready with personalized feed, relevant inbox, configured tools, and safety defaults."
        ) {
            Button("Enter Lilith") {
                if draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft.username = sanitized(displayName)
                }
                onComplete(draft)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func onboardingCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(LilithTheme.textSecondary)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selectionCard(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? LilithTheme.accentA.opacity(0.2) : LilithTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selected ? LilithTheme.accentA : LilithTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func chipGrid(options: [String], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = chunked(options, size: 3)
            ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                let row = entry.element
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        let selected = selection.wrappedValue.contains(option)
                        Button {
                            if selected {
                                selection.wrappedValue.remove(option)
                            } else {
                                selection.wrappedValue.insert(option)
                            }
                        } label: {
                            Text(option)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selected ? Color.black : Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(selected ? LilithTheme.accentB : LilithTheme.elevated, in: Capsule())
                        }
                        .buttonStyle(.plain)
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

    private func sanitized(_ value: String) -> String {
        let cleaned = value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        return cleaned.isEmpty ? "lilith_user" : cleaned
    }

    private func startSetupFlowIfNeeded() {
        guard screen == OnboardingScreen.setup, setupProgress < 1.0 else { return }

        setupProgress = 0.18

        Task {
            for step in stride(from: 0.22, through: 1.0, by: 0.18) {
                try? await Task.sleep(for: .milliseconds(180))
                await MainActor.run {
                    guard screen == OnboardingScreen.setup else { return }
                    setupProgress = min(1.0, step)
                }
            }

            await MainActor.run {
                guard screen == OnboardingScreen.setup else { return }
                setupProgress = 1.0
                screen = OnboardingScreen.completion
            }
        }
    }
}
