// WidgetsBundle.swift — extension entry point. Reads the `WidgetSnapshot` the app writes into
// the App Group container (via `WidgetSnapshotRefresher`) and renders real upcoming posts. The
// widget extension never calls `SocialsAPI` directly.

import SocialsCore
import SwiftUI
import WidgetKit

@main
struct CuantoSocialsWidgets: WidgetBundle {
    var body: some Widget {
        UpcomingPostsWidget()
    }
}

struct UpcomingPostsEntry: TimelineEntry {
    let date: Date
    let posts: [WidgetSnapshotPost]
}

struct UpcomingPostsProvider: TimelineProvider {
    private func loadSnapshot() -> WidgetSnapshot? {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
        else { return nil }
        return SharedCacheFiles(containerURL: containerURL).readWidgetSnapshot()
    }

    func placeholder(in context: Context) -> UpcomingPostsEntry {
        UpcomingPostsEntry(date: .now, posts: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingPostsEntry) -> Void) {
        let posts = loadSnapshot()?.posts ?? []
        completion(UpcomingPostsEntry(date: .now, posts: posts))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingPostsEntry>) -> Void)
    {
        let posts = loadSnapshot()?.posts ?? []
        let entry = UpcomingPostsEntry(date: .now, posts: posts)
        // The app refreshes the App Group snapshot on its own schedule (`BGAppRefreshTask` +
        // launch/sign-in), so the widget just re-reads it next time WidgetKit asks.
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct UpcomingPostsWidget: Widget {
    let kind: String = "UpcomingPosts"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingPostsProvider()) { entry in
            UpcomingPostsWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Posts")
        .description("Shows upcoming scheduled posts.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct UpcomingPostsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpcomingPostsEntry

    var body: some View {
        if family == .accessoryInline {
            if let next = entry.posts.first {
                Text("\(next.title) · \(next.channelName)")
            } else {
                Text("No upcoming posts")
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upcoming Posts")
                    .font(.headline)
                if entry.posts.isEmpty {
                    Text("Nothing scheduled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.posts.prefix(family == .systemSmall ? 1 : 3)) { post in
                        VStack(alignment: .leading) {
                            Text(post.title.isEmpty ? post.channelName : post.title)
                                .font(.caption)
                                .lineLimit(1)
                            Text(post.scheduledAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
