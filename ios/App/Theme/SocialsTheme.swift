import CuantoUI
import SwiftUI

/// The app's design tokens, taken from the web app's own CSS custom properties so iOS and
/// web read as one product — see `ios/brand-spec.md` for the full contract and the rules
/// about which role means what (green = primary action / connected, indigo = AI / switched on).
///
/// The web product is dark-only (`apps/frontend/src/app/(app)/layout.tsx` hardcodes `dark`),
/// so `CuantoSocialsApp` pins the app to `.dark`. The light values exist for the widget and
/// share extensions, which render inside system surfaces that follow the device appearance.
extension Theme {
    static let socials = Theme(
        colors: .socialsDark,
        // Web's dominant radius is 8px with pills for chips/avatars; `full` keeps capsules.
        radius: Radius(sm: 8, md: 12, lg: 16, full: 999),
        typeScale: .socials
    )

    /// For the widget/share targets, which must resolve in light mode too.
    static let socialsAdaptive = Theme(
        colors: .socialsAdaptive,
        radius: Radius(sm: 8, md: 12, lg: 16, full: 999),
        typeScale: .socials
    )
}

extension ColorPalette {
    /// Canonical brand palette — the web app's `--new-*` custom properties, verbatim.
    static let socialsDark = ColorPalette(
        background: Color(hex: 0x0E0E0E),
        foreground: .white,
        card: Color(hex: 0x1A1919),
        cardForeground: .white,
        primary: Color(hex: 0x10B981),
        secondary: Color(hex: 0x1A1919),
        secondaryForeground: Color(hex: 0x999999),
        muted: Color(hex: 0x252525),
        mutedForeground: Color(hex: 0x999999),
        accent: Color(hex: 0x6366F1),
        border: Color(hex: 0x252525),
        destructive: Color(hex: 0xB91C1C),
        success: Color(hex: 0x10B981)
    )

    /// Same roles, resolved per appearance — used where the system owns the surface.
    static let socialsAdaptive = ColorPalette(
        background: Color(light: 0xFFFFFF, dark: 0x0E0E0E),
        foreground: Color(light: 0x0E0E0E, dark: 0xFFFFFF),
        card: Color(light: 0xF6F6F6, dark: 0x1A1919),
        cardForeground: Color(light: 0x0E0E0E, dark: 0xFFFFFF),
        primary: Color(light: 0x0F9F74, dark: 0x10B981),
        secondary: Color(light: 0xF6F6F6, dark: 0x1A1919),
        secondaryForeground: Color(light: 0x5A5A5A, dark: 0x999999),
        muted: Color(light: 0xEDEDED, dark: 0x252525),
        mutedForeground: Color(light: 0x5A5A5A, dark: 0x999999),
        accent: Color(light: 0x4F46E5, dark: 0x6366F1),
        border: Color(light: 0xE2E2E2, dark: 0x252525),
        destructive: Color(light: 0xB91C1C, dark: 0xB91C1C),
        success: Color(light: 0x0F9F74, dark: 0x10B981)
    )
}

extension TypeScale {
    /// Plus Jakarta Sans, the web app's family (bundled OFL copies in `ios/Fonts/`), mapped
    /// through `.custom(_:size:relativeTo:)` so every level still scales with Dynamic Type.
    static let socials = TypeScale(
        largeTitle: .custom(SocialsFont.bold, size: 34, relativeTo: .largeTitle),
        title: .custom(SocialsFont.bold, size: 28, relativeTo: .title),
        headline: .custom(SocialsFont.semiBold, size: 17, relativeTo: .headline),
        body: .custom(SocialsFont.medium, size: 17, relativeTo: .body),
        callout: .custom(SocialsFont.medium, size: 16, relativeTo: .callout),
        footnote: .custom(SocialsFont.medium, size: 13, relativeTo: .footnote),
        caption: .custom(SocialsFont.medium, size: 12, relativeTo: .caption)
    )
}

/// PostScript names of the bundled faces. Wrong names fail silently (SwiftUI falls back to
/// the system font), so `SocialsThemeTests` asserts each one resolves.
enum SocialsFont {
    static let medium = "PlusJakartaSans-Medium"
    static let semiBold = "PlusJakartaSans-SemiBold"
    static let bold = "PlusJakartaSans-Bold"

    static let all = [medium, semiBold, bold]
}

/// Motion durations from the web app's CSS (`global.scss`), so a control's colour change or a
/// sheet's entrance takes the same time on both platforms. See brand-spec.md § Motion.
enum SocialsMotion {
    /// `transition-colors` on buttons/cards.
    static let control = Animation.easeInOut(duration: 0.15)
    /// `fadeIn` / `fadeDown` entrances.
    static let entrance = Animation.smooth(duration: 0.3)
    /// `overFlow` accordion reveals.
    static let reveal = Animation.smooth(duration: 0.35)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Appearance-resolving colour for the extension targets.
    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(traits.userInterfaceStyle == .dark ? Color(hex: dark) : Color(hex: light))
            })
    }
}
