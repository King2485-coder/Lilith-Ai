import SwiftUI

/// Bottom sheet that mirrors the web AgentSelector modal
struct AgentSelectorSheet: View {
    @Binding var selectedMode: AgentMode
    @Binding var selectedAgent: AgentKind
    @Binding var ultraThinking: Bool
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    modesSection
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.horizontal, 16)

                    agentsSection
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.horizontal, 16)

                    ultraThinkingRow
                }
                .padding(.vertical, 8)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
            .navigationTitle("Select Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Modes

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Execution Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ForEach(AgentMode.allCases) { mode in
                modeRow(mode)
            }
        }
    }

    private func modeRow(_ mode: AgentMode) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if mode == .e2 {
                            Text("Pro")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [Color(red:0.9,green:0.7,blue:0.1), Color(red:0.85,green:0.5,blue:0.05)],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(mode.summary)
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                if selectedMode == mode {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                selectedMode == mode
                    ? Color.white.opacity(0.06)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
    }

    // MARK: - Agents

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Specialized Agents")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AgentKind.allCases) { agent in
                    agentCard(agent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func agentCard(_ agent: AgentKind) -> some View {
        Button {
            selectedAgent = agent
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(agentGradient(agent))
                        .frame(width: 40, height: 40)
                    Image(systemName: agent.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(agent.detail)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                selectedAgent == agent
                    ? LilithTheme.accentA.opacity(0.12)
                    : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selectedAgent == agent ? LilithTheme.accentA.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Ultra Thinking

    private var ultraThinkingRow: some View {
        Button {
            ultraThinking.toggle()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: ultraThinking)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Ultra Thinking")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Deep multi-step reasoning")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Toggle("", isOn: $ultraThinking)
                    .labelsHidden()
                    .tint(Color.purple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ultraThinking
                    ? LinearGradient(colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
            )
            .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private func agentGradient(_ agent: AgentKind) -> LinearGradient {
        switch agent {
        case .nova: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .forge: return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sentinel: return LinearGradient(colors: [.green, Color(red:0.2,green:0.8,blue:0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .atlas: return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pulse: return LinearGradient(colors: [Color(red:0.9,green:0.8,blue:0.1), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
