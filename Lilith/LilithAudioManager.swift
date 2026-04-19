import AVFoundation
import SwiftUI

/// Lightweight audio level meter for reactive glow.
final class LilithAudioManager: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?

    @Published var level: CGFloat = 0

    func startListening() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        let url = URL(fileURLWithPath: "/dev/null")

        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
            let normalized = max(0, (power + 60) / 60) // 0...1
            self.level = CGFloat(normalized)
        }
    }

    func stopListening() {
        audioRecorder?.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }

    deinit { stopListening() }
}
