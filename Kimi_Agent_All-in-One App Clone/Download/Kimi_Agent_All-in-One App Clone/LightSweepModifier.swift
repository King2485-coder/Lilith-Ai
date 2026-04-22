import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LightSweepModifier
//
// Periodic soft highlight that glides across a surface edge.
// Looks like light catching a metallic edge or glass panel.
//
// Usage:
//   myView.lightSweep()
//   myView.lightSweep(period: 8, color: .orange, opacity: 0.12)
// ─────────────────────────────────────────────────────────────────────────────

struct LightSweepModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let period:    Double   // seconds between sweep starts
    let duration:  Double   // seconds a single sweep takes to cross
    let color:     Color
    let opacity:   Double
    let angle:     Double   // degrees – tilt of the streak
    let phase:     Double   // time offset between siblings

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                let t          = clock.time + phase
                let cycleFrac  = t.truncatingRemainder(dividingBy: period) / period
                // Only visible during the leading `duration/period` fraction of each cycle
                let activeFrac = duration / period
                let progress   = cycleFrac < activeFrac ? cycleFrac / activeFrac : -1

                if progress >= 0 {
                    // Ease in/out the streak opacity
                    let ease  = sin(progress * .pi)
                    let op    = opacity * ease

                    LinearGradient(
                        stops: [
                            .init(color: .clear,               location: 0.00),
                            .init(color: color.opacity(op),    location: 0.40),
                            .init(color: color.opacity(op),    location: 0.60),
                            .init(color: .clear,               location: 1.00),
                        ],
                        startPoint: .leading,
                        endPoint:   .trailing
                    )
                    .frame(width: geo.size.width * 0.18)
                    .rotationEffect(.degrees(angle))
                    .blendMode(.plusLighter)
                    // Sweep from left-off-screen to right-off-screen
                    .offset(x: -geo.size.width * 0.6 + progress * geo.size.width * 1.4)
                }
            }
            .clipped()
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func lightSweep(
        period:   Double = MotionTiming.sweepInterval,
        duration: Double = MotionTiming.sweepDuration,
        color:    Color  = .white,
        opacity:  Double = 0.09,
        angle:    Double = -15,
        phase:    Double = 0
    ) -> some View {
        modifier(LightSweepModifier(
            period: period, duration: duration,
            color: color, opacity: opacity,
            angle: angle, phase: phase))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ScanLineModifier
//
// A single hairline that sweeps top-to-bottom, simulating a scan / HUD read.
// Use on panel surfaces.
// ─────────────────────────────────────────────────────────────────────────────

struct ScanLineModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let period:  Double
    let opacity: Double
    let phase:   Double

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                let progress = clock.saw(period: period, offset: phase)
                let y        = progress * geo.size.height

                // Fade at top & bottom quarters
                let normY    = y / geo.size.height
                let edge     = min(normY * 5, (1 - normY) * 5, 1.0)
                let op       = opacity * edge

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.cyan.opacity(op), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .offset(y: y - geo.size.height / 2)
                    .allowsHitTesting(false)
            }
            .clipped()
        )
    }
}

extension View {
    func scanLine(
        period:  Double = MotionTiming.panelShimmer * 1.2,
        opacity: Double = 0.12,
        phase:   Double = 0
    ) -> some View {
        modifier(ScanLineModifier(period: period, opacity: opacity, phase: phase))
    }
}
