import Foundation
import Observation

/// Push registration state machine: turns an APNs device token into an `upsertPushDevice` call
/// and tears the registration down on sign-out via `deletePushDevice`. Tracks a retry flag on
/// failure so `PushManager` (App target, UIKit/`UNUserNotificationCenter`) can decide whether to
/// re-attempt. Pure Swift — testable with `StubSocialsAPI`, no simulator boot required
/// (docs/MOBILE-API.md § Push).
@MainActor
@Observable
public final class PushRegistrationViewModel {
    public private(set) var isRegistered = false
    public private(set) var needsRetry = false
    public private(set) var errorMessage: String?
    public private(set) var registeredToken: String?

    private let api: any SocialsAPI
    private let environment: String
    private let bundleId: String?

    public init(
        api: any SocialsAPI, environment: String = "production",
        bundleId: String? = Bundle.main.bundleIdentifier
    ) {
        self.api = api
        self.environment = environment
        self.bundleId = bundleId
    }

    /// Called when the app receives a new APNs device token. Hex-encodes it and upserts via
    /// `SocialsAPI`.
    public func didReceiveToken(_ data: Data) async {
        let token = Self.hexString(data)
        errorMessage = nil
        do {
            let body = PushDeviceUpsert(
                apnsToken: token, environment: environment, bundleId: bundleId,
                locale: Locale.current.identifier, timezone: TimeZone.current.identifier,
                prefs: nil)
            _ = try await api.upsertPushDevice(body)
            registeredToken = token
            isRegistered = true
            needsRetry = false
        } catch {
            needsRetry = true
            isRegistered = false
            errorMessage = "Couldn't register for push notifications. Please try again."
        }
    }

    /// Called on sign-out: deletes the current device registration so a signed-out device stops
    /// receiving org-scoped push. Best-effort — a failed delete still clears local state since
    /// the session is ending regardless.
    public func signOut() async {
        guard let token = registeredToken else { return }
        _ = try? await api.deletePushDevice(token: token)
        registeredToken = nil
        isRegistered = false
        needsRetry = false
    }

    private static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
