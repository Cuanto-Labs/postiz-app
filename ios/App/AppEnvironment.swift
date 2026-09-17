import CuantoCore
import CuantoNet
import CuantoTesting
import Foundation
import Observation
import SocialsCore
import SwiftData

/// Composition root: owns the session, API client, on-disk cache, and sync engine, and
/// injects them into the view tree via `.environment(_:)`. One instance lives for the app's
/// lifetime; `.preview()` builds an equivalent graph with in-memory/stub doubles for tests
/// and SwiftUI previews.
@MainActor
@Observable
public final class AppEnvironment {
    public let sessionStore: SessionStore
    public let api: any SocialsAPI
    public let modelContainer: ModelContainer
    public let cacheStore: CacheStore
    public let syncEngine: SyncEngine<ContinuousClock>

    private let sharedCacheFiles: SharedCacheFiles
    private var signOutTask: Task<Void, Never>?

    private init(
        sessionStore: SessionStore,
        api: any SocialsAPI,
        modelContainer: ModelContainer,
        cacheStore: CacheStore,
        syncEngine: SyncEngine<ContinuousClock>,
        sharedCacheFiles: SharedCacheFiles
    ) {
        self.sessionStore = sessionStore
        self.api = api
        self.modelContainer = modelContainer
        self.cacheStore = cacheStore
        self.syncEngine = syncEngine
        self.sharedCacheFiles = sharedCacheFiles

        // Sign-out is the one lifecycle event the composition root reacts to itself: wipe the
        // cache/outbox and the widget's App Group snapshot together so nothing outlives the
        // session that produced it.
        signOutTask = Task { [sessionStore, cacheStore, sharedCacheFiles] in
            let events = await sessionStore.events
            for await event in events where event == .signedOut {
                try? await SignOutCleaner.wipeEverything(cache: cacheStore, files: sharedCacheFiles)
            }
        }
    }

    isolated deinit {
        signOutTask?.cancel()
    }

    /// Live composition root: real Keychain, real network, on-disk (App Group) SwiftData store.
    public static func live() async -> AppEnvironment {
        let keychain = KeychainStore(
            service: "com.cuantolabs.socials.session",
            accessGroup: AppIdentifiers.keychainAccessGroup
        )

        // Bare client (no tokenProvider): used only for the refresh call itself, so a 401
        // there can never recurse into another refresh attempt.
        let refreshClient = APIClient(baseURL: BuildConfig.apiBaseURL, transport: URLSessionTransport())
        let sessionStore = await SessionStore(
            keychain: keychain,
            refresh: { refreshToken in
                try await refreshClient.send(SocialsEndpoints.refresh(RefreshRequest(refreshToken: refreshToken)))
            }
        )

        let client = APIClient(
            baseURL: BuildConfig.apiBaseURL,
            transport: URLSessionTransport(),
            tokenProvider: sessionStore
        )
        let api = LiveSocialsAPI(client: client, orgProvider: { await sessionStore.currentOrgId })

        let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
        let modelContainer = try! SocialsSchema.makeContainer(inMemory: false, appGroupURL: appGroupURL)
        let cacheStore = CacheStore(modelContainer: modelContainer)
        let outbox = PendingActionOutbox(modelContainer: modelContainer)
        let syncEngine = SyncEngine(
            outbox: outbox,
            executor: UnimplementedActionExecutor(),
            connectivity: NetworkConnectivity(),
            clock: ContinuousClock()
        )
        let sharedCacheFiles = SharedCacheFiles(
            containerURL: appGroupURL ?? FileManager.default.temporaryDirectory)

        return AppEnvironment(
            sessionStore: sessionStore, api: api, modelContainer: modelContainer,
            cacheStore: cacheStore, syncEngine: syncEngine, sharedCacheFiles: sharedCacheFiles)
    }

    /// Preview/test composition root: `StubSocialsAPI`, in-memory SwiftData, ephemeral Keychain
    /// — never touches the real login Keychain or network.
    public static func preview() async -> AppEnvironment {
        let sessionStore = await SessionStore(
            keychain: KeychainStore.ephemeral(),
            refresh: { _ in throw CancellationError() }
        )
        let modelContainer = try! SocialsSchema.makeContainer(inMemory: true)
        let cacheStore = CacheStore(modelContainer: modelContainer)
        let outbox = PendingActionOutbox(modelContainer: modelContainer)
        let syncEngine = SyncEngine(
            outbox: outbox,
            executor: UnimplementedActionExecutor(),
            connectivity: NetworkConnectivity(),
            clock: ContinuousClock()
        )
        let sharedCacheFiles = SharedCacheFiles(containerURL: FileManager.default.temporaryDirectory)

        return AppEnvironment(
            sessionStore: sessionStore, api: StubSocialsAPI(), modelContainer: modelContainer,
            cacheStore: cacheStore, syncEngine: syncEngine, sharedCacheFiles: sharedCacheFiles)
    }
}

/// Placeholder `ActionExecutor`: no live outbox-draining implementation exists yet (tracked
/// separately), so queued actions stay pending rather than being silently dropped or
/// mis-dispatched. Replace with a `LiveSocialsAPI`-backed executor when that card lands.
private struct UnimplementedActionExecutor: ActionExecutor {
    func execute(_ action: PendingActionSnapshot) async throws {
        throw SyncError.retryable("ActionExecutor not implemented yet")
    }
}
