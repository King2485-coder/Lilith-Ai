import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FloatingParticleField
//
// Sparse drifting particles for background depth.
// Renders with Canvas for lightweight performance.
// Mostly cool blue, a few warm orange accents.
// ─────────────────────────────────────────────────────────────────────────────

struct FloatingParticleField: View {
    @ObservedObject private var clock = MotionClock.shared

    // Each particle is fully defined by deterministic random values.
    // Nothing heap-allocated per frame.
    private struct Particle {
        let startX:    Double   // 0…1 of screen width
        let startY:    Double   // 0…1 of screen height
        let radius:    Double   // point radius
        let speed:     Double   // vertical drift speed multiplier
        let driftX:    Double   // horizontal wobble amplitude (points)
        let driftFreq: Double   // wobble frequency
        let phase:     Double   // time offset
        let opacity:   Double   // base opacity
        let isOrange:  Bool     // accent colour flag
    }

    private let particles: [Particle] = {
        var rng = SeedRNG(seed: 99)
        let count = 40
        return (0..<count).map { i in
            Particle(
                startX:    rng.next(),
                startY:    rng.next(),
                radius:    1.0 + rng.next() * 1.6,
                speed:     0.4 + rng.next() * 0.6,
                driftX:    6 + rng.next() * 12,
                driftFreq: 0.15 + rng.next() * 0.2,
                phase:     rng.next() * 2 * .pi,
                opacity:   0.08 + rng.next() * 0.10,
                isOrange:  i % 7 == 0          // ~14 % are orange
            )
        }
    }()

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let t = clock.time
                for p in particles {
                    // Vertical: drift upward, wrap at top
                    let cycleLen = size.height / p.speed
                    let baseY    = p.startY * size.height
                    let raw      = baseY - t.truncatingRemainder(dividingBy: cycleLen) * p.speed
                    let y        = raw < 0 ? raw + size.height : raw

                    // Horizontal: slow sinusoidal wobble
                    let x = p.startX * size.width
                              + sin(t * p.driftFreq + p.phase) * p.driftX

                    // Fade in/out based on vertical position (edges = transparent)
                    let normY   = y / size.height
                    let fadeEdge = min(normY * 6, (1 - normY) * 6, 1.0)
                    let op      = p.opacity * fadeEdge

                    let color: Color = p.isOrange
                        ? Color(red: 1.0, green: 0.55, blue: 0.0).opacity(op)
                        : Color.blue.opacity(op)

                    let r = CGFloat(p.radius)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                               width: r * 2, height: r * 2)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .parallax(depth: 0.65)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Seeded RNG (local copy — avoids cross-file struct name collision)
// ─────────────────────────────────────────────────────────────────────────────

private struct SeedRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 33) / Double(UInt32.max)
    }
}
