import Foundation
import Observation

/// Persists the user's analytics opt-out preference in an injectable `UserDefaults` suite so it
/// is testable without touching `UserDefaults.standard`. Default is opted-IN (`isOptedOut ==
/// false`) per product default; the settings-hub toggle (out of scope here) flips this via
/// `setOptedOut(_:)`. `AnalyticsService` (App target) observes changes and forwards them to
/// `CuantoAnalytics.AnalyticsClient.setOptedOut(_:)`.
@MainActor
@Observable
public final class AnalyticsOptOutStore {
    private static let defaultsKey = "com.cuantolabs.socials.analyticsOptedOut"

    private let defaults: UserDefaults
    private var onChange: ((Bool) -> Void)?

    public private(set) var isOptedOut: Bool

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        self.isOptedOut = defaults.bool(forKey: Self.defaultsKey)
    }

    /// Registers a closure invoked whenever `isOptedOut` changes via `setOptedOut(_:)`. Replaces
    /// any previously registered observer.
    public func observe(_ onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
    }

    /// Updates and persists the opt-out flag, then notifies the registered observer (if any).
    public func setOptedOut(_ value: Bool) {
        isOptedOut = value
        defaults.set(value, forKey: Self.defaultsKey)
        onChange?(value)
    }
}
