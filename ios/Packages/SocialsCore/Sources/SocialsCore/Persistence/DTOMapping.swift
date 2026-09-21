import Foundation

/// Field-level mapping from wire DTOs to `@Model` cache rows. Kept separate from
/// `CacheStore` so the actor stays focused on fetch/insert/delete orchestration.
enum DTOMapping {

    // MARK: - Channels

    static func makeChannel(from dto: ChannelDTO, orgId: String) -> CachedChannel {
        CachedChannel(
            id: dto.id,
            orgId: orgId,
            internalId: dto.internalId,
            name: dto.name,
            identifier: dto.identifier,
            picture: dto.picture,
            disabled: dto.disabled,
            refreshNeeded: dto.refreshNeeded,
            inBetweenSteps: dto.inBetweenSteps,
            maxCharacters: dto.limits.maxCharacters ?? 0,
            editor: dto.limits.editor ?? "TEXT",
            updatedAt: .now
        )
    }

    static func update(_ channel: CachedChannel, from dto: ChannelDTO) {
        channel.internalId = dto.internalId
        channel.name = dto.name
        channel.identifier = dto.identifier
        channel.picture = dto.picture
        channel.disabled = dto.disabled
        channel.refreshNeeded = dto.refreshNeeded
        channel.inBetweenSteps = dto.inBetweenSteps
        channel.maxCharacters = dto.limits.maxCharacters ?? 0
        channel.editor = dto.limits.editor ?? "TEXT"
        channel.updatedAt = .now
    }

    // MARK: - Posts

    /// Fields pulled off a `PostGroupDTO` and normalized for the cache. `nil`
    /// when the record can't be cached — no group/id (no unique key) or no
    /// parseable publish date (no window bucket).
    struct CachedPostFields {
        let group: String
        let publishDate: Date
        let status: PostStatus
        let channelId: String
        let content: String
    }

    static func cachedPostFields(from dto: PostGroupDTO) -> CachedPostFields? {
        guard let group = dto.group ?? dto.id else { return nil }
        guard let publishDateString = dto.publishDate, let publishDate = parseDate(publishDateString) else {
            return nil
        }
        let status = PostStatus(rawValue: (dto.status ?? "").uppercased()) ?? .queue
        let channelId = dto.integration?.id ?? ""
        return CachedPostFields(
            group: group, publishDate: publishDate, status: status, channelId: channelId,
            content: flattenContent(dto.content)
        )
    }

    static func makeCachedPost(orgId: String, fields: CachedPostFields, rawJSON: Data) -> CachedPost {
        CachedPost(
            group: fields.group,
            orgId: orgId,
            publishDate: fields.publishDate,
            status: fields.status,
            channelId: fields.channelId,
            content: fields.content,
            rawJSON: rawJSON,
            updatedAt: .now
        )
    }

    static func update(_ post: CachedPost, fields: CachedPostFields, rawJSON: Data) {
        post.publishDate = fields.publishDate
        post.status = fields.status.rawValue
        post.channelId = fields.channelId
        post.content = fields.content
        post.rawJSON = rawJSON
        post.updatedAt = .now
    }

    private static func flattenContent(_ value: PostContentValue?) -> String {
        switch value {
        case .string(let text): return text
        case .items(let items): return items.compactMap(\.content).joined(separator: "\n")
        case nil: return ""
        }
    }

    // MARK: - Dates

    // `nonisolated(unsafe)`: formatters are configured once at init and only
    // ever read (via `.date(from:)`) afterward — no shared mutable state in practice.
    private nonisolated(unsafe) static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    static func parseDate(_ string: String) -> Date? {
        iso8601Fractional.date(from: string) ?? iso8601.date(from: string)
    }
}
