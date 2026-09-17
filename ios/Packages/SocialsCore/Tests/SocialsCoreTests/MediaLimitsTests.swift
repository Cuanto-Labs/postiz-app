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
