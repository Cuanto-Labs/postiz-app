import CuantoNet
import Foundation

/// Notifications facade builders — split from `SocialsEndpoints` for the same reason as
/// `LibraryEndpoints.swift`. Mirrors `mobile-notifications.controller.ts`.
extension SocialsEndpoints {
    // MARK: - Notifications (mobile-notifications.controller.ts)
    // GET /mobile/v1/notifications, GET /mobile/v1/notifications/list

    public static func notificationsCount(
        orgId: String? = nil
    ) -> Endpoint<NotificationsCountResponse> {
        withOrg(Endpoint(path: "\(basePath)/notifications"), orgId)
    }

    public static func notificationsList(
        orgId: String? = nil
    ) -> Endpoint<NotificationsListResponse> {
        withOrg(Endpoint(path: "\(basePath)/notifications/list"), orgId)
    }
}
