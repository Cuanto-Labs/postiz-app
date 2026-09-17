import Foundation

/// App Group snapshot the widget extension reads: a small, plain-JSON cache of upcoming
/// scheduled posts. Written by `WidgetSnapshotRefresher` (app target, via a `BGAppRefreshTask`)
/// and read by `WidgetsBundle`'s `TimelineProvider` (widget extension) through
/// `SharedCacheFiles`. The widget process never calls `SocialsAPI` directly — the app is the
/// only writer.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let posts: [WidgetSnapshotPost]

    public init(generatedAt: Date, posts: [WidgetSnapshotPost]) {
        self.generatedAt = generatedAt
        self.posts = posts
    }
}

/// One upcoming post entry in a `WidgetSnapshot`, mapped from `PostGroupDTO`.
public struct WidgetSnapshotPost: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let channelName: String
    public let scheduledAt: Date

    public init(id: String, title: String, channelName: String, scheduledAt: Date) {
        self.id = id
        self.title = title
        self.channelName = channelName
        self.scheduledAt = scheduledAt
    }
}
