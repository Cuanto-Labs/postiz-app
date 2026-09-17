import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives every `PostsExtrasEndpoints` builder through a real `APIClient` + scripted
/// `MockTransport`, asserting on the request `APIClient` actually sent (mirrors `EndpointTests`).
@Suite("PostsExtrasEndpoints")
struct PostsExtrasEndpointTests {
    private static let showorgHeader = HTTPField.Name("showorg")!

    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    @Test("list: GET /posts/list with page/limit query and org header")
    func list() async throws {
        let endpoint = PostsExtrasEndpoints.list(page: 2, limit: 20, orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostsListResponse(posts: [], total: 0, page: 2, limit: 20, hasMore: false))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/posts/list?"))
        #expect(path.contains("page=2"))
        #expect(path.contains("limit=20"))
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("old: GET /posts/old with date query")
    func old() async throws {
        let endpoint = PostsExtrasEndpoints.old(date: "2026-01-01")
        let transport = MockTransport()
        try await transport.enqueue(json: OldPostsResponse(posts: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/posts/old?"))
        #expect(path.contains("date=2026-01-01"))
    }

    @Test("findSlot: GET /posts/find-slot")
    func findSlot() async throws {
        let endpoint = PostsExtrasEndpoints.findSlot(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: FindSlotResponse(date: "2026-02-01T00:00:00Z"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/posts/find-slot")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("findSlot(integrationId:): GET /posts/find-slot/:id")
    func findSlotForIntegration() async throws {
        let endpoint = PostsExtrasEndpoints.findSlot(integrationId: "i1")
        let transport = MockTransport()
        try await transport.enqueue(json: FindSlotResponse(date: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/posts/find-slot/i1")
    }

    @Test("statistics: GET /posts/:id/statistics decodes opaque JSON")
    func statistics() async throws {
        let endpoint = PostsExtrasEndpoints.statistics(id: "p1")
        let transport = MockTransport()
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        await transport.enqueue(headers: headers, body: Data(#"{"clicks":10}"#.utf8))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/posts/p1/statistics")
        #expect(result.raw.contains("clicks"))
    }

    @Test("missing: GET /posts/:id/missing")
    func missing() async throws {
        let endpoint = PostsExtrasEndpoints.missing(id: "p1")
        let transport = MockTransport()
        try await transport.enqueue(json: [MissingContentItemDTO(id: "p1", url: "https://x")])
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/posts/p1/missing")
        #expect(result.first?.url == "https://x")
    }

    @Test("comments: GET /posts/:id/comments")
    func comments() async throws {
        let endpoint = PostsExtrasEndpoints.comments(id: "p1")
        let transport = MockTransport()
        try await transport.enqueue(json: PostCommentsResponse(comments: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/posts/p1/comments")
    }

    @Test("createComment: POST /posts/:id/comments with JSON body")
    func createComment() async throws {
        let endpoint = try PostsExtrasEndpoints.createComment(id: "p1", comment: "hi")
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostCommentDTO(id: "c1", content: "hi", postId: "p1", userId: "u1", createdAt: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/posts/p1/comments")
        let body = try #require(recorded.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["comment"] as? String == "hi")
    }

    @Test("preview: GET /posts/:id/preview")
    func preview() async throws {
        let endpoint = PostsExtrasEndpoints.preview(id: "p1")
        let transport = MockTransport()
        try await transport.enqueue(json: PostPreviewResponse(posts: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/posts/p1/preview")
    }
}
