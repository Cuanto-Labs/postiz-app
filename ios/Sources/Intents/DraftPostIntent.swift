import AppIntents
import CuantoCore
import CuantoNet
import Foundation
import SocialsCore

/// Shared composition helper for the App Intents in this file group (`DraftPostIntent`,
/// `SchedulePostIntent`, `TodayScheduleIntent`) — mirrors `AppEnvironment.live()`
/// (`ios/App/AppEnvironment.swift`), scoped to what an intent needs: a session-backed
/// `SocialsAPI`. Intents can run out-of-process (Siri, Shortcuts, widgets) so, like the app,
/// they build their own client rather than reaching into a host app DI container.
enum IntentEnvironment {
    struct SignedOut: Error {}

    /// Builds a live `SocialsAPI` backed by whatever session the host app last wrote to the
    /// shared Keychain. Throws `SignedOut` if there's no signed-in session to act as.
    static func makeSignedInAPI() async throws -> any SocialsAPI {
        let keychain = KeychainStore(
            service: "com.cuantolabs.socials.session",
            accessGroup: AppIdentifiers.keychainAccessGroup
        )
        let refreshClient = APIClient(
            baseURL: ExtensionEnvironment.apiBaseURL, transport: URLSessionTransport())
        let sessionStore = await SessionStore(
            keychain: keychain,
            refresh: { refreshToken in
                try await refreshClient.send(SocialsEndpoints.refresh(RefreshRequest(refreshToken: refreshToken)))
            }
        )
        guard case .signedIn = await sessionStore.state else {
            throw SignedOut()
        }
        let client = APIClient(
            baseURL: ExtensionEnvironment.apiBaseURL, transport: URLSessionTransport(),
            tokenProvider: sessionStore)
        return LiveSocialsAPI(client: client, orgProvider: { await sessionStore.currentOrgId })
    }

    static let isoDate: ISO8601DateFormatter = ISO8601DateFormatter()
}

/// Saves a caption as a draft post via Siri/Shortcuts, without picking a channel or a
/// publish time — mirrors `ComposerViewModel.submit(type: "draft")`. Draft posts show up in
/// the app's calendar as `PostStatusStep.draft`, ready to finish from there.
struct DraftPostIntent: AppIntent {
    static let title: LocalizedStringResource = "Draft Social Post"
    static let description = IntentDescription("Saves a caption as a draft post in Cuanto Socials.")

    @Parameter(title: "Caption")
    var caption: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentEnvironment.makeSignedInAPI()
        let channels = try await api.channels().channels
        guard let channel = channels.first(where: { !$0.disabled }) else {
            return .result(dialog: "No connected channel to draft against yet.")
        }
        let post = PostGroupDTO(
            id: nil, group: nil, publishDate: nil, status: nil,
            integration: PostIntegrationRef(
                id: channel.id, name: channel.name, picture: channel.picture,
                providerIdentifier: channel.identifier),
            content: .string(caption)
        )
        let body = CreatePostBody(type: "draft", posts: [post], date: nil)
        _ = try await api.createPost(body: body, key: IdempotencyKey())
        return .result(dialog: "Saved as a draft in Cuanto Socials.")
    }
}
