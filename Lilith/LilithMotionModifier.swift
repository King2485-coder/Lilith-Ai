import SwiftUI

struct LilithMotionModifier: ViewModifier {
    var state: LilithState
    var float: Bool
    var glow: Bool
    var rotate: Bool
    var pulse: Bool
    var audioLevel: CGFloat
    var lookOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: lookOffset.width, y: yOffset + lookOffset.height)
            .shadow(color: glowColor, radius: glowRadius)
            .rotationEffect(.degrees(rotation))
    }

    private var scale: CGFloat {
        switch state {
        case .idle: return float ? 1.01 : 0.99
        case .listening: return 1.02
        case .thinking: return 0.98
        case .responding: return 1.04
        case .interacting: return 0.97
        }
    }

    private var yOffset: CGFloat {
        switch state {
        case .idle: return float ? -6 : 6
        case .listening: return float ? -5 : 4
        case .thinking: return 0
        case .responding: return -8
        case .interacting: return 4
        }
    }

    private var glowColor: Color {
        switch state {
        case .idle: return .blue.opacity(glow ? 0.25 : 0.12)
        case .listening: return .blue.opacity(0.2 + audioLevel * 0.6)
        case .thinking: return .blue.opacity(0.4)
        case .responding: return .blue.opacity(0.5)
        case .interacting: return .blue.opacity(0.3)
        }
    }

    private var glowRadius: CGFloat {
        switch state {
        case .idle: return glow ? 20 : 10
        case .listening: return 10 + audioLevel * 30
        case .thinking: return 30
        case .responding: return 40
        case .interacting: return 18
        }
    }

    private var rotation: Double {
        switch state {
        case .idle: return rotate ? 1.5 : -1.5
        case .listening: return rotate ? 0.8 : -0.8
        case .thinking: return 0
        case .responding: return 0
        case .interacting: return 0
        }
    }
}
