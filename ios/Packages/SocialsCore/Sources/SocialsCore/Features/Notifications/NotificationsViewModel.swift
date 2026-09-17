import Foundation
import Observation

/// Notifications feed: unread count + list, mirroring web's `notification.component.tsx`
/// (`NotificationComponent` for the bell/count, `NotificationOpenComponent` for the dropdown
/// list) collapsed into one full screen. Lives in `SocialsCore` so it's testable with
/// `StubSocialsAPI`, mirroring `ChannelsViewModel`/`PostDetailViewModel`.
@MainActor
@Observable
public final class NotificationsViewModel {
    public private(set) var notifications: [MobileNotification] = []
    public private(set) var lastReadNotifications: String = ""
    public private(set) var unreadCount = 0
    public private(set) var isLoading = false
    public private(set) var isRefreshing = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Loads the unread count and the list together (mirrors web's two separate SWR hooks
    /// backing the same screen: `/notifications` for `total`, `/notifications/list` for rows).
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let count = try await api.notificationsCount()
            let list = try await api.notificationsList()
            unreadCount = count.total
            notifications = list.notifications
            lastReadNotifications = list.lastReadNotifications
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Pull-to-refresh: re-fetches just the list (mirrors the dropdown's own refresh, which only
    /// re-queries `/notifications/list`; the bell's `total` badge is reset locally on open in the
    /// web component rather than re-fetched).
    public func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        do {
            let list = try await api.notificationsList()
            notifications = list.notifications
            lastReadNotifications = list.lastReadNotifications
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .notFound: return "That couldn't be found."
        case .server, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted:
            return "Something went wrong. Please try again."
        case .aiConsentRequired:
            return "AI text suggestions need your consent first."
        case .cancelled: return ""
        }
    }
}
