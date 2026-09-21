import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives the `AnalyticsEndpoints` builders through a real `APIClient` + scripted
/// `MockTransport`, asserting on the request `APIClient` actually sent (mirrors
/// `PostsExtrasEndpointTests`). Mirrors `mobile-analytics.controller.ts`.
@Suite("AnalyticsEndpoints")
struct AnalyticsEndpointTests {
    private static let showorgHeader = HTTPField.Name("showorg")!

    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    @Test("channel: GET /analytics/channel/:integration?date= with org header")
    func channel() async throws {
        let endpoint = AnalyticsEndpoints.channel(
            integration: "i1", date: .thirtyDays, orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: [
                AnalyticsSeries(
                    label: "followers",
                    data: [AnalyticsPoint(total: "12", date: "2026-01-01")],
                    percentageChange: 5.5)
            ])
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/analytics/channel/i1?"))
        #expect(path.contains("date=30"))
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
        #expect(result.first?.label == "followers")
    }

    @Test("post: GET /analytics/post/:postId?date=")
    func post() async throws {
        let endpoint = AnalyticsEndpoints.post(postId: "p1", date: .sevenDays)
        let transport = MockTransport()
        try await transport.enqueue(json: [AnalyticsSeries]())
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/analytics/post/p1?"))
        #expect(path.contains("date=7"))
        #expect(result.isEmpty)
    }
}
