import Foundation
import SwiftData

/// Plain, `Sendable` view of `DraftPost` — the only shape `SwiftDataDraftStore` hands
/// across the actor boundary. Never return a `@Model` instance from this actor.
public struct DraftPostSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let orgId: String
    public let text: String
    public let perChannelOverrides: [String: String]
    public let channelIds: [String]
    public let scheduledAt: Date?
    public let mediaLocalIds: [String]
    public let updatedAt: Date
    public let serverGroup: String?

    public init(
        id: UUID = UUID(), orgId: String, text: String, perChannelOverrides: [String: String] = [:],
        channelIds: [String] = [], scheduledAt: Date? = nil, mediaLocalIds: [String] = [],
        updatedAt: Date = .now, serverGroup: String? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.text = text
        self.perChannelOverrides = perChannelOverrides
        self.channelIds = channelIds
        self.scheduledAt = scheduledAt
        self.mediaLocalIds = mediaLocalIds
        self.updatedAt = updatedAt
        self.serverGroup = serverGroup
    }

    init(model: DraftPost) {
        self.init(
            id: model.id, orgId: model.orgId, text: model.text,
            perChannelOverrides: model.perChannelOverrides, channelIds: model.channelIds,
            scheduledAt: model.scheduledAt, mediaLocalIds: model.mediaLocalIds,
            updatedAt: model.updatedAt, serverGroup: model.serverGroup
        )
    }
}

/// Actor-isolated, SwiftData-backed autosave store for `DraftPost` rows — the local-authoring
/// counterpart to `CacheStore`'s read cache. `ComposerViewModel` autosaves through this instead
/// of the legacy synchronous `UserDefaultsDraftStore` once callers move to the richer,
/// multi-draft `DraftPost` model (per-draft id, media, schedule) rather than the single-slot
/// `PersistedComposerDraft` blob. Scoped by `orgId` throughout, mirrors `CacheStore`.
@ModelActor
public actor SwiftDataDraftStore {

    /// Autosaves a draft: inserts a new `DraftPost` row if `snapshot.id` isn't known yet,
    /// otherwise updates the existing row in place. Always stamps `updatedAt` with the current
    /// time so autosave ordering reflects when the write actually happened.
    @discardableResult
    public func save(_ snapshot: DraftPostSnapshot) throws -> DraftPostSnapshot {
        let id = snapshot.id
        let existing = try modelContext.fetch(
            FetchDescriptor<DraftPost>(predicate: #Predicate { $0.id == id })
        ).first

        let now = Date.now
        if let existing {
            existing.orgId = snapshot.orgId
            existing.text = snapshot.text
            existing.perChannelOverrides = snapshot.perChannelOverrides
            existing.channelIds = snapshot.channelIds
            existing.scheduledAt = snapshot.scheduledAt
            existing.mediaLocalIds = snapshot.mediaLocalIds
            existing.updatedAt = now
            existing.serverGroup = snapshot.serverGroup
            try modelContext.save()
            return DraftPostSnapshot(model: existing)
        }

        let model = DraftPost(
            id: snapshot.id, orgId: snapshot.orgId, text: snapshot.text,
            perChannelOverrides: snapshot.perChannelOverrides, channelIds: snapshot.channelIds,
            scheduledAt: snapshot.scheduledAt, mediaLocalIds: snapshot.mediaLocalIds,
            updatedAt: now, serverGroup: snapshot.serverGroup
        )
        modelContext.insert(model)
        try modelContext.save()
        return DraftPostSnapshot(model: model)
    }

    /// A single draft by id, or `nil` if it doesn't exist (or was already deleted).
    public func draft(id: UUID) throws -> DraftPostSnapshot? {
        try modelContext.fetch(
            FetchDescriptor<DraftPost>(predicate: #Predicate { $0.id == id })
        ).first.map(DraftPostSnapshot.init)
    }

    /// Every autosaved draft for `orgId`, most recently updated first.
    public func drafts(orgId: String) throws -> [DraftPostSnapshot] {
        var descriptor = FetchDescriptor<DraftPost>(predicate: #Predicate { $0.orgId == orgId })
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return try modelContext.fetch(descriptor).map(DraftPostSnapshot.init)
    }

    /// Deletes a single draft by id; no-op if it's already gone.
    public func delete(id: UUID) throws {
        try modelContext.delete(model: DraftPost.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    /// Deletes every draft for `orgId`, mirrors `CacheStore.wipe(orgId:)`.
    public func wipe(orgId: String) throws {
        try modelContext.delete(model: DraftPost.self, where: #Predicate { $0.orgId == orgId })
        try modelContext.save()
    }
}
