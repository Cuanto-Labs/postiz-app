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
