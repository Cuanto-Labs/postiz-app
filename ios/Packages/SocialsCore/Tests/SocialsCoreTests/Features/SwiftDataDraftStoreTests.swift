import Foundation
import SwiftData
import Testing

@testable import SocialsCore

@Suite("SwiftDataDraftStore")
struct SwiftDataDraftStoreTests {

    private func makeStore() throws -> SwiftDataDraftStore {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        return SwiftDataDraftStore(modelContainer: container)
    }

    private func snapshot(
        id: UUID = UUID(), orgId: String = "org-1", text: String = "hello"
    ) -> DraftPostSnapshot {
        DraftPostSnapshot(
            id: id, orgId: orgId, text: text, perChannelOverrides: ["chan-1": "override"],
            channelIds: ["chan-1"], scheduledAt: nil, mediaLocalIds: ["media-1"])
    }

    @Test("save inserts a new draft, retrievable by id")
    func saveInsertsNewDraft() async throws {
        let store = try makeStore()
        let id = UUID()

        try await store.save(snapshot(id: id, text: "first draft"))

        let saved = try await store.draft(id: id)
        #expect(saved?.text == "first draft")
        #expect(saved?.perChannelOverrides == ["chan-1": "override"])
        #expect(saved?.channelIds == ["chan-1"])
        #expect(saved?.mediaLocalIds == ["media-1"])
    }

    @Test("save with an existing id updates the row in place (autosave), not a duplicate")
    func saveUpdatesExistingDraft() async throws {
        let store = try makeStore()
        let id = UUID()

        try await store.save(snapshot(id: id, text: "v1"))
        try await store.save(snapshot(id: id, text: "v2"))

        let drafts = try await store.drafts(orgId: "org-1")
        #expect(drafts.count == 1)
        #expect(drafts.first?.text == "v2")
    }

    @Test("drafts(orgId:) only returns that org's drafts")
    func draftsScopedByOrg() async throws {
        let store = try makeStore()

        try await store.save(snapshot(orgId: "org-a"))
        try await store.save(snapshot(orgId: "org-b"))

        let orgADrafts = try await store.drafts(orgId: "org-a")
        #expect(orgADrafts.count == 1)
        #expect(orgADrafts.first?.orgId == "org-a")
    }

    @Test("delete(id:) removes the draft")
    func deleteRemovesDraft() async throws {
        let store = try makeStore()
        let id = UUID()
        try await store.save(snapshot(id: id))

        try await store.delete(id: id)

        #expect(try await store.draft(id: id) == nil)
    }

    @Test("wipe(orgId:) only clears that org's drafts")
    func wipeSingleOrg() async throws {
        let store = try makeStore()

        try await store.save(snapshot(orgId: "org-a"))
        try await store.save(snapshot(orgId: "org-b"))

        try await store.wipe(orgId: "org-a")

        #expect(try await store.drafts(orgId: "org-a").isEmpty)
        #expect(try await store.drafts(orgId: "org-b").count == 1)
    }
}
