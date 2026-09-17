import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s notifications methods through a scripted `MockTransport`,
/// mirroring `PostsExtrasAPITests`. Also exercises `StubSocialsAPI`'s call recording.
@Suite("SocialsAPI notifications")
struct NotificationsAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - LiveSocialsAPI happy path

    @Test("notificationsCount: GET /notifications decodes total")
    func notificationsCountDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: NotificationsCountResponse(total: 2))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.notificationsCount()

        #expect(response.total == 2)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/notifications")
    }

    @Test("notificationsList: GET /notifications/list decodes envelope")
    func notificationsListDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: NotificationsListResponse(
                lastReadNotifications: "2026-01-01T00:00:00Z",
                notifications: [
                    MobileNotification(content: "hi", createdAt: "2026-01-02T00:00:00Z")
                ]))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.notificationsList()

        #expect(response.notifications.count == 1)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/notifications/list")
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setNotificationsCountResults([.success(NotificationsCountResponse(total: 5))])
        await stub.setNotificationsListResults([
            .success(
                NotificationsListResponse(
                    lastReadNotifications: "2026-01-01T00:00:00Z", notifications: []))
        ])

        let count = try await stub.notificationsCount()
        _ = try await stub.notificationsList()

        #expect(count.total == 5)
        let countCalls = await stub.notificationsCountCallCount
        #expect(countCalls == 1)
        let listCalls = await stub.notificationsListCallCount
        #expect(listCalls == 1)
    }
}

extension StubSocialsAPI {
    fileprivate func setNotificationsCountResults(
        _ results: [Result<NotificationsCountResponse, Error>]
    ) async {
        notificationsCountResults = results
    }

    fileprivate func setNotificationsListResults(
        _ results: [Result<NotificationsListResponse, Error>]
    ) async {
        notificationsListResults = results
    }
}
