import Foundation

// MARK: - Org (mobile-org.controller.ts)

/// `AddTeamMemberDto.role` (`add.team.member.dto.ts`, `@IsIn(['USER', 'ADMIN'])`).
public enum TeamRole: String, Sendable, Equatable, CaseIterable, Codable {
    case user = "USER"
    case admin = "ADMIN"
}

/// One row of `GET /mobile/v1/org/team` (`OrganizationRepository.getTeam`'s
/// `users: [{ role, user: { email, id, ... } }]` select).
public struct TeamMemberUser: Sendable, Codable, Equatable {
    public let id: String
    public let email: String

    public init(id: String, email: String) {
        self.id = id
        self.email = email
    }
}

public struct TeamMember: Sendable, Codable, Equatable {
    public let role: String
    public let user: TeamMemberUser

    public init(role: String, user: TeamMemberUser) {
        self.role = role
        self.user = user
    }
}

/// `GET /mobile/v1/org/team` response (`OrganizationRepository.getTeam` returns
/// `{ users: TeamMember[] }`, the org record selected down to just its `users`).
public struct TeamListResponse: Sendable, Codable, Equatable {
    public let users: [TeamMember]

    public init(users: [TeamMember]) {
        self.users = users
    }
}

/// `POST /mobile/v1/org/team` body (`AddTeamMemberDto`).
public struct AddTeamMemberRequest: Sendable, Codable, Equatable {
    public let email: String
    public let role: TeamRole
    public let sendEmail: Bool

    public init(email: String, role: TeamRole, sendEmail: Bool) {
        self.email = email
        self.role = role
        self.sendEmail = sendEmail
    }
}

/// `ShortLinkPreference` (Prisma enum, `schema.prisma` — copied verbatim).
public enum ShortlinkPreference: String, Sendable, Equatable, CaseIterable, Codable {
    case ask = "ASK"
    case yes = "YES"
    case no = "NO"
}

/// `GET` / `POST /mobile/v1/org/shortlink` response (`OrganizationRepository
/// .getShortlinkPreference` / `.updateShortlinkPreference`, both select/return `{ shortlink }`).
public struct ShortlinkPreferenceResponse: Sendable, Codable, Equatable {
    public let shortlink: ShortlinkPreference

    public init(shortlink: ShortlinkPreference) {
        self.shortlink = shortlink
    }
}

/// `POST /mobile/v1/org/shortlink` body (`ShortlinkPreferenceDto`).
public struct ShortlinkPreferenceRequest: Sendable, Codable, Equatable {
    public let shortlink: ShortlinkPreference

    public init(shortlink: ShortlinkPreference) {
        self.shortlink = shortlink
    }
}

/// A channel reference inside `MobileWebhook.integrations` (`WebhooksRepository.getWebhooks`'s
/// `integrations: [{ integration: { id, picture, name } }]` include).
public struct WebhookIntegrationRef: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let picture: String?

    public init(id: String, name: String, picture: String?) {
        self.id = id
        self.name = name
        self.picture = picture
    }
}

public struct WebhookIntegrationEntry: Sendable, Codable, Equatable {
    public let integration: WebhookIntegrationRef

    public init(integration: WebhookIntegrationRef) {
        self.integration = integration
    }
}

/// `GET /mobile/v1/org/webhooks` response item (`Webhooks` model, `WebhooksRepository
/// .getWebhooks`). Read-only per VISION §7 — no create/edit DTOs.
public struct MobileWebhook: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let url: String
    public let integrations: [WebhookIntegrationEntry]

    public init(id: String, name: String, url: String, integrations: [WebhookIntegrationEntry]) {
        self.id = id
        self.name = name
        self.url = url
        self.integrations = integrations
    }
}
