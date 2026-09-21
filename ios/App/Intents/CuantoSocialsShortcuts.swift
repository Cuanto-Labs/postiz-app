import AppIntents

/// Surfaces `DraftPostIntent`/`SchedulePostIntent`/`TodayScheduleIntent` to Siri and the
/// Shortcuts app. Lives in the container app target (not the `CuantoSocialsIntents` extension)
/// alongside the intents it vends, which are compiled into both via `Sources/Intents`.
struct CuantoSocialsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DraftPostIntent(),
            phrases: [
                "Draft a post in \(.applicationName)",
                "Save a draft in \(.applicationName)"
            ],
            shortTitle: "Draft Post",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SchedulePostIntent(),
            phrases: [
                "Schedule a post in \(.applicationName)",
                "Schedule a post with \(.applicationName)"
            ],
            shortTitle: "Schedule Post",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: TodayScheduleIntent(),
            phrases: [
                "What's scheduled today in \(.applicationName)",
                "Show today's schedule in \(.applicationName)"
            ],
            shortTitle: "Today's Schedule",
            systemImageName: "calendar"
        )
    }
}
