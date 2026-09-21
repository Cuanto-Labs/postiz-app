import Foundation

// MARK: - AI credits/image/video

/// `GET /mobile/v1/ai/credits` response — remaining AI image/video generation credits for
/// the org's current billing period (`SubscriptionService.checkCredits`).
public struct AICreditsResponse: Decodable, Sendable, Equatable {
    public let credits: Int

    public init(credits: Int) {
        self.credits = credits
    }
}

/// `POST /mobile/v1/ai/image` request body (mirrors `MobileAiImageDto`).
public struct AIImageRequest: Encodable, Sendable, Equatable {
    public let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

/// `POST /mobile/v1/ai/video` request body (mirrors `MobileAiVideoDto` / `VideoDto`).
public struct AIVideoRequest: Encodable, Sendable, Equatable {
    public let type: String
    public let output: String

    public init(type: String, output: String) {
        self.type = type
        self.output = output
    }
}

/// `POST /mobile/v1/ai/image` and `/ai/video` response — the generated media, already
/// saved to the org's media library (`MediaService.saveFile`).
public struct AIMediaResult: Decodable, Sendable, Equatable {
    public let id: String
    public let name: String?
    public let path: String

    public init(id: String, name: String?, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

// MARK: - AI consent/suggest

/// `POST /mobile/v1/ai/consent` request body (mirrors `MobileAiConsentDto`).
public struct AIConsentRequest: Encodable, Sendable, Equatable {
    public let granted: Bool

    public init(granted: Bool) {
        self.granted = granted
    }
}

/// `GET`/`POST /mobile/v1/ai/consent` response — `AiConsentRepository.getConsentAt`/
/// `setConsent`, `nil` when consent has never been granted.
public struct AIConsentResponse: Codable, Sendable, Equatable {
    public let aiConsentAt: String?

    public init(aiConsentAt: String?) {
        self.aiConsentAt = aiConsentAt
    }
}

/// `MobileAiSuggestDto.mode` — `'variations'` rewrites the post, `'fit'` splits it to fit
/// `maxLength`.
public enum AISuggestMode: String, Encodable, Sendable, Equatable {
    case variations
    case fit
}

/// `POST /mobile/v1/ai/suggest` request body (mirrors `MobileAiSuggestDto`; `content` is
/// capped at 5000 chars, `maxLength` at 1-10000, server-side).
public struct AISuggestRequest: Encodable, Sendable, Equatable {
    public let content: String
    public let mode: AISuggestMode
    public let maxLength: Int?

    public init(content: String, mode: AISuggestMode, maxLength: Int? = nil) {
        self.content = content
        self.mode = mode
        self.maxLength = maxLength
    }
}

/// `POST /mobile/v1/ai/suggest` response (`MobileAiService.suggest`). 403 `{msg: 'AI consent
/// required'}` when consent hasn't been granted, 503 `{msg: 'AI not configured'}` when
/// `OPENAI_API_KEY` is unset.
public struct AISuggestResponse: Codable, Sendable, Equatable {
    public let suggestions: [String]

    public init(suggestions: [String]) {
        self.suggestions = suggestions
    }
}
