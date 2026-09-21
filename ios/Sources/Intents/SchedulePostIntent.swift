import AppIntents
import Foundation
import SocialsCore

/// Schedules a post for a future date via Siri/Shortcuts — mirrors
/// `ComposerViewModel.submit(type: "schedule", date:)`. Scheduling is consequential (it queues
/// a real publish), so this confirms with the user before calling `createPost`, per the App
/// Intents `requestConfirmation` API.
struct SchedulePostIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Social Post"
    static let description = IntentDescription(
        "Schedules a caption to publish at a future date in Cuanto Socials.")

    @Parameter(title: "Caption")
    var caption: String

    @Parameter(title: "Publish Date")
    var publishDate: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentEnvironment.makeSignedInAPI()
        let channels = try await api.channels().channels
        guard let channel = channels.first(where: { !$0.disabled }) else {
            return .result(dialog: "No connected channel to schedule against yet.")
        }
        let dateString = IntentEnvironment.isoDate.string(from: publishDate)

        try await requestConfirmation(
            dialog: "Schedule this post for \(publishDate.formatted())?"
        )

        let post = PostGroupDTO(
            id: nil, group: nil, publishDate: dateString, status: nil,
            integration: PostIntegrationRef(
                id: channel.id, name: channel.name, picture: channel.picture,
                providerIdentifier: channel.identifier),
            content: .string(caption)
        )
        let body = CreatePostBody(type: "schedule", posts: [post], date: dateString)
        _ = try await api.createPost(body: body, key: IdempotencyKey())
        return .result(dialog: "Scheduled in Cuanto Socials.")
    }
}
