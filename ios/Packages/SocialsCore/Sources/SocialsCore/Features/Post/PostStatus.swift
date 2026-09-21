import Foundation

/// Display-timeline step for a post, built on top of `SocialsCore.PostStatus`
/// (`Persistence/CacheModels.swift`, the cache's raw status enum) — named `PostStatusStep` rather
/// than `PostStatus` to avoid redeclaring that type. Mirrors the web calendar's status grouping:
/// draft -> queued -> published, with a separate failed branch that's the only state retry acts on.
public enum PostStatusStep: String, Sendable, Equatable, CaseIterable {
    case draft
    case queued
    case published
    case failed

    /// Maps a `PostGroupDTO.status` raw string (`"DRAFT"`/`"QUEUE"`/`"PUBLISHED"`/`"ERROR"`) to
    /// its display step, defaulting to `.queued` for unrecognized/missing values (mirrors
    /// `DTOMapping.cachedPostFields` defaulting to `.queue` on unparseable status).
    public init(rawStatus: String?) {
        switch rawStatus?.uppercased() {
        case "DRAFT": self = .draft
        case "PUBLISHED": self = .published
        case "ERROR": self = .failed
        default: self = .queued
        }
    }
}

/// A post's status timeline: every step up to and including `current` counts as reached.
/// `.failed` is a branch off `.queued`, not part of the draft->queued->published line, so
/// `isReached` only walks the happy-path steps.
public struct PostStatusTimeline: Sendable, Equatable {
    public static let steps: [PostStatusStep] = [.draft, .queued, .published]

    public let current: PostStatusStep

    public init(current: PostStatusStep) {
        self.current = current
    }

    public var isFailed: Bool { current == .failed }

    /// Whether `step` is reached given `current` — always true for steps at/before `current` on
    /// the happy path; false for every step once `current` is `.failed` (nothing downstream of a
    /// failure has actually happened yet).
    public func isReached(_ step: PostStatusStep) -> Bool {
        guard !isFailed else { return step == .draft || step == .queued }
        guard let currentIndex = Self.steps.firstIndex(of: current),
            let stepIndex = Self.steps.firstIndex(of: step)
        else { return false }
        return stepIndex <= currentIndex
    }
}
