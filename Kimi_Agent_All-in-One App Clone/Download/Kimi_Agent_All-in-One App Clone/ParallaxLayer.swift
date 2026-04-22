import SwiftUI
import CoreMotion

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ParallaxMotionManager
// Reads device attitude (gyroscope/accelerometer) and publishes a normalised
// 2-D offset in the range –1…+1 on each axis.
// Falls back to drag-based parallax when motion hardware is unavailable.
// ─────────────────────────────────────────────────────────────────────────────

final class ParallaxMotionManager: ObservableObject {
    static let shared = ParallaxMotionManager()

    /// Normalised tilt offset, range –1…+1 per axis
    @Published private(set) var offset: CGSize = .zero

    private let motion = CMMotionManager()
    private let queue  = OperationQueue()

    // Sensitivity multiplier — tweak without touching callers
    private let sensitivity: Double = 12.0
    // Low-pass filter coefficient (0 = no response, 1 = no smoothing)
    private let alpha: Double = 0.12

    private var rawX: Double = 0
    private var rawY: Double = 0

    private init() {
        queue.maxConcurrentOperationCount = 1
        start()
    }

    deinit { stop() }

    private func start() {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30.0
            motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                // Use attitude roll/pitch for x/y tilt
                let newX = data.attitude.roll   // side tilt
                let newY = data.attitude.pitch  // forward/back tilt

                // Low-pass smooth
                self.rawX += self.alpha * (newX - self.rawX)
                self.rawY += self.alpha * (newY - self.rawY)

                let clampedX = max(-1, min(1, self.rawX * self.sensitivity / 10.0))
                let clampedY = max(-1, min(1, self.rawY * self.sensitivity / 10.0))

                DispatchQueue.main.async {
                    self.offset = CGSize(width: clampedX, height: clampedY)
                }
            }
        }
        // If not available, offset stays .zero; drag fallback is handled in the view
    }

    private func stop() {
        motion.stopDeviceMotionUpdates()
    }

    // Call this from a drag gesture for simulator / devices without motion
    func applyDrag(_ translation: CGSize, in size: CGSize) {
        guard !motion.isDeviceMotionAvailable else { return }
        let nx = max(-1, min(1, translation.width  / (size.width  / 2)))
        let ny = max(-1, min(1, translation.height / (size.height / 2)))
        withAnimation(.interactiveSpring()) {
            offset = CGSize(width: nx, height: ny)
        }
    }

    func resetDrag() {
        guard !motion.isDeviceMotionAvailable else { return }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            offset = .zero
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ParallaxLayer ViewModifier
//
// Wrap any view with .parallax(depth:) to shift it relative to the global
// ParallaxMotionManager.  depth = 1.0 is maximum shift (background).
// depth = 0.0 = no movement (foreground buttons).
// ─────────────────────────────────────────────────────────────────────────────

struct ParallaxModifier: ViewModifier {
    @ObservedObject private var motion = ParallaxMotionManager.shared

    /// 0.0 (foreground / no shift) … 1.0 (background / full shift)
    let depth: Double

    /// Max pixel displacement at depth = 1.0
    private let maxShift: Double = 14.0

    func body(content: Content) -> some View {
        content
            .offset(
                x: motion.offset.width  * maxShift * depth,
                y: motion.offset.height * maxShift * depth
            )
    }
}

extension View {
    /// Apply gyroscope/drag parallax.  depth: 0 (none) … 1 (max background)
    func parallax(depth: Double) -> some View {
        modifier(ParallaxModifier(depth: depth))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FuturisticBackground
// Multi-layer parallax background: deep grid → ring field → star field.
// Each layer shifts at its own depth value so they move at different rates.
// ─────────────────────────────────────────────────────────────────────────────

struct FuturisticBackground: View {
    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 0 — deep black base
                Color.black

                // Layer 1 — slow radial grid (deepest, moves most)
                PerspectiveGridLayer()
                    .parallax(depth: 1.0)

                // Layer 2 — large decorative rings
                BackgroundRingLayer(size: geo.size)
                    .parallax(depth: 0.75)

                // Layer 3 — star/dot field
                StarFieldLayer(size: geo.size)
                    .parallax(depth: 0.55)

                // Layer 4 — atmospheric ambient glow blob
                RadialGlowBlob()
                    .parallax(depth: 0.35)
            }
        }
        .ignoresSafeArea()
    }
}

// ── Sub-layers ───────────────────────────────────────────────────────────────

private struct PerspectiveGridLayer: View {
    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        Canvas { ctx, size in
            let cols = 10
            let rows = 16
            let cw = size.width  / CGFloat(cols)
            let ch = size.height / CGFloat(rows)

            // Very slow vertical drift
            let drift = CGFloat(clock.time.truncatingRemainder(dividingBy: ch)) * 0.15

            var path = Path()
            for c in 0...cols {
                let x = CGFloat(c) * cw
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 0...rows {
                let y = CGFloat(r) * ch + drift
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.blue.opacity(0.04)), lineWidth: 0.5)
        }
    }
}

private struct BackgroundRingLayer: View {
    let size: CGSize
    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        let cx = size.width / 2
        let cy = size.height * 0.38

        Canvas { ctx, _ in
            // Three slow decorative arcs at different radii
            let radii: [(r: CGFloat, op: Double, speed: Double)] = [
                (200, 0.06, MotionTiming.ringSlowCW),
                (280, 0.04, MotionTiming.ringSlowCW * 1.3),
                (360, 0.03, MotionTiming.ringSlowCW * 0.7),
            ]

            for spec in radii {
                let angle = clock.time / spec.speed * 2 * .pi
                let rect  = CGRect(x: cx - spec.r, y: cy - spec.r,
                                   width: spec.r * 2, height: spec.r * 2)
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy),
                           radius: spec.r,
                           startAngle: .radians(angle),
                           endAngle:   .radians(angle + .pi * 1.1),
                           clockwise: false)
                ctx.stroke(arc,
                           with: .color(Color.blue.opacity(spec.op)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct StarFieldLayer: View {
    let size: CGSize
    @ObservedObject private var clock = MotionClock.shared

    // Fixed star positions (deterministic via seeded random)
    private let stars: [(CGPoint, Double)] = {
        var rng = SeedRNG(seed: 42)
        return (0..<80).map { _ in
            let x  = rng.next() * 1.0
            let y  = rng.next() * 1.0
            let ph = rng.next() * 6.28
            return (CGPoint(x: x, y: y), ph)
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for (rel, phase) in stars {
                let x   = rel.x * size.width
                let y   = rel.y * size.height
                let osc = (sin(clock.time * 0.6 + phase) + 1) / 2
                let op  = 0.06 + osc * 0.10
                let r   = CGFloat(0.8 + osc * 0.6)

                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                          width: r * 2, height: r * 2)),
                    with: .color(Color.white.opacity(op))
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct RadialGlowBlob: View {
    @ObservedObject private var clock = MotionClock.shared

    var body: some View {
        GeometryReader { geo in
            let osc = clock.osc(period: MotionTiming.breathSlow)
            let op  = 0.08 + osc * 0.05

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(op), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * 0.55
                    )
                )
                .frame(width: geo.size.width * 0.9,
                       height: geo.size.height * 0.5)
                .position(x: geo.size.width / 2,
                          y: geo.size.height * 0.3)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Simple seeded RNG (no import needed)
// ─────────────────────────────────────────────────────────────────────────────

private struct SeedRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let value = Double(state >> 33) / Double(UInt32.max)
        return value
    }
}
