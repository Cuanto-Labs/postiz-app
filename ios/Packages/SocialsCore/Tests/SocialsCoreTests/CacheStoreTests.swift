import Foundation
import SwiftData
import Testing
@testable import SocialsCore

@Suite("CacheStore")
struct CacheStoreTests {

    private func makeStore() throws -> CacheStore {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        return CacheStore(modelContainer: container)
    }

    private func channelDTO(id: String, name: String = "Chan") -> ChannelDTO {
        ChannelDTO(
            id: id, internalId: "int-\(id)", name: name, identifier: id, picture: nil,
            disabled: false, refreshNeeded: false, inBetweenSteps: false, display: nil,
            type: nil, customer: nil, limits: ChannelLimits(maxCharacters: 280, editor: "TEXT")
        )
    }

    private func postDTO(group: String, date: Date, channelId: String = "chan-1") -> PostGroupDTO {
        PostGroupDTO(
            id: group, group: group, publishDate: ISO8601DateFormatter().string(from: date),
            status: "QUEUE",
            integration: PostIntegrationRef(id: channelId, name: nil, picture: nil, providerIdentifier: nil),
            content: .string("hello")
        )
    }

    @Test("upsertChannels replaces the payload — channels missing from it are deleted")
    func upsertChannelsReplacesPayload() async throws {
        let store = try makeStore()

        try await store.upsertChannels(
            [channelDTO(id: "c1"), channelDTO(id: "c2"), channelDTO(id: "c3")], orgId: "org-1"
        )
        #expect(try await store.channels(orgId: "org-1").count == 3)

        try await store.upsertChannels([channelDTO(id: "c1"), channelDTO(id: "c2")], orgId: "org-1")
        let afterSecond = try await store.channels(orgId: "org-1")
        #expect(afterSecond.count == 2)
        #expect(Set(afterSecond.map(\.id)) == ["c1", "c2"])
    }

    @Test("wipe(orgId:) only clears that org's cache")
    func wipeSingleOrg() async throws {
        let store = try makeStore()

        try await store.upsertChannels([channelDTO(id: "a1")], orgId: "org-a")
        try await store.upsertChannels([channelDTO(id: "b1")], orgId: "org-b")

        try await store.wipe(orgId: "org-a")

        #expect(try await store.channels(orgId: "org-a").isEmpty)
        #expect(try await store.channels(orgId: "org-b").count == 1)
    }

    @Test("wipeAll + SharedCacheFiles.wipe clear every row and the widget file")
    func wipeAllAndSharedFiles() async throws {
        let store = try makeStore()
        try await store.upsertChannels([channelDTO(id: "c1")], orgId: "org-1")

        let now = Date()
        let window = now.addingTimeInterval(-86_400)...now.addingTimeInterval(86_400)
        try await store.upsertPosts([postDTO(group: "g1", date: now)], orgId: "org-1", window: window)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = SharedCacheFiles(containerURL: tempDir)
        try files.writeWidgetSnapshot(Data("{}".utf8))
        let snapshotPath = tempDir.appendingPathComponent("widget-snapshot.json").path
        #expect(FileManager.default.fileExists(atPath: snapshotPath))

        try await SignOutCleaner.wipeEverything(cache: store, files: files)

        #expect(try await store.channels(orgId: "org-1").isEmpty)
        #expect(try await store.posts(orgId: "org-1", in: window).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: snapshotPath))
    }

    @Test("upsertPosts only touches its window — posts outside it are untouched")
    func upsertPostsWindowScoped() async throws {
        let store = try makeStore()
        let now = Date()
        let farFuture = now.addingTimeInterval(30 * 86_400)

        let nearWindow = now.addingTimeInterval(-86_400)...now.addingTimeInterval(86_400)
        let farWindow = farFuture.addingTimeInterval(-86_400)...farFuture.addingTimeInterval(86_400)

        try await store.upsertPosts([postDTO(group: "near", date: now)], orgId: "org-1", window: nearWindow)
        try await store.upsertPosts([postDTO(group: "far", date: farFuture)], orgId: "org-1", window: farWindow)

        // Replace the near window's payload with an empty one — only that window's post goes.
        try await store.upsertPosts([], orgId: "org-1", window: nearWindow)

        #expect(try await store.posts(orgId: "org-1", in: nearWindow).isEmpty)
        let farPosts = try await store.posts(orgId: "org-1", in: farWindow)
        #expect(farPosts.count == 1)
        #expect(farPosts.first?.group == "far")
    }
}
