import SwiftUI

struct LilithLaunchPro: View {
    @State private var codeProgress = 0
    @State private var buildCore = false
    @State private var activate = false
    @State private var particles: [Particle] = Particle.generate(count: 80)

    private let codeLines = [
        "initializing core systems...",
        "building interface lattice...",
        "compiling intelligence modules...",
        "optimizing neural paths...",
        "stabilizing consciousness..."
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                background

                codeLayer
                    .opacity(buildCore ? 0 : 1)
                    .animation(.easeInOut(duration: 0.6), value: buildCore)

                if buildCore {
                    coreLayer(date: timeline.date)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: runSequence)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.07, blue: 0.18),
                    Color(red: 0.06, green: 0.08, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.25),
                    Color.purple.opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 500
            )
            .blendMode(.plusLighter)
            .blur(radius: 20)
        }
    }

    private var codeLayer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(codeLines.indices, id: \.self) { index in
                let visible = index < codeProgress
                Text(codeLines[index])
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.blue.opacity(0.82))
                    .shadow(color: Color.blue.opacity(0.6), radius: 12, y: 4)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 10)
                    .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.18), value: codeProgress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func coreLayer(date: Date) -> some View {
        ZStack {
            particleLayer(date: date)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.65),
                            Color.purple.opacity(0.55),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 160
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 12)
                .opacity(activate ? 1 : 0.75)
                .scaleEffect(activate ? 1.18 : 0.92)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: activate)

            neuralSphere
                .frame(width: 190, height: 190)
                .opacity(activate ? 1 : 0.7)
                .scaleEffect(activate ? 1 : 0.9)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: activate)
        }
    }

    private func particleLayer(date: Date) -> some View {
        GeometryReader { proxy in
            let t = date.timeIntervalSince1970
            ForEach(particles) { particle in
                let position = particle.position(at: t, in: proxy.size)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(position)
                    .opacity(0.6)
                    .blur(radius: 0.4)
            }
        }
    }

    private var neuralSphere: some View {
        ZStack {
            ForEach(0..<24) { i in
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                            center: .center
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: CGFloat(70 + i * 4), height: CGFloat(70 + i * 4))
                    .rotationEffect(.degrees(Double(i) * 7))
                    .opacity(0.12)
            }

            ForEach(0..<14) { i in
                let angle = Double(i) / 14.0 * 2 * .pi
                let radius: CGFloat = 80
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.blue.opacity(0.9), radius: 6)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
    }

    private func runSequence() {
        codeProgress = 1
        for i in 1..<codeLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                codeProgress = i + 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            buildCore = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            activate = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double
    let radius: Double
    let speed: Double
    let size: CGFloat

    static func generate(count: Int) -> [Particle] {
        (0..<count).map { _ in
            Particle(
                angle: Double.random(in: 0 ..< 2 * .pi),
                radius: Double.random(in: 40 ... 150),
                speed: Double.random(in: 0.3 ... 0.9),
                size: CGFloat.random(in: 3 ... 8)
            )
        }
    }

    func position(at time: TimeInterval, in size: CGSize) -> CGPoint {
        let spin = angle + sin(time * speed) * 0.9
        let decay = 1 - exp(-time * 0.2)
        let r = radius * decay
        return CGPoint(
            x: size.width / 2 + CGFloat(cos(spin) * r),
            y: size.height / 2 + CGFloat(sin(spin) * r)
        )
    }
}

#Preview {
    LilithLaunchPro()
}
