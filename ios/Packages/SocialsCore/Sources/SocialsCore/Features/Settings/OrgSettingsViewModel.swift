import Foundation
import Observation

/// Org-level read/settings: shortlink preference picker (`api.shortlinkPreference()` /
/// `api.setShortlinkPreference`) + read-only webhooks list (`api.webhooks()`). Mirrors web's
/// `shortlink-preference.component.tsx` + `webhooks.tsx` (list only, no create/edit).
@MainActor
@Observable
public final class OrgSettingsViewModel {
    public private(set) var shortlink: ShortlinkPreference?
    public private(set) var webhooks: [MobileWebhook] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Loads both the shortlink preference and the webhooks list. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let shortlinkResponse = api.shortlinkPreference()
            async let webhooksResponse = api.webhooks()
            shortlink = try await shortlinkResponse.shortlink
            webhooks = try await webhooksResponse
        } catch {
            errorMessage = "Couldn't load org settings. Please try again."
        }
    }

    /// Saves a new shortlink preference. On failure, reverts the picker to the last-known value
    /// and surfaces an error (mirrors web reverting the select on a failed save).
    public func setShortlink(_ preference: ShortlinkPreference) async {
        let previous = shortlink
        shortlink = preference
        errorMessage = nil
        do {
            let response = try await api.setShortlinkPreference(preference)
            shortlink = response.shortlink
        } catch {
            shortlink = previous
            errorMessage = "Couldn't save that preference. Please try again."
        }
    }
}
