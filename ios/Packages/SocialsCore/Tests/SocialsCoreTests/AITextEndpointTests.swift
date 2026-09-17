import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives the `SocialsEndpoints` AI consent/suggest builders (`AIEndpoints.swift`) through a
/// real `APIClient` + scripted `MockTransport`, asserting on the request `APIClient` actually
/// sent. Same harness as `LibraryEndpointTests`/`NotificationsEndpointTests`.
@Suite("AITextEndpoints")
struct AITextEndpointTests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    private func bodyKeys(_ data: Data?) throws -> Set<String> {
        guard let data else { return [] }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set(object.map { Array($0.keys) } ?? [])
    }

    @Test("aiConsent: GET /ai/consent")
    func aiConsent() async throws {
        let endpoint = SocialsEndpoints.aiConsent()
        let transport = MockTransport()
        try await transport.enqueue(json: AIConsentResponse(aiConsentAt: nil))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/ai/consent")
        #expect(result.aiConsentAt == nil)
    }

    @Test("setAiConsent: POST /ai/consent with {granted} body")
    func setAiConsent() async throws {
        let endpoint = try SocialsEndpoints.setAiConsent(AIConsentRequest(granted: true))
        let transport = MockTransport()
        try await transport.enqueue(json: AIConsentResponse(aiConsentAt: "2026-01-01T00:00:00Z"))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/ai/consent")
        #expect(try bodyKeys(recorded.body) == ["granted"])
        #expect(result.aiConsentAt == "2026-01-01T00:00:00Z")
    }

    @Test("aiSuggest: POST /ai/suggest with {content, mode, maxLength} body")
    func aiSuggest() async throws {
        let endpoint = try SocialsEndpoints.aiSuggest(
            AISuggestRequest(content: "hello world", mode: .variations, maxLength: 280))
        let transport = MockTransport()
        try await transport.enqueue(json: AISuggestResponse(suggestions: ["hi", "hey"]))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/ai/suggest")
        #expect(try bodyKeys(recorded.body) == ["content", "mode", "maxLength"])
        #expect(result.suggestions == ["hi", "hey"])
    }

    @Test("aiSuggest: mode encodes as raw string")
    func aiSuggestModeEncoding() async throws {
        let endpoint = try SocialsEndpoints.aiSuggest(
            AISuggestRequest(content: "hello", mode: .fit))
        let transport = MockTransport()
        try await transport.enqueue(json: AISuggestResponse(suggestions: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        let object = try JSONSerialization.jsonObject(with: recorded.body!) as? [String: Any]
        #expect(object?["mode"] as? String == "fit")
    }
}
