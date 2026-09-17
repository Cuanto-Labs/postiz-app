import AppIntents
import Foundation
import SocialsCore

/// Reads back today's scheduled posts via Siri/Shortcuts — mirrors the calendar's "today"
/// filter on top of `SocialsAPI.posts(from:to:customer:)`. Read-only, so no confirmation needed.
struct TodayScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Social Schedule"
    static let description = IntentDescription(
        "Reads back how many posts are scheduled today in Cuanto Socials.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentEnvironment.makeSignedInAPI()
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        let from = IntentEnvironment.isoDate.string(from: startOfDay)
        let to = IntentEnvironment.isoDate.string(from: endOfDay)
        let response = try await api.posts(from: from, to: to, customer: nil)

        guard !response.posts.isEmpty else {
            return .result(dialog: "Nothing scheduled in Cuanto Socials today.")
        }
        let count = response.posts.count
        let noun = count == 1 ? "post" : "posts"
        return .result(dialog: "You have \(count) \(noun) scheduled in Cuanto Socials today.")
    }
}
