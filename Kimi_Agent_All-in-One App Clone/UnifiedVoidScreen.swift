import SwiftUI

struct UnifiedVoidScreen: View {
    @ObservedObject var appState: LilithUnifiedAppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.02, blue: 0.03),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 260
            )
            .blur(radius: 20)

            VStack(spacing: 0) {
                HStack {
                    Text("THE VOID")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.conversation) { msg in
                            HStack {
                                if msg.isUser { Spacer() }

                                Text(msg.text)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.94))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: 300, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 22)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )

                                if !msg.isUser { Spacer() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .frame(width: 46, height: 46)
                        .overlay(Image(systemName: "waveform").foregroundStyle(.white.opacity(0.9)))

                    HStack {
                        TextField("Talk to Lilith naturally...", text: $appState.voidInput)
                            .foregroundStyle(.white)
                            .submitLabel(.send)
                            .onSubmit { sendMessage() }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    Button(action: sendMessage) {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .foregroundStyle(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                UnifiedBottomNav(selected: .void)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private func sendMessage() {
        let trimmed = appState.voidInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.conversation.append(UnifiedLilithMessage(text: trimmed, isUser: true))
        appState.conversation.append(UnifiedLilithMessage(text: "Understood. I'll keep that in context.", isUser: false))
        appState.voidInput = ""
    }
}
