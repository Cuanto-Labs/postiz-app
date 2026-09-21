import Foundation
import SwiftData

/// Locally-authored post, autosaved as a draft and synced to the server.
@Model
public final class DraftPost {
    @Attribute(.unique) public var id: UUID
    public var orgId: String
    public var text: String
    public var perChannelOverridesData: Data
    public var channelIds: [String]
    public var scheduledAt: Date?
    public var mediaLocalIds: [String]
    public var updatedAt: Date
    public var serverGroup: String?

    /// Per-channel text overrides, stored on disk as encoded `Data`.
    public var perChannelOverrides: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: perChannelOverridesData)) ?? [:] }
        set { perChannelOverridesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public init(
        id: UUID = UUID(),
        orgId: String,
        text: String,
        perChannelOverrides: [String: String] = [:],
        channelIds: [String] = [],
        scheduledAt: Date? = nil,
        mediaLocalIds: [String] = [],
        updatedAt: Date = .now,
        serverGroup: String? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.text = text
        self.perChannelOverridesData = (try? JSONEncoder().encode(perChannelOverrides)) ?? Data()
        self.channelIds = channelIds
        self.scheduledAt = scheduledAt
        self.mediaLocalIds = mediaLocalIds
        self.updatedAt = updatedAt
        self.serverGroup = serverGroup
    }
}

public enum PendingActionKind: String, Codable, Sendable {
    case createPost
    case updatePost
    case reschedulePost
    case deletePost
    case upsertPushDevice
}

public enum PendingActionStatus: String, Codable, Sendable {
    case pending
    case inFlight
    case done
    case failed
}

/// A queued write (create/update/reschedule/delete/push-device-upsert) waiting
/// to be replayed against the server by the sync engine.
@Model
public final class PendingAction {
    @Attribute(.unique) public var id: UUID
    public var orgId: String
    public var kind: String
    public var payload: Data
    public var idempotencyKey: String
    public var createdAt: Date
    public var attempts: Int
    public var nextAttemptAt: Date
    public var lastError: String?
    public var status: String

    public init(
        id: UUID = UUID(),
        orgId: String,
        kind: PendingActionKind,
        payload: Data,
        idempotencyKey: String,
        createdAt: Date = .now,
        attempts: Int = 0,
        nextAttemptAt: Date = .now,
        lastError: String? = nil,
        status: PendingActionStatus = .pending
    ) {
        self.id = id
        self.orgId = orgId
        self.kind = kind.rawValue
        self.payload = payload
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.attempts = attempts
        self.nextAttemptAt = nextAttemptAt
        self.lastError = lastError
        self.status = status.rawValue
    }
}
