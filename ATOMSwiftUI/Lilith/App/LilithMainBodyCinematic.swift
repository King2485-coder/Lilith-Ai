import SwiftUI

// MARK: - Root

struct LilithMainBodyCinematic: View {
    @Binding var messages: [LilithMessage]
    var onSwipeDown: () -> Void = {}

    @State private var animateRings = false

    var body: some View {
        ZStack {
            CinematicBackground(animate: $animateRings)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                CinematicLeftPanel()
                CinematicCenterCore(messages: $messages)
                CinematicRightPanel()
            }

            VStack {
                Spacer()
                CinematicBottomControls()
                    .padding(.bottom, 40)
            }

            // Swipe-down hint
            VStack {
                Spacer()
                Text("Swipe down")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.bottom, 8)
            }
        }
        .onAppear { animateRings = true }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 80 { onSwipeDown() }
                }
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Background

struct CinematicBackground: View {
    @Binding var animate: Bool

    var body: some View {
        ZStack {
            // Fallback gradient when no image asset exists
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.12), Color.black],
                startPoint: .top, endPoint: .bottom
            )

            // Animated rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.5), Color.orange.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(width: CGFloat(400 + i * 200))
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(
                        .linear(duration: Double(30 + i * 10)).repeatForever(autoreverses: false),
                        value: animate
                    )
                    .blur(radius: 1.5)
            }
        }
    }
}

// MARK: - Left Panel

struct CinematicLeftPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("AI TOOLS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(2)

            CinematicTool(icon: "photo.sparkles",     title: "Image Generation")
            CinematicTool(icon: "text.quote",         title: "Text Summarize")
            CinematicTool(icon: "video.badge.waveform", title: "Video Analyzer")

            Spacer()
        }
        .padding(24)
        .frame(width: 220)
    }
}

struct CinematicTool: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue.opacity(0.9))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        .blur(radius: 2)
                )
        )
    }
}

// MARK: - Center Core

struct CinematicCenterCore: View {
    @Binding var messages: [LilithMessage]
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Live chat feed
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if messages.isEmpty {
                            CinematicBubble(text: "Lilith is ready. What's your mission?", left: true)
                        } else {
                            ForEach(messages) { msg in
                                CinematicBubble(text: msg.text, left: !msg.isUser)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.top, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue.opacity(0.8))

                ZStack(alignment: .leading) {
                    if input.isEmpty {
                        Text("Ask Lilith anything…")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 15, design: .rounded))
                    }
                    TextField("", text: $input)
                        .foregroundColor(.white)
                        .font(.system(size: 15, design: .rounded))
                        .submitLabel(.send)
                        .onSubmit { send() }
                }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(input.isEmpty ? Color.white.opacity(0.25) : Color.white)
                }
                .buttonStyle(.plain)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.blue.opacity(0.45), lineWidth: 1)
                            .blur(radius: 3)
                    )
            )
        }
        .padding(20)
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(LilithMessage(text: trimmed, isUser: true))
        MemoryManager.shared.learn(trimmed)
        LilithBrain.userSent(trimmed)
        input = ""
        LilithBrainV2.shared.process(userText: trimmed) { reply in
            self.messages.append(LilithMessage(text: reply, isUser: false))
            MemoryManager.shared.learn(reply)
            LilithBrain.userSent(reply)
            if let suggestion = MemoryManager.shared.suggestion() {
                self.messages.append(LilithMessage(text: suggestion, isUser: false))
            }
        }
    }
}

struct CinematicBubble: View {
    let text: String
    let left: Bool

    var body: some View {
        HStack {
            if !left { Spacer(minLength: 40) }

            Text(text)
                .font(.system(size: 14, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(left ? 0.5 : 0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(left ? Color.blue.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .foregroundColor(.white)

            if left { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Right Panel

struct CinematicRightPanel: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("LIVE FEEDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            CinematicCard(
                title: "Major Tech Event Tomorrow",
                tag: "TECH",
                tagColor: .blue
            )
            CinematicCard(
                title: "AI Market Surge",
                tag: "MARKETS",
                tagColor: .orange
            )

            Spacer()
        }
        .padding(24)
        .frame(width: 260)
    }
}

struct CinematicCard: View {
    let title: String
    let tag: String
    let tagColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 100)
                LinearGradient(
                    colors: [.clear, tagColor.opacity(0.25)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(tag)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(tagColor)
                    .tracking(1.5)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tagColor.opacity(0.45), lineWidth: 1)
                        .blur(radius: 2)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Bottom Controls

struct CinematicBottomControls: View {
    var body: some View {
        HStack(spacing: 50) {
            CinematicCircle(title: "SCAN", icon: "qrcode.viewfinder", color: .blue)
            CinematicCircle(title: "SEND", icon: "paperplane.fill",   color: .white)
            CinematicCircle(title: "PAY",  icon: "creditcard.fill",   color: .orange)
        }
    }
}

struct CinematicCircle: View {
    let title: String
    let icon: String
    let color: Color
    @State private var isActive = false
    @State private var tilt: CGSize = .zero

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 90, height: 90)

                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .blur(radius: 4)

                Circle()
                    .stroke(color, lineWidth: 1)
                    .frame(width: 90, height: 90)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            .shadow(color: color.opacity(isActive ? 0.6 : 0.15), radius: isActive ? 25 : 5)
            .animation(.easeInOut(duration: 0.3), value: isActive)
            .rotation3DEffect(.degrees(Double(tilt.height)), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(Double(-tilt.width)), axis: (x: 0, y: 1, z: 0))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isActive = true
                        tilt = CGSize(
                            width:  value.location.x / 20,
                            height: value.location.y / 20
                        )
                    }
                    .onEnded { _ in
                        isActive = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            tilt = .zero
                        }
                    }
            )

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .tracking(1.5)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var messages: [LilithMessage] = [
            LilithMessage(text: "Lilith is ready.", isUser: false),
            LilithMessage(text: "Show me the highlights.", isUser: true)
        ]
        var body: some View {
            LilithMainBodyCinematic(messages: $messages)
        }
    }
    return PreviewWrapper()
}
