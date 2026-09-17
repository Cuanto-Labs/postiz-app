import Foundation

/// Per-provider posting limits, resolved from the static fallback table below
/// unless the server supplies its own `maxCharacters`/`editor` for a channel.
public struct PlatformLimits: Sendable, Equatable {
    public let maxCharacters: Int
    public let maxImages: Int
    public let maxVideos: Int
    public let mediaRequired: Bool
    public let supportsMentions: Bool
    public let editor: String

    public init(
        maxCharacters: Int,
        maxImages: Int,
        maxVideos: Int,
        mediaRequired: Bool,
        supportsMentions: Bool,
        editor: String
    ) {
        self.maxCharacters = maxCharacters
        self.maxImages = maxImages
        self.maxVideos = maxVideos
        self.mediaRequired = mediaRequired
        self.supportsMentions = supportsMentions
        self.editor = editor
    }
}

/// Static registry of per-provider posting limits, keyed by Postiz provider identifier.
///
/// Server-supplied `maxCharacters`/`editor` (from `/channels`) override the table when present;
/// everything else (media counts, mediaRequired, mentions) always comes from the table.
public enum PlatformRules {
    public static func limits(
        for identifier: String,
        serverLimits: (maxCharacters: Int, editor: String)?
    ) -> PlatformLimits {
        let base = table[identifier] ?? defaultLimits
        guard let serverLimits else { return base }
        return PlatformLimits(
            maxCharacters: serverLimits.maxCharacters,
            maxImages: base.maxImages,
            maxVideos: base.maxVideos,
            mediaRequired: base.mediaRequired,
            supportsMentions: base.supportsMentions,
            editor: serverLimits.editor
        )
    }

    /// Conservative fallback for unknown/unmapped provider identifiers.
    static let defaultLimits = PlatformLimits(
        maxCharacters: 280,
        maxImages: 4,
        maxVideos: 1,
        mediaRequired: false,
        supportsMentions: false,
        editor: "text"
    )

    static let table: [String: PlatformLimits] = [
        "linkedin": PlatformLimits(
            maxCharacters: 3000, maxImages: 20, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "linkedin-page": PlatformLimits(
            maxCharacters: 3000, maxImages: 20, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "x": PlatformLimits(
            maxCharacters: 280, maxImages: 4, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "instagram": PlatformLimits(
            maxCharacters: 2200, maxImages: 10, maxVideos: 1,
            mediaRequired: true, supportsMentions: true, editor: "text"
        ),
        "facebook": PlatformLimits(
            maxCharacters: 63206, maxImages: 4, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "threads": PlatformLimits(
            maxCharacters: 500, maxImages: 4, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "tiktok": PlatformLimits(
            maxCharacters: 2200, maxImages: 4, maxVideos: 1,
            mediaRequired: true, supportsMentions: false, editor: "text"
        ),
        "youtube": PlatformLimits(
            maxCharacters: 5000, maxImages: 4, maxVideos: 1,
            mediaRequired: true, supportsMentions: false, editor: "text"
        ),
        "pinterest": PlatformLimits(
            maxCharacters: 500, maxImages: 4, maxVideos: 1,
            mediaRequired: true, supportsMentions: false, editor: "text"
        ),
        "bluesky": PlatformLimits(
            maxCharacters: 300, maxImages: 4, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
        "mastodon": PlatformLimits(
            maxCharacters: 500, maxImages: 4, maxVideos: 1,
            mediaRequired: false, supportsMentions: true, editor: "text"
        ),
    ]
}
