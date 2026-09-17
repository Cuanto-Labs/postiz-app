import Foundation

/// A width:height aspect ratio, compared with tolerance since real files never land on an exact
/// fraction (Meta's own bounds are inclusive, so a ~1% tolerance mirrors their leniency without
/// rejecting a technically-perfect 1:1 export that decodes as 1.002:1).
public struct MediaAspectRatio: Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    var ratio: Double { height == 0 ? 0 : width / height }

    /// Canonical label for violation messages, e.g. `"16:9"`. Snaps to the nearest well-known
    /// ratio within 2% so a slightly-off decode still reads as a recognizable crop name.
    public var label: String {
        let r = ratio
        let known: [(Double, String)] = [
            (1.0, "1:1"), (4.0 / 5.0, "4:5"), (1.91, "1.91:1"), (9.0 / 16.0, "9:16"),
            (16.0 / 9.0, "16:9"), (2.0 / 3.0, "2:3"),
        ]
        if let match = known.min(by: { abs($0.0 - r) < abs($1.0 - r) }), abs(match.0 - r) / max(match.0, 0.0001) < 0.02 {
            return match.1
        }
        return String(format: "%.2f:1", r)
    }
}

/// Selected media's technical attributes as known to the composer once a file is picked —
/// probed locally (`MediaProbe`) since the server's `MediaDTO` carries no dimensions/duration.
public struct SelectedMediaAttributes: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case image
        case video
    }

    public let id: String
    public let kind: Kind
    public let aspectRatio: MediaAspectRatio?
    public let durationSeconds: Double?

    public init(id: String, kind: Kind, aspectRatio: MediaAspectRatio?, durationSeconds: Double?) {
        self.id = id
        self.kind = kind
        self.aspectRatio = aspectRatio
        self.durationSeconds = durationSeconds
    }
}

/// One technical violation for a single media item, tied back to `mediaID` so the UI surfaces it
/// inline next to the offending thumbnail rather than a generic banner.
public struct MediaLimitViolation: Sendable, Equatable, Identifiable {
    public let mediaID: String
    public let providerIdentifier: String
    public let message: String

    public init(mediaID: String, providerIdentifier: String, message: String) {
        self.mediaID = mediaID
        self.providerIdentifier = providerIdentifier
        self.message = message
    }

    public var id: String { "\(providerIdentifier)-\(mediaID)-\(message)" }
}

/// Per-provider aspect ratio + max video duration, mirrors the server's
/// `libraries/nestjs-libraries/src/mobile/media/media-limits.ts` (`aspectRatios`/`maxVideoSeconds`
/// entries only — image/video counts already live in `PlatformRules`).
public struct MediaTechnicalLimits: Sendable, Equatable {
    /// Empty means "no aspect-ratio restriction".
    public let aspectRatios: [MediaAspectRatio]
    /// `nil` means "no duration cap".
    public let maxVideoSeconds: Double?

    public init(aspectRatios: [MediaAspectRatio], maxVideoSeconds: Double?) {
        self.aspectRatios = aspectRatios
        self.maxVideoSeconds = maxVideoSeconds
    }
}

/// Pure per-provider media technical validation: aspect ratio + max video duration, checked
/// against the actual picked file rather than the post's text/settings (that's
/// `ProviderCrossFieldValidator`).
public enum MediaLimits {
    /// Meta's published bounds are inclusive; a 1% tolerance absorbs decode/rounding drift
    /// without ever accepting a genuinely wrong crop.
    static let aspectTolerance = 0.01

    static let table: [String: MediaTechnicalLimits] = [
        "instagram": MediaTechnicalLimits(
            aspectRatios: [
                MediaAspectRatio(width: 1, height: 1),
                MediaAspectRatio(width: 4, height: 5),
                MediaAspectRatio(width: 1.91, height: 1),
            ],
            maxVideoSeconds: 900),
        "instagram-standalone": MediaTechnicalLimits(
            aspectRatios: [
                MediaAspectRatio(width: 1, height: 1),
                MediaAspectRatio(width: 4, height: 5),
                MediaAspectRatio(width: 1.91, height: 1),
            ],
            maxVideoSeconds: 900),
        "linkedin": MediaTechnicalLimits(aspectRatios: [], maxVideoSeconds: 600),
        "linkedin-page": MediaTechnicalLimits(aspectRatios: [], maxVideoSeconds: 600),
    ]

    public static func limits(for providerIdentifier: String) -> MediaTechnicalLimits? {
        table[providerIdentifier]
    }

    /// Checks every item in `media` against `providerIdentifier`'s technical limits, returning
    /// one violation per failing rule per item.
    public static func violations(
        for media: [SelectedMediaAttributes], providerIdentifier: String
    ) -> [MediaLimitViolation] {
        guard let limits = table[providerIdentifier] else { return [] }
        var out: [MediaLimitViolation] = []
        let displayName = Self.displayName(providerIdentifier)

        for item in media {
            if !limits.aspectRatios.isEmpty, let ratio = item.aspectRatio {
                let matches = limits.aspectRatios.contains {
                    abs($0.ratio - ratio.ratio) <= $0.ratio * aspectTolerance
                }
                if !matches {
                    let allowed = joinedList(limits.aspectRatios.map(\.label))
                    out.append(
                        MediaLimitViolation(
                            mediaID: item.id, providerIdentifier: providerIdentifier,
                            message: "\(displayName) needs a \(allowed) crop — this is \(ratio.label)."))
                }
            }

            if item.kind == .video, let maxSeconds = limits.maxVideoSeconds, let duration = item.durationSeconds,
                duration > maxSeconds
            {
                out.append(
                    MediaLimitViolation(
                        mediaID: item.id, providerIdentifier: providerIdentifier,
                        message:
                            "\(displayName) videos max out at \(Int(maxSeconds))s — this is \(Int(duration.rounded()))s."
                    ))
            }
        }
        return out
    }

    /// `["a", "b", "c"]` -> `"a, b or c"`, mirrors how the violation messages read the allowed list.
    static func joinedList(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        return items.dropLast().joined(separator: ", ") + " or " + last
    }

    static func displayName(_ providerIdentifier: String) -> String {
        switch providerIdentifier {
        case "instagram", "instagram-standalone": return "Instagram"
        case "linkedin", "linkedin-page": return "LinkedIn"
        default: return providerIdentifier.capitalized
        }
    }
}
