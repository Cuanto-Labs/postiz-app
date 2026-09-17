import Testing

@testable import SocialsCore

@Suite("MediaLimits")
struct MediaLimitsTests {
    @Test("instagram accepts its three published aspect ratios")
    func instagramAcceptsPublishedRatios() {
        let square = SelectedMediaAttributes(
            id: "1", kind: .image, aspectRatio: MediaAspectRatio(width: 1080, height: 1080), durationSeconds: nil)
        let portrait = SelectedMediaAttributes(
            id: "2", kind: .image, aspectRatio: MediaAspectRatio(width: 1080, height: 1350), durationSeconds: nil)
        let landscape = SelectedMediaAttributes(
            id: "3", kind: .image, aspectRatio: MediaAspectRatio(width: 1910, height: 1000), durationSeconds: nil)

        let violations = MediaLimits.violations(
            for: [square, portrait, landscape], providerIdentifier: "instagram")
        #expect(violations.isEmpty)
    }

    @Test("instagram rejects 16:9 with a message naming the crop and the allowed list")
    func instagramRejectsWrongRatio() {
        let widescreen = SelectedMediaAttributes(
            id: "1", kind: .image, aspectRatio: MediaAspectRatio(width: 1920, height: 1080), durationSeconds: nil)

        let violations = MediaLimits.violations(for: [widescreen], providerIdentifier: "instagram")
        #expect(violations.count == 1)
        #expect(violations[0].mediaID == "1")
        #expect(violations[0].message == "Instagram needs a 1:1, 4:5 or 1.91:1 crop — this is 16:9.")
    }

    @Test("aspect ratio tolerance absorbs ~1% decode drift but not more")
    func toleranceIsApproximatelyOnePercent() {
        let almostSquare = SelectedMediaAttributes(
            id: "1", kind: .image, aspectRatio: MediaAspectRatio(width: 1000, height: 1008), durationSeconds: nil)
        #expect(MediaLimits.violations(for: [almostSquare], providerIdentifier: "instagram").isEmpty)

        let offSquare = SelectedMediaAttributes(
            id: "2", kind: .image, aspectRatio: MediaAspectRatio(width: 1000, height: 1100), durationSeconds: nil)
        #expect(!MediaLimits.violations(for: [offSquare], providerIdentifier: "instagram").isEmpty)
    }

    @Test("instagram video over 900s is flagged, under is not")
    func instagramVideoDuration() {
        let tooLong = SelectedMediaAttributes(id: "1", kind: .video, aspectRatio: nil, durationSeconds: 901)
        let ok = SelectedMediaAttributes(id: "2", kind: .video, aspectRatio: nil, durationSeconds: 899)

        let violations = MediaLimits.violations(for: [tooLong, ok], providerIdentifier: "instagram")
        #expect(violations.count == 1)
        #expect(violations[0].mediaID == "1")
        #expect(violations[0].message.contains("900s"))
    }

    @Test("linkedin has no aspect-ratio restriction but caps video duration at 600s")
    func linkedinDurationOnly() {
        let anyRatio = SelectedMediaAttributes(
            id: "1", kind: .image, aspectRatio: MediaAspectRatio(width: 3, height: 1), durationSeconds: nil)
        #expect(MediaLimits.violations(for: [anyRatio], providerIdentifier: "linkedin").isEmpty)

        let tooLong = SelectedMediaAttributes(id: "2", kind: .video, aspectRatio: nil, durationSeconds: 601)
        let violations = MediaLimits.violations(for: [tooLong], providerIdentifier: "linkedin-page")
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("LinkedIn"))
    }

    @Test("unknown provider identifier returns no violations")
    func unknownProviderIsPermissive() {
        let anything = SelectedMediaAttributes(
            id: "1", kind: .video, aspectRatio: MediaAspectRatio(width: 1, height: 5), durationSeconds: 99999)
        #expect(MediaLimits.violations(for: [anything], providerIdentifier: "mastodon").isEmpty)
    }

    @Test("media with no probed dimensions/duration is never flagged")
    func missingAttributesArePermissive() {
        let unknown = SelectedMediaAttributes(id: "1", kind: .video, aspectRatio: nil, durationSeconds: nil)
        #expect(MediaLimits.violations(for: [unknown], providerIdentifier: "instagram").isEmpty)
    }
}

/// The server ships `getMediaLimits(providerIdentifier)` on every channel
/// (`mobile-channels.controller.ts`), so these cover preferring that payload over the local table.
@Suite("MediaLimits — server-supplied limits")
struct MediaLimitsServerPayloadTests {
    private func image(_ id: String, _ w: Double, _ h: Double, bytes: Int? = nil, mime: String? = nil)
        -> SelectedMediaAttributes
    {
        SelectedMediaAttributes(
            id: id, kind: .image, aspectRatio: MediaAspectRatio(width: w, height: h),
            durationSeconds: nil, byteCount: bytes, mimeType: mime)
    }

    @Test("aspect ratios parse from the server's string form")
    func parsesWireRatios() {
        #expect(MediaAspectRatio(wire: "1:1")?.ratio == 1)
        #expect(MediaAspectRatio(wire: "4:5")?.ratio == 0.8)
        #expect(MediaAspectRatio(wire: "1.91:1")?.ratio == 1.91)
        #expect(MediaAspectRatio(wire: "square") == nil)
        #expect(MediaAspectRatio(wire: "1:0") == nil)
    }

    @Test("server limits override the local table, so a backend change needs no app release")
    func serverLimitsWin() {
        // Locally Instagram forbids 9:16; a server that allows it must not be second-guessed.
        let story = image("1", 1080, 1920)
        let served = ChannelMediaLimits(maxVideoSeconds: 900, aspectRatios: ["9:16"])
        #expect(MediaLimits.violations(for: [story], providerIdentifier: "instagram").count == 1)
        #expect(
            MediaLimits.violations(
                for: [story], providerIdentifier: "instagram", serverLimits: served
            ).isEmpty)
    }

    @Test("a provider the local table doesn't know is still validated from the server payload")
    func serverLimitsCoverUnknownProvider() {
        let served = ChannelMediaLimits(aspectRatios: ["9:16"])
        let square = image("1", 1000, 1000)
        #expect(MediaLimits.violations(for: [square], providerIdentifier: "tiktok").isEmpty)
        #expect(
            MediaLimits.violations(
                for: [square], providerIdentifier: "tiktok", serverLimits: served
            ).count == 1)
    }

    @Test("an unparseable ratio entry is ignored rather than blocking every post")
    func unparseableRatioIsIgnored() {
        let served = ChannelMediaLimits(aspectRatios: ["portrait"])
        #expect(
            MediaLimits.violations(
                for: [image("1", 1920, 1080)], providerIdentifier: "instagram", serverLimits: served
            ).isEmpty)
    }

    @Test("MIME outside the server's allow-list is flagged by format name")
    func mimeViolation() {
        let served = ChannelMediaLimits(imageMimes: ["image/jpeg", "image/png"])
        let heic = image("1", 1000, 1000, mime: "image/heic")
        let violations = MediaLimits.violations(
            for: [heic], providerIdentifier: "instagram", serverLimits: served)
        #expect(violations.count == 1)
        #expect(violations[0].message == "Instagram doesn't accept image/heic — use JPEG or PNG.")
        let jpeg = image("2", 1000, 1000, mime: "image/jpeg")
        #expect(
            MediaLimits.violations(for: [jpeg], providerIdentifier: "instagram", serverLimits: served)
                .isEmpty)
    }

    @Test("a file over the server's byte cap is flagged in MB")
    func byteCapViolation() {
        let served = ChannelMediaLimits(maxImageBytes: 8 * 1_048_576, imageMimes: [])
        let big = image("1", 1000, 1000, bytes: 12 * 1_048_576)
        let violations = MediaLimits.violations(
            for: [big], providerIdentifier: "instagram", serverLimits: served)
        #expect(violations.count == 1)
        #expect(violations[0].message == "Instagram caps this file at 8.0MB — this is 12MB.")
    }

    @Test("no byte count probed means no byte violation")
    func missingByteCountIsPermissive() {
        let served = ChannelMediaLimits(maxImageBytes: 1)
        #expect(
            MediaLimits.violations(
                for: [image("1", 1000, 1000)], providerIdentifier: "instagram", serverLimits: served
            ).isEmpty)
    }
}

/// `validate()` previously checked character count and aspect/duration but never how many photos
/// or videos a provider takes, nor whether it refuses a text-only post — Instagram's is the one
/// that matters, since a caption-only post is rejected at publish.
@Suite("ComposerViewModel — media counts")
@MainActor
struct ComposerMediaCountTests {
    private func channel(
        _ identifier: String, media: ChannelMediaLimits? = nil, id: String = "c1"
    ) -> ChannelDTO {
        ChannelDTO(
            id: id, internalId: id, name: identifier, identifier: identifier, picture: nil,
            disabled: false, refreshNeeded: false, inBetweenSteps: false, display: nil,
            type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: 3000, editor: "text", media: media))
    }

    private func viewModel(_ channels: [ChannelDTO]) -> ComposerViewModel {
        let vm = ComposerViewModel(api: StubSocialsAPI(), channels: channels)
        for channel in channels { vm.toggleChannel(channel) }
        vm.setGlobalContent("Launch day.")
        return vm
    }

    private func attach(_ vm: ComposerViewModel, images: Int = 0, videos: Int = 0) {
        for i in 0..<images {
            vm.attachMediaToGlobal(
                MediaDTO(
                    id: "img\(i)", name: "a.jpg", originalName: nil, path: "/a\(i).jpg",
                    thumbnail: nil, alt: nil, thumbnailTimestamp: nil, status: nil,
                    processingError: nil))
        }
        for i in 0..<videos {
            vm.attachMediaToGlobal(
                MediaDTO(
                    id: "vid\(i)", name: "a.mp4", originalName: nil, path: "/a\(i).mp4",
                    thumbnail: nil, alt: nil, thumbnailTimestamp: nil, status: nil,
                    processingError: nil))
        }
    }

    @Test("instagram refuses a caption-only post and blocks submit")
    func instagramNeedsMedia() {
        let ig = channel("instagram")
        let vm = viewModel([ig])
        #expect(vm.mediaCountErrors(for: ig) == ["Instagram needs at least one photo or video."])
        #expect(!vm.isValid)
        attach(vm, images: 1)
        #expect(vm.mediaCountErrors(for: ig).isEmpty)
        #expect(vm.isValid)
    }

    @Test("more photos than the provider takes is flagged with both numbers")
    func tooManyImages() {
        let li = channel("linkedin")
        let vm = viewModel([li])
        attach(vm, images: 12)
        #expect(
            vm.mediaCountErrors(for: li) == ["LinkedIn takes 9 photos per post — this has 12."])
        #expect(!vm.isValid)
    }

    @Test("more than one video is flagged")
    func tooManyVideos() {
        let ig = channel("instagram")
        let vm = viewModel([ig])
        attach(vm, videos: 2)
        #expect(vm.mediaCountErrors(for: ig).contains("Instagram takes 1 video per post — this has 2."))
    }

    @Test("server-sent counts win over the table")
    func serverCountsWin() {
        let li = channel("linkedin", media: ChannelMediaLimits(maxImages: 4, maxVideos: 1))
        let vm = viewModel([li])
        attach(vm, images: 6)
        #expect(vm.mediaCountErrors(for: li) == ["LinkedIn takes 4 photos per post — this has 6."])
    }

    @Test("a text-only provider is unaffected")
    func textOnlyProviderIsQuiet() {
        let x = channel("x")
        let vm = viewModel([x])
        #expect(vm.mediaCountErrors(for: x).isEmpty)
        #expect(vm.isValid)
    }
}
