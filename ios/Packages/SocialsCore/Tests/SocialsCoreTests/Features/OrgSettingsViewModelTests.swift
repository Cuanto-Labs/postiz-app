import Foundation
import Testing

@testable import SocialsCore

@Suite("OrgSettingsViewModel")
@MainActor
struct OrgSettingsViewModelTests {

    private func webhook(id: String = "wh-1", name: String = "Slack", url: String = "https://example.com")
        -> MobileWebhook
    {
        MobileWebhook(id: id, name: name, url: url, integrations: [])
    }

    @Test("load populates both shortlink preference and webhooks")
    func loadPopulatesBoth() async {
        let api = StubSocialsAPI()
        await api.setShortlinkPreferenceResults([.success(ShortlinkPreferenceResponse(shortlink: .yes))])
        await api.setWebhooksResults([.success([webhook()])])
        let viewModel = OrgSettingsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.shortlink == .yes)
        #expect(viewModel.webhooks == [webhook()])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("setShortlink records the call and reflects the saved value")
    func setShortlinkRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setShortlinkPreferenceResults([.success(ShortlinkPreferenceResponse(shortlink: .ask))])
        await api.setWebhooksResults([.success([])])
        await api.setSetShortlinkResults([.success(ShortlinkPreferenceResponse(shortlink: .yes))])
        let viewModel = OrgSettingsViewModel(api: api)
        await viewModel.load()

        await viewModel.setShortlink(.yes)

        let calls = await api.setShortlinkCalls
        #expect(calls == [.yes])
        #expect(viewModel.shortlink == .yes)
    }

    @Test("failed save reverts the picker and surfaces an error")
    func failedSaveReverts() async {
        let api = StubSocialsAPI()
        await api.setShortlinkPreferenceResults([.success(ShortlinkPreferenceResponse(shortlink: .ask))])
        await api.setWebhooksResults([.success([])])
        await api.setSetShortlinkResults([.failure(SocialsAPIError.offline)])
        let viewModel = OrgSettingsViewModel(api: api)
        await viewModel.load()

        await viewModel.setShortlink(.yes)

        #expect(viewModel.shortlink == .ask)
        #expect(viewModel.errorMessage != nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setShortlinkPreferenceResults(_ results: [Result<ShortlinkPreferenceResponse, Error>]) {
        shortlinkResults = results
    }

    fileprivate func setWebhooksResults(_ results: [Result<[MobileWebhook], Error>]) {
        webhooksResults = results
    }

    fileprivate func setSetShortlinkResults(_ results: [Result<ShortlinkPreferenceResponse, Error>]) {
        setShortlinkResults = results
    }
}
