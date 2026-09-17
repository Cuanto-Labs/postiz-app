import Foundation
import SwiftData

/// Central SwiftData schema + container factory for the cache and outbox models.
public enum SocialsSchema {
    public static let models: [any PersistentModel.Type] = [
        CachedChannel.self,
        CachedPost.self,
        DraftPost.self,
        PendingAction.self,
    ]

    /// `ModelContainer(for:configurations:)` is not safe to call concurrently —
    /// swift-testing runs different `@Suite`s in parallel by default, and
    /// concurrent container creation (in-memory or not) has caused intermittent
    /// SIGSEGV crashes across test suites. Serialize creation here so every
    /// call site is safe without needing `.serialized` on each suite.
    private static let creationLock = NSLock()

    /// Builds the shared `ModelContainer`.
    /// - Parameters:
    ///   - inMemory: use a transient, in-memory store (tests, previews).
    ///   - appGroupURL: when given (and `inMemory` is false), the on-disk store
    ///     lives inside this App Group container so the app, widgets and the
    ///     share extension all read the same cache/outbox.
    public static func makeContainer(inMemory: Bool, appGroupURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let appGroupURL {
            let storeURL = appGroupURL.appendingPathComponent("SocialsCore.sqlite")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        creationLock.lock()
        defer { creationLock.unlock() }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
