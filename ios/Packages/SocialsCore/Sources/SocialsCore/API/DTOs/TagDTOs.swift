import Foundation

// MARK: - Tags

/// A `Tags` row (`mobile-tags.controller.ts` proxies the Prisma record through untransformed
/// on every route — list/create/edit/delete all return this shape).
public struct TagDTO: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let color: String
    public let orgId: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let deletedAt: String?

    public init(
        id: String, name: String, color: String, orgId: String?, createdAt: String?,
        updatedAt: String?, deletedAt: String?
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.orgId = orgId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

/// `GET /mobile/v1/tags` response.
public struct TagsListResponse: Sendable, Codable, Equatable {
    public let tags: [TagDTO]

    public init(tags: [TagDTO]) {
        self.tags = tags
    }
}

/// `POST` / `PUT /mobile/v1/tags/:id` body.
public struct CreateTagRequest: Sendable, Codable, Equatable {
    public let name: String
    public let color: String

    public init(name: String, color: String) {
        self.name = name
        self.color = color
    }
}
