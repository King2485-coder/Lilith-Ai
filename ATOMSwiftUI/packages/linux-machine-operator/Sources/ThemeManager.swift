import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private init() {}
    
    var primaryBackground: Color {
        Color(light: Color(hex: "F3F4F6"), dark: Color(hex: "111827"))
    }
    
    var secondaryBackground: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1F2937"))
    }
    
    var tertiaryBackground: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "374151"))
    }
    
    var cardBackground: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1F2937"))
    }
    
    var primaryText: Color {
        Color(light: Color(hex: "1F2937"), dark: Color(hex: "F9FAFB"))
    }
    
    var secondaryText: Color {
        Color(light: Color(hex: "4B5563"), dark: Color(hex: "D1D5DB"))
    }
    
    var tertiaryText: Color {
        Color(light: Color(hex: "6B7280"), dark: Color(hex: "9CA3AF"))
    }
    
    var accent: Color {
        Color(light: Color(hex: "4B5563"), dark: Color(hex: "9CA3AF"))
    }
    
    var accentSubtle: Color {
        Color(light: Color(hex: "F3F4F6"), dark: Color(hex: "374151"))
    }
    
    var border: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "4B5563"))
    }
    
    var cardBorder: Color {
        Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.1))
    }
    
    var divider: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "374151"))
    }
    
    var success: Color {
        Color(light: Color(hex: "10B981"), dark: Color(hex: "34D399"))
    }
    
    var error: Color {
        Color(light: Color(hex: "EF4444"), dark: Color(hex: "F87171"))
    }
    
    var warning: Color {
        Color(light: Color(hex: "F59E0B"), dark: Color(hex: "FBBF24"))
    }
    
    var shadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    let radiusSmall: CGFloat = 8
    let radiusMedium: CGFloat = 12
    let radiusLarge: CGFloat = 16
    let radiusXL: CGFloat = 20
    let radiusFull: CGFloat = 100
    
    let spacingXS: CGFloat = 4
    let spacingS: CGFloat = 8
    let spacingM: CGFloat = 12
    let spacingL: CGFloat = 16
    let spacingXL: CGFloat = 20
    let spacingXXL: CGFloat = 24
    let spacingSection: CGFloat = 32
    
    let shadowRadiusSmall: CGFloat = 8
    let shadowRadiusMedium: CGFloat = 16
    let shadowRadiusLarge: CGFloat = 24
    
    var springSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    var springSmooth: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    var springBouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }
    
    var easeQuick: Animation {
        .easeOut(duration: 0.2)
    }
    
    var easeMedium: Animation {
        .easeInOut(duration: 0.3)
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}