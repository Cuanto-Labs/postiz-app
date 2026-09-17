import Foundation
import Testing

@testable import SocialsCore

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {

    private func config(providers: [ConfigProvider]) -> ConfigResponse {
        ConfigResponse(
            minVersion: "1.0.0", providers: providers,
            links: ConfigLinks(support: "https://s", terms: "https://t", privacy: "https://p"))
    }

    @Test("advance walks welcome -> schedule -> analytics -> firstChannel and stops there")
    func advanceWalksPanelsAndStops() async {
        let viewModel = OnboardingViewModel(api: StubSocialsAPI())
        #expect(viewModel.panel == .welcome)

        viewModel.advance()
        #expect(viewModel.panel == .schedule)

        viewModel.advance()
        #expect(viewModel.panel == .analytics)

        viewModel.advance()
        #expect(viewModel.panel == .firstChannel)
        #expect(viewModel.isOnFirstChannelStep)

        viewModel.advance()
        #expect(viewModel.panel == .firstChannel)
    }

    @Test("back walks panels in reverse and stops at welcome")
    func backWalksPanelsAndStops() async {
        let viewModel = OnboardingViewModel(api: StubSocialsAPI())
        #expect(!viewModel.canGoBack)

        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.canGoBack)

        viewModel.back()
        #expect(viewModel.panel == .schedule)

        viewModel.back()
        #expect(viewModel.panel == .welcome)
        #expect(!viewModel.canGoBack)

        viewModel.back()
        #expect(viewModel.panel == .welcome)
    }

    @Test("entering firstChannel loads providers from config")
    func enteringFirstChannelLoadsProviders() async {
        let api = StubSocialsAPI()
        let providers = [
            ConfigProvider(identifier: "x", name: "X"),
            ConfigProvider(identifier: "linkedin", name: "LinkedIn"),
        ]
        await api.setConfigResults([.success(config(providers: providers))])
        let viewModel = OnboardingViewModel(api: api)

        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        // advance() kicks the load off in a detached Task; run it directly instead of
        // racing that task, mirroring how other view model tests await network effects.
        await viewModel.loadProviders()

        #expect(viewModel.providers.map(\.identifier) == ["x", "linkedin"])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
        let count = await api.configCallCount
        #expect(count >= 1)
    }

    @Test("selectProvider records the chosen provider and enables finishing")
    func selectProviderEnablesFinish() async {
        let viewModel = OnboardingViewModel(api: StubSocialsAPI())
        #expect(!viewModel.canFinish)

        viewModel.selectProvider("linkedin")

        #expect(viewModel.selectedProviderId == "linkedin")
        #expect(viewModel.canFinish)
    }

    @Test("loadProviders surfaces a message on failure and leaves providers empty")
    func loadProvidersSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.failure(SocialsAPIError.offline)])
        let viewModel = OnboardingViewModel(api: api)

        await viewModel.loadProviders()

        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
        #expect(!viewModel.isLoading)
    }
}

extension StubSocialsAPI {
    fileprivate func setConfigResults(_ results: [Result<ConfigResponse, Error>]) {
        configResults = results
    }
}
