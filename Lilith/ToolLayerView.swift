import SwiftUI

// MARK: - Tool Layer View

struct ToolLayerView: View {
    var onSelectDestination: (WorkspaceDestination) -> Void
    var onInjectPrompt: (String) -> Void

    @StateObject private var viewModel = ToolLayerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Search
                        searchBar

                        // Pinned
                        if !viewModel.pinnedEntries.isEmpty {
                            sectionHeader("Pinned")
                            toolScroll(entries: viewModel.pinnedEntries)
                        }

                        // Recent
                        if !viewModel.recentEntries.isEmpty {
                            sectionHeader("Recently Used")
                            toolScroll(entries: Array(viewModel.recentEntries))
                        }

                        // Categories
                        ForEach(Array(viewModel.entriesByCategory.enumerated()), id: \.offset) { _, pair in
                            let category = pair.0
                            let entries = pair.1
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(category.title, icon: category.icon)
                                toolScroll(entries: entries)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color(white: 0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.4))

            TextField("Search tools or intent…", text: $viewModel.searchQuery)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(white: 0.9))
                .tint(Color(white: 0.5))

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.4), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tool Scroll

    private func toolScroll(entries: [ToolEntry]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(entries) { entry in
                    ToolCard(
                        entry: entry,
                        onTogglePin: { viewModel.togglePin(for: entry) },
                        onSetMode: { mode in viewModel.setMode(mode, for: entry) },
                        onTap: {
                            viewModel.recordUse(for: entry)
                            handleTap(entry: entry)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func handleTap(entry: ToolEntry) {
        switch entry.mode {
        case .selfGuided:
            dismiss()
            onSelectDestination(entry.destination)
        case .lilithAssisted:
            let prompt = "Open \(entry.title) to help me with "
            dismiss()
            onInjectPrompt(prompt)
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let entry: ToolEntry
    let onTogglePin: () -> Void
    let onSetMode: (ToolAccessMode) -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: entry.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(white: 0.1))
                    )

                Spacer()

                Button(action: onTogglePin) {
                    Image(systemName: entry.isPinned ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(entry.isPinned ? Color.yellow.opacity(0.8) : Color(white: 0.3))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(1)
            }

            // Mode selector
            HStack(spacing: 0) {
                ForEach(ToolAccessMode.allCases) { mode in
                    Button(action: { onSetMode(mode) }) {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(entry.mode == mode ? Color.black : Color(white: 0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                entry.mode == mode
                                ? Color(white: 0.85)
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(white: 0.14).opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .padding(12)
        .frame(width: 170, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.4), lineWidth: 0.5)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onTap()
        }
    }
}
