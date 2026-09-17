import Testing

@testable import SocialsCore

@Suite("ProviderCrossFieldValidator")
struct ProviderCrossFieldValidatorTests {
    @Test("instagram story with more than one media item is rejected")
    func instagramStoryNeedsSingleMedia() {
        let errors = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: ["post_type": "story"], imageCount: 2, videoCount: 0)
        #expect(errors == [.instagramStoryNeedsSingleMedia])
    }

    @Test("instagram story with exactly one media item is fine")
    func instagramStorySingleMediaOK() {
        let errors = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram-standalone", settings: ["post_type": "story"], imageCount: 1,
            videoCount: 0)
        #expect(errors.isEmpty)
    }

    @Test("instagram trial reel requires exactly one video and no photos")
    func instagramTrialReelNeedsSingleVideo() {
        let withPhoto = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: ["is_trial_reel": "true"], imageCount: 1, videoCount: 1)
        #expect(withPhoto == [.instagramTrialReelNeedsSingleVideo])

        let noVideo = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: ["is_trial_reel": "true"], imageCount: 0, videoCount: 0)
        #expect(noVideo.isEmpty, "zero media is PostValidator.mediaRequired's job, not this validator's")

        let ok = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: ["is_trial_reel": "true"], imageCount: 0, videoCount: 1)
        #expect(ok.isEmpty)
    }

    @Test("instagram carousel over 10 items is rejected")
    func instagramCarouselLimit() {
        let errors = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: [:], imageCount: 11, videoCount: 0)
        #expect(errors == [.instagramTooManyCarouselItems(limit: 10)])
    }

    @Test("linkedin carousel on requires at least 2 images and rejects any video")
    func linkedinCarouselRules() {
        let tooFewImages = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin", settings: ["post_as_images_carousel": "true"], imageCount: 1,
            videoCount: 0)
        #expect(tooFewImages == [.linkedinCarouselNeedsMoreImages(minimum: 2)])

        let withVideo = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin-page", settings: ["post_as_images_carousel": "true"], imageCount: 2,
            videoCount: 1)
        #expect(withVideo == [.linkedinCarouselNoVideo])

        let ok = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin", settings: ["post_as_images_carousel": "true"], imageCount: 3,
            videoCount: 0)
        #expect(ok.isEmpty)
    }

    @Test("linkedin without carousel allows at most one video")
    func linkedinNonCarouselVideoCap() {
        let tooMany = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin", settings: [:], imageCount: 0, videoCount: 2)
        #expect(tooMany == [.linkedinTooManyVideos(limit: 1)])

        let ok = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin", settings: [:], imageCount: 0, videoCount: 1)
        #expect(ok.isEmpty)
    }

    @Test("zero media never triggers cross-field errors")
    func zeroMediaIsPermissive() {
        let instagram = ProviderCrossFieldValidator.validate(
            providerIdentifier: "instagram", settings: ["post_type": "story"], imageCount: 0, videoCount: 0)
        #expect(instagram.isEmpty)

        let linkedin = ProviderCrossFieldValidator.validate(
            providerIdentifier: "linkedin", settings: ["post_as_images_carousel": "true"], imageCount: 0,
            videoCount: 0)
        #expect(linkedin.isEmpty)
    }

    @Test("providers without cross-field rules always pass")
    func otherProvidersUnaffected() {
        let errors = ProviderCrossFieldValidator.validate(
            providerIdentifier: "facebook", settings: ["post_as_images_carousel": "true"], imageCount: 0,
            videoCount: 5)
        #expect(errors.isEmpty)
    }
}
