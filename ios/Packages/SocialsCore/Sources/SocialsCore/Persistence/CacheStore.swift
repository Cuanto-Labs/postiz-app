import Foundation
import SwiftData

/// Plain, `Sendable` view of `CachedChannel` — the only shape `CacheStore` hands
/// across the actor boundary. Never return a `@Model` instance from this actor.
public struct ChannelSnapshot: Sendable, Equatable, Identifiable {
    public let id: String
    public let orgId: String
    public let internalId: String
    public let name: String
    public let identifier: String
    public let picture: String?
    public let disabled: Bool
    public let refreshNeeded: Bool
    public let inBetweenSteps: Bool
    public let maxCharacters: Int
    public let editor: String
    public let updatedAt: Date

    public init(
        id: String, orgId: String, internalId: String, name: String, identifier: String,
        picture: String?, disabled: Bool, refreshNeeded: Bool, inBetweenSteps: Bool,
        maxCharacters: Int, editor: String, updatedAt: Date
    ) {
        self.id = id
        self.orgId = orgId
        self.internalId = internalId
        self.name = name
        self.identifier = identifier
        self.picture = picture
        self.disabled = disabled
        self.refreshNeeded = refreshNeeded
        self.inBetweenSteps = inBetweenSteps
        self.maxCharacters = maxCharacters
        self.editor = editor
        self.updatedAt = updatedAt
    }

    init(model: CachedChannel) {
        self.init(
            id: model.id, orgId: model.orgId, internalId: model.internalId, name: model.name,
            identifier: model.identifier, picture: model.picture, disabled: model.disabled,
            refreshNeeded: model.refreshNeeded, inBetweenSteps: model.inBetweenSteps,
            maxCharacters: model.maxCharacters, editor: model.editor, updatedAt: model.updatedAt
        )
    }
}

/// Plain, `Sendable` view of `CachedPost` — the only shape `CacheStore` hands
/// across the actor boundary. Never return a `@Model` instance from this actor.
public struct PostSnapshot: Sendable, Equatable, Identifiable {
    public var id: String { group }
    public let group: String
    public let orgId: String
    public let publishDate: Date
    public let status: PostStatus
    public let channelId: String
    public let content: String
    public let rawJSON: Data
    public let updatedAt: Date

    public init(
        group: String, orgId: String, publishDate: Date, status: PostStatus, channelId: String,
        content: String, rawJSON: Data, updatedAt: Date
    ) {
        self.group = group
        self.orgId = orgId
        self.publishDate = publishDate
        self.status = status
        self.channelId = channelId
        self.content = content
        self.rawJSON = rawJSON
        self.updatedAt = updatedAt
    }

    init(model: CachedPost) {
        self.init(
            group: model.group, orgId: model.orgId, publishDate: model.publishDate,
            status: PostStatus(rawValue: model.status) ?? .queue, channelId: model.channelId,
            content: model.content, rawJSON: model.rawJSON, updatedAt: model.updatedAt
        )
    }
}

/// Actor-isolated gateway onto the `SocialsSchema` cache/outbox container.
/// Scoped by `orgId` throughout (docs/IOS-APP-PLAN.md §6): switching orgs reads
/// a different slice, and sign-out wipes every org via `wipeAll()`.
@ModelActor
public actor CacheStore {

    /// Insert/update channels for `orgId` by `id`; deletes any cached channel
    /// for that org that isn't in `dtos`.
    public func upsertChannels(_ dtos: [ChannelDTO], orgId: String) throws {
        let existing = try modelContext.fetch(
            FetchDescriptor<CachedChannel>(predicate: #Predicate { $0.orgId == orgId })
        )
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for dto in dtos {
            if let current = byId.removeValue(forKey: dto.id) {
                DTOMapping.update(current, from: dto)
            } else {
                modelContext.insert(DTOMapping.makeChannel(from: dto, orgId: orgId))
            }
        }
        for stale in byId.values {
            modelContext.delete(stale)
        }
        try modelContext.save()
    }

    /// Replaces posts within `window` for `orgId`: insert/update by `group`,
    /// deletes cached posts whose `publishDate` falls inside the window but
    /// aren't in `groups`. Posts outside the window are left untouched.
    public func upsertPosts(_ groups: [PostGroupDTO], orgId: String, window: ClosedRange<Date>) throws {
        let lowerBound = window.lowerBound
        let upperBound = window.upperBound
        let existing = try modelContext.fetch(
            FetchDescriptor<CachedPost>(predicate: #Predicate {
                $0.orgId == orgId && $0.publishDate >= lowerBound && $0.publishDate <= upperBound
            })
        )
        var byGroup = Dictionary(uniqueKeysWithValues: existing.map { ($0.group, $0) })

        for dto in groups {
            guard let fields = DTOMapping.cachedPostFields(from: dto) else { continue }
            let rawJSON = (try? JSONEncoder().encode(dto)) ?? Data()
            if let current = byGroup.removeValue(forKey: fields.group) {
                DTOMapping.update(current, fields: fields, rawJSON: rawJSON)
            } else {
                modelContext.insert(DTOMapping.makeCachedPost(orgId: orgId, fields: fields, rawJSON: rawJSON))
            }
        }
        for stale in byGroup.values {
            modelContext.delete(stale)
        }
        try modelContext.save()
    }

    public func channels(orgId: String) throws -> [ChannelSnapshot] {
        try modelContext.fetch(
            FetchDescriptor<CachedChannel>(predicate: #Predicate { $0.orgId == orgId })
        ).map(ChannelSnapshot.init)
    }

    public func posts(orgId: String, in window: ClosedRange<Date>) throws -> [PostSnapshot] {
        let lowerBound = window.lowerBound
        let upperBound = window.upperBound
        return try modelContext.fetch(
            FetchDescriptor<CachedPost>(predicate: #Predicate {
                $0.orgId == orgId && $0.publishDate >= lowerBound && $0.publishDate <= upperBound
            })
        ).map(PostSnapshot.init)
    }

    /// Deletes every cached/outbox row (channels, posts, drafts, pending
    /// actions) scoped to `orgId`.
    public func wipe(orgId: String) throws {
        try modelContext.delete(model: CachedChannel.self, where: #Predicate { $0.orgId == orgId })
        try modelContext.delete(model: CachedPost.self, where: #Predicate { $0.orgId == orgId })
        try modelContext.delete(model: DraftPost.self, where: #Predicate { $0.orgId == orgId })
        try modelContext.delete(model: PendingAction.self, where: #Predicate { $0.orgId == orgId })
        try modelContext.save()
    }

    /// Deletes every cached/outbox row for every org (sign-out).
    public func wipeAll() throws {
        try modelContext.delete(model: CachedChannel.self)
        try modelContext.delete(model: CachedPost.self)
        try modelContext.delete(model: DraftPost.self)
        try modelContext.delete(model: PendingAction.self)
        try modelContext.save()
    }
}
