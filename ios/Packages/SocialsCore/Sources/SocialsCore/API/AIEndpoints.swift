import CuantoNet
import Foundation

/// AI consent/suggest builders — split from `SocialsEndpoints` for the same reason as
/// `LibraryEndpoints.swift`/`NotificationsEndpoints.swift`. Credits/image/video builders
/// (`aiCredits`, `aiGenerateImage`, `aiGenerateVideo`) already live on `SocialsEndpoints`
/// itself; this file only adds the routes `mobile-ai.controller.ts` reads solely from the
/// authenticated user (no org header): GET/POST /mobile/v1/ai/consent, POST
/// /mobile/v1/ai/suggest.
extension SocialsEndpoints {
    // MARK: - AI consent/suggest (mobile-ai.controller.ts)

    public static func aiConsent() -> Endpoint<AIConsentResponse> {
        Endpoint(path: "\(basePath)/ai/consent")
    }

    public static func setAiConsent(_ body: AIConsentRequest) throws -> Endpoint<AIConsentResponse>
    {
        try Endpoint(method: .post, path: "\(basePath)/ai/consent", body: .json(body))
    }

    public static func aiSuggest(_ body: AISuggestRequest) throws -> Endpoint<AISuggestResponse> {
        try Endpoint(method: .post, path: "\(basePath)/ai/suggest", body: .json(body))
    }
}
