import CuantoAnalytics
import CuantoNet
import Foundation
import SocialsCore

/// Wires `CuantoAnalytics.AnalyticsClient` (OnyxMetric ingest — no third-party analytics SDKs)
/// to the app's `AnalyticsOptOutStore`: seeds the client with the persisted opt-out flag on
/// launch, then keeps it in sync as the flag changes. `AppEnvironment.live()` builds `.live(...)`
/// against the real ingest endpoint; `AppEnvironment.preview()` (and any `-uiTestStub` launch)
/// uses `.noop(...)` so UI tests never emit real events.
@MainActor
public final class AnalyticsService {
    public let tracker: any AnalyticsTracking

    public init(tracker: any AnalyticsTracking, optOutStore: AnalyticsOptOutStore) {
        self.tracker = tracker
        Task { await tracker.setOptedOut(optOutStore.isOptedOut) }
        optOutStore.observe { optedOut in
            Task { await tracker.setOptedOut(optedOut) }
        }
    }

    /// Real OnyxMetric-backed service, synced with `optOutStore`.
    public static func live(optOutStore: AnalyticsOptOutStore) -> AnalyticsService {
        let client = APIClient(
            baseURL: AnalyticsConfig.ingestBaseURL, transport: URLSessionTransport())
        let tracker = AnalyticsClient(
            apiClient: client, ingestPath: AnalyticsConfig.ingestPath, appKey: AnalyticsConfig.appKey)
        return AnalyticsService(tracker: tracker, optOutStore: optOutStore)
    }

    /// No-op service for previews and UI tests (`-uiTestStub`): never sends real events.
    public static func noop(optOutStore: AnalyticsOptOutStore) -> AnalyticsService {
        AnalyticsService(tracker: NoopAnalytics(), optOutStore: optOutStore)
    }
}

/// OnyxMetric ingest config. Overridable via Info.plist for staging/prod, mirroring
/// `BuildConfig.apiBaseURL` (AppIdentifiers.swift).
private enum AnalyticsConfig {
    static var ingestBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OnyxMetricIngestBaseURL") as? String,
            let url = URL(string: value)
        {
            return url
        }
        return URL(string: "https://onyx.cuantolabs.com")!
    }

    static let ingestPath = "/api/ingest"

    static var appKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OnyxMetricAppKey") as? String
            ?? "cuanto-socials-ios"
    }
}
