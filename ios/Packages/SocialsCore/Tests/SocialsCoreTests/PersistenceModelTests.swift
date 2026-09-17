import Foundation
import SwiftData
import Testing
@testable import SocialsCore

@Suite("Persistence models")
struct PersistenceModelTests {
    @Test("insert and fetch each model by unique key")
    func insertAndFetchByUniqueKey() throws {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let channel = CachedChannel(
            id: "chan-1", orgId: "org-1", internalId: "int-1", name: "Chan",
            identifier: "x", maxCharacters: 280, editor: "TEXT"
        )
        context.insert(channel)

        let post = CachedPost(
            group: "group-1", orgId: "org-1", publishDate: .now, status: .queue,
            channelId: "chan-1", content: "hi", rawJSON: Data()
        )
        context.insert(post)

        let draft = DraftPost(orgId: "org-1", text: "draft text")
        context.insert(draft)

        let action = PendingAction(
            orgId: "org-1", kind: .createPost, payload: Data(), idempotencyKey: "idem-1"
        )
        context.insert(action)

        try context.save()

        let fetchedChannel = try context.fetch(
            FetchDescriptor<CachedChannel>(predicate: #Predicate { $0.id == "chan-1" })
        ).first
        #expect(fetchedChannel?.id == "chan-1")

        let fetchedPost = try context.fetch(
            FetchDescriptor<CachedPost>(predicate: #Predicate { $0.group == "group-1" })
        ).first
        #expect(fetchedPost?.group == "group-1")

        let draftID = draft.id
        let fetchedDraft = try context.fetch(
            FetchDescriptor<DraftPost>(predicate: #Predicate { $0.id == draftID })
        ).first
        #expect(fetchedDraft?.id == draftID)

        let actionID = action.id
        let fetchedAction = try context.fetch(
            FetchDescriptor<PendingAction>(predicate: #Predicate { $0.id == actionID })
        ).first
        #expect(fetchedAction?.id == actionID)
    }

    @Test("orgId predicate filtering")
    func orgIdFiltering() throws {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        context.insert(CachedChannel(
            id: "c1", orgId: "org-a", internalId: "i1", name: "A",
            identifier: "a", maxCharacters: 100, editor: "TEXT"
        ))
        context.insert(CachedChannel(
            id: "c2", orgId: "org-b", internalId: "i2", name: "B",
            identifier: "b", maxCharacters: 100, editor: "TEXT"
        ))

        context.insert(CachedPost(
            group: "g1", orgId: "org-a", publishDate: .now, status: .draft,
            channelId: "c1", content: "a", rawJSON: Data()
        ))
        context.insert(CachedPost(
            group: "g2", orgId: "org-b", publishDate: .now, status: .draft,
            channelId: "c2", content: "b", rawJSON: Data()
        ))

        context.insert(PendingAction(orgId: "org-a", kind: .createPost, payload: Data(), idempotencyKey: "k1"))
        context.insert(PendingAction(orgId: "org-b", kind: .createPost, payload: Data(), idempotencyKey: "k2"))

        try context.save()

        let orgAChannels = try context.fetch(
            FetchDescriptor<CachedChannel>(predicate: #Predicate { $0.orgId == "org-a" })
        )
        #expect(orgAChannels.count == 1)
        #expect(orgAChannels.first?.id == "c1")

        let orgAPosts = try context.fetch(
            FetchDescriptor<CachedPost>(predicate: #Predicate { $0.orgId == "org-a" })
        )
        #expect(orgAPosts.count == 1)
        #expect(orgAPosts.first?.group == "g1")

        let orgAActions = try context.fetch(
            FetchDescriptor<PendingAction>(predicate: #Predicate { $0.orgId == "org-a" })
        )
        #expect(orgAActions.count == 1)
        #expect(orgAActions.first?.idempotencyKey == "k1")
    }

    @Test("duplicate unique key upserts rather than duplicates")
    func duplicateUniqueKeyUpserts() throws {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        context.insert(CachedChannel(
            id: "chan-dup", orgId: "org-1", internalId: "int-1", name: "First",
            identifier: "x", maxCharacters: 280, editor: "TEXT"
        ))
        try context.save()

        context.insert(CachedChannel(
            id: "chan-dup", orgId: "org-1", internalId: "int-1", name: "Second",
            identifier: "x", maxCharacters: 280, editor: "TEXT"
        ))
        try context.save()

        let all = try context.fetch(
            FetchDescriptor<CachedChannel>(predicate: #Predicate { $0.id == "chan-dup" })
        )
        #expect(all.count == 1)
        #expect(all.first?.name == "Second")
    }
}
