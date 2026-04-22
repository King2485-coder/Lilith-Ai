import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BreathingGlow ViewModifier
//
// Adds a soft, pulsing coloured shadow behind any view.
// Driven by MotionClock so it stays in phase with the global rhythm.
// ─────────────────────────────────────────────────────────────────────────────

struct BreathingGlowModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let color:    Color
    let minBlur:  CGFloat       // smallest glow radius
    let maxBlur:  CGFloat       // largest glow radius
    let minOp:    Double        // minimum glow opacity
    let maxOp:    Double        // maximum glow opacity
    let period:   Double        // breathing period in seconds
    let phase:    Double        // time offset so siblings differ

    func body(content: Content) -> some View {
        let t   = clock.osc(period: period, offset: phase)
        let blur = minBlur + CGFloat(t) * (maxBlur - minBlur)
        let op   = minOp   + t           * (maxOp   - minOp)

        content
            .shadow(color: color.opacity(op), radius: blur)
            .shadow(color: color.opacity(op * 0.4), radius: blur * 2.2)
    }
}

extension View {
    func breathingGlow(
        color:   Color  = .blue,
        minBlur: CGFloat = 4,
        maxBlur: CGFloat = 18,
        minOp:   Double  = 0.15,
        maxOp:   Double  = 0.55,
        period:  Double  = MotionTiming.breathSlow,
        phase:   Double  = 0
    ) -> some View {
        modifier(BreathingGlowModifier(
            color: color, minBlur: minBlur, maxBlur: maxBlur,
            minOp: minOp, maxOp: maxOp, period: period, phase: phase))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BreathingScale ViewModifier
//
// Gentle scale pulse.  No spring bounce — pure sinusoidal.
// ─────────────────────────────────────────────────────────────────────────────

struct BreathingScaleModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let minScale: Double
    let maxScale: Double
    let period:   Double
    let phase:    Double

    func body(content: Content) -> some View {
        let t = clock.osc(period: period, offset: phase)
        let s = minScale + t * (maxScale - minScale)
        return content.scaleEffect(s)
    }
}

extension View {
    func breathingScale(
        min: Double = 0.985,
        max: Double = 1.015,
        period: Double = MotionTiming.breathSlow,
        phase:  Double = 0
    ) -> some View {
        modifier(BreathingScaleModifier(
            minScale: min, maxScale: max, period: period, phase: phase))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ShimmerModifier
//
// A diagonal highlight stripe that slides across the view.
// Use on panel surfaces and metallic edges.
// ─────────────────────────────────────────────────────────────────────────────

struct ShimmerModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let period:    Double   // seconds per full cycle
    let angle:     Double   // stripe angle in degrees
    let opacity:   Double   // peak opacity of the stripe
    let phase:     Double   // time offset

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                let progress = clock.saw(period: period, offset: phase)
                // Map 0…1 → stripe x from –width to +2×width so it's fully off-screen at both ends
                let travel  = geo.size.width * 2.5
                let x       = -geo.size.width * 0.75 + progress * travel

                LinearGradient(
                    stops: [
                        .init(color: .clear,                      location: 0.0),
                        .init(color: .white.opacity(opacity),     location: 0.45),
                        .init(color: .white.opacity(opacity),     location: 0.55),
                        .init(color: .clear,                      location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint:   .trailing
                )
                .frame(width: geo.size.width * 0.25)
                .offset(x: x)
                .rotationEffect(.degrees(angle), anchor: .center)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .clipped()
        )
    }
}

extension View {
    func shimmer(
        period:  Double = MotionTiming.panelShimmer,
        angle:   Double = -20,
        opacity: Double = 0.07,
        phase:   Double = 0
    ) -> some View {
        modifier(ShimmerModifier(period: period, angle: angle,
                                 opacity: opacity, phase: phase))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MicroPulseModifier
//
// A very subtle opacity flicker for small utility icons.
// Uses a faster, low-amplitude oscillation.
// ─────────────────────────────────────────────────────────────────────────────

struct MicroPulseModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let minOp:  Double
    let maxOp:  Double
    let period: Double
    let phase:  Double

    func body(content: Content) -> some View {
        let t = clock.osc(period: period, offset: phase)
        return content.opacity(minOp + t * (maxOp - minOp))
    }
}

extension View {
    func microPulse(
        minOp:  Double = 0.70,
        maxOp:  Double = 1.00,
        period: Double = MotionTiming.breathFast,
        phase:  Double = 0
    ) -> some View {
        modifier(MicroPulseModifier(minOp: minOp, maxOp: maxOp,
                                    period: period, phase: phase))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotatingRingView
//
// A partial arc that rotates continuously.
// Composable — stack multiples for layered ring feel.
// ─────────────────────────────────────────────────────────────────────────────

struct RotatingRingView: View {
    @ObservedObject private var clock = MotionClock.shared

    let radius:    CGFloat
    let lineWidth: CGFloat
    let color:     Color
    let arcLength: Double   // arc sweep in degrees (0…360)
    let period:    Double   // full rotation period in seconds
    let clockwise: Bool
    let phase:     Double

    var body: some View {
        let angle = clock.time / period * 360.0 * (clockwise ? 1 : -1) + phase
        return Circle()
            .trim(from: 0, to: arcLength / 360.0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(angle))
    }
}
