import Foundation

// MARK: - Tokens & auth response

/// `MobileTokens = { accessToken, refreshToken, expiresIn, sessionId }` (docs/MOBILE-API.md).
public struct MobileTokens: Sendable, Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let sessionId: String

    public init(accessToken: String, refreshToken: String, expiresIn: Int, sessionId: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.sessionId = sessionId
    }
}

public struct MobileUser: Sendable, Codable, Equatable {
    public let id: String
    public let email: String
    public let name: String?
    public let lastName: String?
    public let pictureId: String?

    public init(id: String, email: String, name: String?, lastName: String?, pictureId: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.lastName = lastName
        self.pictureId = pictureId
    }
}

public struct MobileOrg: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let role: String
    public let disabled: Bool

    public init(id: String, name: String, role: String, disabled: Bool) {
        self.id = id
        self.name = name
        self.role = role
        self.disabled = disabled
    }
}

/// `MobileAuthResponse = MobileTokens & { user, orgs }` (docs/MOBILE-API.md).
public struct MobileAuthResponse: Sendable, Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let sessionId: String
    public let user: MobileUser
    public let orgs: [MobileOrg]

    public init(
        accessToken: String, refreshToken: String, expiresIn: Int, sessionId: String,
        user: MobileUser, orgs: [MobileOrg]
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.sessionId = sessionId
        self.user = user
        self.orgs = orgs
    }
}

/// `/auth/register` returns either `MobileAuthResponse` or `{ activate: true }` when email
/// verification is on (docs/MOBILE-API.md).
public enum RegisterResult: Sendable, Equatable {
    case authenticated(MobileAuthResponse)
    case activate
}

extension RegisterResult: Codable {
    private enum ActivateKeys: String, CodingKey {
        case activate
    }

    public init(from decoder: Decoder) throws {
        if let activateContainer = try? decoder.container(keyedBy: ActivateKeys.self),
            let activate = try? activateContainer.decode(Bool.self, forKey: .activate), activate
        {
            self = .activate
            return
        }
        let response = try MobileAuthResponse(from: decoder)
        self = .authenticated(response)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .activate:
            var container = encoder.container(keyedBy: ActivateKeys.self)
            try container.encode(true, forKey: .activate)
        case .authenticated(let response):
            try response.encode(to: encoder)
        }
    }
}

// MARK: - Me / plan

public struct MobilePlan: Sendable, Codable, Equatable {
    public let tier: String
    public let options: [String: Bool]

    public init(tier: String, options: [String: Bool]) {
        self.tier = tier
        self.options = options
    }
}

/// `GET /mobile/v1/me` → `{ user, org, orgs, plan: { tier, options }, sessionId }`.
public struct MeResponse: Sendable, Codable, Equatable {
    public let user: MobileUser
    public let org: MobileOrg
    public let orgs: [MobileOrg]
    public let plan: MobilePlan
    public let sessionId: String

    public init(
        user: MobileUser, org: MobileOrg, orgs: [MobileOrg], plan: MobilePlan, sessionId: String
    ) {
        self.user = user
        self.org = org
        self.orgs = orgs
        self.plan = plan
        self.sessionId = sessionId
    }
}

// MARK: - Config

public struct ConfigProvider: Sendable, Codable, Equatable {
    public let identifier: String
    public let name: String

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public struct ConfigLinks: Sendable, Codable, Equatable {
    public let support: String
    public let terms: String
    public let privacy: String

    public init(support: String, terms: String, privacy: String) {
        self.support = support
        self.terms = terms
        self.privacy = privacy
    }
}

/// `GET /mobile/v1/config` → `{ minVersion, providers, links }`.
public struct ConfigResponse: Sendable, Codable, Equatable {
    public let minVersion: String
    public let providers: [ConfigProvider]
    public let links: ConfigLinks

    public init(minVersion: String, providers: [ConfigProvider], links: ConfigLinks) {
        self.minVersion = minVersion
        self.providers = providers
        self.links = links
    }
}

// MARK: - Devices

public struct MobileSession: Sendable, Codable, Equatable {
    public let id: String
    public let deviceId: String
    public let deviceName: String?
    public let createdAt: String
    public let lastUsedAt: String
    public let expiresAt: String
    public let current: Bool

    public init(
        id: String, deviceId: String, deviceName: String?, createdAt: String, lastUsedAt: String,
        expiresAt: String, current: Bool
    ) {
        self.id = id
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.expiresAt = expiresAt
        self.current = current
    }
}

/// `GET /mobile/v1/devices` → `{ devices: MobileSession[] }`.
public struct DevicesResponse: Sendable, Codable, Equatable {
    public let devices: [MobileSession]

    public init(devices: [MobileSession]) {
        self.devices = devices
    }
}

// MARK: - Generic ok

/// `{ ok: true }` — shared by logout, device delete, post delete, etc.
public struct OkResponse: Sendable, Codable, Equatable {
    public let ok: Bool

    public init(ok: Bool) {
        self.ok = ok
    }
}

// MARK: - Request bodies

public struct LoginRequest: Sendable, Codable, Equatable {
    public let email: String
    public let password: String
    public let deviceId: String
    public let deviceName: String?

    public init(email: String, password: String, deviceId: String, deviceName: String?) {
        self.email = email
        self.password = password
        self.deviceId = deviceId
        self.deviceName = deviceName
    }

    private enum CodingKeys: String, CodingKey {
        case email, password, deviceId, deviceName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        password = try container.decode(String.self, forKey: .password)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
    }

    // Always emits `deviceName` (as JSON null when absent) rather than the
    // synthesized `encodeIfPresent`, which would omit the key entirely.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(password, forKey: .password)
        try container.encode(deviceId, forKey: .deviceId)
        if let deviceName {
            try container.encode(deviceName, forKey: .deviceName)
        } else {
            try container.encodeNil(forKey: .deviceName)
        }
    }
}

public struct RegisterRequest: Sendable, Codable, Equatable {
    public let email: String
    public let password: String
    public let company: String
    public let provider: String
    public let inviteCode: String?
    public let deviceId: String
    public let deviceName: String?

    public init(
        email: String, password: String, company: String = "", provider: String = "LOCAL",
        inviteCode: String? = nil, deviceId: String, deviceName: String?
    ) {
        self.email = email
        self.password = password
        self.company = company
        self.provider = provider
        self.inviteCode = inviteCode
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}

public struct RefreshRequest: Sendable, Codable, Equatable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct LogoutRequest: Sendable, Codable, Equatable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct AppleNativeRequest: Sendable, Codable, Equatable {
    public let identityToken: String
    public let deviceId: String
    public let deviceName: String?
    public let fullName: String?

    public init(identityToken: String, deviceId: String, deviceName: String?, fullName: String?) {
        self.identityToken = identityToken
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.fullName = fullName
    }
}

public struct OAuthStartRequest: Sendable, Codable, Equatable {
    public let provider: String
    public let codeChallenge: String

    public init(provider: String, codeChallenge: String) {
        self.provider = provider
        self.codeChallenge = codeChallenge
    }
}

public struct OAuthStartResponse: Sendable, Codable, Equatable {
    public let url: String
    public let state: String

    public init(url: String, state: String) {
        self.url = url
        self.state = state
    }
}

public struct OAuthExchangeRequest: Sendable, Codable, Equatable {
    public let provider: String
    public let code: String
    public let state: String
    public let codeVerifier: String
    public let deviceId: String
    public let deviceName: String?

    public init(
        provider: String, code: String, state: String, codeVerifier: String, deviceId: String,
        deviceName: String?
    ) {
        self.provider = provider
        self.code = code
        self.state = state
        self.codeVerifier = codeVerifier
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}
