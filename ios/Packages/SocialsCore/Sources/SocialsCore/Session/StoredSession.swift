import Foundation

/// Everything `SessionStore` persists to the Keychain as one JSON blob: tokens, the signed-in
/// user, their orgs, and which org is currently active. `var` fields (not `let`) because
/// `SessionStore` mutates a decoded copy in place (token rotation, org switch) before writing
/// it back — see `docs/MOBILE-API.md` for the wire shapes this mirrors.
public struct StoredSession: Sendable, Codable, Equatable {
    public var tokens: MobileTokens
    public var user: MobileUser
    public var orgs: [MobileOrg]
    public var currentOrgId: String?
    public var issuedAt: Date

    public init(
        tokens: MobileTokens, user: MobileUser, orgs: [MobileOrg], currentOrgId: String?,
        issuedAt: Date
    ) {
        self.tokens = tokens
        self.user = user
        self.orgs = orgs
        self.currentOrgId = currentOrgId
        self.issuedAt = issuedAt
    }
}
