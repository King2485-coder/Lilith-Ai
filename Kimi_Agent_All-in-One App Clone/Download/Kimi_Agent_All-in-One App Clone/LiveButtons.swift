import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LiveSendButton
//
// Drop-in wrapper for your existing SEND button content.
// Adds: breathing scale, rotating halo, expanding glow ring, inner shimmer.
// The label/icon inside is unchanged — just wrap it.
//
// Usage:
//   LiveSendButton { /* your existing SEND label */ }
// ─────────────────────────────────────────────────────────────────────────────

struct LiveSendButton<Label: View>: View {
    @ObservedObject private var clock = MotionClock.shared
    let diameter: CGFloat
    @ViewBuilder let label: () -> Label

    init(diameter: CGFloat = 82, @ViewBuilder label: @escaping () -> Label) {
        self.diameter = diameter
        self.label = label
    }

    var body: some View {
        let breathOsc   = clock.osc(period: MotionTiming.breathSlow, offset: 0)
        let glowOsc     = clock.osc(period: MotionTiming.breathMedium, offset: 0.5)
        let scaleVal    = 0.985 + breathOsc * 0.030   // 0.985 … 1.015
        let glowBlur    = diameter * 0.25 + CGFloat(glowOsc) * diameter * 0.2
        let glowOp      = 0.20 + glowOsc * 0.30

        ZStack {
            // ── Outer expanding glow ring ──────────────────────────────────
            Circle()
                .stroke(Color.blue.opacity(glowOp * 0.6),
                        lineWidth: 1.5)
                .frame(width: diameter * 1.45 + CGFloat(glowOsc) * 8,
                       height: diameter * 1.45 + CGFloat(glowOsc) * 8)

            // ── Soft glow fill behind button ──────────────────────────────
            Circle()
                .fill(Color.blue.opacity(glowOp * 0.15))
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .blur(radius: glowBlur)

            // ── Rotating halo arc ─────────────────────────────────────────
            RotatingRingView(
                radius:    diameter * 0.62,
                lineWidth: 1.5,
                color:     Color.cyan.opacity(0.45),
                arcLength: 130,
                period:    MotionTiming.energyRing,
                clockwise: true,
                phase:     0
            )

            // ── Counter-rotating accent arc ───────────────────────────────
            RotatingRingView(
                radius:    diameter * 0.55,
                lineWidth: 1.0,
                color:     Color.blue.opacity(0.30),
                arcLength: 60,
                period:    MotionTiming.ringFastCCW,
                clockwise: false,
                phase:     80
            )

            // ── The actual button body ────────────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.55 + breathOsc * 0.15),
                            Color(red: 0.0, green: 0.15, blue: 0.45),
                        ],
                        center:      .center,
                        startRadius: 0,
                        endRadius:   diameter * 0.5
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.55), lineWidth: 1.5)
                )
                .shimmer(period: 3.8, angle: -25, opacity: 0.10)
                .lightSweep(period: 7.0, duration: 1.4, opacity: 0.12, phase: 1.5)
                .shadow(color: .blue.opacity(0.55), radius: glowBlur * 0.6)
                .overlay(label())
        }
        .scaleEffect(scaleVal)
        .parallax(depth: 0.05)   // buttons shift least
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LiveScanButton
//
// SCAN — cool blue ambient pulse.  Weaker than SEND.
// ─────────────────────────────────────────────────────────────────────────────

struct LiveScanButton<Label: View>: View {
    @ObservedObject private var clock = MotionClock.shared
    let diameter: CGFloat
    @ViewBuilder let label: () -> Label

    init(diameter: CGFloat = 60, @ViewBuilder label: @escaping () -> Label) {
        self.diameter = diameter
        self.label = label
    }

    var body: some View {
        let osc    = clock.osc(period: MotionTiming.breathMedium, offset: 1.2)
        let glowOp = 0.12 + osc * 0.18
        let blr    = diameter * 0.3 + CGFloat(osc) * diameter * 0.15

        ZStack {
            // Glow halo
            Circle()
                .fill(Color.blue.opacity(glowOp * 0.4))
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .blur(radius: blr)

            // Slow rotating arc
            RotatingRingView(
                radius:    diameter * 0.58,
                lineWidth: 1.0,
                color:     Color.blue.opacity(0.35),
                arcLength: 100,
                period:    MotionTiming.ringSlowCW * 0.8,
                clockwise: true,
                phase:     30
            )

            // Button body
            Circle()
                .fill(Color.blue.opacity(0.18 + osc * 0.08))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(Color.blue.opacity(0.55 + osc * 0.25), lineWidth: 1)
                )
                .shimmer(period: MotionTiming.panelShimmer, opacity: 0.07, phase: 0.8)
                .shadow(color: .blue.opacity(0.30 + osc * 0.15), radius: blr * 0.5)
                .overlay(label())
        }
        .parallax(depth: 0.05)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LivePayButton
//
// PAY — warm orange energy pulse.  Weaker than SEND.
// ─────────────────────────────────────────────────────────────────────────────

struct LivePayButton<Label: View>: View {
    @ObservedObject private var clock = MotionClock.shared
    let diameter: CGFloat
    @ViewBuilder let label: () -> Label

    init(diameter: CGFloat = 60, @ViewBuilder label: @escaping () -> Label) {
        self.diameter = diameter
        self.label = label
    }

    private let orange = Color(red: 1.0, green: 0.55, blue: 0.0)

    var body: some View {
        let osc    = clock.osc(period: MotionTiming.breathMedium, offset: 2.4)
        let glowOp = 0.10 + osc * 0.15
        let blr    = diameter * 0.28 + CGFloat(osc) * diameter * 0.12

        ZStack {
            // Glow halo
            Circle()
                .fill(orange.opacity(glowOp * 0.4))
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .blur(radius: blr)

            // Slow CCW arc
            RotatingRingView(
                radius:    diameter * 0.58,
                lineWidth: 1.0,
                color:     orange.opacity(0.35),
                arcLength: 90,
                period:    MotionTiming.ringSlowCW,
                clockwise: false,
                phase:     60
            )

            // Button body
            Circle()
                .fill(orange.opacity(0.15 + osc * 0.07))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(orange.opacity(0.50 + osc * 0.25), lineWidth: 1)
                )
                .shimmer(period: MotionTiming.panelShimmer * 1.1, opacity: 0.07, phase: 2.0)
                .shadow(color: orange.opacity(0.28 + osc * 0.12), radius: blr * 0.5)
                .overlay(label())
        }
        .parallax(depth: 0.05)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LiveIconButton
//
// Small utility icon with micro-pulse.  Wrap existing icon buttons.
// ─────────────────────────────────────────────────────────────────────────────

struct LiveIconButton<Label: View>: View {
    let phase: Double
    @ViewBuilder let label: () -> Label

    var body: some View {
        label()
            .microPulse(minOp: 0.68, maxOp: 1.0,
                        period: MotionTiming.breathFast,
                        phase: phase)
            .breathingGlow(color: .blue,
                           minBlur: 2, maxBlur: 7,
                           minOp: 0.05, maxOp: 0.20,
                           period: MotionTiming.breathMedium,
                           phase: phase)
    }
}
