import SwiftUI

struct LeftPanelView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let sampleHistory: [ConversationEntry] = [
        ConversationEntry(title: "Summarize research paper", date: .now.addingTimeInterval(-3600)),
        ConversationEntry(title: "Generate product image",   date: .now.addingTimeInterval(-7200)),
        ConversationEntry(title: "Scan document → text",    date: .now.addingTimeInterval(-86400)),
    ]

    var body: some View {
        ZStack {
            // Panel background
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("History")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.15))

                // Conversation history list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(sampleHistory) { entry in
                            HistoryRowView(entry: entry)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer()

                Divider().background(Color.white.opacity(0.15))

                // Tool shortcuts
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    ForEach(ToolType.allCases) { tool in
                        Button {
                            viewModel.selectTool(tool)
                        } label: {
                            Label(tool.rawValue, systemImage: tool.icon)
                                .font(.subheadline)
                                .foregroundStyle(viewModel.selectedTool == tool ? .blue : .white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedTool == tool
                                        ? Color.blue.opacity(0.15)
                                        : Color.clear
                                )
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 34)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - History Row

private struct HistoryRowView: View {
    let entry: ConversationEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    LeftPanelView()
        .environmentObject(AppViewModel())
        .background(Color.black)
}
