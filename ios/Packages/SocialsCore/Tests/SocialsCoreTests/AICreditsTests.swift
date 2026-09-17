import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// `LiveSocialsAPI` AI credits/image/video generation: happy-path decode plus the
/// 402 → `.aiNotInPlan`/`.aiCreditsExhausted` split (docs/IOS-APP-PLAN.md §4.7,
/// apps/backend/src/api/routes/mobile/mobile-ai.controller.ts).
@Suite("AICredits")
struct AICreditsTests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - Happy path (decode)

    @Test("aiCredits: decodes {credits} response")
    func aiCreditsDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 200, json: ["credits": 7])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.aiCredits(type: "ai_images")

        #expect(response == AICreditsResponse(credits: 7))
    }

    @Test("aiGenerateImage: decodes saved media")
    func aiGenerateImageDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            status: 200, json: ["id": "m1", "name": "img.png", "path": "https://cdn/img.png"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.aiGenerateImage(prompt: "a cat")

        #expect(
            response == AIMediaResult(id: "m1", name: "img.png", path: "https://cdn/img.png"))
    }

    @Test("aiGenerateVideo: decodes saved media")
    func aiGenerateVideoDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            status: 200, json: ["id": "m2", "name": "clip.mp4", "path": "https://cdn/clip.mp4"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.aiGenerateVideo(
            AIVideoRequest(type: "text2video", output: "vertical"))

        #expect(
            response == AIMediaResult(id: "m2", name: "clip.mp4", path: "https://cdn/clip.mp4"))
    }

    // MARK: - 402 mapping

    @Test("aiGenerateImage: 402 {section: ai} maps to .aiNotInPlan")
    func notInPlan() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 402, json: ["section": "ai", "action": "create"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiGenerateImage(prompt: "a cat")
            Issue.record("expected SocialsAPIError.aiNotInPlan to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .aiNotInPlan)
        }
    }

    @Test("aiGenerateImage: 402 credits message maps to .aiCreditsExhausted")
    func creditsExhausted() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 402, json: ["msg": "No credits left"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiGenerateImage(prompt: "a cat")
            Issue.record("expected SocialsAPIError.aiCreditsExhausted to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .aiCreditsExhausted)
        }
    }

    @Test("aiGenerateVideo: 402 with an unrecognized body falls back to .server")
    func unknownPaymentError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 402, json: ["msg": "Payment required"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiGenerateVideo(AIVideoRequest(type: "text2video", output: "vertical"))
            Issue.record("expected SocialsAPIError.server to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .server(code: 402, message: "Payment required"))
        }
    }
}
