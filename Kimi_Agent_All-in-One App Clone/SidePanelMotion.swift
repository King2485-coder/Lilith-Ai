import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LivePanelModifier
//
// Add to any side panel container View to get:
//   • shimmer sweep
//   • scan line
//   • edge border breathing glow
//
// Usage:
//   LeftPanelView().livePanel(phase: 0.0)
//   RightPanelView().livePanel(phase: 2.0)   // phase offset so they differ
// ─────────────────────────────────────────────────────────────────────────────

struct LivePanelModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    let phase:     Double   // time offset (seconds)
    let edge:      Edge     // which edge to glow

    func body(content: Content) -> some View {
        let borderOsc = clock.osc(period: MotionTiming.breathSlow, offset: phase)
        let borderOp  = 0.12 + borderOsc * 0.18

        content
            // Scanning line sweep
            .scanLine(period: MotionTiming.panelShimmer * 1.3, opacity: 0.08, phase: phase)
            // Diagonal shimmer pass
            .shimmer(period: MotionTiming.panelShimmer, opacity: 0.06, phase: phase)
            // Occasional horizontal light sweep
            .lightSweep(period: MotionTiming.sweepInterval + phase,
                        duration: MotionTiming.sweepDuration,
                        opacity: 0.07,
                        phase: phase)
            // Breathing edge glow
            .overlay(
                edgeGlow(borderOp: borderOp)
                    .allowsHitTesting(false)
            )
    }

    @ViewBuilder
    private func edgeGlow(borderOp: Double) -> some View {
        GeometryReader { geo in
            let lineW: CGFloat = 1.0
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color.blue.opacity(borderOp), lineWidth: lineW)
            // Extra inner blur glow on the panel's inner edge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(borderOp * 0.35), .clear],
                        startPoint: edge == .leading ? .leading : .trailing,
                        endPoint:   edge == .leading ? .trailing : .leading
                    )
                )
                .frame(width: 24)
                .frame(maxWidth: .infinity,
                       alignment: edge == .leading ? .leading : .trailing)
                .blur(radius: 8)
        }
    }
}

extension View {
    /// Apply living panel surface treatment (shimmer, scan, border glow)
    func livePanel(phase: Double = 0, edge: Edge = .leading) -> some View {
        modifier(LivePanelModifier(phase: phase, edge: edge))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FuturisticPanelTransition
//
// A custom AnyTransition that makes panels glide in/out like they're sliding
// on hidden rails — combined move + opacity + slight scale.
// ─────────────────────────────────────────────────────────────────────────────

extension AnyTransition {
    /// Panel slides from the given edge with a fade and very slight scale shrink.
    static func futuristicPanel(edge: Edge) -> AnyTransition {
        let insertion = AnyTransition
            .move(edge: edge)
            .combined(with: .opacity)
            .combined(with: .scale(scale: 0.97, anchor: edge == .leading ? .leading : .trailing))

        let removal = AnyTransition
            .move(edge: edge)
            .combined(with: .opacity)
            .combined(with: .scale(scale: 0.97, anchor: edge == .leading ? .leading : .trailing))

        return .asymmetric(insertion: insertion, removal: removal)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Updated LeftPanelView + RightPanelView wrappers
//
// These are thin wrappers that add motion on top of whatever content you
// already have.  Replace the existing LeftPanelView / RightPanelView usages
// in ContentView with these, OR apply `.livePanel()` directly in ContentView.
// ─────────────────────────────────────────────────────────────────────────────

/// Apply in ContentView instead of a plain .transition(.move(edge: .leading))
/// Example:
///   if showLeftPanel {
///       LeftPanelView()
///           .transition(.futuristicPanel(edge: .leading))
///           .livePanel(phase: 0, edge: .leading)
///           .parallax(depth: 0.15)
///   }
///
/// Nothing here overwrites LeftPanelView or RightPanelView — they live on.
struct PanelUsageGuide { /* documentation only — no runtime code */ }
