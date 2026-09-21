import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s channel management methods (settings, lifecycle, connect,
/// function) through a scripted `MockTransport`, mirroring `LiveSocialsAPITests`.
@Suite("SocialsAPI channel settings/lifecycle/connect/function")
struct ChannelSettingsAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - Happy path

    @Test("updateChannelSettings: decodes raw response body")
    func updateChannelSettingsDecodesRaw() async throws {
        let transport = MockTransport()
        await transport.enqueue(status: 200, body: Data(#"{"posted":true}"#.utf8))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.updateChannelSettings(
            "c1", body: ChannelSettingsRequest(additionalSettings: "{}"))

        #expect(response.raw == #"{"posted":true}"#)
    }

    @Test("disableChannel: sends POST to /channels/:id/disable")
    func disableChannelSendsRequest() async throws {
        let transport = MockTransport()
        await transport.enqueue(status: 200, body: Data(#"{"posted":true}"#.utf8))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.disableChannel("c1")

        #expect(response.raw == #"{"posted":true}"#)
        let recorded = await transport.recordedRequests
        #expect(recorded.count == 1)
        #expect(recorded[0].request.path == "/mobile/v1/channels/c1/disable")
    }

    @Test("deleteChannel: sends DELETE to /channels/:id")
    func deleteChannelSendsRequest() async throws {
        let transport = MockTransport()
        await transport.enqueue(status: 200, body: Data(#"{"posted":true}"#.utf8))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.deleteChannel("c1")

        let recorded = await transport.recordedRequests
        #expect(recorded.count == 1)
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/channels/c1")
    }

    @Test("connectStart: decodes {url, state} response")
    func connectStartDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            status: 200, json: ChannelConnectResponse(url: "https://x.example/oauth", state: "s1"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.connectStart(
            provider: "x", refresh: nil, externalUrl: nil)

        #expect(response.url == "https://x.example/oauth")
        #expect(response.state == "s1")
    }

    @Test("channelMentions: decodes mention array")
    func channelMentionsDecodesArray() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            status: 200, json: [ChannelMentionDTO(id: "1", image: nil, label: "@alice")])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.channelMentions(
            ChannelFunctionRequest(name: "mentions", id: "c1", data: "al"))

        #expect(response.mentions.count == 1)
        #expect(response.mentions[0].label == "@alice")
        #expect(response.none == false)
    }

    @Test("channelMentions: decodes {none: true} when unsupported")
    func channelMentionsDecodesNone() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 200, json: ["none": true])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.channelMentions(
            ChannelFunctionRequest(name: "mentions", id: "c1", data: "al"))

        #expect(response.mentions.isEmpty)
        #expect(response.none == true)
    }

    // MARK: - Error mapping

    @Test("connectStart: 400 {msg} maps to .validation with message")
    func connectStartValidationError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 400, json: ["msg": "Integration not allowed"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.connectStart(provider: "bad", refresh: nil, externalUrl: nil)
            Issue.record("expected SocialsAPIError.validation to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .validation(message: "Integration not allowed"))
        }
    }

    @Test("deleteChannel: 404 {msg} maps to .notFound with message")
    func deleteChannelNotFound() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Channel not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.deleteChannel("missing")
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Channel not found"))
        }
    }
}
