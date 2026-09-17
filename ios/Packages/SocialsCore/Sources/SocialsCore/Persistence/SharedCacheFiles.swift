import Foundation

/// Writes/wipes the widget's App Group cache file. Deliberately outside
/// `CacheStore`/SwiftData: the widget extension reads a plain JSON snapshot
/// rather than opening the shared `ModelContainer`.
public struct SharedCacheFiles: Sendable {
    private static let snapshotFileName = "widget-snapshot.json"

    /// App Group container URL (`AppIdentifiers.appGroup`, resolved by the
    /// caller); tests pass a temp directory instead.
    public let containerURL: URL

    public init(containerURL: URL) {
        self.containerURL = containerURL
    }

    private var snapshotURL: URL {
        containerURL.appendingPathComponent(Self.snapshotFileName)
    }

    /// Writes `data` as the widget's snapshot, creating the container
    /// directory first if it doesn't exist yet.
    public func writeWidgetSnapshot(_ data: Data) throws {
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try data.write(to: snapshotURL, options: .atomic)
    }

    /// Removes the widget snapshot file. A no-op if it's already absent.
    public func wipe() throws {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        try FileManager.default.removeItem(at: snapshotURL)
    }
}

/// Sign-out helper: wipes the SwiftData cache/outbox and the App Group widget
/// snapshot together so callers never forget one half.
public enum SignOutCleaner {
    public static func wipeEverything(cache: CacheStore, files: SharedCacheFiles) async throws {
        try await cache.wipeAll()
        try files.wipe()
    }
}
