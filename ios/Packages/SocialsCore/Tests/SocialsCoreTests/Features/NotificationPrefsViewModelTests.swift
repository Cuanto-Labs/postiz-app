import Foundation
import Testing

@testable import SocialsCore

@Suite("NotificationPrefsViewModel")
@MainActor
struct NotificationPrefsViewModelTests {

    @Test("load fetches both email and push prefs")
    func loadFetchesBoth() async {
        let api = StubSocialsAPI()
        await api.setEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: false, sendStreakEmails: true))
        ])
        await api.setPushPrefsResults([
            .success(PushPrefsResponse(prefs: PushPrefs(values: [PushPrefs.postFailed: false])))
        ])
        let viewModel = NotificationPrefsViewModel(api: api)

        await viewModel.load(token: "device-token")

        #expect(viewModel.sendSuccessEmails == true)
        #expect(viewModel.sendFailureEmails == false)
        #expect(viewModel.sendStreakEmails == true)
        #expect(viewModel.isPushEnabled(.postFailed) == false)
        #expect(viewModel.isPushEnabled(.postPublished) == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load with no push token skips the push fetch")
    func loadWithoutTokenSkipsPush() async {
        let api = StubSocialsAPI()
        await api.setEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: true, sendStreakEmails: true))
        ])
        let viewModel = NotificationPrefsViewModel(api: api)

        await viewModel.load(token: nil)

        let calls = await api.pushPrefsCalls
        #expect(calls.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("togglePush records the updated call with the category flag")
    func togglePushRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setPushPrefsResults([.success(PushPrefsResponse(prefs: PushPrefs()))])
        await api.setUpdatePushPrefsResults([
            .success(PushPrefsResponse(prefs: PushPrefs(values: [PushPrefs.postFailed: false])))
        ])
        let viewModel = NotificationPrefsViewModel(api: api)
        await viewModel.load(token: "device-token")

        await viewModel.togglePush(.postFailed, on: false)

        let calls = await api.updatePushPrefsCalls
        #expect(calls.first?.apnsToken == "device-token")
        #expect(calls.first?.prefs[PushPrefs.postFailed] == false)
        #expect(viewModel.isPushEnabled(.postFailed) == false)
    }

    @Test("togglePush failure reverts the value")
    func togglePushFailureReverts() async {
        let api = StubSocialsAPI()
        await api.setPushPrefsResults([.success(PushPrefsResponse(prefs: PushPrefs()))])
        await api.setUpdatePushPrefsResults([.failure(SocialsAPIError.offline)])
        let viewModel = NotificationPrefsViewModel(api: api)
        await viewModel.load(token: "device-token")

        await viewModel.togglePush(.postFailed, on: false)

        #expect(viewModel.isPushEnabled(.postFailed) == true)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggleEmail records the update with the edited flag")
    func toggleEmailRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: true, sendStreakEmails: true))
        ])
        await api.setUpdateEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: false, sendStreakEmails: true))
        ])
        let viewModel = NotificationPrefsViewModel(api: api)
        await viewModel.load(token: nil)

        await viewModel.toggleEmail(.failure, on: false)

        let calls = await api.updateEmailPrefsCalls
        #expect(calls.first?.sendFailureEmails == false)
        #expect(viewModel.sendFailureEmails == false)
    }

    @Test("toggleEmail failure reverts the value")
    func toggleEmailFailureReverts() async {
        let api = StubSocialsAPI()
        await api.setEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: true, sendStreakEmails: true))
        ])
        await api.setUpdateEmailPrefsResults([.failure(SocialsAPIError.offline)])
        let viewModel = NotificationPrefsViewModel(api: api)
        await viewModel.load(token: nil)

        await viewModel.toggleEmail(.failure, on: false)

        #expect(viewModel.sendFailureEmails == true)
        #expect(viewModel.errorMessage != nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setEmailPrefsResults(_ results: [Result<EmailNotificationPrefs, Error>]) {
        emailPrefsResults = results
    }

    fileprivate func setUpdateEmailPrefsResults(
        _ results: [Result<EmailNotificationPrefs, Error>]
    ) {
        updateEmailPrefsResults = results
    }

    fileprivate func setPushPrefsResults(_ results: [Result<PushPrefsResponse, Error>]) {
        pushPrefsResults = results
    }

    fileprivate func setUpdatePushPrefsResults(_ results: [Result<PushPrefsResponse, Error>]) {
        updatePushPrefsResults = results
    }
}
