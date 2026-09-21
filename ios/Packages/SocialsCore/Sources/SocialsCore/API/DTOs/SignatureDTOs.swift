import Foundation

// MARK: - Signatures

/// A `Signatures` row (`mobile-signatures.controller.ts` proxies the Prisma record
/// untransformed). `GET /signatures/default` falls back to `{}` when no default is set
/// (`signature.controller.ts`: `(await ...) || {}`), so every field is optional.
public struct SignatureDTO: Sendable, Codable, Equatable {
    public let id: String?
    public let organizationId: String?
    public let content: String?
    public let autoAdd: Bool?
    public let createdAt: String?
    public let updatedAt: String?
    public let deletedAt: String?

    public init(
        id: String?, organizationId: String?, content: String?, autoAdd: Bool?,
        createdAt: String?, updatedAt: String?, deletedAt: String?
    ) {
        self.id = id
        self.organizationId = organizationId
        self.content = content
        self.autoAdd = autoAdd
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

/// `POST` / `PUT /mobile/v1/signatures/:id` body.
public struct SignatureRequest: Sendable, Codable, Equatable {
    public let content: String
    public let autoAdd: Bool

    public init(content: String, autoAdd: Bool) {
        self.content = content
        self.autoAdd = autoAdd
    }
}
