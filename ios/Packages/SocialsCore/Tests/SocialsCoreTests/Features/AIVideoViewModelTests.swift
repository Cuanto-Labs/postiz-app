import Foundation
import Testing

@testable import SocialsCore

@Suite("AIVideoViewModel")
@MainActor
struct AIVideoViewModelTests {

    @Test("loadCredits requests type ai_videos and sets .ready")
    func loadCreditsReady() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 4))])
        let viewModel = AIVideoViewModel(api: api)

        await viewModel.loadCredits()

        #expect(viewModel.phase == .ready(credits: 4))
        #expect(viewModel.credits == 4)
        #expect(await api.aiCreditsCalls == ["ai_videos"])
    }

    @Test("loadCredits with 0 credits sets .outOfCredits")
    func loadCreditsZero() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 0))])
        let viewModel = AIVideoViewModel(api: api)

        await viewModel.loadCredits()

        #expect(viewModel.phase == .outOfCredits)
    }

    @Test("generate records aiGenerateVideoCalls[0].type/.output and sets .generated")
    func generateSucceeds() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([
            .success(AICreditsResponse(credits: 5)), .success(AICreditsResponse(credits: 4)),
        ])
        let result = AIMediaResult(id: "m2", name: "clip.mp4", path: "https://cdn/clip.mp4")
        await api.setAiGenerateVideoResults([.success(result)])
        let viewModel = AIVideoViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(type: "text2video", output: "vertical")

        #expect(await api.aiGenerateVideoCalls.first?.type == "text2video")
        #expect(await api.aiGenerateVideoCalls.first?.output == "vertical")
        #expect(viewModel.phase == .generated(result))
        #expect(viewModel.credits == 4)
    }

    @Test("generate with 0 credits sets .outOfCredits without calling the API")
    func generateWithZeroCredits() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 0))])
        let viewModel = AIVideoViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(type: "text2video", output: "vertical")

        #expect(viewModel.phase == .outOfCredits)
        #expect(await api.aiGenerateVideoCalls.isEmpty)
    }

    @Test("generate maps .aiCreditsExhausted to .outOfCredits")
    func generateCreditsExhausted() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 5))])
        await api.setAiGenerateVideoResults([.failure(SocialsAPIError.aiCreditsExhausted)])
        let viewModel = AIVideoViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(type: "text2video", output: "vertical")

        #expect(viewModel.phase == .outOfCredits)
    }

    @Test("generate maps .aiNotInPlan to .notInPlan")
    func generateNotInPlan() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 5))])
        await api.setAiGenerateVideoResults([.failure(SocialsAPIError.aiNotInPlan)])
        let viewModel = AIVideoViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(type: "text2video", output: "vertical")

        #expect(viewModel.phase == .notInPlan)
    }

    @Test("generate maps .aiConsentRequired to .consentRequired")
    func generateConsentRequired() async {
        let api = StubSocialsAPI()
        await api.setAiCreditsResults([.success(AICreditsResponse(credits: 5))])
        await api.setAiGenerateVideoResults([.failure(SocialsAPIError.aiConsentRequired)])
        let viewModel = AIVideoViewModel(api: api)
        await viewModel.loadCredits()

        await viewModel.generate(type: "text2video", output: "vertical")

        #expect(viewModel.phase == .consentRequired)
    }
}

extension StubSocialsAPI {
    fileprivate func setAiCreditsResults(_ results: [Result<AICreditsResponse, Error>]) {
        aiCreditsResults = results
    }

    fileprivate func setAiGenerateVideoResults(_ results: [Result<AIMediaResult, Error>]) {
        aiGenerateVideoResults = results
    }
}
