import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s analytics methods (channelAnalytics, postAnalytics) through a
/// scripted `MockTransport`, mirroring `PostsExtrasAPITests`. Also exercises `StubSocialsAPI`'s
/// call recording for the same set.
@Suite("SocialsAPI analytics")
struct AnalyticsAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - LiveSocialsAPI happy path

    @Test("channelAnalytics: GET /analytics/channel/:integration?date= decodes series")
    func channelAnalyticsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: [
                AnalyticsSeries(
                    label: "followers",
                    data: [AnalyticsPoint(total: "12", date: "2026-01-01")],
                    percentageChange: 5.5)
            ])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.channelAnalytics(integrationId: "i1", range: .thirtyDays)

        #expect(response.first?.label == "followers")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path?.hasPrefix("/mobile/v1/analytics/channel/i1?") == true)
        #expect(recorded[0].request.path?.contains("date=30") == true)
    }

    @Test("postAnalytics: GET /analytics/post/:postId?date= decodes series")
    func postAnalyticsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: [AnalyticsSeries]())
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.postAnalytics(postId: "p1", range: .sevenDays)

        #expect(response.isEmpty)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path?.hasPrefix("/mobile/v1/analytics/post/p1?") == true)
        #expect(recorded[0].request.path?.contains("date=7") == true)
    }

    // MARK: - Error mapping

    @Test("channelAnalytics: 404 {msg} maps to .notFound with message")
    func channelAnalyticsNotFoundError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Integration not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.channelAnalytics(integrationId: "missing", range: .sevenDays)
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Integration not found"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setChannelAnalyticsResults([.success([
            AnalyticsSeries(label: "followers", data: [], percentageChange: 0)
        ])])
        await stub.setPostAnalyticsResults([.success([])])

        _ = try await stub.channelAnalytics(integrationId: "i1", range: .thirtyDays)
        _ = try await stub.postAnalytics(postId: "p1", range: .sevenDays)

        let channelCalls = await stub.channelAnalyticsCalls
        #expect(channelCalls.count == 1)
        #expect(channelCalls[0].0 == "i1")
        #expect(channelCalls[0].1 == .thirtyDays)

        let postCalls = await stub.postAnalyticsCalls
        #expect(postCalls.count == 1)
        #expect(postCalls[0].0 == "p1")
        #expect(postCalls[0].1 == .sevenDays)
    }
}

extension StubSocialsAPI {
    fileprivate func setChannelAnalyticsResults(_ results: [Result<[AnalyticsSeries], Error>]) async {
        channelAnalyticsResults = results
    }

    fileprivate func setPostAnalyticsResults(_ results: [Result<[AnalyticsSeries], Error>]) async {
        postAnalyticsResults = results
    }
}
