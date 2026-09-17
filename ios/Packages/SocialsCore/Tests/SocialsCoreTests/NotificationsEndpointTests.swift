import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives the `SocialsEndpoints` notifications builders (`NotificationsEndpoints.swift`)
/// through a real `APIClient` + scripted `MockTransport`. Same harness as `LibraryEndpointTests`.
@Suite("NotificationsEndpoints")
struct NotificationsEndpointTests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    @Test("notificationsCount: GET /notifications")
    func notificationsCount() async throws {
        let endpoint = SocialsEndpoints.notificationsCount()
        let transport = MockTransport()
        try await transport.enqueue(json: NotificationsCountResponse(total: 3))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/notifications")
        #expect(result.total == 3)
    }

    @Test("notificationsList: GET /notifications/list")
    func notificationsList() async throws {
        let endpoint = SocialsEndpoints.notificationsList()
        let transport = MockTransport()
        try await transport.enqueue(
            json: NotificationsListResponse(
                lastReadNotifications: "2026-01-01T00:00:00Z",
                notifications: [
                    MobileNotification(content: "hello", createdAt: "2026-01-02T00:00:00Z")
                ]))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/notifications/list")
        #expect(result.lastReadNotifications == "2026-01-01T00:00:00Z")
        #expect(result.notifications.first?.content == "hello")
    }
}
