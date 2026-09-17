import Foundation
import Observation

/// Root settings screen state: the signed-in user + active org (from `GET /mobile/v1/me`) and
/// sign-out. The toggles that live on the settings hub (AI consent, analytics opt-out) are
/// driven by their own view models (`AIConsentViewModel`, `AnalyticsOptOutStore`) — this type
/// only owns what's specific to the hub itself. Mirrors the web `global.settings.tsx` header.
@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var user: MobileUser?
    public private(set) var org: MobileOrg?
    public private(set) var isLoading = false
    public private(set) var isSigningOut = false
    public private(set) var errorMessage: String?

    /// `"1.2.3 (45)"` — short version + build number from the injected `Bundle`. Defaults to
    /// `Bundle.main` so app code doesn't have to pass one; tests inject `Bundle(for:)` a test
    /// bundle, or any bundle with an `Info.plist`.
    public let appVersion: String

    private let api: any SocialsAPI
    private let sessionStore: SessionStore

    public init(api: any SocialsAPI, sessionStore: SessionStore, bundle: Bundle = .main) {
        self.api = api
        self.sessionStore = sessionStore
        self.appVersion = Self.formattedVersion(bundle: bundle)
    }

    /// Loads the current user + org. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.me()
            user = response.user
            org = response.org
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Couldn't load your account. Please try again."
        }
    }

    /// Revokes the current session server-side (best-effort — a failed `logout` call still
    /// clears the local session since the user asked to sign out regardless) and clears local
    /// session state.
    public func signOut() async {
        isSigningOut = true
        errorMessage = nil
        defer { isSigningOut = false }
        if let refreshToken = await sessionStore.currentRefreshToken {
            _ = try? await api.logout(LogoutRequest(refreshToken: refreshToken))
        }
        await sessionStore.signOut()
    }

    private static func formattedVersion(bundle: Bundle) -> String {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        default: return "Couldn't load your account. Please try again."
        }
    }
}
