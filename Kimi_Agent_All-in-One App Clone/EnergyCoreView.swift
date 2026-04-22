import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EnergyCoreView
//
// Drop this anywhere above the main content (or inline near the top centre)
// to replace / augment the existing glowing orb.  It reads MotionClock and
// produces:
//   • A breathing radial glow
//   • Three layered rotating partial-arc rings
//   • Tiny orbiting mote particles
//   • A central solid core with shimmer
//
// Size is controlled by the `diameter` parameter.
// ─────────────────────────────────────────────────────────────────────────────

struct EnergyCoreView: View {
    var diameter: CGFloat = 96

    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        ZStack {
            // ── Outer breathing glow halo ──────────────────────────────────
            let haloOsc = clock.osc(period: MotionTiming.breathSlow, offset: 1.1)
            let haloBlur = diameter * 0.45 + CGFloat(haloOsc) * diameter * 0.25
            let haloOp   = 0.15 + haloOsc * 0.18

            Circle()
                .fill(Color.blue.opacity(haloOp))
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .blur(radius: haloBlur)

            // ── Outer decorative ring (slow CW) ───────────────────────────
            RotatingRingView(
                radius:    diameter * 0.72,
                lineWidth: 1.0,
                color:     Color.blue.opacity(0.25),
                arcLength: 240,
                period:    MotionTiming.ringSlowCW,
                clockwise: true,
                phase:     0
            )

            // ── Mid accent ring (medium CCW) ──────────────────────────────
            RotatingRingView(
                radius:    diameter * 0.58,
                lineWidth: 1.5,
                color:     Color.cyan.opacity(0.30),
                arcLength: 160,
                period:    MotionTiming.ringFastCCW,
                clockwise: false,
                phase:     45
            )

            // ── Inner energy ring (fast CW) ───────────────────────────────
            RotatingRingView(
                radius:    diameter * 0.43,
                lineWidth: 2.0,
                color:     Color.blue.opacity(0.50),
                arcLength: 90,
                period:    MotionTiming.energyRing,
                clockwise: true,
                phase:     120
            )

            // ── Orbiting motes ────────────────────────────────────────────
            OrbitingMotes(coreRadius: diameter * 0.5)

            // ── Core sphere ───────────────────────────────────────────────
            let coreOsc = clock.osc(period: MotionTiming.breathMedium, offset: 0.7)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.55 + coreOsc * 0.25),
                            Color.blue.opacity(0.40),
                            Color.black.opacity(0.6),
                        ],
                        center:      .center,
                        startRadius: 0,
                        endRadius:   diameter * 0.48
                    )
                )
                .frame(width: diameter * 0.88, height: diameter * 0.88)
                .shimmer(period: 3.2, angle: -30, opacity: 0.12)

            // ── Central sparkle icon ──────────────────────────────────────
            Image(systemName: "sparkles")
                .font(.system(size: diameter * 0.28, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: diameter * 1.6, height: diameter * 1.6)
        .parallax(depth: 0.2)   // foreground — minimal shift
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Orbiting Motes (tiny particles that arc around the core)
// ─────────────────────────────────────────────────────────────────────────────

private struct OrbitingMotes: View {
    let coreRadius: CGFloat
    @ObservedObject private var clock = MotionClock.shared

    private struct Mote {
        let orbitR:  CGFloat   // orbit radius
        let speed:   Double    // radians per second
        let phase:   Double    // starting angle
        let size:    CGFloat
        let opacity: Double
    }

    private let motes: [Mote] = [
        Mote(orbitR: 1.25, speed: 0.55, phase: 0.0,  size: 2.5, opacity: 0.55),
        Mote(orbitR: 1.40, speed: 0.38, phase: 2.1,  size: 2.0, opacity: 0.40),
        Mote(orbitR: 1.15, speed: 0.70, phase: 4.2,  size: 1.8, opacity: 0.45),
        Mote(orbitR: 1.50, speed: 0.28, phase: 1.0,  size: 1.5, opacity: 0.30),
        Mote(orbitR: 1.30, speed: 0.50, phase: 5.5,  size: 2.2, opacity: 0.35),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(motes.enumerated()), id: \.offset) { _, mote in
                let angle = clock.time * mote.speed + mote.phase
                let r     = coreRadius * mote.orbitR
                let x     = cos(angle) * r
                let y     = sin(angle) * r

                // Opacity fades when "behind" the sphere (simulate 3D)
                let depthOp = max(0, sin(angle)) * mote.opacity + mote.opacity * 0.25

                Circle()
                    .fill(Color.cyan.opacity(depthOp))
                    .frame(width: mote.size, height: mote.size)
                    .blur(radius: 0.5)
                    .offset(x: x, y: y)
            }
        }
    }
}
