import SwiftUI

// MARK: - Material 3 Color Tokens
struct MD3ColorSet {
    // Primary
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    // Secondary
    let secondary: Color
    let onSecondary: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color
    // Tertiary
    let tertiary: Color
    let onTertiary: Color
    let tertiaryContainer: Color
    let onTertiaryContainer: Color
    // Surface / Background
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color
    let background: Color
    let onBackground: Color
    let outline: Color
    let outlineVariant: Color
    // Error
    let error: Color
    let onError: Color
    let errorContainer: Color
    let onErrorContainer: Color
    // Shadow / inverse
    let shadow: Color
    let inverseSurface: Color
    let inverseOnSurface: Color
    let inversePrimary: Color
}

extension MD3ColorSet {
    static let light = MD3ColorSet(
        primary: Color(hex: 0x6750A4),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xEADDFF),
        onPrimaryContainer: Color(hex: 0x21005D),
        secondary: Color(hex: 0x625B71),
        onSecondary: Color(hex: 0xFFFFFF),
        secondaryContainer: Color(hex: 0xE8DEF8),
        onSecondaryContainer: Color(hex: 0x1D192B),
        tertiary: Color(hex: 0x7D5260),
        onTertiary: Color(hex: 0xFFFFFF),
        tertiaryContainer: Color(hex: 0xFFD8E4),
        onTertiaryContainer: Color(hex: 0x31111D),
        surface: Color(hex: 0xFEF7FF),
        onSurface: Color(hex: 0x1C1B1F),
        surfaceVariant: Color(hex: 0xE7E0EC),
        onSurfaceVariant: Color(hex: 0x49454F),
        background: Color(hex: 0xFEF7FF),
        onBackground: Color(hex: 0x1C1B1F),
        outline: Color(hex: 0x79747E),
        outlineVariant: Color(hex: 0xCAC4D0),
        error: Color(hex: 0xB3261E),
        onError: Color(hex: 0xFFFFFF),
        errorContainer: Color(hex: 0xF9DEDC),
        onErrorContainer: Color(hex: 0x410E0B),
        shadow: Color(hex: 0x000000),
        inverseSurface: Color(hex: 0x313033),
        inverseOnSurface: Color(hex: 0xF4EFF4),
        inversePrimary: Color(hex: 0xD0BCFF)
    )

    static let dark = MD3ColorSet(
        primary: Color(hex: 0xD0BCFF),
        onPrimary: Color(hex: 0x381E72),
        primaryContainer: Color(hex: 0x4F378B),
        onPrimaryContainer: Color(hex: 0xEADDFF),
        secondary: Color(hex: 0xCCC2DC),
        onSecondary: Color(hex: 0x332D41),
        secondaryContainer: Color(hex: 0x4A4458),
        onSecondaryContainer: Color(hex: 0xE8DEF8),
        tertiary: Color(hex: 0xEFB8C8),
        onTertiary: Color(hex: 0x492532),
        tertiaryContainer: Color(hex: 0x633B48),
        onTertiaryContainer: Color(hex: 0xFFD8E4),
        surface: Color(hex: 0x1C1B1F),
        onSurface: Color(hex: 0xE6E1E5),
        surfaceVariant: Color(hex: 0x49454F),
        onSurfaceVariant: Color(hex: 0xCAC4D0),
        background: Color(hex: 0x1C1B1F),
        onBackground: Color(hex: 0xE6E1E5),
        outline: Color(hex: 0x938F99),
        outlineVariant: Color(hex: 0x49454F),
        error: Color(hex: 0xF2B8B5),
        onError: Color(hex: 0x601410),
        errorContainer: Color(hex: 0x8C1D18),
        onErrorContainer: Color(hex: 0xF9DEDC),
        shadow: Color(hex: 0x000000),
        inverseSurface: Color(hex: 0xE6E1E5),
        inverseOnSurface: Color(hex: 0x313033),
        inversePrimary: Color(hex: 0x6750A4)
    )
}

// MARK: - M3 Type Scale
struct MD3TypeScale {
    let displayLarge: Font
    let displayMedium: Font
    let displaySmall: Font
    let headlineLarge: Font
    let headlineMedium: Font
    let headlineSmall: Font
    let titleLarge: Font
    let titleMedium: Font
    let titleSmall: Font
    let bodyLarge: Font
    let bodyMedium: Font
    let bodySmall: Font
    let labelLarge: Font
    let labelMedium: Font
    let labelSmall: Font

    static let standard = MD3TypeScale(
        displayLarge: .system(size: 57, weight: .regular, design: .default),
        displayMedium: .system(size: 45, weight: .regular, design: .default),
        displaySmall: .system(size: 36, weight: .regular, design: .default),
        headlineLarge: .system(size: 32, weight: .semibold, design: .default),
        headlineMedium: .system(size: 28, weight: .semibold, design: .default),
        headlineSmall: .system(size: 24, weight: .semibold, design: .default),
        titleLarge: .system(size: 22, weight: .medium, design: .default),
        titleMedium: .system(size: 16, weight: .medium, design: .default),
        titleSmall: .system(size: 14, weight: .medium, design: .default),
        bodyLarge: .system(size: 16, weight: .regular, design: .default),
        bodyMedium: .system(size: 14, weight: .regular, design: .default),
        bodySmall: .system(size: 12, weight: .regular, design: .default),
        labelLarge: .system(size: 14, weight: .medium, design: .default),
        labelMedium: .system(size: 12, weight: .medium, design: .default),
        labelSmall: .system(size: 11, weight: .medium, design: .default)
    )
}

// MARK: - Theme Observable Object
final class MD3Theme: ObservableObject {
    @Published var colorScheme: ColorScheme = .light
    @Published var colors: MD3ColorSet = .light
    @Published var typeScale: MD3TypeScale = .standard

    func applyColorScheme(_ scheme: ColorScheme) {
        colorScheme = scheme
        colors = scheme == .dark ? .dark : .light
    }
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - View Modifier Convenience
extension View {
    func md3DisplayLarge() -> some View {
        modifier(MD3FontModifier(font: .standard.displayLarge))
    }
    func md3HeadlineMedium() -> some View {
        modifier(MD3FontModifier(font: .standard.headlineMedium))
    }
    func md3TitleLarge() -> some View {
        modifier(MD3FontModifier(font: .standard.titleLarge))
    }
    func md3TitleMedium() -> some View {
        modifier(MD3FontModifier(font: .standard.titleMedium))
    }
    func md3BodyLarge() -> some View {
        modifier(MD3FontModifier(font: .standard.bodyLarge))
    }
    func md3BodyMedium() -> some View {
        modifier(MD3FontModifier(font: .standard.bodyMedium))
    }
    func md3LabelLarge() -> some View {
        modifier(MD3FontModifier(font: .standard.labelLarge))
    }
}

struct MD3FontModifier: ViewModifier {
    let font: Font
    func body(content: Content) -> some View {
        content.font(font)
    }
}
