import Foundation
import Observation

/// Which email toggle `toggleEmail(_:on:)` flips. Mirrors the three `EmailNotificationPrefs`
/// fields (`EmailNotificationsDto`).
public enum EmailPrefKey: Sendable {
    case success, failure, streak
}

/// Notification preferences screen: push per-category toggles (`PushCategory`, via
/// `GET`/`PUT /push/prefs` for the current device token) plus the email toggles from the web
/// `email-notifications.component.tsx` (`sendSuccessEmails`/`sendFailureEmails`/
/// `sendStreakEmails`). Each toggle applies optimistically and reverts on failure.
@MainActor
@Observable
public final class NotificationPrefsViewModel {
    public private(set) var pushPrefs = PushPrefs()
    public var sendSuccessEmails = true
    public var sendFailureEmails = true
    public var sendStreakEmails = true
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var pushToken: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Loads email prefs always, and push prefs when a device `token` is available (nil when
    /// the device hasn't registered for push yet — the push section then offers to enable it).
    public func load(token: String?) async {
        pushToken = token
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let email = try await api.emailNotificationPrefs()
            applyEmailPrefs(email)
            if let token {
                let push = try await api.pushPrefs(token: token)
                pushPrefs = push.prefs
            }
        } catch {
            errorMessage = "Couldn't load notification preferences. Please try again."
        }
    }

    /// Whether `category` is enabled. Missing keys default to enabled (server hasn't recorded an
    /// explicit opt-out yet).
    public func isPushEnabled(_ category: PushCategory) -> Bool {
        pushPrefs[category.rawValue] ?? true
    }

    public func togglePush(_ category: PushCategory, on: Bool) async {
        guard let token = pushToken else { return }
        let previous = pushPrefs
        pushPrefs[category.rawValue] = on
        errorMessage = nil
        do {
            let response = try await api.updatePushPrefs(
                PushPrefsUpdateRequest(apnsToken: token, prefs: pushPrefs))
            pushPrefs = response.prefs
        } catch {
            pushPrefs = previous
            errorMessage = "Couldn't update push preferences. Please try again."
        }
    }

    public func toggleEmail(_ key: EmailPrefKey, on: Bool) async {
        let previous = currentEmailPrefs
        setEmailValue(key, on)
        errorMessage = nil
        do {
            let updated = try await api.updateEmailNotificationPrefs(currentEmailPrefs)
            applyEmailPrefs(updated)
        } catch {
            applyEmailPrefs(previous)
            errorMessage = "Couldn't update email preferences. Please try again."
        }
    }

    private var currentEmailPrefs: EmailNotificationPrefs {
        EmailNotificationPrefs(
            sendSuccessEmails: sendSuccessEmails, sendFailureEmails: sendFailureEmails,
            sendStreakEmails: sendStreakEmails)
    }

    private func setEmailValue(_ key: EmailPrefKey, _ on: Bool) {
        switch key {
        case .success: sendSuccessEmails = on
        case .failure: sendFailureEmails = on
        case .streak: sendStreakEmails = on
        }
    }

    private func applyEmailPrefs(_ prefs: EmailNotificationPrefs) {
        sendSuccessEmails = prefs.sendSuccessEmails
        sendFailureEmails = prefs.sendFailureEmails
        sendStreakEmails = prefs.sendStreakEmails
    }
}
