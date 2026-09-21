import Foundation

// MARK: - Notifications

/// `GET /mobile/v1/notifications` response (`NotificationService.getMainPageCount` /
/// `NotificationsRepository.getMainPageCount`) — unread count since the user's
/// `lastReadNotifications` watermark. docs/MOBILE-API.md § notifications.
public struct NotificationsCountResponse: Sendable, Codable, Equatable {
    public let total: Int

    public init(total: Int) {
        self.total = total
    }
}

/// One row of `notifications` in `NotificationsListResponse` — `NotificationsRepository
/// .getNotifications` `select`s only `createdAt`/`content` (no `id`/read flag on the row
/// itself; read state is derived by comparing `createdAt` to the envelope's
/// `lastReadNotifications`, same as `notification.component.tsx`).
public struct MobileNotification: Sendable, Codable, Equatable {
    public let content: String
    public let createdAt: String

    public init(content: String, createdAt: String) {
        self.content = content
        self.createdAt = createdAt
    }
}

/// `GET /mobile/v1/notifications/list` response — also advances the server-side
/// `lastReadNotifications` watermark as a side effect (`NotificationsRepository
/// .getNotifications`).
public struct NotificationsListResponse: Sendable, Codable, Equatable {
    public let lastReadNotifications: String
    public let notifications: [MobileNotification]

    public init(lastReadNotifications: String, notifications: [MobileNotification]) {
        self.lastReadNotifications = lastReadNotifications
        self.notifications = notifications
    }
}
