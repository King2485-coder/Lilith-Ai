import SwiftUI

/// Main animated Lilith avatar.
struct LilithView: View {
    @EnvironmentObject var manager: LilithStateManager
    @StateObject private var audio = LilithAudioManager()

    @State private var float = false
    @State private var glow = false
    @State private var rotate = false
    @State private var blink = false
    @State private var pulse = false
    @State private var lookOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Image(currentImageName)
                .resizable()
                .scaledToFit()
                .modifier(
                    LilithMotionModifier(
                        state: manager.state,
                        float: float,
                        glow: glow,
                        rotate: rotate,
                        pulse: pulse,
                        audioLevel: audio.level,
                        lookOffset: lookOffset
                    )
                )
        }
        .onAppear {
            startIdleAnimations()
            startBlinkLoop()
            audio.startListening()
        }
        .onDisappear {
            audio.stopListening()
        }
        .onChange(of: manager.state) { _, newValue in
            if newValue == .interacting {
                focusOnInput()
            } else if newValue == .listening {
                // already handled by audio-driven glow
                lookOffset = .zero
            }
        }
    }

    private var currentImageName: String {
        if blink { return "lilith_blink_closed" }
        switch manager.state {
        case .idle: return "lilith_neutral"
        case .listening: return "lilith_listening"
        case .thinking: return "lilith_processing"
        case .responding: return "lilith_smirk"
        case .interacting: return "lilith_soft_smile"
        }
    }

    private func startIdleAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            float.toggle()
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            glow.toggle()
        }
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
            rotate.toggle()
        }
    }

    private func startBlinkLoop() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 4...6), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.08)) {
                blink = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    blink = false
                }
            }
        }
    }

    private func focusOnInput() {
        withAnimation(.easeInOut(duration: 0.3)) {
            lookOffset = CGSize(width: 5, height: 2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                lookOffset = .zero
            }
        }
    }
}
