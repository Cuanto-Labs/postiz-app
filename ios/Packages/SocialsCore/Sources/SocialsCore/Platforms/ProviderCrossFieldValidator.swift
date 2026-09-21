import Foundation

/// A provider-specific rule violation that spans more than one field (settings + media counts
/// together), so it can't be expressed by `PlatformRules`/`PostValidator` (single-field limits)
/// or `ProviderSettingsSchema.validate` (single-field DTO shape). Mirrors the same server-side
/// `checkValidity` cross-checks each provider's `social.abstract.ts` subclass runs before publish.
public enum ProviderCrossFieldError: Sendable, Equatable {
    case instagramStoryNeedsSingleMedia
    case instagramTrialReelNeedsSingleVideo
    case instagramTooManyCarouselItems(limit: Int)
    case linkedinCarouselNeedsMoreImages(minimum: Int)
    case linkedinCarouselNoVideo
    case linkedinTooManyVideos(limit: Int)

    public var message: String {
        switch self {
        case .instagramStoryNeedsSingleMedia:
            return "Instagram stories take exactly one photo or video."
        case .instagramTrialReelNeedsSingleVideo:
            return "Trial reels need exactly one video and no photos."
        case .instagramTooManyCarouselItems(let limit):
            return "Instagram carousels max out at \(limit) items."
        case .linkedinCarouselNeedsMoreImages(let minimum):
            return "Image carousel needs at least \(minimum) images."
        case .linkedinCarouselNoVideo:
            return "Image carousel can't include a video — turn off the carousel or remove the video."
        case .linkedinTooManyVideos(let limit):
            return "LinkedIn allows \(limit) video per post."
        }
    }
}

/// Cross-field validation for providers whose `checkValidity` couples settings to media counts:
/// Instagram (`post_type`/`is_trial_reel` vs. media) and LinkedIn (`post_as_images_carousel` vs.
/// media). Dispatches by `providerIdentifier` — the one place allowed to know provider names, per
/// the repo rule against per-provider branching in generic code (every other file in
/// `SocialsCore/Platforms` stays provider-agnostic).
public enum ProviderCrossFieldValidator {
    /// `settings` is the raw string form state from `ProviderSettingsFormView` (toggles as
    /// `"true"`/`"false"`, mirrors `ProviderSettingsField`). Media-count-only failures (zero media
    /// on a media-required provider) are `PostValidator.mediaRequired`'s job, not this validator's
    /// — this only fires once there IS media to cross-check against settings.
    public static func validate(
        providerIdentifier: String,
        settings: [String: String],
        imageCount: Int,
        videoCount: Int
    ) -> [ProviderCrossFieldError] {
        switch providerIdentifier {
        case "instagram", "instagram-standalone":
            return instagramErrors(settings: settings, imageCount: imageCount, videoCount: videoCount)
        case "linkedin", "linkedin-page":
            return linkedinErrors(settings: settings, imageCount: imageCount, videoCount: videoCount)
        default:
            return []
        }
    }

    private static func instagramErrors(
        settings: [String: String], imageCount: Int, videoCount: Int
    ) -> [ProviderCrossFieldError] {
        let total = imageCount + videoCount
        guard total > 0 else { return [] }

        var errors: [ProviderCrossFieldError] = []
        if settings["post_type"] == "story", total != 1 {
            errors.append(.instagramStoryNeedsSingleMedia)
        }
        if settings["is_trial_reel"] == "true", videoCount != 1 || imageCount != 0 {
            errors.append(.instagramTrialReelNeedsSingleVideo)
        }
        if imageCount + videoCount > 10 {
            errors.append(.instagramTooManyCarouselItems(limit: 10))
        }
        return errors
    }

    private static func linkedinErrors(
        settings: [String: String], imageCount: Int, videoCount: Int
    ) -> [ProviderCrossFieldError] {
        guard imageCount + videoCount > 0 else { return [] }

        var errors: [ProviderCrossFieldError] = []
        if settings["post_as_images_carousel"] == "true" {
            if imageCount < 2 {
                errors.append(.linkedinCarouselNeedsMoreImages(minimum: 2))
            }
            if videoCount > 0 {
                errors.append(.linkedinCarouselNoVideo)
            }
        } else if videoCount > 1 {
            errors.append(.linkedinTooManyVideos(limit: 1))
        }
        return errors
    }
}
