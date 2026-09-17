import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// `LiveSocialsAPI` AI consent/suggest: happy-path decode, 403 `{msg: 'AI consent required'}`
/// → `.aiConsentRequired`, 402 → `.aiNotInPlan`, and `StubSocialsAPI` call recording
/// (apps/backend/src/api/routes/mobile/mobile-ai.controller.ts).
@Suite("AITextAPI")
struct AITextAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - Happy path (decode)

    @Test("aiConsent: decodes {aiConsentAt}")
    func aiConsentDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 200, json: ["aiConsentAt": "2026-01-01T00:00:00Z"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.aiConsent()

        #expect(response == AIConsentResponse(aiConsentAt: "2026-01-01T00:00:00Z"))
    }

    @Test("setAIConsent: decodes {aiConsentAt}")
    func setAIConsentDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 200, json: ["aiConsentAt": "2026-01-01T00:00:00Z"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.setAIConsent(AIConsentRequest(granted: true))

        #expect(response == AIConsentResponse(aiConsentAt: "2026-01-01T00:00:00Z"))
    }

    @Test("aiSuggest: decodes {suggestions}")
    func aiSuggestDecodes() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 200, json: ["suggestions": ["hi", "hey"]])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.aiSuggest(
            AISuggestRequest(content: "hello", mode: .variations))

        #expect(response == AISuggestResponse(suggestions: ["hi", "hey"]))
    }

    // MARK: - Error mapping

    @Test("aiSuggest: 403 {msg: 'AI consent required'} maps to .aiConsentRequired")
    func consentRequired() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 403, json: ["msg": "AI consent required"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiSuggest(AISuggestRequest(content: "hello", mode: .variations))
            Issue.record("expected SocialsAPIError.aiConsentRequired to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .aiConsentRequired)
        }
    }

    @Test("aiSuggest: other 403 stays .forbidden")
    func otherForbiddenStaysForbidden() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 403, json: ["msg": "Forbidden"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiSuggest(AISuggestRequest(content: "hello", mode: .variations))
            Issue.record("expected SocialsAPIError.forbidden to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .forbidden(message: "Forbidden"))
        }
    }

    @Test("aiSuggest: 402 {section: ai} maps to .aiNotInPlan")
    func notInPlan() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 402, json: ["section": "ai", "action": "create"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiSuggest(AISuggestRequest(content: "hello", mode: .variations))
            Issue.record("expected SocialsAPIError.aiNotInPlan to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .aiNotInPlan)
        }
    }

    @Test("aiSuggest: 503 'AI not configured' maps to .server(code: 503, ...)")
    func aiNotConfigured() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 503, json: ["msg": "AI not configured"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.aiSuggest(AISuggestRequest(content: "hello", mode: .variations))
            Issue.record("expected SocialsAPIError.server to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .server(code: 503, message: "AI not configured"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records aiConsent/setAIConsent/aiSuggest calls and replays results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setAiConsentResults([.success(AIConsentResponse(aiConsentAt: nil))])
        await stub.setSetAIConsentResults([
            .success(AIConsentResponse(aiConsentAt: "2026-01-01T00:00:00Z"))
        ])
        await stub.setAiSuggestResults([.success(AISuggestResponse(suggestions: ["hi"]))])

        _ = try await stub.aiConsent()
        _ = try await stub.setAIConsent(AIConsentRequest(granted: true))
        _ = try await stub.aiSuggest(AISuggestRequest(content: "hello", mode: .fit))

        let consentCalls = await stub.aiConsentCallCount
        #expect(consentCalls == 1)
        let setConsentCalls = await stub.setAIConsentCalls
        #expect(setConsentCalls == [true])
        let suggestCalls = await stub.aiSuggestCalls
        #expect(suggestCalls == [AISuggestRequest(content: "hello", mode: .fit)])
    }
}

extension StubSocialsAPI {
    fileprivate func setAiConsentResults(_ results: [Result<AIConsentResponse, Error>]) async {
        aiConsentResults = results
    }

    fileprivate func setSetAIConsentResults(_ results: [Result<AIConsentResponse, Error>]) async {
        setAIConsentResults = results
    }

    fileprivate func setAiSuggestResults(_ results: [Result<AISuggestResponse, Error>]) async {
        aiSuggestResults = results
    }
}
