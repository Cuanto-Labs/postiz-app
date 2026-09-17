import Foundation
import Observation

/// App-shell gate: what `RootView` shows on launch and whenever the session changes. Checks
/// `GET /mobile/v1/config` for `minVersion` first — a forced update wins over everything else,
/// including sign-in — then falls back to `SessionStore.state` for auth/onboarding routing.
/// Also listens to `SessionStore.events` so a forced sign-out (401 refresh failure, explicit
/// sign-out from anywhere in the app) always routes back to `.signedOut`.
@MainActor
@Observable
public final class RootViewModel {
    public enum Phase: Sendable, Equatable {
        case loading
        case updateRequired(minimum: AppVersion)
        case signedOut
        case onboarding
        case signedIn(user: MobileUser, orgs: [MobileOrg], orgId: String?)
    }

    private static let onboardingKey = "com.cuantolabs.socials.hasSeenOnboarding"

    public private(set) var phase: Phase = .loading

    private let api: any SocialsAPI
    private let sessionStore: SessionStore
    private let installedVersion: AppVersion
    private let defaults: UserDefaults
    private var eventsTask: Task<Void, Never>?

    /// - Parameters:
    ///   - installedVersion: defaults to the running app's `CFBundleShortVersionString`; tests
    ///     inject a fixed value so `updateRequired`/`ok` is deterministic.
    ///   - defaults: where "has seen onboarding" is persisted; tests inject an isolated suite.
    public init(
        api: any SocialsAPI,
        sessionStore: SessionStore,
        installedVersion: AppVersion = .installed(bundle: .main),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.installedVersion = installedVersion
        self.defaults = defaults
    }

    isolated deinit {
        eventsTask?.cancel()
    }

    /// Runs the gate: starts listening for forced sign-out, then evaluates forced-update +
    /// session state. Call once on `RootView` appear.
    public func start() async {
        if eventsTask == nil {
            let sessionStore = self.sessionStore
            eventsTask = Task { [weak self] in
                let events = await sessionStore.events
                for await event in events where event == .signedOut {
                    self?.phase = .signedOut
                }
            }
        }
        await refresh()
    }

    /// Re-evaluates the gate: forced-update check (fails open on an offline/unparsable
    /// `config()`), then the current session state. Safe to call repeatedly (e.g. a
    /// pull-to-retry after a failed `config()`).
    public func refresh() async {
        let minVersion = try? await api.config().minVersion
        if case .updateRequired(let minimum) = UpdateGate.evaluate(
            minVersion: minVersion, installed: installedVersion)
        {
            phase = .updateRequired(minimum: minimum)
            return
        }
        await applySessionState()
    }

    /// `RootView` calls this once onboarding's last panel finishes, to move straight to
    /// `.signedIn` without an extra `config()` round-trip.
    public func finishOnboarding() async {
        defaults.set(true, forKey: Self.onboardingKey)
        await applySessionState()
    }

    /// `RootView` calls this after `SignInView`/`RegisterView` report a successful sign-in.
    public func signedIn() async {
        await applySessionState()
    }

    private func applySessionState() async {
        switch await sessionStore.state {
        case .signedOut:
            phase = .signedOut
        case .signedIn(let user, let orgs, let orgId):
            phase =
                defaults.bool(forKey: Self.onboardingKey)
                ? .signedIn(user: user, orgs: orgs, orgId: orgId)
                : .onboarding
        }
    }
}
