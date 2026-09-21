import Foundation
import Testing

@testable import SocialsCore

@Suite("AIImageViewModel")
@MainActor
struct AIImageViewModelTests {

    @Test("loadCredits reflects the Stub's credits and sets .ready")
    func loadCreditsReady() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 3))])
        let viewModel = AIImageViewModel(api: api)

        await viewModel.loadCredits()

        #expect(viewModel.phase == .ready(credits: 3))
        #expect(viewModel.credits == 3)
        #expect(await api.aiCreditsCalls == ["ai_images"])
    }

    @Test("loadCredits with 0 credits sets .outOfCredits")
    func loadCreditsZero() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 0))])
        let viewModel = AIImageViewModel(api: api)

        await viewModel.loadCredits()

        #expect(viewModel.phase == .outOfCredits)
    }

    @Test("generate records aiGenerateImageCalls == [prompt] and sets .generated")
    func generateSucceeds() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([
            .success(AICreditsResponse(credits: 3)), .success(AICreditsResponse(credits: 2)),
        ])
        let result = AIMediaResult(id: "m1", name: "img.png", path: "https://cdn/img.png")
        await api.setAiGenerateImageResults([.success(result)])
        let viewModel = AIImageViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(prompt: "a cat riding a bike")

        #expect(await api.aiGenerateImageCalls == ["a cat riding a bike"])
        #expect(viewModel.phase == .generated(result))
        #expect(viewModel.credits == 2)
    }

    @Test("generate with 0 credits sets .outOfCredits without calling the API")
    func generateWithZeroCredits() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 0))])
        let viewModel = AIImageViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(prompt: "a cat")

        #expect(viewModel.phase == .outOfCredits)
        #expect(await api.aiGenerateImageCalls.isEmpty)
    }

    @Test("generate maps .aiCreditsExhausted to .outOfCredits")
    func generateCreditsExhausted() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 3))])
        await api.setAiGenerateImageResults([.failure(SocialsAPIError.aiCreditsExhausted)])
        let viewModel = AIImageViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(prompt: "a cat")

        #expect(viewModel.phase == .outOfCredits)
    }

    @Test("generate maps .aiNotInPlan to .notInPlan")
    func generateNotInPlan() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 3))])
        await api.setAiGenerateImageResults([.failure(SocialsAPIError.aiNotInPlan)])
        let viewModel = AIImageViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(prompt: "a cat")

        #expect(viewModel.phase == .notInPlan)
    }

    @Test("generate maps .aiConsentRequired to .consentRequired")
    func generateConsentRequired() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 3))])
        await api.setAiGenerateImageResults([.failure(SocialsAPIError.aiConsentRequired)])
        let viewModel = AIImageViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(prompt: "a cat")

        #expect(viewModel.phase == .consentRequired)
    }
}

extension StubSocialsAPI {
    fileprivate func setAiCreditsResults(_ results: [Result<AICreditsResponse, Error>]) {
        aiCreditsResults = results
    }

    fileprivate func setAiGenerateImageResults(_ results: [Result<AIMediaResult, Error>]) {
        aiGenerateImageResults = results
    }
}
