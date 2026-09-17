import Foundation
import Testing

@testable import SocialsCore

private final class StubWebAuth: SignInWebAuthenticating, @unchecked Sendable {
    private let result: Result<URL, Error>

    init(result: Result<URL, Error>) {
        self.result = result
    }

    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        try result.get()
    }
}

@Suite("ChannelsViewModel")
@MainActor
struct ChannelsViewModelTests {

    private func channel(
        id: String = "1", internalId: String = "int-1", name: String = "My Page",
        refreshNeeded: Bool = false, disabled: Bool = false
    ) -> ChannelDTO {
        ChannelDTO(
            id: id, internalId: internalId, name: name, identifier: "facebook", picture: nil,
            disabled: disabled, refreshNeeded: refreshNeeded, inBetweenSteps: false,
            display: nil, type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: nil, editor: nil))
    }

    private func makeViewModel(
        api: StubSocialsAPI, webAuth: any SignInWebAuthenticating = StubWebAuth(
            result: .failure(CancellationError()))
    ) -> ChannelsViewModel {
        ChannelsViewModel(api: api, webAuth: webAuth, callbackURLScheme: "cuantosocials")
    }

    @Test
    func loadPopulatesChannels() async {
        let api = StubSocialsAPI()
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        let viewModel = makeViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.channels == [ch])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setChannelsResults([.failure(SocialsAPIError.offline)])
        let viewModel = makeViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.channels.isEmpty)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    @Test
    func connectStartsFlowAndReloadsOnSuccess() async {
        let api = StubSocialsAPI()
        await api.setConnectStartResults([
            .success(ChannelConnectResponse(url: "https://example.com/oauth", state: "s1"))
        ])
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        let webAuth = StubWebAuth(result: .success(URL(string: "cuantosocials://connected")!))
        let viewModel = makeViewModel(api: api, webAuth: webAuth)

        await viewModel.connect(provider: "facebook")

        #expect(viewModel.channels == [ch])
        #expect(viewModel.errorMessage == nil)
        let calls = await api.connectStartCalls
        #expect(calls.first?.provider == "facebook")
        #expect(calls.first?.refresh == nil)
    }

    @Test
    func connectPassesRefreshForReconnect() async {
        let api = StubSocialsAPI()
        await api.setConnectStartResults([
            .success(ChannelConnectResponse(url: "https://example.com/oauth", state: "s1"))
        ])
        await api.setChannelsResults([.success(ChannelsResponse(channels: []))])
        let webAuth = StubWebAuth(result: .success(URL(string: "cuantosocials://connected")!))
        let viewModel = makeViewModel(api: api, webAuth: webAuth)

        await viewModel.connect(provider: "facebook", refresh: "int-1")

        let calls = await api.connectStartCalls
        #expect(calls.first?.refresh == "int-1")
    }

    @Test
    func connectSilentlyIgnoresCancellation() async {
        let api = StubSocialsAPI()
        await api.setConnectStartResults([
            .success(ChannelConnectResponse(url: "https://example.com/oauth", state: "s1"))
        ])
        let webAuth = StubWebAuth(result: .failure(CancellationError()))
        let viewModel = makeViewModel(api: api, webAuth: webAuth)

        await viewModel.connect(provider: "facebook")

        #expect(viewModel.errorMessage == nil || viewModel.errorMessage == "")
    }

    @Test
    func deleteSurfaces406AsDeletePostsFirstMessage() async {
        let api = StubSocialsAPI()
        await api.setDeleteChannelResults([
            .failure(SocialsAPIError.server(code: 406, message: nil))
        ])
        let viewModel = makeViewModel(api: api)

        await viewModel.delete(channel())

        #expect(
            viewModel.errorMessage
                == "You have to delete all the posts associated with this channel before deleting it."
        )
    }

    @Test
    func disableReloadsChannelsOnSuccess() async {
        let api = StubSocialsAPI()
        await api.setDisableChannelResults([.success(OpaqueJSONResult(raw: "{}"))])
        let ch = channel(disabled: true)
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        let viewModel = makeViewModel(api: api)

        await viewModel.disable(ch)

        #expect(viewModel.channels == [ch])
        let calls = await api.disableChannelCalls
        #expect(calls == ["1"])
    }

    @Test
    func enableReloadsChannelsOnSuccess() async {
        let api = StubSocialsAPI()
        await api.setEnableChannelResults([.success(OpaqueJSONResult(raw: "{}"))])
        let ch = channel(disabled: false)
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        let viewModel = makeViewModel(api: api)

        await viewModel.enable(ch)

        let calls = await api.enableChannelCalls
        #expect(calls == ["1"])
    }
}

extension StubSocialsAPI {
    fileprivate func setChannelsResults(_ results: [Result<ChannelsResponse, Error>]) {
        channelsResults = results
    }
    fileprivate func setConnectStartResults(_ results: [Result<ChannelConnectResponse, Error>]) {
        connectStartResults = results
    }
    fileprivate func setDeleteChannelResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        deleteChannelResults = results
    }
    fileprivate func setDisableChannelResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        disableChannelResults = results
    }
    fileprivate func setEnableChannelResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        enableChannelResults = results
    }
}
