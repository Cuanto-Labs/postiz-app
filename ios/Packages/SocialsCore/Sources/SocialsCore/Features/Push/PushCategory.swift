import Foundation

/// Push notification categories, shared by `PushManager` (`UNNotificationCategory` registration,
/// App target) and payload routing (deep-link dispatch on notification tap). Raw values match the
/// `PushPrefs` keys (`post.published` etc.) so registration, prefs, and payload routing all agree
/// on one vocabulary (docs/MOBILE-API.md § Push).
public enum PushCategory: String, Sendable, CaseIterable {
    case postFailed = "post.failed"
    case postPublished = "post.published"
    case channelReconnect = "channel.reconnect_needed"

    /// Action identifiers valid for this category, in display order.
    public var actions: [PushAction] {
        switch self {
        case .postFailed: return [.retry, .open]
        case .postPublished: return [.open, .shareLink]
        case .channelReconnect: return [.reconnect]
        }
    }
}

/// Notification action identifiers. Raw values match the `UNNotificationAction` identifiers
/// `PushManager` registers and payload routing switches on.
public enum PushAction: String, Sendable {
    case retry = "RETRY"
    case open = "OPEN"
    case shareLink = "SHARE_LINK"
    case reconnect = "RECONNECT"
}
