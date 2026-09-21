import Foundation
import Testing

@testable import SocialsCore

@Suite("TagsViewModel")
@MainActor
struct TagsViewModelTests {

    private func tag(
        id: String = "t1", name: String = "Launch", color: String = "#622FF6"
    ) -> TagDTO {
        TagDTO(
            id: id, name: name, color: color, orgId: nil, createdAt: nil, updatedAt: nil,
            deletedAt: nil)
    }

    @Test
    func loadPopulatesTags() async {
        let api = StubSocialsAPI()
        let t = tag()
        await api.setTagsResults([.success(TagsListResponse(tags: [t]))])
        let viewModel = TagsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.tags == [t])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setTagsResults([.failure(SocialsAPIError.offline)])
        let viewModel = TagsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.tags.isEmpty)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    @Test
    func toggleSelectionBuildsSelectedTagRefs() async {
        let api = StubSocialsAPI()
        let t = tag()
        await api.setTagsResults([.success(TagsListResponse(tags: [t]))])
        let viewModel = TagsViewModel(api: api)
        await viewModel.load()

        viewModel.toggleSelection(t)

        #expect(viewModel.isSelected(t))
        #expect(viewModel.selectedTagRefs == [PostTagRef(value: "Launch", label: "Launch")])

        viewModel.toggleSelection(t)

        #expect(!viewModel.isSelected(t))
        #expect(viewModel.selectedTagRefs.isEmpty)
    }

    @Test
    func createTagReloadsAndSelectsNewTag() async {
        let api = StubSocialsAPI()
        let t = tag()
        await api.setCreateTagResults([.success(t)])
        await api.setTagsResults([.success(TagsListResponse(tags: [t]))])
        let viewModel = TagsViewModel(api: api)

        let ok = await viewModel.createTag(name: "Launch", color: "#622FF6")

        #expect(ok)
        #expect(viewModel.tags == [t])
        #expect(viewModel.isSelected(t))
        let calls = await api.createTagCalls
        #expect(calls == [CreateTagRequest(name: "Launch", color: "#622FF6")])
    }

    @Test
    func deleteTagReloadsAndDropsSelection() async {
        let api = StubSocialsAPI()
        let t = tag()
        await api.setTagsResults([
            .success(TagsListResponse(tags: [t])),
            .success(TagsListResponse(tags: [])),
        ])
        let viewModel = TagsViewModel(api: api)
        await viewModel.load()
        viewModel.toggleSelection(t)
        await api.setDeleteTagResults([.success(t)])

        let ok = await viewModel.deleteTag(t)

        #expect(ok)
        #expect(viewModel.tags.isEmpty)
        #expect(viewModel.selectedTagIds.isEmpty)
        let calls = await api.deleteTagCalls
        #expect(calls == ["t1"])
    }
}

@Suite("SignaturesViewModel")
@MainActor
struct SignaturesViewModelTests {

    private func signature(
        id: String? = "s1", content: String? = "Best regards", autoAdd: Bool? = true
    ) -> SignatureDTO {
        SignatureDTO(
            id: id, organizationId: nil, content: content, autoAdd: autoAdd, createdAt: nil,
            updatedAt: nil, deletedAt: nil)
    }

    @Test
    func loadPopulatesSignaturesAndDefault() async {
        let api = StubSocialsAPI()
        let sig = signature()
        await api.setSignaturesResults([.success([sig])])
        await api.setDefaultSignatureResults([.success(sig)])
        let viewModel = SignaturesViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.signatures == [sig])
        #expect(viewModel.defaultSignature == sig)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadTreatsEmptyDefaultFallbackAsNil() async {
        let api = StubSocialsAPI()
        await api.setSignaturesResults([.success([])])
        await api.setDefaultSignatureResults([
            .success(SignatureDTO(
                id: nil, organizationId: nil, content: nil, autoAdd: nil, createdAt: nil,
                updatedAt: nil, deletedAt: nil))
        ])
        let viewModel = SignaturesViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.defaultSignature == nil)
    }

    @Test
    func loadSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setSignaturesResults([.failure(SocialsAPIError.offline)])
        await api.setDefaultSignatureResults([.failure(SocialsAPIError.offline)])
        let viewModel = SignaturesViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    @Test
    func autoInsertContentReturnsContentWhenAutoAddTrue() async {
        let api = StubSocialsAPI()
        await api.setSignaturesResults([.success([])])
        await api.setDefaultSignatureResults([.success(signature(autoAdd: true))])
        let viewModel = SignaturesViewModel(api: api)
        await viewModel.load()

        #expect(viewModel.autoInsertContent == "Best regards")
    }

    @Test
    func autoInsertContentNilWhenAutoAddFalse() async {
        let api = StubSocialsAPI()
        await api.setSignaturesResults([.success([])])
        await api.setDefaultSignatureResults([.success(signature(autoAdd: false))])
        let viewModel = SignaturesViewModel(api: api)
        await viewModel.load()

        #expect(viewModel.autoInsertContent == nil)
    }

    @Test
    func createSignatureReloadsList() async {
        let api = StubSocialsAPI()
        let sig = signature()
        await api.setCreateSignatureResults([.success(sig)])
        await api.setSignaturesResults([.success([sig])])
        await api.setDefaultSignatureResults([.success(sig)])
        let viewModel = SignaturesViewModel(api: api)

        let ok = await viewModel.createSignature(content: "Best regards", autoAdd: true)

        #expect(ok)
        #expect(viewModel.signatures == [sig])
        let calls = await api.createSignatureCalls
        #expect(calls == [SignatureRequest(content: "Best regards", autoAdd: true)])
    }

    @Test
    func deleteSignatureReloadsList() async {
        let api = StubSocialsAPI()
        let sig = signature()
        await api.setDeleteSignatureResults([.success(sig)])
        await api.setSignaturesResults([.success([])])
        await api.setDefaultSignatureResults([
            .success(SignatureDTO(
                id: nil, organizationId: nil, content: nil, autoAdd: nil, createdAt: nil,
                updatedAt: nil, deletedAt: nil))
        ])
        let viewModel = SignaturesViewModel(api: api)

        let ok = await viewModel.deleteSignature(sig)

        #expect(ok)
        #expect(viewModel.signatures.isEmpty)
        let calls = await api.deleteSignatureCalls
        #expect(calls == ["s1"])
    }

    @Test
    func updateSignatureWithoutIdReturnsFalseAndMakesNoCall() async {
        let api = StubSocialsAPI()
        let sig = signature(id: nil)
        let viewModel = SignaturesViewModel(api: api)

        let ok = await viewModel.updateSignature(sig, content: "x", autoAdd: false)

        #expect(!ok)
        let calls = await api.updateSignatureCalls
        #expect(calls.isEmpty)
    }
}

extension StubSocialsAPI {
    fileprivate func setTagsResults(_ results: [Result<TagsListResponse, Error>]) {
        tagsResults = results
    }
    fileprivate func setCreateTagResults(_ results: [Result<TagDTO, Error>]) {
        createTagResults = results
    }
    fileprivate func setDeleteTagResults(_ results: [Result<TagDTO, Error>]) {
        deleteTagResults = results
    }
    fileprivate func setSignaturesResults(_ results: [Result<[SignatureDTO], Error>]) {
        signaturesResults = results
    }
    fileprivate func setDefaultSignatureResults(_ results: [Result<SignatureDTO, Error>]) {
        defaultSignatureResults = results
    }
    fileprivate func setCreateSignatureResults(_ results: [Result<SignatureDTO, Error>]) {
        createSignatureResults = results
    }
    fileprivate func setDeleteSignatureResults(_ results: [Result<SignatureDTO, Error>]) {
        deleteSignatureResults = results
    }
}
