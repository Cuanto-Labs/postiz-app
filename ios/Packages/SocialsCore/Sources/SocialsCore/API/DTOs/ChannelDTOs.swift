import Foundation

// MARK: - Channels

/// Nested `Customer` relation echoed on a channel (`p.customer` in
/// `mobile-channels.controller.ts`, included via Prisma `customer: true`).
public struct ChannelCustomer: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let orgId: String
    public let createdAt: String
    public let updatedAt: String
    public let deletedAt: String?

    public init(
        id: String, name: String, orgId: String, createdAt: String, updatedAt: String,
        deletedAt: String?
    ) {
        self.id = id
        self.name = name
        self.orgId = orgId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public struct ChannelLimits: Sendable, Codable, Equatable {
    public let maxCharacters: Int?
    public let editor: String?

    public init(maxCharacters: Int?, editor: String?) {
        self.maxCharacters = maxCharacters
        self.editor = editor
    }
}

/// `GET /mobile/v1/channels` element (docs/MOBILE-API.md).
public struct ChannelDTO: Sendable, Codable, Equatable {
    public let id: String
    public let internalId: String
    public let name: String
    public let identifier: String
    public let picture: String?
    public let disabled: Bool
    public let refreshNeeded: Bool
    public let inBetweenSteps: Bool
    public let display: String?
    public let type: String?
    public let customer: ChannelCustomer?
    public let limits: ChannelLimits

    public init(
        id: String, internalId: String, name: String, identifier: String, picture: String?,
        disabled: Bool, refreshNeeded: Bool, inBetweenSteps: Bool, display: String?, type: String?,
        customer: ChannelCustomer?, limits: ChannelLimits
    ) {
        self.id = id
        self.internalId = internalId
        self.name = name
        self.identifier = identifier
        self.picture = picture
        self.disabled = disabled
        self.refreshNeeded = refreshNeeded
        self.inBetweenSteps = inBetweenSteps
        self.display = display
        self.type = type
        self.customer = customer
        self.limits = limits
    }
}

public struct ChannelsResponse: Sendable, Codable, Equatable {
    public let channels: [ChannelDTO]

    public init(channels: [ChannelDTO]) {
        self.channels = channels
    }
}

// MARK: - Push

/// `PUT /mobile/v1/push/devices` body (docs/MOBILE-API.md).
public struct PushDeviceUpsert: Sendable, Codable, Equatable {
    public let apnsToken: String
    public let environment: String
    public let bundleId: String?
    public let locale: String?
    public let timezone: String?
    public let prefs: PushPrefs?

    public init(
        apnsToken: String, environment: String, bundleId: String?, locale: String?,
        timezone: String?, prefs: PushPrefs?
    ) {
        self.apnsToken = apnsToken
        self.environment = environment
        self.bundleId = bundleId
        self.locale = locale
        self.timezone = timezone
        self.prefs = prefs
    }
}

/// Push notification prefs keyed by `post.published` / `post.failed` /
/// `channel.reconnect_needed` (docs/MOBILE-API.md § Push). Backed by a dictionary so unknown
/// keys round-trip untouched rather than being dropped.
public struct PushPrefs: Sendable, Equatable {
    public static let postPublished = "post.published"
    public static let postFailed = "post.failed"
    public static let channelReconnectNeeded = "channel.reconnect_needed"

    public var values: [String: Bool]

    public init(values: [String: Bool] = [:]) {
        self.values = values
    }

    public subscript(key: String) -> Bool? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

extension PushPrefs: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: Bool].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

/// `PUT /mobile/v1/push/devices` response → `{ device }` (docs/MOBILE-API.md).
public struct PushDeviceResponse: Sendable, Codable, Equatable {
    public let device: PushDeviceUpsert

    public init(device: PushDeviceUpsert) {
        self.device = device
    }
}

/// `GET /mobile/v1/push/prefs` / `PUT /mobile/v1/push/prefs` response → `{ prefs }`
/// (docs/MOBILE-API.md).
public struct PushPrefsResponse: Sendable, Codable, Equatable {
    public let prefs: PushPrefs

    public init(prefs: PushPrefs) {
        self.prefs = prefs
    }
}

/// `PUT /mobile/v1/push/prefs` body — `MobilePushPrefsDto` (docs/MOBILE-API.md).
public struct PushPrefsUpdateRequest: Sendable, Codable, Equatable {
    public let apnsToken: String
    public let prefs: PushPrefs

    public init(apnsToken: String, prefs: PushPrefs) {
        self.apnsToken = apnsToken
        self.prefs = prefs
    }
}
