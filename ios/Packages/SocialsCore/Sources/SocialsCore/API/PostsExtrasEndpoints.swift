import Foundation
import CuantoNet

/// Extra `/mobile/v1/posts/*` endpoints beyond the core CRUD set in `SocialsEndpoints`:
/// paginated list, old posts, find-slot, statistics, missing content, comments, preview.
public enum PostsExtrasEndpoints {
    private static var basePath: String { SocialsEndpoints.basePath }

    /// Decode strategy for `OpaqueJSONResult`-typed endpoints: capture the raw response bytes
    /// as a UTF-8 string rather than assuming a specific JSON shape (mirrors
    /// `SocialsEndpoints`'s private `rawDecode`, duplicated here since it's file-private there).
    private static let rawDecode: @Sendable (Data, JSONDecoder) throws -> OpaqueJSONResult = {
        data, _ in
        OpaqueJSONResult(raw: String(decoding: data, as: UTF8.self))
    }

    /// `GET /mobile/v1/posts/list` — paginated list.
    public static func list(page: Int? = nil, limit: Int? = nil, orgId: String? = nil)
        -> Endpoint<PostsListResponse>
    {
        var endpoint = Endpoint<PostsListResponse>(path: "\(basePath)/posts/list")
        if let page { endpoint = endpoint.query("page", String(page)) }
        if let limit { endpoint = endpoint.query("limit", String(limit)) }
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/old` — posts before a given date.
    public static func old(date: String, orgId: String? = nil) -> Endpoint<OldPostsResponse> {
        let endpoint = Endpoint<OldPostsResponse>(path: "\(basePath)/posts/old").query("date", date)
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/find-slot` — next free posting slot.
    public static func findSlot(orgId: String? = nil) -> Endpoint<FindSlotResponse> {
        let endpoint = Endpoint<FindSlotResponse>(path: "\(basePath)/posts/find-slot")
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/find-slot/:id` — next free posting slot for a specific integration.
    public static func findSlot(integrationId: String, orgId: String? = nil) -> Endpoint<FindSlotResponse> {
        let endpoint = Endpoint<FindSlotResponse>(path: "\(basePath)/posts/find-slot/\(integrationId)")
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/:id/statistics` — response shape isn't pinned down by
    /// docs/MOBILE-API.md, decode as opaque JSON.
    public static func statistics(id: String, orgId: String? = nil) -> Endpoint<OpaqueJSONResult> {
        let endpoint = Endpoint<OpaqueJSONResult>(
            path: "\(basePath)/posts/\(id)/statistics", decode: rawDecode)
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/:id/missing` — missing content items.
    public static func missing(id: String, orgId: String? = nil) -> Endpoint<[MissingContentItemDTO]> {
        let endpoint = Endpoint<[MissingContentItemDTO]>(path: "\(basePath)/posts/\(id)/missing")
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/:id/comments`.
    public static func comments(id: String, orgId: String? = nil) -> Endpoint<PostCommentsResponse> {
        let endpoint = Endpoint<PostCommentsResponse>(path: "\(basePath)/posts/\(id)/comments")
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `POST /mobile/v1/posts/:id/comments`.
    public static func createComment(id: String, comment: String, orgId: String? = nil) throws
        -> Endpoint<PostCommentDTO>
    {
        let endpoint = try Endpoint<PostCommentDTO>(
            method: .post, path: "\(basePath)/posts/\(id)/comments",
            body: .json(CreateCommentRequest(comment: comment)))
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/posts/:id/preview`.
    public static func preview(id: String, orgId: String? = nil) -> Endpoint<PostPreviewResponse> {
        let endpoint = Endpoint<PostPreviewResponse>(path: "\(basePath)/posts/\(id)/preview")
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }
}
