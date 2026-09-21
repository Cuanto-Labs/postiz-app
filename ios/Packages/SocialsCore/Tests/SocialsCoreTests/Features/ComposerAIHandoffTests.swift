import Foundation
import Testing

@testable import SocialsCore

@Suite("ComposerViewModel+AI")
@MainActor
struct ComposerAIHandoffTests {

    private func channel(
        internalId: String = "int-1", maxCharacters: Int? = nil
    ) -> ChannelDTO {
        ChannelDTO(
            id: internalId, internalId: internalId, name: "My Page", identifier: "facebook",
            picture: nil, disabled: false, refreshNeeded: false,
            inBetweenSteps: false, display: nil, type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: maxCharacters, editor: nil))
    }

    @Test("attachAIMedia appends an attachment with the result's id and path")
    func attachAIMediaAppendsAttachment() {
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [channel()])
        let result = AIMediaResult(id: "media-1", name: "sunset.png", path: "https://cdn/media-1.png")

        viewModel.attachAIMedia(result)

        #expect(viewModel.globalDraft.media == [ComposerMediaRef(id: "media-1", path: "https://cdn/media-1.png")])
    }

    @Test("attachAIMedia appends, it does not replace, existing media")
    func attachAIMediaAppendsToExistingMedia() {
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [channel()])
        viewModel.attachAIMedia(AIMediaResult(id: "first", name: nil, path: "https://cdn/first.png"))

        viewModel.attachAIMedia(AIMediaResult(id: "second", name: nil, path: "https://cdn/second.png"))

        #expect(viewModel.globalDraft.media.map(\.id) == ["first", "second"])
    }

    @Test("applySuggestion(.replace) sets the global draft content")
    func applySuggestionReplaceSetsText() {
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [channel()])
        viewModel.setGlobalContent("original")

        viewModel.applySuggestion("rewritten copy", mode: .replace)

        #expect(viewModel.globalDraft.content == "rewritten copy")
    }

    @Test("applySuggestion(.insertAtCursor) preserves the existing prefix")
    func applySuggestionInsertPreservesPrefix() {
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [channel()])
        viewModel.setGlobalContent("Check this out: ")

        viewModel.applySuggestion("it's amazing!", mode: .insertAtCursor)

        #expect(viewModel.globalDraft.content == "Check this out: it's amazing!")
    }

    @Test("applySuggestion exceeding the per-channel char limit surfaces existing validation")
    func applySuggestionOverCharLimitSurfacesValidation() {
        let ch = channel(maxCharacters: 5)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.toggleChannel(ch)

        viewModel.applySuggestion("way too long for the limit", mode: .replace)

        #expect(viewModel.validate() == [.overCharLimit(channelId: ch.internalId, limit: 5)])
    }
}
