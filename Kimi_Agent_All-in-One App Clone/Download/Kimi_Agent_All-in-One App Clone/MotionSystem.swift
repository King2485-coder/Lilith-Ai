import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Unified Animation Timing Constants
// All durations are prime-ish multiples so animations never perfectly sync
// and the whole screen feels organically alive rather than mechanical.
// ─────────────────────────────────────────────────────────────────────────────

enum MotionTiming {
    // Core breathing — the slowest heartbeat everything else references
    static let breathSlow:   Double = 4.8
    static let breathMedium: Double = 3.2
    static let breathFast:   Double = 1.9

    // Ring / halo rotation
    static let ringSlowCW:   Double = 18.0   // outer decorative ring
    static let ringFastCCW:  Double = 11.0   // inner accent ring (counter-clock)
    static let energyRing:   Double =  7.3   // energy core inner ring

    // Particle drift
    static let particleDrift: Double = 6.0   // average drift cycle

    // Light sweeps
    static let sweepInterval: Double = 6.5   // seconds between sweep passes
    static let sweepDuration: Double = 1.8   // duration of each pass

    // Panel shimmer
    static let panelShimmer:  Double = 4.1

    // Panel show / hide
    static let panelSlide:    Double = 0.42

    // Tool transition
    static let toolFade:      Double = 0.35
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MotionClock  (single source of truth for phase-based animation)
// Publish a monotonic "beat" every 100 ms so views can compute their own
// phase offsets without each needing their own Timer.
// ─────────────────────────────────────────────────────────────────────────────

final class MotionClock: ObservableObject {
    static let shared = MotionClock()

    /// Seconds elapsed since app launch — drives all phase calculations.
    @Published private(set) var time: Double = 0

    private var cancellable: AnyCancellable?
    private let start = Date()

    private init() {
        cancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.time = Date().timeIntervalSince(self.start)
            }
    }

    // Convenience: normalised oscillator between 0…1
    // phase offsets let different elements be out of sync naturally
    func osc(period: Double, offset: Double = 0) -> Double {
        let t = (time + offset).truncatingRemainder(dividingBy: period) / period
        return (sin(t * 2 * .pi) + 1) / 2   // 0…1
    }

    // Sawtooth 0…1 — useful for one-way sweeps
    func saw(period: Double, offset: Double = 0) -> Double {
        (time + offset).truncatingRemainder(dividingBy: period) / period
    }
}
