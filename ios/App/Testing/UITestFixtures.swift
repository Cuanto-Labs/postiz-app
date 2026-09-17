import Foundation
import SocialsCore
import UIKit

/// Deterministic fixtures for the `-uiTestStub` launch path (see `AppEnvironment.preview()`).
/// Seeds a `StubSocialsAPI` with just enough scripted responses to drive
/// `SignInComposeScheduleFlowTests` end to end: sign in (email), see one connected channel,
/// open the composer, and schedule a post. `StubSocialsAPI` is otherwise off-limits inside the
/// App target (see `AppEnvironment.swift`) — this is the one other file allowed to reference it.
enum UITestFixtures {
    static let email = "uitest@cuantolabs.com"
    static let password = "uitest-password"
    static let channelName = "UITest Channel"
    static let instagramChannelName = "Cuanto Labs"
    static let linkedInChannelName = "Cuanto Labs Co."

    /// Shared sign-in payload for both the scripted `/auth/login` response and
    /// `signInDirectly(_:)`'s bypass path — one source of truth for the fixture user/org.
    static var authResponse: MobileAuthResponse {
        let user = MobileUser(id: "u1", email: email, name: "UI Test", lastName: nil, pictureId: nil)
        let org = MobileOrg(id: "org1", name: "UI Test Org", role: "OWNER", disabled: false)
        return MobileAuthResponse(
            accessToken: "uitest-access-token", refreshToken: "uitest-refresh-token",
            expiresIn: 3600, sessionId: "uitest-session", user: user, orgs: [org])
    }

    /// Value following `flag` in the process's launch arguments (e.g. `-uiTestTab channels` ->
    /// `"channels"` for `flag == "-uiTestTab"`), or `nil` if the flag wasn't passed.
    static func launchArgValue(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Signs the stub session in directly, bypassing `SignInView` — used by `-uiTestTab`
    /// relaunches (`ScreenshotUITests`) so switching tabs via a fresh process launch doesn't mean
    /// re-driving the sign-in form every time.
    static func signInDirectly(_ sessionStore: SessionStore) async {
        try? await sessionStore.signIn(authResponse)
    }

    /// Seeds the scripted responses `SignInComposeScheduleFlowTests` needs and marks onboarding
    /// as already seen, so a fresh sign-in lands straight on `MainTabView` instead of
    /// `OnboardingView`.
    static func seed(_ api: StubSocialsAPI) async {
        UserDefaults.standard.set(true, forKey: "com.cuantolabs.socials.hasSeenOnboarding")
        // `UserDefaultsDraftStore` persists to the same on-disk `UserDefaults.standard` key across
        // every app launch, including a *previous* `-uiTestStub` run's leftover composer draft —
        // without this, a stale draft from an earlier screenshot/test run bleeds into this one's
        // "just sign in, pick one channel" scenarios (confirmed: extra channels showing selected
        // that this run never picked). Every stub launch starts the composer from a clean slate.
        UserDefaultsDraftStore().clearDraft()

        let channel = ChannelDTO(
            id: "c1", internalId: "c1", name: channelName, identifier: "uitest-channel",
            picture: nil, disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: "x", customer: nil,
            limits: ChannelLimits(maxCharacters: nil, editor: nil))

        // Instagram + LinkedIn, with `limits.media` populated the way the server sends it
        // (`ChannelMediaLimits`) — exercises `MediaTrayView`/`ChannelPreviewCard` for real
        // multi-channel, real-media composer screenshots instead of the single text-only channel
        // above.
        let instagramChannel = ChannelDTO(
            id: "c2", internalId: "c2", name: instagramChannelName, identifier: "instagram",
            picture: nil, disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: "instagram", customer: nil,
            limits: ChannelLimits(
                maxCharacters: nil, editor: nil,
                media: ChannelMediaLimits(
                    maxImages: 10, maxVideos: 1, maxVideoSeconds: 900,
                    aspectRatios: ["1:1", "4:5", "1.91:1"])))
        let linkedInChannel = ChannelDTO(
            id: "c3", internalId: "c3", name: linkedInChannelName, identifier: "linkedin",
            picture: nil, disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: "linkedin", customer: nil,
            limits: ChannelLimits(
                maxCharacters: nil, editor: nil,
                media: ChannelMediaLimits(maxImages: 9, maxVideos: 1, maxVideoSeconds: 600)))

        let post = PostGroupDTO(
            id: "p1", group: "g1", publishDate: nil, status: "QUEUE", integration: nil, content: nil)

        await api.setLoginResults([.success(authResponse)])
        // Every screen that loads channels within one process (Channels tab, the composer's own
        // independent `loadChannels(into:)`, plus the extra `-uiTestTab`/`-uiTestMedia` relaunches
        // `ScreenshotUITests` now drives) each consume one from the queue — 4 comfortably covers
        // any single launch's load(s) without changing the FIFO-exhaustion behavior other tests
        // rely on.
        let channelsResponse = ChannelsResponse(channels: [channel, instagramChannel, linkedInChannel])
        await api.setChannelsResults(Array(repeating: .success(channelsResponse), count: 4))
        await api.setCreatePostResults([.success(post)])

        // Successful responses for every other screen `MainTabView` can reach, so a
        // manual QA walkthrough never trips a `StubError.notScripted` (which every view model's
        // generic `catch` turns into a "Something went wrong" banner, or — for Notifications — a
        // full-screen error+retry state). Repeated 8x per queue: comfortably covers the
        // day/week/month/list display-mode switches on Calendar, the badge-model load in
        // `MainTabView` plus the Notifications screen's own load/refresh, and any manual
        // pull-to-refresh during the walkthrough, without changing `StubSocialsAPI`'s
        // FIFO-exhaustion behavior (other tests rely on that to exercise error paths).
        // A populated week, media library and notification list rather than empty states: these
        // are the App Store frames, and a store listing of empty screens reads as an app with
        // nothing in it (Guideline 2.3.3). Dates are relative to "now" so the calendar always
        // lands on the visible week whenever the set is regenerated.
        let scheduled = Self.scheduledWeek(
            instagram: instagramChannel, linkedIn: linkedInChannel, other: channel)
        await api.setPostsResults(
            Array(repeating: .success(PostsResponse(posts: scheduled)), count: 8))
        await api.setPostsListResults(
            Array(
                repeating: .success(
                    PostsListResponse(
                        posts: scheduled.map(Self.listItem), total: scheduled.count, page: 0,
                        limit: 100, hasMore: false)),
                count: 8))
        await api.setMediaListResults(
            Array(repeating: .success(MediaListResponse(pages: 1, results: Self.mediaLibrary())), count: 8))
        await api.setNotificationsCountResults(
            Array(repeating: .success(NotificationsCountResponse(total: 3)), count: 8))
        await api.setNotificationsListResults(
            Array(
                repeating: .success(
                    NotificationsListResponse(
                        lastReadNotifications: Self.iso(hoursFromNow: -30),
                        notifications: Self.notifications())),
                count: 8))
        // Shared between the AI image and AI video screens (the stub doesn't branch on `type`).
        await api.setAICreditsResults(
            Array(repeating: .success(AICreditsResponse(credits: 10)), count: 8))
        let personalDetails = PersonalDetails(id: authResponse.user.id, name: "UI Test", bio: nil)
        await api.setPersonalDetailsResults(Array(repeating: .success(personalDetails), count: 4))
        await api.setUpdatePersonalDetailsResults(
            Array(repeating: .success(personalDetails), count: 4))
    }

    // MARK: - Composer media fixture (`-uiTestMedia`)

    /// Selects Instagram + LinkedIn and attaches one fixture image straight into the global draft
    /// plus the upload tray — no real upload (`UploadQueue.seedCompleted`), no binary asset in
    /// git (the pixel data is drawn in-process via `UIGraphicsImageRenderer` at exactly the size
    /// that either passes or trips Instagram's aspect-ratio rule). Drives `-uiTestMedia
    /// valid|violation` (`ScreenshotUITests`); no-op unless both that and `-uiTestStub` are set.
    static func seedComposerMediaIfNeeded(into model: ComposerViewModel, uploadQueue: UploadQueue) {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestStub"),
            let raw = launchArgValue("-uiTestMedia"),
            let mode = ComposerMediaFixture(rawValue: raw)
        else { return }

        // Start from a clean slate: `UserDefaultsDraftStore` persists across relaunches, and this
        // fixture always wants exactly Instagram + LinkedIn selected with exactly one attachment.
        model.clearDraft()
        for identifier in ["instagram", "linkedin"] {
            if let channel = model.channels.first(where: { $0.identifier == identifier }) {
                model.toggleChannel(channel)
            }
        }

        let size = mode.pixelSize
        let mediaId = "uitest-media-\(mode.rawValue)"
        let pngData = Self.fixtureImage(size: size)
        // Written to disk and referenced by its `file://` URL: the tray thumbnail and every
        // preview card load `MediaDTO.path` through `AsyncImage`, so an unresolvable scheme left
        // both showing a spinner over an empty frame.
        let fileName = "fixture-\(mode.rawValue).png"
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        try? pngData.write(to: fileURL)
        let media = MediaDTO(
            id: mediaId, name: fileName, originalName: nil,
            path: fileURL.absoluteString, thumbnail: nil, alt: nil,
            thumbnailTimestamp: nil, status: "ready", processingError: nil)
        let attributes = SelectedMediaAttributes(
            id: mediaId, kind: .image,
            aspectRatio: MediaAspectRatio(width: size.width, height: size.height),
            durationSeconds: nil, byteCount: pngData.count, mimeType: "image/png")

        // A written caption, not an empty editor: the App Store frames should show the composer
        // mid-post the way a reviewer would actually see it.
        model.setGlobalContent(
            "Launch week recap — three cities, one deploy, zero downtime. Full write-up in the comments.")
        model.attachMediaToGlobal(media, attributes: attributes)
        uploadQueue.seedCompleted(id: mediaId, fileName: media.name, media: media)
    }

    // MARK: - Populated stub content

    private static func iso(hoursFromNow hours: Double) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(hours * 3600))
    }

    /// Posts spread across the current week — a mix of queued and published across all three stub
    /// channels, so week/month/list views all have something to draw.
    private static func scheduledWeek(
        instagram: ChannelDTO, linkedIn: ChannelDTO, other: ChannelDTO
    ) -> [PostGroupDTO] {
        let entries:
            [(hours: Double, channel: ChannelDTO, status: String, content: String)] = [
                (-48, linkedIn, "PUBLISHED", "Why we rebuilt scheduling around one queue per channel."),
                (-26, instagram, "PUBLISHED", "Studio day. Three shoots, one calendar."),
                (3, instagram, "QUEUE", "Launch week recap — three cities, one deploy, zero downtime."),
                (27, linkedIn, "QUEUE", "Hiring: iOS engineer who likes calendars more than meetings."),
                (51, other, "QUEUE", "Monthly roundup goes out Friday — drafts are open for comments."),
                (75, instagram, "QUEUE", "Behind the scenes of the new composer."),
            ]
        return entries.enumerated().map { index, entry in
            PostGroupDTO(
                id: "stub-post-\(index)", group: "stub-group-\(index)",
                publishDate: iso(hoursFromNow: entry.hours), status: entry.status,
                integration: PostIntegrationRef(
                    id: entry.channel.internalId, name: entry.channel.name, picture: nil,
                    providerIdentifier: entry.channel.identifier),
                content: .string(entry.content))
        }
    }

    /// The same scheduled post as the list endpoint returns it (`GET /mobile/v1/posts/list`),
    /// so Calendar's list display mode shows the same week the grid modes do.
    private static func listItem(_ post: PostGroupDTO) -> PostListItemDTO {
        PostListItemDTO(
            id: post.id, content: post.content, publishDate: post.publishDate, releaseURL: nil,
            releaseId: nil, state: post.status, group: post.group, integration: post.integration,
            intervalInDays: nil, creationMethod: nil)
    }

    /// Media library entries backed by the same drawn gradient as the composer fixture, written to
    /// the temp dir so `AsyncImage` actually has bytes to render.
    private static func mediaLibrary() -> [MediaDTO] {
        let sizes: [(name: String, size: CGSize)] = [
            ("launch-week-1080.png", CGSize(width: 1080, height: 1080)),
            ("studio-day-1080x1350.png", CGSize(width: 1080, height: 1350)),
            ("roundup-1920x1080.png", CGSize(width: 1920, height: 1080)),
            ("hiring-1080.png", CGSize(width: 1080, height: 1080)),
        ]
        return sizes.enumerated().compactMap { index, entry in
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(entry.name)
            try? fixtureImage(size: entry.size).write(to: url)
            return MediaDTO(
                id: "stub-media-\(index)", name: entry.name, originalName: entry.name,
                path: url.absoluteString, thumbnail: url.absoluteString, alt: nil,
                thumbnailTimestamp: nil, status: "ready", processingError: nil)
        }
    }

    private static func notifications() -> [MobileNotification] {
        [
            MobileNotification(
                content: "Your Instagram post published successfully.", createdAt: iso(hoursFromNow: -2)),
            MobileNotification(
                content: "LinkedIn post scheduled for tomorrow at 9:00 AM.", createdAt: iso(hoursFromNow: -8)),
            MobileNotification(
                content: "Cuanto Labs Co. needs to be reconnected in 7 days.",
                createdAt: iso(hoursFromNow: -28)),
        ]
    }

    /// A drawn brand-gradient PNG at `size` — cheap, deterministic, and needs no binary asset
    /// checked into git. Green → indigo, the app's own primary/accent pair, so the attachment in
    /// the store frames looks like artwork rather than a test swatch.
    private static func fixtureImage(size: CGSize) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors =
                [UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1).cgColor,
                 UIColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
            {
                context.cgContext.drawLinearGradient(
                    gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                return
            }
            UIColor.systemTeal.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }
}

/// Which fixture image `-uiTestMedia` attaches: `.valid` passes every seeded channel's aspect
/// check, `.violation` is a 16:9 crop that trips Instagram's (`aspectRatios: ["1:1","4:5",
/// "1.91:1"]`) but not LinkedIn's (no aspect restriction).
enum ComposerMediaFixture: String {
    case valid
    case violation

    var pixelSize: CGSize {
        switch self {
        case .valid: return CGSize(width: 1080, height: 1080)
        case .violation: return CGSize(width: 1920, height: 1080)
        }
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
