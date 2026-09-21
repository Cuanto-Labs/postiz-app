import Foundation

// MARK: - Posts list (paginated)

/// A single item from `GET /mobile/v1/posts/list` / `GET /mobile/v1/posts/old` (docs/MOBILE-API.md
/// § posts/list, § posts/old — wire shape not pinned down beyond "PostsService.getPostsList /
/// getOldPosts result"). Tolerant decode, mirroring `PostGroupDTO`'s style: unknown keys ignored.
public struct PostListItemDTO: Sendable, Equatable {
    public let id: String?
    public let content: PostContentValue?
    public let publishDate: String?
    public let releaseURL: String?
    public let releaseId: String?
    public let state: String?
    public let group: String?
    public let integration: PostIntegrationRef?
    public let intervalInDays: Int?
    public let creationMethod: String?

    public init(
        id: String?, content: PostContentValue?, publishDate: String?, releaseURL: String?,
        releaseId: String?, state: String?, group: String?, integration: PostIntegrationRef?,
        intervalInDays: Int?, creationMethod: String?
    ) {
        self.id = id
        self.content = content
        self.publishDate = publishDate
        self.releaseURL = releaseURL
        self.releaseId = releaseId
        self.state = state
        self.group = group
        self.integration = integration
        self.intervalInDays = intervalInDays
        self.creationMethod = creationMethod
    }
}

extension PostListItemDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, content, publishDate, releaseURL, releaseId, state, group, integration,
            intervalInDays, creationMethod
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        content = try container.decodeIfPresent(PostContentValue.self, forKey: .content)
        publishDate = try container.decodeIfPresent(String.self, forKey: .publishDate)
        releaseURL = try container.decodeIfPresent(String.self, forKey: .releaseURL)
        releaseId = try container.decodeIfPresent(String.self, forKey: .releaseId)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        group = try container.decodeIfPresent(String.self, forKey: .group)
        integration = try container.decodeIfPresent(PostIntegrationRef.self, forKey: .integration)
        intervalInDays = try container.decodeIfPresent(Int.self, forKey: .intervalInDays)
        creationMethod = try container.decodeIfPresent(String.self, forKey: .creationMethod)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(publishDate, forKey: .publishDate)
        try container.encodeIfPresent(releaseURL, forKey: .releaseURL)
        try container.encodeIfPresent(releaseId, forKey: .releaseId)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(integration, forKey: .integration)
        try container.encodeIfPresent(intervalInDays, forKey: .intervalInDays)
        try container.encodeIfPresent(creationMethod, forKey: .creationMethod)
    }
}

/// `GET /mobile/v1/posts/list` result — `PostsService.getPostsList` wraps
/// `{ posts, total, page, limit, hasMore }`; all fields optional here (tolerant decode).
public struct PostsListResponse: Sendable, Codable, Equatable {
    public let posts: [PostListItemDTO]
    public let total: Int?
    public let page: Int?
    public let limit: Int?
    public let hasMore: Bool?

    public init(
        posts: [PostListItemDTO], total: Int?, page: Int?, limit: Int?, hasMore: Bool?
    ) {
        self.posts = posts
        self.total = total
        self.page = page
        self.limit = limit
        self.hasMore = hasMore
    }
}

/// `GET /mobile/v1/posts/old` returns a bare array (`PostsService.getOldPosts` result), not an
/// object wrapper.
public struct OldPostsResponse: Sendable, Codable, Equatable {
    public let posts: [PostListItemDTO]

    public init(posts: [PostListItemDTO]) {
        self.posts = posts
    }
}

extension OldPostsResponse {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        posts = try container.decode([PostListItemDTO].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(posts)
    }
}

// MARK: - Find slot

/// `GET /mobile/v1/posts/find-slot` / `find-slot/:id` result: `{ date }`.
public struct FindSlotResponse: Sendable, Codable, Equatable {
    public let date: String?

    public init(date: String?) {
        self.date = date
    }
}

// MARK: - Missing content

/// One entry from `GET /mobile/v1/posts/:id/missing` (`PostsService.getMissingContent`
/// result — `{ id, url }[]`).
public struct MissingContentItemDTO: Sendable, Codable, Equatable {
    public let id: String?
    public let url: String?

    public init(id: String?, url: String?) {
        self.id = id
        self.url = url
    }
}

// MARK: - Comments

/// A single comment row (`Comments` Prisma model: id/content/postId/userId/createdAt).
public struct PostCommentDTO: Sendable, Codable, Equatable {
    public let id: String?
    public let content: String?
    public let postId: String?
    public let userId: String?
    public let createdAt: String?

    public init(id: String?, content: String?, postId: String?, userId: String?, createdAt: String?) {
        self.id = id
        self.content = content
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
    }
}

/// `GET /mobile/v1/posts/:id/comments` result: `{ comments: [...] }`.
public struct PostCommentsResponse: Sendable, Codable, Equatable {
    public let comments: [PostCommentDTO]

    public init(comments: [PostCommentDTO]) {
        self.comments = comments
    }
}

/// `POST /mobile/v1/posts/:id/comments` body (`MobileCommentDto`: `comment`, required non-empty).
public struct CreateCommentRequest: Sendable, Codable, Equatable {
    public let comment: String

    public init(comment: String) {
        self.comment = comment
    }
}

// MARK: - Preview

/// `GET /mobile/v1/posts/:id/preview` result: an array of the post + its recursive children
/// (`PostsService.getPostsRecursively`); item shape overlaps `PostGroupDTO`'s tolerant fields.
public struct PostPreviewResponse: Sendable, Codable, Equatable {
    public let posts: [PostGroupDTO]

    public init(posts: [PostGroupDTO]) {
        self.posts = posts
    }
}

extension PostPreviewResponse {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        posts = try container.decode([PostGroupDTO].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(posts)
    }
}
