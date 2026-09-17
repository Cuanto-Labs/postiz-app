import CuantoUI
import SwiftUI

/// Brand identity for a channel — the colour + glyph that says "this is Instagram" when the
/// avatar is missing, still loading, or grayscaled out in the picker. Keyed by Postiz provider
/// identifier, the same key space as `PlatformRules.table` and `ProviderSettingsCatalog`; suffixed
/// variants (`instagram-standalone`, `linkedin-page`, `facebook-page`) share the parent brand, and
/// an identifier the table doesn't know falls back to a neutral mark rather than disappearing.
enum ProviderIdentity {
    static func symbol(for identifier: String) -> String { mark(for: identifier).symbol }
    static func color(for identifier: String) -> Color { mark(for: identifier).color }

    private static func mark(for identifier: String) -> (symbol: String, color: Color) {
        let base = identifier.split(separator: "-").first.map(String.init) ?? identifier
        return marks[base] ?? ("globe", Color(hex: 0x999999))
    }

    /// Glyphs are SF Symbols that read as the platform's own metaphor (camera for Instagram,
    /// briefcase for LinkedIn) — the brands' real logos aren't licensable as app assets.
    private static let marks: [String: (symbol: String, color: Color)] = [
        "instagram": ("camera.fill", Color(hex: 0xE1306C)),
        "linkedin": ("briefcase.fill", Color(hex: 0x0A66C2)),
        "facebook": ("person.2.fill", Color(hex: 0x1877F2)),
        "x": ("xmark", Color(hex: 0x000000)),
        "threads": ("at", Color(hex: 0x000000)),
        "tiktok": ("music.note", Color(hex: 0x010101)),
        "youtube": ("play.fill", Color(hex: 0xFF0000)),
        "pinterest": ("pin.fill", Color(hex: 0xE60023)),
        "bluesky": ("cloud.fill", Color(hex: 0x0285FF)),
        "mastodon": ("person.3.fill", Color(hex: 0x6364FF)),
        "telegram": ("paperplane.fill", Color(hex: 0x229ED9)),
        "discord": ("message.fill", Color(hex: 0x5865F2)),
        "slack": ("number", Color(hex: 0x4A154B)),
        "reddit": ("antenna.radiowaves.left.and.right", Color(hex: 0xFF4500)),
        "dribbble": ("basketball.fill", Color(hex: 0xEA4C89)),
    ]
}

/// The identity mark as a small badge — a filled brand disc with the provider glyph, sized by
/// `size` (its diameter). Decorative: every call site already names the channel in its own
/// accessibility label, so this stays hidden from VoiceOver.
struct ProviderBadge: View {
    let identifier: String
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(ProviderIdentity.color(for: identifier))
            .overlay {
                Image(systemName: ProviderIdentity.symbol(for: identifier))
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
