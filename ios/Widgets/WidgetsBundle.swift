// WidgetsBundle.swift — extension entry point. Placeholder widget until
// real timeline data lands; keeps CuantoSocialsWidgets compiling.

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
}

struct UpcomingPostsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingPostsEntry {
        UpcomingPostsEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingPostsEntry) -> Void) {
        completion(UpcomingPostsEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingPostsEntry>) -> Void) {
        let entry = UpcomingPostsEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct UpcomingPostsWidgetView: View {
    let entry: UpcomingPostsEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Upcoming posts")
            Text(AppIdentifiers.appGroup)
                .font(.caption2)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
