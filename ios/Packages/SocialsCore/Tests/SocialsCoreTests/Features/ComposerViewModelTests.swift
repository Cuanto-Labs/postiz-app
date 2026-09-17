import Foundation
import Testing

@testable import SocialsCore

@Suite("ComposerViewModel")
@MainActor
struct ComposerViewModelTests {

    private func channel(
        internalId: String = "int-1", name: String = "My Page", identifier: String = "facebook",
        disabled: Bool = false, inBetweenSteps: Bool = false, maxCharacters: Int? = nil
    ) -> ChannelDTO {
        ChannelDTO(
            id: internalId, internalId: internalId, name: name, identifier: identifier,
            picture: nil, disabled: disabled, refreshNeeded: false,
            inBetweenSteps: inBetweenSteps, display: nil, type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: maxCharacters, editor: nil))
    }

    // MARK: - Channel picks

    @Test
    func toggleChannelSelectsAndDeselects() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])

        viewModel.toggleChannel(ch)
        #expect(viewModel.isSelected(ch))
        #expect(viewModel.selectedChannels == [ch])

        viewModel.toggleChannel(ch)
        #expect(!viewModel.isSelected(ch))
        #expect(viewModel.selectedChannels.isEmpty)
    }

    @Test
    func selectableChannelsExcludesDisabledAndInBetweenSteps() {
        let ok = channel(internalId: "ok")
        let disabled = channel(internalId: "disabled", disabled: true)
        let onboarding = channel(internalId: "onboarding", inBetweenSteps: true)
        let viewModel = ComposerViewModel(
            api: StubSocialsAPI(), channels: [ok, disabled, onboarding])

        #expect(viewModel.selectableChannels == [ok])
    }

    @Test
    func deselectingChannelDropsCustomization() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.toggleChannel(ch)
        viewModel.toggleCustomize(for: ch.internalId)
        viewModel.setContent("custom", for: ch.internalId)

        viewModel.toggleChannel(ch)

        #expect(!viewModel.isCustomized(ch.internalId))
        #expect(viewModel.draft(for: ch.internalId).content.isEmpty)
    }

    // MARK: - Global + per-channel customize

    @Test
    func customizeSeedsFromGlobalDraft() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.setGlobalContent("hello world")

        viewModel.toggleCustomize(for: ch.internalId)

        #expect(viewModel.isCustomized(ch.internalId))
        #expect(viewModel.draft(for: ch.internalId).content == "hello world")
    }

    @Test
    func uncustomizedChannelFallsBackToGlobal() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.setGlobalContent("global text")

        #expect(viewModel.draft(for: ch.internalId).content == "global text")
    }

    @Test
    func setContentOnlyAppliesWhenCustomized() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.setGlobalContent("global text")

        viewModel.setContent("ignored", for: ch.internalId)
        #expect(viewModel.draft(for: ch.internalId).content == "global text")

        viewModel.toggleCustomize(for: ch.internalId)
        viewModel.setContent("per-channel text", for: ch.internalId)
        #expect(viewModel.draft(for: ch.internalId).content == "per-channel text")
        #expect(viewModel.globalDraft.content == "global text")
    }

    @Test
    func togglingCustomizeOffDropsOverride() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.setGlobalContent("global text")
        viewModel.toggleCustomize(for: ch.internalId)
        viewModel.setContent("override", for: ch.internalId)

        viewModel.toggleCustomize(for: ch.internalId)

        #expect(!viewModel.isCustomized(ch.internalId))
        #expect(viewModel.draft(for: ch.internalId).content == "global text")
    }

    // MARK: - Char limits

    @Test
    func charLimitUsesChannelLimitsWhenPresent() {
        let ch = channel(maxCharacters: 280)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])

        #expect(viewModel.charLimit(for: ch) == 280)
    }

    @Test
    func charLimitFallsBackToDefaultWhenMissing() {
        let ch = channel(maxCharacters: nil)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])

        #expect(viewModel.charLimit(for: ch) == ComposerViewModel.defaultCharLimit)
    }

    @Test
    func isOverCharLimitReflectsContentLength() {
        let ch = channel(maxCharacters: 5)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.setGlobalContent("123456")

        #expect(viewModel.isOverCharLimit(for: ch))
        #expect(viewModel.charCount(for: ch) == 6)
    }

    // MARK: - Validation

    @Test
    func validateFailsWithNoChannelsSelected() {
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [])

        #expect(viewModel.validate() == [.noChannelsSelected])
        #expect(!viewModel.isValid)
    }

    @Test
    func validateFailsOnEmptyContent() {
        let ch = channel()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.toggleChannel(ch)

        #expect(viewModel.validate() == [.emptyContent(channelId: ch.internalId)])
    }

    @Test
    func validateFailsOverCharLimit() {
        let ch = channel(maxCharacters: 5)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("too long for the limit")

        #expect(viewModel.validate() == [.overCharLimit(channelId: ch.internalId, limit: 5)])
    }

    @Test
    func validatePassesWithSelectedChannelAndContentWithinLimit() {
        let ch = channel(maxCharacters: 280)
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch])
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("hello")

        #expect(viewModel.isValid)
    }

    // MARK: - CreatePostBody builder

    @Test
    func buildCreatePostBodyMirrorsSelectedChannels() {
        let a = channel(internalId: "a", name: "Page A", identifier: "facebook")
        let b = channel(internalId: "b", name: "Page B", identifier: "x")
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [a, b])
        viewModel.toggleChannel(a)
        viewModel.toggleChannel(b)
        viewModel.setGlobalContent("global text")
        viewModel.toggleCustomize(for: b.internalId)
        viewModel.setContent("custom for b", for: b.internalId)

        let body = viewModel.buildCreatePostBody(
            type: "now", date: "2026-09-17T12:00:00Z", tags: [PostTagRef(value: "1", label: "L")])

        #expect(body.type == "now")
        #expect(body.date == "2026-09-17T12:00:00Z")
        #expect(body.tags == [PostTagRef(value: "1", label: "L")])
        #expect(body.posts.count == 2)
        #expect(body.posts[0].integration?.id == "a")
        #expect(body.posts[0].content == .string("global text"))
        #expect(body.posts[1].integration?.id == "b")
        #expect(body.posts[1].content == .string("custom for b"))
    }

    // MARK: - Draft persistence

    @Test
    func persistAndRestoreDraftRoundTrips() {
        let ch = channel()
        let store = InMemoryDraftStore()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch], draftStore: store)
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("saved text")
        viewModel.persistDraft()

        let restored = ComposerViewModel(api: StubSocialsAPI(), channels: [ch], draftStore: store)
        restored.restoreDraft()

        #expect(restored.selectedChannelIds == [ch.internalId])
        #expect(restored.globalDraft.content == "saved text")
    }

    @Test
    func clearDraftResetsStateAndStorage() {
        let ch = channel()
        let store = InMemoryDraftStore()
        let viewModel = ComposerViewModel(api: StubSocialsAPI(), channels: [ch], draftStore: store)
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("saved text")
        viewModel.persistDraft()

        viewModel.clearDraft()

        #expect(viewModel.selectedChannelIds.isEmpty)
        #expect(viewModel.globalDraft.content.isEmpty)
        #expect(store.loadDraft() == nil)
    }

    // MARK: - Submit

    @Test
    func submitSendsBodyAndClearsDraftOnSuccess() async {
        let ch = channel()
        let api = StubSocialsAPI()
        await api.setCreatePostResults([
            .success(
                PostGroupDTO(
                    id: "1", group: "g1", publishDate: nil, status: "now", integration: nil,
                    content: nil))
        ])
        let viewModel = ComposerViewModel(api: api, channels: [ch])
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("hello")

        let success = await viewModel.submit(type: "now")

        #expect(success)
        let calls = await api.createPostCalls
        #expect(calls.count == 1)
        #expect(viewModel.selectedChannelIds.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func submitFailsFastWhenInvalidWithoutCallingAPI() async {
        let api = StubSocialsAPI()
        let viewModel = ComposerViewModel(api: api, channels: [])

        let success = await viewModel.submit(type: "now")

        #expect(!success)
        let calls = await api.createPostCalls
        #expect(calls.isEmpty)
    }

    @Test
    func submitSurfacesAPIError() async {
        let ch = channel()
        let api = StubSocialsAPI()
        await api.setCreatePostResults([.failure(SocialsAPIError.offline)])
        let viewModel = ComposerViewModel(api: api, channels: [ch])
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("hello")

        let success = await viewModel.submit(type: "now")

        #expect(!success)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    @Test
    func submitUpdatesExistingGroupInsteadOfCreating() async {
        let ch = channel()
        let api = StubSocialsAPI()
        await api.setUpdatePostResults([
            .success(
                PostGroupDTO(
                    id: "1", group: "g1", publishDate: nil, status: "now", integration: nil,
                    content: nil))
        ])
        let viewModel = ComposerViewModel(api: api, channels: [ch])
        viewModel.existingGroup = "g1"
        viewModel.toggleChannel(ch)
        viewModel.setGlobalContent("hello")

        let success = await viewModel.submit(type: "now")

        #expect(success)
        let updateCalls = await api.updatePostCalls
        #expect(updateCalls.count == 1)
        #expect(updateCalls.first?.group == "g1")
        let createCalls = await api.createPostCalls
        #expect(createCalls.isEmpty)
        #expect(viewModel.existingGroup == nil)
    }

    // MARK: - Find slot

    @Test
    func findSlotStoresReturnedDate() async {
        let api = StubSocialsAPI()
        await api.setFindSlotResults([.success(FindSlotResponse(date: "2026-09-20T10:00:00Z"))])
        let viewModel = ComposerViewModel(api: api, channels: [])

        await viewModel.findSlot()

        #expect(viewModel.scheduleDate == "2026-09-20T10:00:00Z")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func findSlotSurfacesAPIError() async {
        let api = StubSocialsAPI()
        await api.setFindSlotResults([.failure(SocialsAPIError.offline)])
        let viewModel = ComposerViewModel(api: api, channels: [])

        await viewModel.findSlot()

        #expect(viewModel.scheduleDate == nil)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    // MARK: - Delete

    @Test
    func deleteRemovesExistingGroupOnSuccess() async {
        let api = StubSocialsAPI()
        await api.setDeletePostResults([.success(OkResponse(ok: true))])
        let viewModel = ComposerViewModel(api: api, channels: [])
        viewModel.existingGroup = "g1"

        let success = await viewModel.delete()

        #expect(success)
        let calls = await api.deletePostCalls
        #expect(calls == ["g1"])
        #expect(viewModel.existingGroup == nil)
    }

    @Test
    func deleteWithoutExistingGroupIsNoOp() async {
        let api = StubSocialsAPI()
        let viewModel = ComposerViewModel(api: api, channels: [])

        let success = await viewModel.delete()

        #expect(!success)
        let calls = await api.deletePostCalls
        #expect(calls.isEmpty)
    }
}

extension StubSocialsAPI {
    fileprivate func setCreatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        createPostResults = results
    }

    fileprivate func setUpdatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        updatePostResults = results
    }

    fileprivate func setDeletePostResults(_ results: [Result<OkResponse, Error>]) {
        deletePostResults = results
    }

    fileprivate func setFindSlotResults(_ results: [Result<FindSlotResponse, Error>]) {
        findSlotResults = results
    }
}
