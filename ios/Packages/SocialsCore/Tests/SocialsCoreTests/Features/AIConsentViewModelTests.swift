import Foundation
import Testing

@testable import SocialsCore

@Suite("AIConsentViewModel")
@MainActor
struct AIConsentViewModelTests {

    @Test("load reflects the Stub's aiConsentAt")
    func loadReflectsConsentAt() async {
        let api = StubSocialsAPI()
        await api.setAiConsentResults([.success(AIConsentResponse(aiConsentAt: "2026-09-01T00:00:00Z"))])
        let viewModel = AIConsentViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.aiConsentAt == "2026-09-01T00:00:00Z")
        #expect(viewModel.isGranted)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("load with nil aiConsentAt reports not granted")
    func loadNilConsentAt() async {
        let api = StubSocialsAPI()
        await api.setAiConsentResults([.success(AIConsentResponse(aiConsentAt: nil))])
        let viewModel = AIConsentViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.aiConsentAt == nil)
        #expect(!viewModel.isGranted)
    }

    @Test("grant records setAIConsentCalls == [true] and updates state")
    func grantRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setSetAIConsentResults([
            .success(AIConsentResponse(aiConsentAt: "2026-09-17T00:00:00Z"))
        ])
        let viewModel = AIConsentViewModel(api: api)

        await viewModel.grant()

        #expect(await api.setAIConsentCalls == [true])
        #expect(viewModel.isGranted)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("revoke records setAIConsentCalls == [false] and updates state")
    func revokeRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setSetAIConsentResults([.success(AIConsentResponse(aiConsentAt: nil))])
        let viewModel = AIConsentViewModel(api: api)

        await viewModel.revoke()

        #expect(await api.setAIConsentCalls == [false])
        #expect(!viewModel.isGranted)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("grant failure keeps previous state and sets errorMessage")
    func grantFailureKeepsPreviousState() async {
        let api = StubSocialsAPI()
        await api.setAiConsentResults([.success(AIConsentResponse(aiConsentAt: nil))])
        await api.setSetAIConsentResults([.failure(SocialsAPIError.offline)])
        let viewModel = AIConsentViewModel(api: api)
        await viewModel.load()

        await viewModel.grant()

        #expect(!viewModel.isGranted)
        #expect(viewModel.errorMessage != nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setAiConsentResults(_ results: [Result<AIConsentResponse, Error>]) {
        aiConsentResults = results
    }

    fileprivate func setSetAIConsentResults(_ results: [Result<AIConsentResponse, Error>]) {
        setAIConsentResults = results
    }
}
