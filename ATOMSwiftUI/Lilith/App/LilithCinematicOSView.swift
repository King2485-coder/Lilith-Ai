import SwiftUI

struct LilithCinematicOSView: View {
    @EnvironmentObject private var speech: LilithSpeechManager
    @EnvironmentObject private var state: LilithStateManager

    @State private var showingMainBody = false
    @State private var dragOffset: CGFloat = 0

    @State private var prompt = ""
    @State private var panels: [VoidPanel] = []

    @State private var interactionLog: [String] = [
        "Lilith online. Intent engine active.",
        "Natural language channel ready."
    ]

    @State private var selectedTool = "Image generation"

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                voidScreen(size: proxy.size)
                    .offset(y: showingMainBody ? -proxy.size.height + dragOffset : dragOffset)

                mainBodyScreen(size: proxy.size)
                    .offset(y: showingMainBody ? dragOffset : proxy.size.height + dragOffset)
            }
            .contentShape(Rectangle())
            .gesture(verticalNavigationGesture(height: proxy.size.height))
            .ignoresSafeArea()
            .task {
                await speech.requestPermissions()
            }
            .onChange(of: speech.transcript) { _, newValue in
                if speech.isListening { return }
                let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    prompt = cleaned
                    submitPrompt(cleaned)
                }
            }
        }
    }

    private func voidScreen(size: CGSize) -> some View {
        ZStack {
            ObsidianFluidBackground()

            ForEach(panels) { panel in
                VoidFloatingPanel(panel: panel)
                    .frame(maxWidth: min(290, size.width - 46))
                    .position(x: panel.position.x * size.width, y: panel.position.y * size.height)
            }

            VStack {
                Spacer()
                VoidInputDock(
                    text: $prompt,
                    isListening: speech.isListening,
                    onSend: {
                        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return }
                        submitPrompt(cleaned)
                    },
                    onVoice: {
                        if speech.isListening {
                            speech.stopListening()
                        } else {
                            speech.startListening()
                            state.set(.listening)
                        }
                    }
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
            }

            VStack {
                Spacer()
                Text("Swipe up")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.26))
                    .padding(.bottom, 12)
            }
        }
    }

    private func mainBodyScreen(size: CGSize) -> some View {
        ZStack {
            MainBodyHUDBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 28)

                HStack(alignment: .top, spacing: 14) {
                    MainBodyToolRail(selectedTool: $selectedTool)
                        .frame(width: max(118, size.width * 0.21))

                    MainBodyChatCore(log: interactionLog)
                        .frame(maxWidth: .infinity)

                    MainBodyInfoRail()
                        .frame(width: max(118, size.width * 0.21))
                }
                .padding(.horizontal, 14)

                Spacer(minLength: 14)

                ZStack(alignment: .bottomTrailing) {
                    MainBodyActionCluster()
                        .frame(maxWidth: .infinity)

                    MainBodyToolsGrid()
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 26)
            }

            VStack {
                Spacer()
                Text("Swipe down")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .padding(.bottom, 8)
            }
        }
    }

    private func verticalNavigationGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .global)
            .onChanged { value in
                let translation = value.translation.height
                if showingMainBody {
                    dragOffset = max(translation, -36)
                } else {
                    dragOffset = min(translation, 36)
                }
            }
            .onEnded { value in
                let threshold = height * 0.14
                let translation = value.translation.height
                let projected = value.predictedEndTranslation.height

                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    if !showingMainBody && (translation < -threshold || projected < -threshold * 1.6) {
                        showingMainBody = true
                    } else if showingMainBody && (translation > threshold || projected > threshold * 1.6) {
                        showingMainBody = false
                    }
                    dragOffset = 0
                }
            }
    }

    private func submitPrompt(_ input: String) {
        prompt = ""
        state.set(.thinking)

        let userPanel = VoidPanel(
            title: "You",
            content: input,
            kind: .text,
            position: randomPanelPosition()
        )

        let response = synthesizeResponse(for: input)
        let lilithPanel = VoidPanel(
            title: "Lilith",
            content: response,
            kind: .suggestion,
            position: randomPanelPosition()
        )

        withAnimation(.easeInOut(duration: 0.35)) {
            panels.append(userPanel)
            panels.append(lilithPanel)
            interactionLog.append("You: \(input)")
            interactionLog.append("Lilith: \(response)")
            if interactionLog.count > 16 {
                interactionLog.removeFirst(interactionLog.count - 16)
            }
        }

        state.set(.responding)
        speech.speak(response)
        state.set(.idle)
    }

    private func randomPanelPosition() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 0.20 ... 0.80),
            y: CGFloat.random(in: 0.18 ... 0.62)
        )
    }

    private func synthesizeResponse(for input: String) -> String {
        let lower = input.lowercased()
        if lower.contains("remind") {
            return "Reminder understood. I will stage it for later with context and timing options."
        }
        if lower.contains("eat") || lower.contains("food") {
            return "You need something easy and steady tonight: protein, warm carbs, and hydration. I can generate 3 fast options."
        }
        if lower.contains("meeting") {
            return "Tomorrow morning meeting detected. I can prepare a pre-brief, agenda bullets, and a 10-minute prep timer."
        }
        return "Intent captured. I can now map this into planning, media, messaging, finance, or tool workflows."
    }
}

private struct ObsidianFluidBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            Canvas { context, size in
                phase += 0.003

                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(Color.black))

                let silver1 = Color(red: 0.22, green: 0.22, blue: 0.24).opacity(0.34)
                let silver2 = Color(red: 0.43, green: 0.43, blue: 0.46).opacity(0.16)
                let silver3 = Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.54)

                for idx in 0 ..< 4 {
                    var blob = Path()
                    let w = size.width * (0.82 + CGFloat(idx) * 0.08)
                    let h = size.height * (0.56 + CGFloat(idx) * 0.09)
                    let x = (size.width - w) * 0.5 + sin(phase * 4 + CGFloat(idx)) * 28
                    let y = (size.height - h) * 0.5 + cos(phase * 5 + CGFloat(idx) * 0.7) * 22
                    blob.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))

                    let shade: Color = idx % 3 == 0 ? silver1 : (idx % 3 == 1 ? silver2 : silver3)
                    context.fill(blob, with: .color(shade), style: FillStyle(eoFill: false, antialiased: true))
                }
            }
            .blur(radius: 36)
        }
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear, Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct VoidInputDock: View {
    @Binding var text: String
    var isListening: Bool
    var onSend: () -> Void
    var onVoice: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask Lilith anything...", text: $text)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .foregroundStyle(Color.white.opacity(0.92))
                .font(.system(size: 16, weight: .medium, design: .rounded))

            Button(action: onVoice) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isListening ? Color(red: 0.70, green: 0.72, blue: 0.78) : Color.white.opacity(0.86))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(0.08), radius: 16, y: 2)
        )
    }
}

private enum VoidPanelKind {
    case text
    case image
    case video
    case tool
    case suggestion
}

private struct VoidPanel: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let kind: VoidPanelKind
    let position: CGPoint
}

private struct VoidFloatingPanel: View {
    let panel: VoidPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(panel.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(panel.content)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(0.06), radius: 14, y: 1)
        )
    }
}

private struct MainBodyHUDBackground: View {
    var body: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.03, green: 0.03, blue: 0.04),
                    Color(red: 0.08, green: 0.04, blue: 0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.16, green: 0.48, blue: 0.88).opacity(0.16), lineWidth: 1)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.93, green: 0.45, blue: 0.13).opacity(0.12), lineWidth: 1)
                .padding(6)
        }
        .ignoresSafeArea()
    }
}

private struct MainBodyToolRail: View {
    @Binding var selectedTool: String
    private let tools = ["Image generation", "Text summarize", "Video analyzer"]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(tools, id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Text(tool)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke((selectedTool == tool ? Color(red: 0.15, green: 0.52, blue: 0.95) : Color.white.opacity(0.09)), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

private struct MainBodyChatCore: View {
    let log: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LILITH MAIN BODY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.16, green: 0.52, blue: 0.95).opacity(0.95))

            Text("Chat / interaction panel")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.16, green: 0.52, blue: 0.95).opacity(0.44), lineWidth: 1)
                )
        )
    }
}

private struct MainBodyInfoRail: View {
    var body: some View {
        VStack(spacing: 10) {
            railCard(title: "News", body: "Neon lane synced. 3 highlights ready.")
            railCard(title: "Events", body: "2 events detected for your timeline.")
            railCard(title: "Content", body: "Preview render prepared and staged.")
            Spacer()
        }
    }

    private func railCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.18))
            Text(body)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.95, green: 0.52, blue: 0.18).opacity(0.34), lineWidth: 1)
                )
        )
    }
}

private struct MainBodyActionCluster: View {
    var body: some View {
        HStack(spacing: 26) {
            actionCircle(label: "SCAN", color: Color(red: 0.15, green: 0.52, blue: 0.95), diameter: 68)
            actionCircle(label: "SEND", color: Color(red: 0.95, green: 0.52, blue: 0.18), diameter: 96)
            actionCircle(label: "PAY", color: Color(red: 0.15, green: 0.52, blue: 0.95), diameter: 68)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionCircle(label: String, color: Color, diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.56))
                .overlay(Circle().stroke(color.opacity(0.64), lineWidth: 1.2))
                .shadow(color: color.opacity(0.36), radius: 14, y: 0)
            Text(label)
                .font(.system(size: diameter > 80 ? 18 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct MainBodyToolsGrid: View {
    private let symbols = [
        "wand.and.stars", "camera.viewfinder", "qrcode.viewfinder", "waveform",
        "creditcard", "photo", "video", "globe"
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0 ..< 2) { row in
                HStack(spacing: 8) {
                    ForEach(0 ..< 4) { col in
                        let index = row * 4 + col
                        Image(systemName: symbols[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.46))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.13), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.50))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
