import Foundation
import Observation

/// Drives the org switcher: loads the caller's orgs from `GET /mobile/v1/me` and persists the
/// active choice through `SessionStore`. Lives in `SocialsCore` (not the App target) so it's
/// testable with `StubSocialsAPI` + an ephemeral `SessionStore`, without booting a simulator.
@MainActor
@Observable
public final class OrgSwitcherViewModel {
    public private(set) var orgs: [MobileOrg] = []
    public private(set) var currentOrgId: String?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI
    private let sessionStore: SessionStore

    public init(api: any SocialsAPI, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    /// Refreshes `orgs` (and the active org) from `me()`. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.me()
            orgs = response.orgs
            currentOrgId = await sessionStore.currentOrgId ?? response.org.id
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Switches the active org and persists the choice via `SessionStore`. No-op if `orgId` is
    /// already the active org.
    public func selectOrg(_ orgId: String) async {
        guard orgId != currentOrgId else { return }
        errorMessage = nil
        do {
            try await sessionStore.setCurrentOrgId(orgId)
            currentOrgId = orgId
        } catch {
            errorMessage = "Couldn't switch organizations. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .server, .notFound, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
