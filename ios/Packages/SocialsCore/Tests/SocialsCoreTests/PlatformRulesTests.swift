import Testing
@testable import SocialsCore

@Suite("PlatformRules + PostValidator")
struct PlatformRulesTests {
    @Test("table lookups return the documented per-provider limits")
    func tableLookups() {
        let x = PlatformRules.limits(for: "x", serverLimits: nil)
        #expect(x.maxCharacters == 280)
        #expect(x.maxImages == 4)
        #expect(x.maxVideos == 1)

        let instagram = PlatformRules.limits(for: "instagram", serverLimits: nil)
        #expect(instagram.maxCharacters == 2200)
        #expect(instagram.maxImages == 10)
        #expect(instagram.mediaRequired)

        let linkedin = PlatformRules.limits(for: "linkedin", serverLimits: nil)
        #expect(linkedin.maxCharacters == 3000)
        #expect(linkedin.maxImages == 9)  // matches MEDIA_LIMITS.linkedin server-side

        let facebook = PlatformRules.limits(for: "facebook", serverLimits: nil)
        #expect(facebook.maxCharacters == 63206)

        let threads = PlatformRules.limits(for: "threads", serverLimits: nil)
        #expect(threads.maxCharacters == 500)

        let tiktok = PlatformRules.limits(for: "tiktok", serverLimits: nil)
        #expect(tiktok.mediaRequired)

        let youtube = PlatformRules.limits(for: "youtube", serverLimits: nil)
        #expect(youtube.mediaRequired)

        let pinterest = PlatformRules.limits(for: "pinterest", serverLimits: nil)
        #expect(pinterest.mediaRequired)

        let bluesky = PlatformRules.limits(for: "bluesky", serverLimits: nil)
        #expect(bluesky.maxCharacters == 300)

        let mastodon = PlatformRules.limits(for: "mastodon", serverLimits: nil)
        #expect(mastodon.maxCharacters == 500)
    }

    @Test("server-supplied limits override the table's characters/editor, not media rules")
    func serverOverrideWins() {
        let limits = PlatformRules.limits(
            for: "x",
            serverLimits: (maxCharacters: 999, editor: "markdown")
        )
        #expect(limits.maxCharacters == 999)
        #expect(limits.editor == "markdown")
        // media rules still come from the table
        #expect(limits.maxImages == 4)
        #expect(limits.maxVideos == 1)
    }

    @Test("unknown provider identifier falls back to the conservative default")
    func unknownProviderDefault() {
        let limits = PlatformRules.limits(for: "some-new-provider", serverLimits: nil)
        #expect(limits == PlatformRules.defaultLimits)
        #expect(limits.maxCharacters == 280)
        #expect(limits.maxImages == 4)
        #expect(limits.maxVideos == 1)
        #expect(!limits.mediaRequired)
    }

    @Test("x weights URLs as 23 characters regardless of actual length")
    func xURLWeighting() {
        let limits = PlatformRules.limits(for: "x", serverLimits: nil)
        let shortURL = "check https://example.com out"
        let longURL = "check https://example.com/a/very/long/path/that/is/definitely/over/23/chars out"

        let shortRemaining = PostValidator.remainingCharacters(text: shortURL, identifier: "x", limits: limits)
        let longRemaining = PostValidator.remainingCharacters(text: longURL, identifier: "x", limits: limits)

        // Both URLs count as exactly 23 chars, so the non-URL text length difference is the only variance.
        let nonURLShort = shortURL.count - "https://example.com".count
        let nonURLLong = longURL.count - "https://example.com/a/very/long/path/that/is/definitely/over/23/chars".count
        #expect(nonURLShort == nonURLLong)
        #expect(shortRemaining == longRemaining)
        #expect(limits.maxCharacters - shortRemaining == nonURLShort + 23)
    }

    @Test("instagram post without media triggers mediaRequired")
    func instagramWithoutMediaRequiresMedia() {
        let issues = PostValidator.validate(
            text: "hello world",
            mediaCounts: (images: 0, videos: 0),
            channel: (identifier: "instagram", refreshNeeded: false, disabled: false, serverLimits: nil)
        )
        #expect(issues.contains(.mediaRequired))
    }

    @Test("refreshNeeded channel surfaces needsReconnect")
    func refreshNeededSurfacesReconnect() {
        let issues = PostValidator.validate(
            text: "hello",
            mediaCounts: (images: 0, videos: 0),
            channel: (identifier: "x", refreshNeeded: true, disabled: false, serverLimits: nil)
        )
        #expect(issues.contains(.needsReconnect))
    }

    @Test("disabled channel surfaces channelDisabled")
    func disabledChannelSurfacesChannelDisabled() {
        let issues = PostValidator.validate(
            text: "hello",
            mediaCounts: (images: 0, videos: 0),
            channel: (identifier: "x", refreshNeeded: false, disabled: true, serverLimits: nil)
        )
        #expect(issues.contains(.channelDisabled))
    }

    @Test("empty text triggers .empty")
    func emptyTextTriggersEmpty() {
        let issues = PostValidator.validate(
            text: "   ",
            mediaCounts: (images: 0, videos: 0),
            channel: (identifier: "x", refreshNeeded: false, disabled: false, serverLimits: nil)
        )
        #expect(issues.contains(.empty))
    }

    @Test("text over the limit triggers tooLong with count/limit")
    func overLimitTriggersTooLong() {
        let limits = PlatformRules.limits(for: "x", serverLimits: nil)
        let text = String(repeating: "a", count: limits.maxCharacters + 5)
        let issues = PostValidator.validate(
            text: text,
            mediaCounts: (images: 0, videos: 1),
            channel: (identifier: "x", refreshNeeded: false, disabled: false, serverLimits: nil)
        )
        #expect(issues.contains(.tooLong(count: limits.maxCharacters + 5, limit: limits.maxCharacters)))
    }

    @Test("too many images/videos are flagged against the table limits")
    func tooManyMediaFlagged() {
        let issues = PostValidator.validate(
            text: "hello",
            mediaCounts: (images: 999, videos: 999),
            channel: (identifier: "x", refreshNeeded: false, disabled: false, serverLimits: nil)
        )
        #expect(issues.contains(.tooManyImages(limit: 4)))
        #expect(issues.contains(.tooManyVideos(limit: 1)))
    }
}
