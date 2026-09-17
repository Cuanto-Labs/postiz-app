import Foundation
import CuantoCore

/// Shared runtime environment for the app extensions (Share, Widgets, Intents) — mirrors
/// what the host app wires up in `CuantoSocialsApp`, but scoped to what an extension process
/// actually needs: the app-group `DefaultsStore` and the API base URL. Extensions run in
/// their own process, so they cannot reach the host app's DI container directly; this is
/// the seam they read through instead.
public enum ExtensionEnvironment {
    /// `DefaultsStore` backed by the shared app-group suite (`AppIdentifiers.appGroup`),
    /// so widgets/intents/share can read state the host app writes (and vice versa).
    public static var sharedDefaults: DefaultsStore {
        DefaultsStore(suiteName: AppIdentifiers.appGroup)
    }

    /// Container directory for the shared app group, for extensions that need to read/write
    /// files the host app also has access to (e.g. cached snapshots for widget timelines).
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
    }

    /// The API base URL, resolved the same way as the host app (`SocialsAPIBaseURL` in the
    /// extension's own `Info.plist`, injected per-config via `project.yml`).
    public static var apiBaseURL: URL {
        BuildConfig.apiBaseURL
    }
}
