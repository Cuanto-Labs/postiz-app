import Foundation

/// A single reason a draft/post cannot be submitted to a channel, as surfaced by ``PostValidator``.
public enum ValidationIssue: Sendable, Equatable {
    case tooLong(count: Int, limit: Int)
    case mediaRequired
    case tooManyImages(limit: Int)
    case tooManyVideos(limit: Int)
    case needsReconnect
    case channelDisabled
    case empty
}

/// Validates post text/media against a channel's ``PlatformLimits`` before submission.
public enum PostValidator {
    public static func validate(
        text: String,
        mediaCounts: (images: Int, videos: Int),
        channel: (
            identifier: String,
            refreshNeeded: Bool,
            disabled: Bool,
            serverLimits: (maxCharacters: Int, editor: String)?
        )
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if channel.disabled {
            issues.append(.channelDisabled)
        }
        if channel.refreshNeeded {
            issues.append(.needsReconnect)
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.empty)
        }

        let limits = PlatformRules.limits(for: channel.identifier, serverLimits: channel.serverLimits)
        let count = weightedLength(of: text, identifier: channel.identifier)
        if count > limits.maxCharacters {
            issues.append(.tooLong(count: count, limit: limits.maxCharacters))
        }

        if limits.mediaRequired && mediaCounts.images == 0 && mediaCounts.videos == 0 {
            issues.append(.mediaRequired)
        }

        if mediaCounts.images > limits.maxImages {
            issues.append(.tooManyImages(limit: limits.maxImages))
        }

        if mediaCounts.videos > limits.maxVideos {
            issues.append(.tooManyVideos(limit: limits.maxVideos))
        }

        return issues
    }

    /// Characters left under `limits` for `identifier`, counting extended grapheme clusters.
    /// On `x`, URLs are weighted as a fixed 23 characters regardless of their real length
    /// (t.co-style link shortening).
    public static func remainingCharacters(
        text: String,
        identifier: String,
        limits: PlatformLimits
    ) -> Int {
        limits.maxCharacters - weightedLength(of: text, identifier: identifier)
    }

    private static func weightedLength(of text: String, identifier: String) -> Int {
        guard identifier == "x", let detector = urlDetector, !text.isEmpty else {
            return text.count
        }

        let nsRange = NSRange(location: 0, length: (text as NSString).length)
        let matches = detector.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return text.count }

        var length = 0
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            length += text.distance(from: cursor, to: range.lowerBound)
            length += 23
            cursor = range.upperBound
        }
        length += text.distance(from: cursor, to: text.endIndex)
        return length
    }

    private static let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}
