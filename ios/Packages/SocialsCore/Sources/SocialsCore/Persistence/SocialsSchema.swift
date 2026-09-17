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
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
