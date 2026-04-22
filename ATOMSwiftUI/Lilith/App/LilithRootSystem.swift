import SwiftUI

// MARK: - Shared Model

struct LilithMessage: Identifiable {
    let id   = UUID()
    let text : String
    let isUser: Bool
}

// MARK: - Memory Manager

struct LilithMemory: Codable {
    var favoriteFoods: [String] = []
    var reminders: [String] = []
}

final class MemoryManager {
    static let shared = MemoryManager()
    private let key = "lilith_memory"
    private(set) var memory = LilithMemory()

    init() { load() }

    func learn(_ text: String) {
        let t = text.lowercased()
        if t.contains("i like")    { memory.favoriteFoods.append(text) }
        if t.contains("remind me") { memory.reminders.append(text) }
        save()
    }

    func suggestion() -> String? {
        if let last = memory.favoriteFoods.last { return "You mentioned \"\(last)\". Want that again tonight?" }
        if let rem  = memory.reminders.last     { return "Reminder: \(rem)" }
        return nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(memory) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let m = try? JSONDecoder().decode(LilithMemory.self, from: data) {
            memory = m
        }
    }
}

// MARK: - AI Service

final class LilithAI {
    static let shared = LilithAI()

    private struct AIRes: Decodable { let reply: String }

    /// Sends `text` to the local FastAPI backend.
    /// Falls back to `fallback(text)` if the server is unreachable.
    func send(_ text: String,
              fallback: @escaping (String) -> String = LilithAI.offlineReply,
              completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:8000/api/chat") else { return }

        var req = URLRequest(url: url, timeoutInterval: 6)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["message": text])

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                if let data, error == nil,
                   let res = try? JSONDecoder().decode(AIRes.self, from: data) {
                    completion(res.reply)
                } else {
                    completion(fallback(text))
                }
            }
        }.resume()
    }

    static func offlineReply(_ input: String) -> String {
        let lower = input.lowercased()
        if lower.contains("remind")                 { return "Reminder staged with context and timing options." }
        if lower.contains("food") || lower.contains("eat") { return "Protein, warm carbs, hydration — 3 fast options ready." }
        if lower.contains("meeting")                { return "Pre-brief, agenda bullets, and 10-minute prep timer ready." }
        if lower.contains("scan")                   { return "Scanner ready. Point at any code, text, or surface." }
        if lower.contains("pay")                    { return "Payment interface loaded. Confirm recipient and amount." }
        return "Intent captured. I can map this into planning, media, messaging, finance, or tool workflows."
    }
}

// MARK: - Root Orchestrator

struct LilithRootSystem: View {

    @State private var currentScreen: AppScreen = .void
    @State private var messages: [LilithMessage] = []

    enum AppScreen { case void, main }

    var body: some View {
        ZStack {
            // Void
            LilithVoidScreen(
                messages: $messages,
                onSwipeUp: {
                    withAnimation(.easeInOut(duration: 0.5)) { currentScreen = .main }
                }
            )
            .opacity(currentScreen == .void ? 1 : 0)
            .allowsHitTesting(currentScreen == .void)

            // Main Body
            LilithMainBodyCinematic(
                messages: $messages,
                onSwipeDown: {
                    withAnimation(.easeInOut(duration: 0.5)) { currentScreen = .void }
                }
            )
            .offset(y: currentScreen == .main ? 0 : UIScreen.main.bounds.height)
            .allowsHitTesting(currentScreen == .main)

            // Approval overlay — floats above both screens
            LilithApprovalOverlay()
                .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            LilithBrain.appOpened()
            LilithAutonomousGPT.shared.start()
            LilithRealtimeEngine.shared.start()
            LilithContextEngine.shared.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lilithAction)) { note in
            if let text = note.object as? String {
                withAnimation {
                    messages.append(LilithMessage(text: text, isUser: false))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lilithRealtimeUpdate)) { note in
            if let text = note.object as? String {
                withAnimation {
                    messages.append(LilithMessage(text: text, isUser: false))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lilithContextUpdate)) { note in
            if let text = note.object as? String {
                withAnimation {
                    messages.append(LilithMessage(text: text, isUser: false))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lilithWorkflowEvent)) { note in
            if let text = note.object as? String {
                withAnimation {
                    messages.append(LilithMessage(text: text, isUser: false))
                }
            }
        }
    }
}

// MARK: - Void Screen

struct LilithVoidScreen: View {

    @Binding var messages: [LilithMessage]
    var onSwipeUp: () -> Void

    @State private var input: String = ""

    var body: some View {
        ZStack {
            VoidBackgroundLayer()
                .ignoresSafeArea()

            // Floating message panels — fixed positions, show last 4
            GeometryReader { geo in
                let recent = Array(messages.suffix(4))

                // Slot anchor points (proportional to screen)
                let slots: [(CGFloat, CGFloat)] = [
                    (0.52, 0.28),   // top-centre-right
                    (0.30, 0.43),   // mid-left
                    (0.65, 0.52),   // mid-right
                    (0.38, 0.20),   // upper-left
                ]

                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, message in
                    let (fx, fy) = idx < slots.count ? slots[idx] : (0.5, 0.4)
                    VoidMessagePanel(text: message.text, isUser: message.isUser)
                        .frame(width: min(260, geo.size.width - 48))
                        .position(x: geo.size.width * fx, y: geo.size.height * fy)
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        .animation(.easeOut(duration: 0.4), value: messages.count)
                }
            }

            // Proactive suggestion overlay — sits above panels, below input
            VStack {
                Spacer()
                LilithSuggestionOverlay()
                    .padding(.bottom, 108)
            }

            VStack {
                Spacer()
                VoidInputBar(text: $input, onSend: sendMessage)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 44)
            }

            // Swipe hint
            VStack {
                Spacer()
                Text("Swipe up")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.26))
                    .padding(.bottom, 10)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -80 { onSwipeUp() }
                }
        )
    }

    private func sendMessage() {
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

// MARK: - Void Background (Cinematic)

private struct VoidBackgroundLayer: View {
    var body: some View {
        CinematicVoidBackground()
    }
}

struct CinematicVoidBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            ZStack {
                // Warped background: three offset copies blended to simulate liquid distortion
                ForEach(0..<3, id: \.self) { layer in
                    let fl = CGFloat(layer)
                    Image("lilith_void_soft_surfaces_visual")
                        .resizable()
                        .scaledToFill()
                        .offset(
                            x: sin(t * 0.6 + fl * 1.2) * 8,
                            y: cos(t * 0.4 + fl * 0.9) * 5
                        )
                        .opacity(layer == 0 ? 1.0 : 0.18)
                        .blendMode(layer == 0 ? .normal : .screen)
                }

                Color.black.opacity(0.35)

                // Depth vignette
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.40)
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 600
                )

                ParticleField()
            }
            .ignoresSafeArea()
        }
    }
}

struct ParticleField: View {
    // Stable positions seeded at init; animation drives y drift
    private let seedPositions: [CGPoint] = (0..<20).map { _ in
        CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1))
    }
    @State private var driftOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate)
                Canvas { context, size in
                    for (i, seed) in seedPositions.enumerated() {
                        let drift = sin(t * 0.3 + CGFloat(i) * 0.7) * 0.06
                        let px = seed.x * size.width
                        let py = (seed.y + drift).truncatingRemainder(dividingBy: 1.0) * size.height
                        var path = Path()
                        path.addEllipse(in: CGRect(x: px - 1.5, y: py - 1.5, width: 3, height: 3))
                        context.fill(path, with: .color(Color.white.opacity(0.06)))
                    }
                }
            }
        }
    }
}

// MARK: - Void Message Panel (glass + pulse)

private struct VoidMessagePanel: View {
    let text: String
    let isUser: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .background(.ultraThinMaterial.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(isUser ? Color.white.opacity(0.15) : Color.blue.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: isUser ? Color.white.opacity(pulse ? 0.12 : 0.04)
                                     : Color.blue.opacity(pulse ? 0.20 : 0.06),
                        radius: pulse ? 20 : 5)

            HStack(spacing: 8) {
                if !isUser {
                    Circle()
                        .fill(Color.blue.opacity(0.75))
                        .frame(width: 6, height: 6)
                }
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(4)
                if isUser { Spacer() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scaleEffect(pulse ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Void Input Bar

private struct VoidInputBar: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("", text: $text)
                .foregroundColor(.white)
                .font(.system(size: 16, design: .rounded))
                .submitLabel(.send)
                .onSubmit { onSend() }
                .overlay(
                    Text("Ask Lilith anything…")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 16, design: .rounded))
                        .opacity(text.isEmpty ? 1 : 0)
                        .allowsHitTesting(false),
                    alignment: .leading
                )

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        text.isEmpty ? Color.white.opacity(0.25) : Color.white
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}
