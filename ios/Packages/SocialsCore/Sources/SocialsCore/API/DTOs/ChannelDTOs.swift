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

// MARK: - Channel management (settings, lifecycle, connect, function)

/// `PUT /mobile/v1/channels/:id/customer-name` body — `MobileChannelNameDto`.
public struct ChannelCustomerNameRequest: Sendable, Codable, Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// `PUT /mobile/v1/channels/:id/group` body — `MobileChannelGroupDto`.
public struct ChannelGroupRequest: Sendable, Codable, Equatable {
    public let group: String

    public init(group: String) {
        self.group = group
    }
}

/// `POST /mobile/v1/channels/:id/settings` body — `MobileChannelSettingsDto`.
public struct ChannelSettingsRequest: Sendable, Codable, Equatable {
    public let additionalSettings: String

    public init(additionalSettings: String) {
        self.additionalSettings = additionalSettings
    }
}

/// One entry of `IntegrationTimeDto.time` — `IntegrationValidateTimeDto`.
public struct ChannelTimeSlot: Sendable, Codable, Equatable {
    public let time: Int

    public init(time: Int) {
        self.time = time
    }
}

/// `POST /mobile/v1/channels/:id/time` body — `IntegrationTimeDto`.
public struct ChannelTimeRequest: Sendable, Codable, Equatable {
    public let time: [ChannelTimeSlot]

    public init(time: [ChannelTimeSlot]) {
        self.time = time
    }
}

/// `POST /mobile/v1/channels/function` (and `/mentions`) body — `IntegrationFunctionDto`.
/// `data` is a caller-serialized JSON string (mirrors `additionalSettings` above) since the
/// backend accepts arbitrary provider-specific payloads here.
public struct ChannelFunctionRequest: Sendable, Codable, Equatable {
    public let name: String
    public let id: String
    public let data: String?

    public init(name: String, id: String, data: String? = nil) {
        self.name = name
        self.id = id
        self.data = data
    }
}

/// One mention suggestion — element of the array `POST /mobile/v1/channels/mentions` can return.
public struct ChannelMentionDTO: Sendable, Codable, Equatable {
    public let id: String
    public let image: String?
    public let label: String

    public init(id: String, image: String?, label: String) {
        self.id = id
        self.image = image
        self.label = label
    }
}

/// `POST /mobile/v1/channels/mentions` response — either an array of mentions or `{ none: true }`
/// when the provider doesn't support mention search. Decodes the array when present, else falls
/// back to an empty list (mirrors the `PushPrefs` custom-`Codable` precedent above).
public struct ChannelMentionsResult: Sendable, Equatable {
    public let mentions: [ChannelMentionDTO]
    public let none: Bool

    public init(mentions: [ChannelMentionDTO] = [], none: Bool = false) {
        self.mentions = mentions
        self.none = none
    }
}

extension ChannelMentionsResult: Codable {
    private struct NoneShape: Codable {
        let none: Bool
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([ChannelMentionDTO].self) {
            self.init(mentions: list, none: false)
        } else if let shape = try? container.decode(NoneShape.self) {
            self.init(mentions: [], none: shape.none)
        } else {
            self.init(mentions: [], none: false)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if none {
            try container.encode(NoneShape(none: true))
        } else {
            try container.encode(mentions)
        }
    }
}

/// `GET /mobile/v1/channels/connect/:provider` response.
public struct ChannelConnectResponse: Sendable, Codable, Equatable {
    public let url: String
    public let state: String

    public init(url: String, state: String) {
        self.url = url
        self.state = state
    }
}

/// Catch-all for channel mutation responses whose shape isn't documented/stable
/// (customer-name, group, settings, time, disable, enable, delete, function — these proxy
/// straight through to provider-specific service calls). Carries the raw response bytes as a
/// UTF-8 string rather than guessing a strict `Codable` shape; see `SocialsEndpoints.rawDecode`.
public struct OpaqueJSONResult: Sendable, Codable, Equatable {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
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
