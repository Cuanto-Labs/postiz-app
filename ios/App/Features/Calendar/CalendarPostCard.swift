import SocialsCore
import SwiftUI

/// One post entry on a calendar screen: channel picture, publish time, status badge, and a
/// one-line content preview. Shared by day/agenda, week grid, month grid, and list — mirrors
/// web's post box rendered inline by `calendar.tsx` (day/week/month) and `time.table.tsx` style
/// rows for the list view.
struct CalendarPostCard: View {
    let publishDate: String?
    let status: String?
    let channelName: String?
    let channelPicture: String?
    /// Postiz provider identifier for the posting channel — drives the brand mark shown when the
    /// channel has no picture (or it hasn't loaded), so a week of posts doesn't read as a column
    /// of identical grey dots.
    var channelIdentifier: String? = nil
    let content: PostContentValue?
    /// Card-menu actions (preview link, duplicate, delete) — mirrors web's calendar post
    /// dropdown in `calendar.tsx` (`duplicatePost`/`deletePost`/preview link actions). `nil`
    /// hides that action from the menu, so callers that don't need it (e.g. read-only
    /// contexts) can omit it.
    var onPreview: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private var hasMenuActions: Bool {
        onPreview != nil || onDuplicate != nil || onDelete != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: channelPicture.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            } placeholder: {
                if let channelIdentifier {
                    ProviderBadge(identifier: channelIdentifier, size: 24)
                } else {
                    Circle().fill(.secondary.opacity(0.2)).frame(width: 24, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Self.previewText(content))
                    .font(.footnote)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let time = Self.displayTime(publishDate) {
                        Text(time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let status {
                        Text(status.capitalized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Self.statusColor(status))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(channelName: channelName, status: status, content: content))
        .accessibilityAddTraits(hasMenuActions ? .isButton : [])
        .contextMenu {
            if let onPreview {
                Button("Preview", systemImage: "eye", action: onPreview)
                    .accessibilityLabel("Preview post")
            }
            if let onDuplicate {
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                    .accessibilityLabel("Duplicate post")
            }
            if let onDelete {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .accessibilityLabel("Delete post")
            }
        }
    }

    static func previewText(_ content: PostContentValue?) -> String {
        switch content {
        case .string(let value): return value
        case .items(let items): return items.compactMap(\.content).first ?? ""
        case nil: return ""
        }
    }

    private static func displayTime(_ iso: String?) -> String? {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private static func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "QUEUE", "PENDING": return .orange
        case "PUBLISHED", "COMPLETED": return .green
        case "ERROR", "FAILED": return .red
        case "DRAFT": return .secondary
        default: return .secondary
        }
    }

    private static func accessibilityLabel(channelName: String?, status: String?, content: PostContentValue?)
        -> String
    {
        var parts: [String] = []
        if let channelName, !channelName.isEmpty { parts.append(channelName) }
        let preview = previewText(content)
        if !preview.isEmpty { parts.append(preview) }
        if let status, !status.isEmpty { parts.append(status.capitalized) }
        return parts.isEmpty ? "Post" : parts.joined(separator: ", ")
    }
}
