import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ImmersiveDashboard
//
// This is the MOTION-ONLY shell that wraps your existing screen.
// It does NOT redesign or move any controls.
//
// HOW TO USE
// ──────────
// Replace your root screen ZStack background with FuturisticBackground().
// Then layer ImmersiveMotionOverlay on top of the background but BELOW your UI.
// Finally apply the modifiers to individual UI elements as shown below.
//
// Minimal integration example:
//
//   var body: some View {
//       ZStack {
//           FuturisticBackground()           // ← new: replaces plain Color.black
//
//           ImmersiveMotionOverlay()         // ← new: particles + energy rings
//
//           // ── your existing content starts here ──────────────────────────
//           VStack {
//               EnergyCoreView(diameter: 96)  // ← drop where your orb was
//               …
//               HStack {
//                   LiveScanButton(diameter: 60) { /* your SCAN label */ }
//                   LiveSendButton(diameter: 82) { /* your SEND label */ }
//                   LivePayButton(diameter: 60)  { /* your PAY label */  }
//               }
//               …
//           }
//           .centerPanelDepth()              // ← new: floating depth on centre
//
//           // side panels — swap .transition(.move) for .futuristicPanel
//           if showLeftPanel {
//               LeftPanelView()
//                   .livePanel(phase: 0, edge: .leading)
//                   .parallax(depth: 0.15)
//                   .transition(.futuristicPanel(edge: .leading))
//           }
//           if showRightPanel {
//               RightPanelView()
//                   .livePanel(phase: 2.3, edge: .trailing)
//                   .parallax(depth: 0.15)
//                   .transition(.futuristicPanel(edge: .trailing))
//           }
//       }
//       .animation(.easeInOut(duration: MotionTiming.panelSlide), value: showLeftPanel)
//       .animation(.easeInOut(duration: MotionTiming.panelSlide), value: showRightPanel)
//   }
//
// ─────────────────────────────────────────────────────────────────────────────

/// Particle field + mid-depth ring layer.
/// Place this ABOVE FuturisticBackground but BELOW your existing UI layout.
struct ImmersiveMotionOverlay: View {
    var body: some View {
        ZStack {
            // Floating particles (depth 0.65 parallax internally)
            FloatingParticleField()

            // HUD decorative rings — between background and panels
            HUDRingLayer()
                .allowsHitTesting(false)
                .parallax(depth: 0.45)
        }
        .allowsHitTesting(false)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - HUDRingLayer
// Mid-depth decorative arc/ring geometry that sits between background and UI.
// ─────────────────────────────────────────────────────────────────────────────

private struct HUDRingLayer: View {
    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width  / 2
            let cy = geo.size.height * 0.36

            ZStack {
                // Large outer thin ring
                RotatingRingView(
                    radius:    min(geo.size.width, geo.size.height) * 0.44,
                    lineWidth: 0.7,
                    color:     Color.blue.opacity(0.07),
                    arcLength: 300,
                    period:    MotionTiming.ringSlowCW * 1.4,
                    clockwise: true,
                    phase:     0
                )
                .position(x: cx, y: cy)

                // Medium accent ring
                RotatingRingView(
                    radius:    min(geo.size.width, geo.size.height) * 0.35,
                    lineWidth: 0.5,
                    color:     Color.cyan.opacity(0.06),
                    arcLength: 180,
                    period:    MotionTiming.ringFastCCW * 1.2,
                    clockwise: false,
                    phase:     90
                )
                .position(x: cx, y: cy)

                // Small fast inner ring
                RotatingRingView(
                    radius:    min(geo.size.width, geo.size.height) * 0.22,
                    lineWidth: 1.0,
                    color:     Color.blue.opacity(0.09),
                    arcLength: 120,
                    period:    MotionTiming.energyRing * 1.3,
                    clockwise: true,
                    phase:     45
                )
                .position(x: cx, y: cy)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Full integration preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview("Immersive Motion Preview") {
    ZStack {
        // Background layer (deepest)
        FuturisticBackground()

        // Mid-depth motion overlay
        ImmersiveMotionOverlay()

        // Simulated screen content
        VStack(spacing: 28) {
            Spacer()

            // Energy core where the top orb lives
            EnergyCoreView(diameter: 100)

            Text("AI DASHBOARD")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(4)

            Spacer()

            // Main action row
            HStack(spacing: 32) {
                LiveScanButton(diameter: 64) {
                    VStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 20, weight: .light))
                        Text("SCAN")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                }

                LiveSendButton(diameter: 88) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 24, weight: .light))
                        Text("SEND")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                }

                LivePayButton(diameter: 64) {
                    VStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 20, weight: .light))
                        Text("PAY")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                }
            }

            // Small utility icons
            HStack(spacing: 24) {
                ForEach(Array(["mic", "camera", "qrcode", "bolt"].enumerated()), id: \.offset) { i, icon in
                    LiveIconButton(phase: Double(i) * 0.7) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                    }
                }
            }

            Spacer().frame(height: 48)
        }
        .centerPanelDepth()
        .parallax(depth: 0.08)
    }
    .preferredColorScheme(.dark)
}
