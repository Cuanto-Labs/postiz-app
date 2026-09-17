import SocialsCore
import UIKit
import UserNotifications

/// Owns push permission + registration: sets the `UNNotificationCategory` set from
/// `PushCategory` on app start, requests authorization (only ever called after first
/// successful sign-in — see `RootView`), registers for remote notifications, and forwards the
/// resulting APNs device token to `PushRegistrationViewModel`. Also the `UNUserNotificationCenterDelegate`
/// that turns a tapped/actioned notification into `(categoryId, actionId, userInfo)` for
/// `onAction`, wired to `DeepLinkRouter` by a later card — this card only plumbs the callback.
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    /// Set once `AppEnvironment` exists (`CuantoSocialsApp`), so a device token received before
    /// then still has somewhere to go once wiring finishes.
    var registrationViewModel: PushRegistrationViewModel?

    /// Notification tap/action forwarding. `push-deeplink` card wires this to `DeepLinkRouter`.
    var onAction: (@MainActor (_ categoryId: String, _ actionId: String, _ userInfo: [AnyHashable: Any]) -> Void)?

    private override init() {
        super.init()
    }

    /// Registers `UNNotificationCategory`/action definitions. Safe to call on every launch,
    /// regardless of authorization status or sign-in state.
    func registerCategories() {
        UNUserNotificationCenter.current().delegate = self

        let categories = Set(
            PushCategory.allCases.map { category in
                UNNotificationCategory(
                    identifier: category.rawValue,
                    actions: category.actions.map(Self.notificationAction),
                    intentIdentifiers: [],
                    options: []
                )
            })
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    /// Requests notification authorization and, if granted, registers for remote notifications.
    /// Callers must gate this on "user has just signed in for the first time" — never call on
    /// cold launch.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` forwards
    /// the raw token here.
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        Task { await registrationViewModel?.didReceiveToken(deviceToken) }
    }

    private static func notificationAction(for action: PushAction) -> UNNotificationAction {
        switch action {
        case .retry:
            return UNNotificationAction(identifier: action.rawValue, title: "Retry", options: [])
        case .open:
            return UNNotificationAction(identifier: action.rawValue, title: "Open", options: [.foreground])
        case .shareLink:
            return UNNotificationAction(identifier: action.rawValue, title: "Share Link", options: [.foreground])
        case .reconnect:
            return UNNotificationAction(identifier: action.rawValue, title: "Reconnect", options: [.foreground])
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// Notifications that arrive while the app is foregrounded still show a banner/sound.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier
        // `[AnyHashable: Any]` isn't Sendable; box it for the hop to the MainActor closure.
        // Safe here because the dictionary is an immutable snapshot handed to us by UNUserNotificationCenter.
        let userInfoBox = UserInfoBox(value: response.notification.request.content.userInfo)
        await MainActor.run {
            PushManager.shared.onAction?(categoryId, actionId, userInfoBox.value)
        }
    }
}

/// Wraps `[AnyHashable: Any]` so it can cross an actor boundary; see usage above.
/// `nonisolated` because the project defaults to MainActor isolation and this type must be
/// constructible from the `nonisolated` delegate callback.
private nonisolated struct UserInfoBox: @unchecked Sendable {
    let value: [AnyHashable: Any]
}
