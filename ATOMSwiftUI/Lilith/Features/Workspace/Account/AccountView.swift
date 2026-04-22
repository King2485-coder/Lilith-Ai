import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = AccountViewModel()

    @Binding var selectedAgent: AgentKind
    @Binding var selectedMode: AgentMode
    @Binding var ultraThinking: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    creditsCard
                    preferencesCard
                    if authStore.user?.isSuperAdmin == true {
                        adminCard
                    }
                    logoutCard
                }
                .padding(16)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Account")
            .task {
                guard let token = authStore.token, let user = authStore.user else { return }
                await viewModel.load(token: token, isSuperAdmin: user.isSuperAdmin)
            }
            .refreshable {
                guard let token = authStore.token, let user = authStore.user else { return }
                await viewModel.load(token: token, isSuperAdmin: user.isSuperAdmin)
            }
        }
    }

    private var profileCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(authStore.user?.name ?? "User")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(authStore.user?.email ?? "")
                    .foregroundStyle(LilithTheme.textSecondary)
                Text(authStore.user?.isSuperAdmin == true ? "Super Admin" : (authStore.user?.role.capitalized ?? "Member"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(authStore.user?.isSuperAdmin == true ? LilithTheme.accentC : LilithTheme.accentA)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var creditsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Credits + Subscription")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let creditsSummary = viewModel.creditsSummary {
                    Text(creditsSummary.unlimited ? "Unlimited credits" : String(format: "%.2f credits", creditsSummary.credits ?? 0))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                if let subscription = viewModel.subscription {
                    Text("Plan: \(subscription.subscription.plan.capitalized)")
                        .foregroundStyle(LilithTheme.textSecondary)
                    Text("Status: \(subscription.subscription.status.capitalized)")
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Workspace Preferences")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack {
                    Label(selectedAgent.title, systemImage: selectedAgent.symbol)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(selectedMode.title)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                Toggle("Ultra Thinking", isOn: $ultraThinking)
                    .tint(LilithTheme.accentB)
                    .foregroundStyle(.white)
            }
        }
    }

    private var adminCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Admin Snapshot")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let stats = viewModel.adminStats {
                    Text("Users: \(stats.users.total) total, \(stats.users.active) active")
                        .foregroundStyle(LilithTheme.textSecondary)
                    Text("Projects: \(stats.content.projects), Conversations: \(stats.content.conversations)")
                        .foregroundStyle(LilithTheme.textSecondary)
                    Text("Media: \(stats.content.videos) videos, \(stats.content.images) images")
                        .foregroundStyle(LilithTheme.textSecondary)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var logoutCard: some View {
        GlassCard {
            Button(role: .destructive) {
                authStore.logout()
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
