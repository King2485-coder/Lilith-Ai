import SwiftUI
import CoreMotion

final class UnifiedMotionManager: ObservableObject {
    private let manager = CMMotionManager()

    @Published var motionX: CGFloat = 0
    @Published var motionY: CGFloat = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 40.0

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }

            let pitch = motion.attitude.pitch
            let roll = motion.attitude.roll

            self?.motionX = CGFloat(max(min(roll * 14, 12), -12))
            self?.motionY = CGFloat(max(min(pitch * 14, 12), -12))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
