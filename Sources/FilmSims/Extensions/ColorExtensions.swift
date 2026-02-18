import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Base Dark Theme Colors
    static let surfaceDark = Color(hex: "#050508")
    static let surfaceMedium = Color(hex: "#0A0A0E")     // Android SurfaceMedium 0xFF0A0A0E
    static let surfaceLight = Color(hex: "#151519")
    static let surfaceElevated = Color(hex: "#1E1E24")
    
    // Glass Effect Colors
    static let glassBackground = Color(hex: "#101014").opacity(0.94)
    static let glassBackgroundLight = Color(hex: "#161620").opacity(0.72)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassBorderLight = Color.white.opacity(0.08)
    static let glassHighlight = Color.white.opacity(0.06)

    // Android Liquid palette (glass surfaces)
    static let glassSurface = Color.white.opacity(0.125)      // 0x20FFFFFF
    static let glassSurfaceDark = Color.white.opacity(0.082)  // 0x15FFFFFF
    static let glassBorderAndroid = Color.white.opacity(0.094) // 0x18FFFFFF
    static let glassBorderHighlightAndroid = Color.white.opacity(0.145) // 0x25FFFFFF
    
    // Accent Colors - Warm amber/gold palette
    static let accentStart = Color(hex: "#FF8A50")
    static let accentEnd = Color(hex: "#FFC06A")
    static let accentPrimary = Color(hex: "#FFAB60")
    static let accentDark = Color(hex: "#E07830")
    static let accentGlow = Color(hex: "#FF8A50").opacity(0.2)
    static let accentGlowStrong = Color(hex: "#FF8A50").opacity(0.3)
    
    // Secondary Accent - Soft cyan (Android AccentSecondary 0xFF40C4B0)
    static let secondaryStart = Color(hex: "#40C4B0")
    static let secondaryEnd = Color(hex: "#60D4C4")
    static let accentSecondary = Color(hex: "#40C4B0")

    // Tertiary accent (purple)
    static let accentTertiary = Color(hex: "#6200EE")
    
    // Text Colors (matches Android LiquidColors exactly)
    static let textPrimary = Color(hex: "#F0F0F0")        // Android TextHighEmphasis 0xFFF0F0F0
    static let textSecondary = Color.white.opacity(0.847) // Android TextMediumEmphasis 0xD8FFFFFF
    static let textTertiary = Color.white.opacity(0.502)  // Android TextLowEmphasis 0x80FFFFFF
    static let textDisabled = Color.white.opacity(0.25)
    
    // Utility Colors
    static let overlayDark = Color.black.opacity(0.91)
    static let overlayMedium = Color.black.opacity(0.72)
    static let rippleLight = Color.white.opacity(0.09)
    static let rippleAccent = Color(hex: "#FFAB60").opacity(0.16)
    
    // Selection State Colors (matches Android LiquidColors)
    static let chipSelectedBackground = Color(hex: "#FFAB60")
    static let chipSelectedText = Color(hex: "#0C0C10")    // Android ChipSelectedText 0xFF0C0C10
    static let chipUnselectedBackground = Color.white.opacity(0.157) // 0x28FFFFFF
    static let chipUnselectedText = Color.white.opacity(0.847) // 0xD8FFFFFF
    
    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
