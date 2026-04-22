import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CenterPanelDepthModifier
//
// Makes the centre content panel feel like it floats above the background:
//   • Layered shadow depth
//   • Breathing edge glow (all 4 sides, subtle)
//   • Occasional glass reflection sweep
//
// Usage:
//   mainContentPanel.centerPanelDepth()
// ─────────────────────────────────────────────────────────────────────────────

struct CenterPanelDepthModifier: ViewModifier {
    @ObservedObject private var clock = MotionClock.shared

    func body(content: Content) -> some View {
        let glowOsc = clock.osc(period: MotionTiming.breathSlow, offset: 0.8)
        let edgeOp  = 0.06 + glowOsc * 0.08

        content
            // Floating shadow stack — three layers at different radii = depth
            .shadow(color: .black.opacity(0.65), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
            .shadow(color: Color.blue.opacity(edgeOp), radius: 28, x: 0, y: 0)
            // Glass reflection sweep every N seconds
            .lightSweep(period: MotionTiming.sweepInterval * 1.3,
                        duration: MotionTiming.sweepDuration * 1.1,
                        color: .white,
                        opacity: 0.06,
                        angle: -12,
                        phase: 3.0)
            // Top-bar highlight
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04 + glowOsc * 0.04),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func centerPanelDepth() -> some View {
        modifier(CenterPanelDepthModifier())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ToolTransitionModifier
//
// Applies to the content inside the centre panel when the active tool changes.
// Achieves: smooth fade + scale + blur cleanup (no hard cuts).
//
// Usage:
//   Group {
//       switch selectedTool { … }
//   }
//   .toolTransition(id: viewModel.selectedTool?.id ?? "none")
// ─────────────────────────────────────────────────────────────────────────────

struct ToolTransitionModifier: ViewModifier {
    let id: String   // unique string for the current tool

    func body(content: Content) -> some View {
        content
            .id(id)   // forces SwiftUI to tear down / rebuild on id change
            .transition(
                .asymmetric(
                    insertion: .opacity
                        .combined(with: .scale(scale: 0.97))
                        .combined(with: .blur(radius: 6)),
                    removal: .opacity
                        .combined(with: .scale(scale: 1.02))
                        .combined(with: .blur(radius: 4))
                )
            )
            .animation(
                .easeInOut(duration: MotionTiming.toolFade),
                value: id
            )
    }
}

extension View {
    func toolTransition(id: String) -> some View {
        modifier(ToolTransitionModifier(id: id))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Blur transition extension
// ─────────────────────────────────────────────────────────────────────────────

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active:   BlurTransitionModifier(radius: radius),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
}

private struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}
