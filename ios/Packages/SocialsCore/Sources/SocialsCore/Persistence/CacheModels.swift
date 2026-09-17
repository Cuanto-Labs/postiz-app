import Foundation
import SwiftData

/// Raw string status mirroring the server's Prisma `State` enum
/// (`QUEUE`, `PUBLISHED`, `ERROR`, `DRAFT`).
public enum PostStatus: String, Codable, Sendable {
    case queue = "QUEUE"
    case published = "PUBLISHED"
    case error = "ERROR"
    case draft = "DRAFT"
}

/// Cached view of `/mobile/v1/channels`, keyed by org.
@Model
public final class CachedChannel {
    @Attribute(.unique) public var id: String
    public var orgId: String
    public var internalId: String
    public var name: String
    public var identifier: String
    public var picture: String?
    public var disabled: Bool
    public var refreshNeeded: Bool
    public var inBetweenSteps: Bool
    public var maxCharacters: Int
    public var editor: String
    public var updatedAt: Date

    public init(
        id: String,
        orgId: String,
        internalId: String,
        name: String,
        identifier: String,
        picture: String? = nil,
        disabled: Bool = false,
        refreshNeeded: Bool = false,
        inBetweenSteps: Bool = false,
        maxCharacters: Int,
        editor: String,
        updatedAt: Date = .now
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
}

/// Cached view of a post group from `/mobile/v1/posts`, keyed by org.
@Model
public final class CachedPost {
    @Attribute(.unique) public var group: String
    public var orgId: String
    public var publishDate: Date
    public var status: String
    public var channelId: String
    public var content: String
    public var rawJSON: Data
    public var updatedAt: Date

    public init(
        group: String,
        orgId: String,
        publishDate: Date,
        status: PostStatus,
        channelId: String,
        content: String,
        rawJSON: Data,
        updatedAt: Date = .now
    ) {
        self.group = group
        self.orgId = orgId
        self.publishDate = publishDate
        self.status = status.rawValue
        self.channelId = channelId
        self.content = content
        self.rawJSON = rawJSON
        self.updatedAt = updatedAt
    }
}
