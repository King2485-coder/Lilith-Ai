import SwiftUI

enum LilithState: String, CaseIterable {
    case idle
    case listening
    case thinking
    case responding
    case interacting
}

class LilithStateManager: ObservableObject {
    @Published var state: LilithState = .idle

    func set(_ newState: LilithState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = newState
        }
    }
}
