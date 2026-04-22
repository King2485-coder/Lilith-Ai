import SwiftUI

enum LilithTheme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.07)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.11)
    static let elevated = Color(red: 0.15, green: 0.16, blue: 0.15)
    static let border = Color.white.opacity(0.08)
    static let accentA = Color(red: 0.38, green: 0.78, blue: 0.55)
    static let accentB = Color(red: 0.90, green: 0.74, blue: 0.37)
    static let accentC = Color(red: 0.58, green: 0.74, blue: 0.92)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)

    static let heroGradient = LinearGradient(
        colors: [accentA.opacity(0.94), Color(red: 0.24, green: 0.35, blue: 0.28), accentB.opacity(0.92)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glowGradient = RadialGradient(
        colors: [accentA.opacity(0.22), accentB.opacity(0.14), .clear],
        center: .topLeading,
        startRadius: 30,
        endRadius: 460
    )
}
