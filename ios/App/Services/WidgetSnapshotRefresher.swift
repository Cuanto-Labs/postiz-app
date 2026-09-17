import BackgroundTasks
import Foundation
import SocialsCore
import WidgetKit

/// Keeps the widget's App Group snapshot fresh: registers/schedules a `BGAppRefreshTask`
/// (identifier `com.cuantolabs.socials.refresh`, declared in `project.yml`/`Info.plist`), and on
/// each run fetches the next week of upcoming posts from the real `SocialsAPI`, writes a
/// `WidgetSnapshot` via `SharedCacheFiles`, and reloads `UpcomingPostsWidget`'s timeline. The
/// widget extension itself never touches the network — this is the only writer of the snapshot
/// file.
///
/// `BGTaskScheduler.register` must run before `application(_:didFinishLaunchingWithOptions:)`
/// returns, before `AppEnvironment`/`SocialsAPI` exist — so, like `PushManager`, this is a
/// `shared` singleton registered early from `AppDelegate` and wired to its real dependencies
/// later via `configure(api:files:)` once `CuantoSocialsApp` builds `AppEnvironment`.
@MainActor
public final class WidgetSnapshotRefresher {
    public static let shared = WidgetSnapshotRefresher()

    private static let taskIdentifier = "com.cuantolabs.socials.refresh"
    private static let refreshInterval: TimeInterval = 60 * 60
    private static let lookahead: TimeInterval = 60 * 60 * 24 * 7

    private var api: (any SocialsAPI)?
    private var files: SharedCacheFiles?

    private init() {}

    /// Supplies the real dependencies once they exist. Safe to call again (e.g. after sign-in
    /// swaps the API client) — later calls simply replace the previous values.
    public func configure(api: any SocialsAPI, files: SharedCacheFiles) {
        self.api = api
        self.files = files
    }

    /// Registers the task handler. Call once from `AppDelegate`, before
    /// `didFinishLaunchingWithOptions` returns — safe to call even before `configure` runs,
    /// since `writeSnapshot` no-ops until dependencies are set.
    public func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) {
            [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            self?.handle(task: task)
        }
    }

    /// Submits the next refresh request. Call after `configure()`, and again from `handle`
    /// each time a run starts, so there's always a future run pending.
    public func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Fetches and writes the snapshot immediately — used on launch/sign-in so the widget has
    /// data before the first background run ever fires.
    public func refreshNow() async {
        await writeSnapshot()
    }

    private func handle(task: BGAppRefreshTask) {
        schedule()
        let refreshTask = Task {
            await writeSnapshot()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { refreshTask.cancel() }
    }

    private func writeSnapshot() async {
        guard let api, let files else { return }
        do {
            let now = Date()
            let formatter = ISO8601DateFormatter()
            let response = try await api.posts(
                from: formatter.string(from: now),
                to: formatter.string(from: now.addingTimeInterval(Self.lookahead)),
                customer: nil)
            let posts = Self.snapshotPosts(from: response.posts, formatter: formatter)
            try files.writeWidgetSnapshot(WidgetSnapshot(generatedAt: now, posts: posts))
            WidgetCenter.shared.reloadTimelines(ofKind: "UpcomingPosts")
        } catch {
            // Best-effort background refresh: leave the previous snapshot in place on failure.
        }
    }

    private static func snapshotPosts(
        from groups: [PostGroupDTO], formatter: ISO8601DateFormatter
    ) -> [WidgetSnapshotPost] {
        groups
            .compactMap { group -> WidgetSnapshotPost? in
                guard let publishDate = group.publishDate, let date = formatter.date(from: publishDate)
                else { return nil }
                return WidgetSnapshotPost(
                    id: group.id ?? group.group ?? UUID().uuidString,
                    title: Self.title(for: group.content),
                    channelName: group.integration?.name ?? "Channel",
                    scheduledAt: date)
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private static func title(for content: PostContentValue?) -> String {
        switch content {
        case .string(let value): return value
        case .items(let items): return items.first?.content ?? ""
        case nil: return ""
        }
    }
}
