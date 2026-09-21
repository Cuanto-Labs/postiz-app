import UIKit

/// Installed via `@UIApplicationDelegateAdaptor` in `CuantoSocialsApp` — the only UIKit hook
/// SwiftUI's `App` protocol doesn't expose: `UNNotificationCategory` registration on launch and
/// the APNs device-token callback, both forwarded to `PushManager`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            PushManager.shared.registerCategories()
        }
        // Must register before this method returns (BGTaskScheduler API contract) — called
        // directly, not deferred via `Task {}`, since the project's default actor isolation is
        // `MainActor` so this call is already on the right actor here.
        WidgetSnapshotRefresher.shared.register()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Best-effort: `PushRegistrationViewModel` already tracks `needsRetry` for the
        // upsert-call failure path; a registration failure here just means no token to send.
    }
}
