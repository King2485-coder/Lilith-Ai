import SwiftUI

// MARK: - Void Core View
// Pure black canvas. 10 tiny almost-invisible white dots drifting upward.
// No gradients. No glows. No rings. No decorative graphics.

struct VoidCoreView: View {
    @State private var dotSeeds: [VoidDotSeed] = []

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.033, paused: false)) { timeline in
                Canvas { context, canvasSize in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    // Pure black background — drawn explicitly to be certain
                    context.fill(
                        Path(CGRect(origin: .zero, size: canvasSize)),
                        with: .color(.black)
                    )

                    // 10 tiny white dots drifting upward
                    for seed in dotSeeds {
                        let pos = seed.position(in: canvasSize, time: time)
                        let alpha = seed.alpha(at: pos.y, canvasHeight: canvasSize.height)
                        let rect = CGRect(
                            x: pos.x - seed.size / 2,
                            y: pos.y - seed.size / 2,
                            width: seed.size,
                            height: seed.size
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color.white.opacity(alpha))
                        )
                    }
                }
            }
        }
        .background(Color.black)
        .onAppear {
            initializeDots()
        }
    }

    private func initializeDots() {
        dotSeeds = (0..<10).map { i in
            VoidDotSeed(
                baseX: Double.random(in: 0.1...0.9),
                baseY: Double.random(in: 0.0...1.0),
                size: Double.random(in: 1.5...3.0),
                baseAlpha: Double.random(in: 0.05...0.10),
                driftSpeed: Double.random(in: 0.015...0.04),
                wobbleAmp: Double.random(in: 8...20),
                wobbleFreq: Double.random(in: 0.3...0.7),
                wobblePhase: Double.random(in: 0...Double.pi * 2),
                seedIndex: Double(i)
            )
        }
    }
}

// MARK: - Dot Seed

struct VoidDotSeed {
    let baseX: Double        // normalized 0...1 across width
    let baseY: Double        // normalized 0...1 across height
    let size: Double
    let baseAlpha: Double
    let driftSpeed: Double   // vertical drift speed (fraction of height per second)
    let wobbleAmp: Double    // horizontal wobble amplitude in points
    let wobbleFreq: Double   // wobble frequency
    let wobblePhase: Double  // wobble phase offset
    let seedIndex: Double

    func position(in canvasSize: CGSize, time: Double) -> CGPoint {
        let canvasH = max(canvasSize.height, 1)
        let canvasW = max(canvasSize.width, 1)

        // Wrap upward drift: baseY drifts up and wraps at top
        let driftedY = (baseY - driftSpeed * time).truncatingRemainder(dividingBy: 1.0)
        let wrappedY = driftedY < 0 ? driftedY + 1.0 : driftedY

        let y = wrappedY * canvasH

        // Gentle horizontal wobble
        let wobble = sin(time * wobbleFreq + wobblePhase + seedIndex) * wobbleAmp
        let x = baseX * canvasW + wobble

        return CGPoint(x: x, y: y)
    }

    func alpha(at y: Double, canvasHeight: Double) -> Double {
        // Fade near top edge for smooth wrapping
        let normalizedY = y / max(canvasHeight, 1)
        let topFade = min(1.0, normalizedY / 0.08)
        return baseAlpha * topFade
    }
}
