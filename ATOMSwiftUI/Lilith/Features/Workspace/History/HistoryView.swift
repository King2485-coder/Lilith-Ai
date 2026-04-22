import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = HistoryViewModel()

    /// Callback: user tapped a conversation → load it in chat and switch tab
    var onSelectConversation: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView()
                        .tint(LilithTheme.accentA)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.load(token: token)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                guard let token = authStore.token else { return }
                await viewModel.load(token: token)
            }
            .refreshable {
                guard let token = authStore.token else { return }
                await viewModel.load(token: token)
            }
        }
    }

    // MARK: - List

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conv in
                Button {
                    onSelectConversation(conv.id)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LilithTheme.accentA.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "message.fill")
                                .foregroundStyle(LilithTheme.accentA)
                                .font(.system(size: 16))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(conv.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                if let count = conv.messageCount {
                                    Text("\(count) messages")
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                                if let date = conv.updatedAt {
                                    Text("·")
                                        .foregroundStyle(LilithTheme.textSecondary)
                                        .font(.caption)
                                    Text(date.prefix(10))
                                        .font(.caption)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LilithTheme.surface)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.delete(id: conv.id, token: token)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52))
                .foregroundStyle(.gray.opacity(0.35))
            Text("No History")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Your past conversations will appear here.")
                .font(.subheadline)
                .foregroundStyle(LilithTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
