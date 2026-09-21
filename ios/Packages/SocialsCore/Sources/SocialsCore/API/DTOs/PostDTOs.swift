import Foundation

// MARK: - Post content (tolerant)

/// Post body content: either a plain string or a per-channel array of content items.
/// Server shape isn't pinned down by docs/MOBILE-API.md — decode tolerantly rather than fail.
public enum PostContentValue: Sendable, Equatable {
    case string(String)
    case items([PostContentItem])
}

extension PostContentValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let items = try? container.decode([PostContentItem].self) {
            self = .items(items)
            return
        }
        let string = try container.decode(String.self)
        self = .string(string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .items(let value): try container.encode(value)
        }
    }
}

public struct PostContentItem: Sendable, Codable, Equatable {
    public let integration: String?
    public let content: String?

    public init(integration: String?, content: String?) {
        self.integration = integration
        self.content = content
    }
}

/// Channel reference on a post group — tolerant of the `integration` vs `channel` key
/// (docs/MOBILE-API.md doesn't pin the exact name).
public struct PostIntegrationRef: Sendable, Codable, Equatable {
    public let id: String?
    public let name: String?
    public let picture: String?
    public let providerIdentifier: String?

    public init(id: String?, name: String?, picture: String?, providerIdentifier: String?) {
        self.id = id
        self.name = name
        self.picture = picture
        self.providerIdentifier = providerIdentifier
    }
}

/// A single post group entry from `GET /mobile/v1/posts` / `GET /mobile/v1/posts/:group`.
/// Tolerant decode: `status`/`state`, `integration`/`channel`; unknown keys are ignored
/// (`KeyedDecodingContainer` only reads keys listed in `CodingKeys`).
public struct PostGroupDTO: Sendable, Equatable {
    public let id: String?
    public let group: String?
    public let publishDate: String?
    public let status: String?
    public let integration: PostIntegrationRef?
    public let content: PostContentValue?

    public init(
        id: String?, group: String?, publishDate: String?, status: String?,
        integration: PostIntegrationRef?, content: PostContentValue?
    ) {
        self.id = id
        self.group = group
        self.publishDate = publishDate
        self.status = status
        self.integration = integration
        self.content = content
    }
}

extension PostGroupDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, group, publishDate, status, state, integration, channel, content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        group = try container.decodeIfPresent(String.self, forKey: .group)
        publishDate = try container.decodeIfPresent(String.self, forKey: .publishDate)
        status =
            try container.decodeIfPresent(String.self, forKey: .status)
            ?? (try container.decodeIfPresent(String.self, forKey: .state))
        integration =
            try container.decodeIfPresent(PostIntegrationRef.self, forKey: .integration)
            ?? (try container.decodeIfPresent(PostIntegrationRef.self, forKey: .channel))
        content = try container.decodeIfPresent(PostContentValue.self, forKey: .content)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(publishDate, forKey: .publishDate)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(integration, forKey: .integration)
        try container.encodeIfPresent(content, forKey: .content)
    }
}

public struct PostsResponse: Sendable, Codable, Equatable {
    public let posts: [PostGroupDTO]

    public init(posts: [PostGroupDTO]) {
        self.posts = posts
    }
}

// MARK: - Create / update body

/// Tag reference on a create/update post body (web `CreatePostDto.tags[]`:
/// `{ value, label }`, both required).
public struct PostTagRef: Sendable, Codable, Equatable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

/// `POST /mobile/v1/posts` / `PUT /mobile/v1/posts/:group` raw body. docs/MOBILE-API.md
/// documents only `posts[]` and `type` for the mobile routes, but the backend validates
/// against the web `CreatePostDto` (`libraries/nestjs-libraries/src/dtos/posts/create.post.dto.ts`),
/// which additionally carries `order`, `shortLink`, `inter`, `republish`, `date`, and `tags`.
/// Those extra fields are optional here so existing mobile-only callers (`type`/`posts` only)
/// keep compiling; per-post item shape mirrors `PostGroupDTO`.
public struct CreatePostBody: Sendable, Equatable {
    public let type: String
    public let posts: [PostGroupDTO]
    public let order: String?
    public let shortLink: Bool?
    public let inter: Int?
    public let republish: Bool?
    public let date: String?
    public let tags: [PostTagRef]?

    public init(
        type: String, posts: [PostGroupDTO], order: String? = nil, shortLink: Bool? = nil,
        inter: Int? = nil, republish: Bool? = nil, date: String? = nil,
        tags: [PostTagRef]? = nil
    ) {
        self.type = type
        self.posts = posts
        self.order = order
        self.shortLink = shortLink
        self.inter = inter
        self.republish = republish
        self.date = date
        self.tags = tags
    }
}

/// Wire shape is the web `CreatePostDto`: each post is
/// `{ integration: { id }, value: [{ content, image: [] }], group?, settings: { __type } }`,
/// and `shortLink`/`date`/`tags` are required. Decoding also accepts the legacy
/// `PostGroupDTO` shape so offline actions queued by older builds still replay.
extension CreatePostBody: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, posts, order, shortLink, inter, republish, date, tags
    }

    private enum PostKeys: String, CodingKey {
        case integration, value, group, settings, content
    }

    private struct WireIntegration: Codable {
        let id: String?
    }

    private struct WireValue: Codable {
        let content: String?
        let image: [String]?
    }

    private struct WireSettings: Codable {
        let type: String?

        enum CodingKeys: String, CodingKey {
            case type = "__type"
        }
    }

    /// One `posts[]` element. Decoding a single value per unkeyed-container slot keeps the
    /// container's cursor correct for both the wire and the legacy shape.
    private struct WirePost: Decodable {
        let post: PostGroupDTO
        let isWireShape: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: PostKeys.self)
            guard container.contains(.value) else {
                post = try PostGroupDTO(from: decoder)
                isWireShape = false
                return
            }
            let integration = try container.decodeIfPresent(
                WireIntegration.self, forKey: .integration)
            let values = try container.decodeIfPresent([WireValue].self, forKey: .value) ?? []
            let settings = try container.decodeIfPresent(WireSettings.self, forKey: .settings)
            post = PostGroupDTO(
                id: nil, group: try container.decodeIfPresent(String.self, forKey: .group),
                publishDate: nil, status: nil,
                integration: PostIntegrationRef(
                    id: integration?.id, name: nil, picture: nil,
                    providerIdentifier: settings?.type),
                content: .string(values.first?.content ?? ""))
            isWireShape = true
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        order = try container.decodeIfPresent(String.self, forKey: .order)
        shortLink = try container.decodeIfPresent(Bool.self, forKey: .shortLink)
        inter = try container.decodeIfPresent(Int.self, forKey: .inter)
        republish = try container.decodeIfPresent(Bool.self, forKey: .republish)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        tags = try container.decodeIfPresent([PostTagRef].self, forKey: .tags)

        let publishDate = date
        posts = try container.decode([WirePost].self, forKey: .posts).map { wire in
            guard wire.isWireShape else { return wire.post }
            // The wire shape carries one `date` for the whole body, not per post.
            return PostGroupDTO(
                id: wire.post.id, group: wire.post.group, publishDate: publishDate,
                status: wire.post.status, integration: wire.post.integration,
                content: wire.post.content)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(shortLink ?? false, forKey: .shortLink)
        try container.encode(date ?? Self.nowISO8601(), forKey: .date)
        try container.encode(tags ?? [], forKey: .tags)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(inter, forKey: .inter)
        try container.encodeIfPresent(republish, forKey: .republish)

        var postsContainer = container.nestedUnkeyedContainer(forKey: .posts)
        for post in posts {
            var item = postsContainer.nestedContainer(keyedBy: PostKeys.self)
            try item.encode(WireIntegration(id: post.integration?.id), forKey: .integration)
            try item.encode([WireValue(content: Self.text(of: post.content), image: [])], forKey: .value)
            try item.encodeIfPresent(post.group, forKey: .group)
            try item.encode(WireSettings(type: post.integration?.providerIdentifier), forKey: .settings)
        }
    }

    private static func text(of content: PostContentValue?) -> String {
        switch content {
        case .string(let value): value
        case .items(let items): items.first?.content ?? ""
        case nil: ""
        }
    }

    private static func nowISO8601() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

// MARK: - Reschedule

public struct RescheduleRequest: Sendable, Codable, Equatable {
    public let date: String
    public let action: String?

    public init(date: String, action: String?) {
        self.date = date
        self.action = action
    }
}

public struct RescheduleResponse: Sendable, Codable, Equatable {
    public let group: String
    public let date: String

    public init(group: String, date: String) {
        self.group = group
        self.date = date
    }
}
