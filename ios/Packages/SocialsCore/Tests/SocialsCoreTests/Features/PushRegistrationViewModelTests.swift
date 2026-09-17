import Foundation
import Testing

@testable import SocialsCore

@Suite("PushRegistrationViewModel")
@MainActor
struct PushRegistrationViewModelTests {

    private func tokenData() -> Data {
        Data([0xDE, 0xAD, 0xBE, 0xEF])
    }

    private func deviceResponse(token: String) -> PushDeviceResponse {
        PushDeviceResponse(
            device: PushDeviceUpsert(
                apnsToken: token, environment: "production", bundleId: nil, locale: nil,
                timezone: nil, prefs: nil))
    }

    @Test("didReceiveToken upserts the hex-encoded token and marks registered")
    func didReceiveTokenRegisters() async {
        let api = StubSocialsAPI()
        await api.setUpsertPushDeviceResults([.success(deviceResponse(token: "deadbeef"))])
        let viewModel = PushRegistrationViewModel(api: api)

        await viewModel.didReceiveToken(tokenData())

        let calls = await api.upsertPushDeviceCalls
        #expect(calls.count == 1)
        #expect(calls.first?.apnsToken == "deadbeef")
        #expect(viewModel.isRegistered)
        #expect(viewModel.registeredToken == "deadbeef")
        #expect(!viewModel.needsRetry)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("didReceiveToken sets needsRetry on failure without crashing")
    func didReceiveTokenFailureSetsRetry() async {
        let api = StubSocialsAPI()
        await api.setUpsertPushDeviceResults([.failure(SocialsAPIError.offline)])
        let viewModel = PushRegistrationViewModel(api: api)

        await viewModel.didReceiveToken(tokenData())

        #expect(viewModel.needsRetry)
        #expect(!viewModel.isRegistered)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("signOut deletes the registered device token")
    func signOutDeletesDevice() async {
        let api = StubSocialsAPI()
        await api.setUpsertPushDeviceResults([.success(deviceResponse(token: "deadbeef"))])
        await api.setDeletePushDeviceResults([.success(OkResponse(ok: true))])
        let viewModel = PushRegistrationViewModel(api: api)
        await viewModel.didReceiveToken(tokenData())

        await viewModel.signOut()

        let calls = await api.deletePushDeviceCalls
        #expect(calls == ["deadbeef"])
        #expect(!viewModel.isRegistered)
        #expect(viewModel.registeredToken == nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setUpsertPushDeviceResults(_ results: [Result<PushDeviceResponse, Error>]) {
        upsertPushDeviceResults = results
    }

    fileprivate func setDeletePushDeviceResults(_ results: [Result<OkResponse, Error>]) {
        deletePushDeviceResults = results
    }
}
