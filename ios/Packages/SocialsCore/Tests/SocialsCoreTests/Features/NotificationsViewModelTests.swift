import Foundation
import Testing

@testable import SocialsCore

@Suite("NotificationsViewModel")
@MainActor
struct NotificationsViewModelTests {

    @Test("load populates items and unreadCount from the stub")
    func loadPopulatesItemsAndUnreadCount() async throws {
        let api = StubSocialsAPI()
        await api.setNotificationsCountResults([.success(NotificationsCountResponse(total: 3))])
        await api.setNotificationsListResults([
            .success(
                NotificationsListResponse(
                    lastReadNotifications: "2024-09-01T00:00:00Z",
                    notifications: [
                        MobileNotification(content: "First", createdAt: "2024-09-10T00:00:00Z"),
                        MobileNotification(content: "Second", createdAt: "2024-09-09T00:00:00Z"),
                    ]))
        ])
        let viewModel = NotificationsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.unreadCount == 3)
        #expect(viewModel.notifications.map(\.content) == ["First", "Second"])
        #expect(viewModel.lastReadNotifications == "2024-09-01T00:00:00Z")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load surfaces a message on failure")
    func loadSurfacesError() async throws {
        let api = StubSocialsAPI()
        await api.setNotificationsCountResults([.failure(SocialsAPIError.offline)])
        let viewModel = NotificationsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.notifications.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("refresh re-fetches the list")
    func refreshRefetchesList() async throws {
        let api = StubSocialsAPI()
        await api.setNotificationsCountResults([.success(NotificationsCountResponse(total: 1))])
        await api.setNotificationsListResults([
            .success(NotificationsListResponse(lastReadNotifications: "", notifications: [])),
            .success(
                NotificationsListResponse(
                    lastReadNotifications: "",
                    notifications: [MobileNotification(content: "New", createdAt: "2024-09-11T00:00:00Z")])),
        ])
        let viewModel = NotificationsViewModel(api: api)
        await viewModel.load()

        await viewModel.refresh()

        #expect(await api.notificationsListCallCount == 2)
        #expect(viewModel.notifications.map(\.content) == ["New"])
    }
}

extension StubSocialsAPI {
    fileprivate func setNotificationsCountResults(_ results: [Result<NotificationsCountResponse, Error>]) {
        notificationsCountResults = results
    }
    fileprivate func setNotificationsListResults(_ results: [Result<NotificationsListResponse, Error>]) {
        notificationsListResults = results
    }
}
