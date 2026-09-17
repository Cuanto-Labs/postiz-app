import Foundation
import Testing

@testable import SocialsCore

@Suite("CopilotViewModel")
@MainActor
struct CopilotViewModelTests {

    @Test("suggest populates suggestions on success")
    func suggestSucceeds() async {
        let api = StubSocialsAPI()
        await api.setAiSuggestResults([.success(AISuggestResponse(suggestions: ["Hello there", "Hi!"]))])
        let viewModel = CopilotViewModel(api: api)

        await viewModel.suggest(content: "hello", mode: .variations)

        #expect(viewModel.suggestions == ["Hello there", "Hi!"])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.consentRequired)
        #expect(!viewModel.notInPlan)
        #expect(!viewModel.isLoading)
    }

    @Test("suggest sends content/mode/maxLength in the request")
    func suggestSendsRequest() async {
        let api = StubSocialsAPI()
        await api.setAiSuggestResults([.success(AISuggestResponse(suggestions: ["x"]))])
        let viewModel = CopilotViewModel(api: api)

        await viewModel.suggest(content: "hello", mode: .fit, maxLength: 100)

        #expect(
            await api.aiSuggestCalls == [
                AISuggestRequest(content: "hello", mode: .fit, maxLength: 100)
            ])
    }

    @Test("suggest rejects empty content without calling the API")
    func suggestRejectsEmptyContent() async {
        let api = StubSocialsAPI()
        let viewModel = CopilotViewModel(api: api)

        await viewModel.suggest(content: "   ", mode: .variations)

        #expect(viewModel.errorMessage != nil)
        #expect(await api.aiSuggestCalls.isEmpty)
    }

    @Test("suggest rejects content over 5000 chars without calling the API")
    func suggestRejectsTooLong() async {
        let api = StubSocialsAPI()
        let viewModel = CopilotViewModel(api: api)
        let tooLong = String(repeating: "a", count: CopilotViewModel.maxContentLength + 1)

        await viewModel.suggest(content: tooLong, mode: .variations)

        #expect(viewModel.errorMessage != nil)
        #expect(await api.aiSuggestCalls.isEmpty)
    }

    @Test("suggest sets consentRequired on .aiConsentRequired")
    func suggestSetsConsentRequired() async {
        let api = StubSocialsAPI()
        await api.setAiSuggestResults([.failure(SocialsAPIError.aiConsentRequired)])
        let viewModel = CopilotViewModel(api: api)

        await viewModel.suggest(content: "hello", mode: .variations)

        #expect(viewModel.consentRequired)
        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("suggest sets notInPlan on .aiNotInPlan")
    func suggestSetsNotInPlan() async {
        let api = StubSocialsAPI()
        await api.setAiSuggestResults([.failure(SocialsAPIError.aiNotInPlan)])
        let viewModel = CopilotViewModel(api: api)

        await viewModel.suggest(content: "hello", mode: .variations)

        #expect(viewModel.notInPlan)
        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("reset clears suggestions and gate state")
    func resetClearsState() async {
        let api = StubSocialsAPI()
        await api.setAiSuggestResults([.success(AISuggestResponse(suggestions: ["a"]))])
        let viewModel = CopilotViewModel(api: api)
        await viewModel.suggest(content: "hello", mode: .variations)

        viewModel.reset()

        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.consentRequired)
        #expect(!viewModel.notInPlan)
    }
}

extension StubSocialsAPI {
    fileprivate func setAiSuggestResults(_ results: [Result<AISuggestResponse, Error>]) {
        aiSuggestResults = results
    }
}
