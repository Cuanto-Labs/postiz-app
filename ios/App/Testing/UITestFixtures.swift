import Foundation
import SocialsCore

/// Deterministic fixtures for the `-uiTestStub` launch path (see `AppEnvironment.preview()`).
/// Seeds a `StubSocialsAPI` with just enough scripted responses to drive
/// `SignInComposeScheduleFlowTests` end to end: sign in (email), see one connected channel,
/// open the composer, and schedule a post. `StubSocialsAPI` is otherwise off-limits inside the
/// App target (see `AppEnvironment.swift`) — this is the one other file allowed to reference it.
enum UITestFixtures {
    static let email = "uitest@cuantolabs.com"
    static let password = "uitest-password"
    static let channelName = "UITest Channel"

    /// Seeds the scripted responses `SignInComposeScheduleFlowTests` needs and marks onboarding
    /// as already seen, so a fresh sign-in lands straight on `MainTabView` instead of
    /// `OnboardingView`.
    static func seed(_ api: StubSocialsAPI) async {
        UserDefaults.standard.set(true, forKey: "com.cuantolabs.socials.hasSeenOnboarding")

        let user = MobileUser(id: "u1", email: email, name: "UI Test", lastName: nil, pictureId: nil)
        let org = MobileOrg(id: "org1", name: "UI Test Org", role: "OWNER", disabled: false)
        let auth = MobileAuthResponse(
            accessToken: "uitest-access-token", refreshToken: "uitest-refresh-token",
            expiresIn: 3600, sessionId: "uitest-session", user: user, orgs: [org])

        let channel = ChannelDTO(
            id: "c1", internalId: "c1", name: channelName, identifier: "uitest-channel",
            picture: nil, disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: "x", customer: nil,
            limits: ChannelLimits(maxCharacters: nil, editor: nil))

        let post = PostGroupDTO(
            id: "p1", group: "g1", publishDate: nil, status: "QUEUE", integration: nil, content: nil)

        await api.setLoginResults([.success(auth)])
        // Two scripted responses: the Channels tab's own `ChannelsViewModel` load and the
        // composer's independent `loadChannels(into:)` each consume one from the queue.
        await api.setChannelsResults([
            .success(ChannelsResponse(channels: [channel])),
            .success(ChannelsResponse(channels: [channel])),
        ])
        await api.setCreatePostResults([.success(post)])

        // Empty-but-successful responses for every other screen `MainTabView` can reach, so a
        // manual QA walkthrough never trips a `StubError.notScripted` (which every view model's
        // generic `catch` turns into a "Something went wrong" banner, or — for Notifications — a
        // full-screen error+retry state). Repeated 8x per queue: comfortably covers the
        // day/week/month/list display-mode switches on Calendar, the badge-model load in
        // `MainTabView` plus the Notifications screen's own load/refresh, and any manual
        // pull-to-refresh during the walkthrough, without changing `StubSocialsAPI`'s
        // FIFO-exhaustion behavior (other tests rely on that to exercise error paths).
        await api.setPostsResults(Array(repeating: .success(PostsResponse(posts: [])), count: 8))
        await api.setPostsListResults(
            Array(
                repeating: .success(
                    PostsListResponse(posts: [], total: 0, page: 0, limit: 100, hasMore: false)),
                count: 8))
        await api.setMediaListResults(
            Array(repeating: .success(MediaListResponse(pages: 1, results: [])), count: 8))
        await api.setNotificationsCountResults(
            Array(repeating: .success(NotificationsCountResponse(total: 0)), count: 8))
        await api.setNotificationsListResults(
            Array(
                repeating: .success(
                    NotificationsListResponse(lastReadNotifications: "", notifications: [])),
                count: 8))
        // Shared between the AI image and AI video screens (the stub doesn't branch on `type`).
        await api.setAICreditsResults(
            Array(repeating: .success(AICreditsResponse(credits: 10)), count: 8))
        let personalDetails = PersonalDetails(id: user.id, name: "UI Test", bio: nil)
        await api.setPersonalDetailsResults(Array(repeating: .success(personalDetails), count: 4))
        await api.setUpdatePersonalDetailsResults(
            Array(repeating: .success(personalDetails), count: 4))
    }
}

/// Actor-isolated setters — mirrors the pattern `SocialsCoreTests` doubles use to script
/// `StubSocialsAPI` (a plain cross-actor `=` assignment to a `var` stored property isn't
/// permitted; these run inside the actor's own isolation domain instead).
extension StubSocialsAPI {
    fileprivate func setLoginResults(_ results: [Result<MobileAuthResponse, Error>]) {
        loginResults = results
    }
    fileprivate func setChannelsResults(_ results: [Result<ChannelsResponse, Error>]) {
        channelsResults = results
    }
    fileprivate func setCreatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        createPostResults = results
    }
    fileprivate func setPostsResults(_ results: [Result<PostsResponse, Error>]) {
        postsResults = results
    }
    fileprivate func setPostsListResults(_ results: [Result<PostsListResponse, Error>]) {
        postsListResults = results
    }
    fileprivate func setMediaListResults(_ results: [Result<MediaListResponse, Error>]) {
        mediaListResults = results
    }
    fileprivate func setNotificationsCountResults(
        _ results: [Result<NotificationsCountResponse, Error>]
    ) {
        notificationsCountResults = results
    }
    fileprivate func setNotificationsListResults(
        _ results: [Result<NotificationsListResponse, Error>]
    ) {
        notificationsListResults = results
    }
    fileprivate func setAICreditsResults(_ results: [Result<AICreditsResponse, Error>]) {
        aiCreditsResults = results
    }
    fileprivate func setPersonalDetailsResults(_ results: [Result<PersonalDetails, Error>]) {
        personalDetailsResults = results
    }
    fileprivate func setUpdatePersonalDetailsResults(_ results: [Result<PersonalDetails, Error>]) {
        updatePersonalDetailsResults = results
    }
}
