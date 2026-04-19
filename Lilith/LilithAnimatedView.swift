import SwiftUI

enum LilithExpression {
    case neutral
    case thinking
    case smirk
}

struct LilithAnimatedView: View {
    @State private var expression: LilithExpression = .neutral
    @State private var glow = false
    @State private var float = false
    @State private var blink = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.2),
                    Color.purple.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Glow behind Lilith
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 300
                    )
                )
                .blur(radius: 40)
                .scaleEffect(glow ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glow)

            // Lilith Image
            Image(currentImage)
                .resizable()
                .scaledToFit()
                .frame(width: 280)
                .scaleEffect(float ? 1.02 : 0.98)
                .offset(y: float ? -5 : 5)
                .shadow(color: .blue.opacity(0.4), radius: 20)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: float)
        }
        .onAppear {
            glow = true
            float = true
            startBehavior()
            startBlink()
        }
    }

    private var currentImage: String {
        switch expression {
        case .neutral: return "atom_neutral"
        case .thinking: return "atom_thinking"
        case .smirk: return "atom_smirk"
        }
    }

    // MARK: - Expression loop
    private func startBehavior() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                switch expression {
                case .neutral:
                    expression = .thinking
                case .thinking:
                    expression = .smirk
                case .smirk:
                    expression = .neutral
                }
            }
        }
    }

    // MARK: - Blink
    private func startBlink() {
        Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                blink = false
            }
        }
    }
}

#Preview {
    LilithAnimatedView()
}
