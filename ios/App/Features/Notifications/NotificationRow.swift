import SocialsCore
import SwiftUI

/// Single notification row: relative time within 24h (absolute date beyond that), HTML-stripped
/// content, bold styling for unread rows. Mirrors web's `ShowNotification` in
/// `notification.component.tsx`.
struct NotificationRow: View {
    let notification: MobileNotification
    let isUnread: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.strippedHTML(notification.content))
                .font(isUnread ? .body.bold() : .body)
                .accessibilityLabel(isUnread ? "Unread notification" : "Notification")

            Text(Self.displayDate(notification.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    /// Strips HTML tags from the raw content (web renders it with `dangerouslySetInnerHTML`
    /// after linkifying URLs; SwiftUI has no HTML renderer, so this surfaces plain text instead
    /// of raw markup).
    private static func strippedHTML(_ content: String) -> String {
        content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let isWithin24h = Date().timeIntervalSince(date) < 24 * 60 * 60
        let formatter = DateFormatter()
        if isWithin24h {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: .now)
        } else {
            formatter.dateFormat = "MMM d, yyyy h:mm a"
            return formatter.string(from: date)
        }
    }
}
