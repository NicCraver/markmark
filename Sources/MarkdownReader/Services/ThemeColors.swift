import SwiftUI

// MARK: - 主题颜色令牌

/// 从 ThemeDefinition 派生的颜色令牌，参照 buddy-macos 的 deriveTokens()
/// 用于通过 SwiftUI Environment 传递到所有视图
struct ThemeColors: Equatable, Sendable {
    // 核心色
    let surface: Color
    let ink: Color
    let accent: Color
    let success: Color
    let danger: Color

    // 派生背景色
    let bgElevated: Color
    let bgSubtle: Color
    let bgMuted: Color

    // 派生文字色
    let fgSecondary: Color
    let fgMuted: Color

    // 派生强调色
    let accentHover: Color
    let accentSoft: Color

    // 派生边框色
    let border: Color
    let borderSubtle: Color

    /// 从 ThemeDefinition 和对比度派生颜色
    static func from(_ theme: ThemeDefinition) -> ThemeColors {
        let c = Double(theme.contrast) / 100.0
        let isDark = theme.type == .dark

        let surface = Color(hex: theme.surface) ?? .black
        let ink = Color(hex: theme.ink) ?? .white
        let accent = Color(hex: theme.accent) ?? .blue
        let success = Color(hex: theme.success) ?? .green
        let danger = Color(hex: theme.danger) ?? .red

        return ThemeColors(
            surface: surface,
            ink: ink,
            accent: accent,
            success: success,
            danger: danger,
            bgElevated: isDark
                ? surface.mixed(with: ink, fraction: 0.08 + c * 0.08)
                : surface.mixed(with: ink, fraction: 0.16 + c * 0.12),
            bgSubtle: isDark
                ? ink.opacity(0.02 + c * 0.02)
                : surface.mixed(with: ink, fraction: 0.08 + c * 0.08),
            bgMuted: isDark
                ? ink.opacity(0.04 + c * 0.03)
                : surface.mixed(with: ink, fraction: 0.12 + c * 0.10),
            fgSecondary: ink.opacity(0.65 + c * 0.10),
            fgMuted: isDark
                ? ink.opacity(0.42 + c * 0.13)
                : ink.opacity(0.45 + c * 0.10),
            accentHover: isDark
                ? accent.lighter(by: 0.12)
                : accent.darker(by: 0.08),
            accentSoft: isDark
                ? Color.black.mixed(with: accent, fraction: 0.20 + c * 0.08)
                : surface.mixed(with: accent, fraction: 0.11 + c * 0.04),
            border: ink.opacity(0.06 + c * 0.04),
            borderSubtle: ink.opacity(0.04 + c * 0.02)
        )
    }
}

// MARK: - SwiftUI Environment 支持

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.from(
        ThemeDefinition(id: "buddy-dark", name: "Buddy Dark", type: .dark,
                        surface: "#18181a", ink: "#e8e8e3", accent: "#339cff",
                        success: "#40c977", danger: "#fa423e", contrast: 60)
    )
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

extension View {
    func applyThemeColors(_ colors: ThemeColors) -> some View {
        environment(\.themeColors, colors)
    }
}

// MARK: - Color 混合辅助

extension Color {
    /// 将两个颜色按比例混合
    func mixed(with other: Color, fraction: Double) -> Color {
        let selfNS = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        let otherNS = NSColor(other).usingColorSpace(.sRGB) ?? NSColor.white
        let r = selfNS.redComponent * (1 - fraction) + otherNS.redComponent * fraction
        let g = selfNS.greenComponent * (1 - fraction) + otherNS.greenComponent * fraction
        let b = selfNS.blueComponent * (1 - fraction) + otherNS.blueComponent * fraction
        return Color(red: r, green: g, blue: b)
    }

    /// 变亮
    func lighter(by amount: Double) -> Color {
        mixed(with: .white, fraction: amount)
    }

    /// 变暗
    func darker(by amount: Double) -> Color {
        mixed(with: .black, fraction: amount)
    }
}
