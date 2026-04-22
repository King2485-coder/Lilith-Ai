import SwiftUI

struct DefaultDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var pulse       = false
    @State private var outerPulse  = false
    @State private var chatInput   = ""
    @State private var messages: [(String, Bool)] = []   // (text, isUser)
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pulsing orb
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 20)
                    .scaleEffect(outerPulse ? 1.15 : 0.85)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: outerPulse
                    )

                // Inner animated ring
                Circle()
                    .stroke(
                        LinearGradient(colors: [.blue, .purple, .blue],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        lineWidth: 2.5
                    )
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: pulse
                    )

                // Core
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.6), Color.black],
                            center: .center,
                            startRadius: 10,
                            endRadius: 52
                        )
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            .frame(width: 120, height: 120)
            .onAppear {
                pulse      = true
                outerPulse = true
            }

            Text("Kimi Agent")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.top, 18)

            Text("Ask me anything, or choose a tool →")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Quick tool chips
            HStack(spacing: 12) {
                ForEach(ToolType.allCases) { tool in
                    Button {
                        viewModel.selectTool(tool)
                    } label: {
                        Label(tool.rawValue, systemImage: tool.icon)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(20)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.bottom, 20)

            // Chat input bar
            HStack(spacing: 12) {
                TextField("Message…", text: $chatInput)
                    .foregroundStyle(.white)
                    .focused($fieldFocused)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(14)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(chatInput.isEmpty ? Color.gray : Color.blue)
                }
                .disabled(chatInput.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func sendMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append((text, true))
        chatInput = ""
        fieldFocused = false
        // Wire to /api/chat endpoint
    }
}

#Preview {
    DefaultDashboardView()
        .environmentObject(AppViewModel())
}
