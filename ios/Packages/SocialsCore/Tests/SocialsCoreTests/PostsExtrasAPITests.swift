import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s posts-extras methods (postsList, oldPosts, findSlot, statistics,
/// comments, addComment, preview, missing) through a scripted `MockTransport`, mirroring
/// `ChannelSettingsAPITests`. Also exercises `StubSocialsAPI`'s call recording for the same set.
@Suite("SocialsAPI posts extras")
struct PostsExtrasAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - LiveSocialsAPI happy path

    @Test("postsList: GET /posts/list decodes paginated response")
    func postsListDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostsListResponse(posts: [], total: 1, page: 1, limit: 10, hasMore: false))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.postsList(page: 1, limit: 10)

        #expect(response.total == 1)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path?.hasPrefix("/mobile/v1/posts/list?") == true)
    }

    @Test("oldPosts: GET /posts/old decodes bare array")
    func oldPostsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: OldPostsResponse(posts: []))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.oldPosts(date: "2026-01-01")

        #expect(response.posts.isEmpty)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path?.hasPrefix("/mobile/v1/posts/old?") == true)
    }

    @Test("findSlot: nil integrationId hits /posts/find-slot")
    func findSlotWithoutIntegration() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: FindSlotResponse(date: "2026-02-01T00:00:00Z"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.findSlot(integrationId: nil)

        #expect(response.date == "2026-02-01T00:00:00Z")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/posts/find-slot")
    }

    @Test("findSlot: integrationId hits /posts/find-slot/:id")
    func findSlotWithIntegration() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: FindSlotResponse(date: nil))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.findSlot(integrationId: "i1")

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/posts/find-slot/i1")
    }

    @Test("statistics: decodes opaque JSON")
    func statisticsDecodesOpaqueJSON() async throws {
        let transport = MockTransport()
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        await transport.enqueue(headers: headers, body: Data(#"{"clicks":10}"#.utf8))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.statistics(id: "p1")

        #expect(response.raw == #"{"clicks":10}"#)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/posts/p1/statistics")
    }

    @Test("comments: GET /posts/:id/comments decodes list")
    func commentsDecodesList() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostCommentsResponse(
                comments: [
                    PostCommentDTO(
                        id: "c1", content: "nice", postId: "p1", userId: "u1", createdAt: nil)
                ]))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.comments(id: "p1")

        #expect(response.comments.count == 1)
        #expect(response.comments[0].content == "nice")
    }

    @Test("addComment: POST /posts/:id/comments sends {comment} body")
    func addCommentSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostCommentDTO(id: "c1", content: "hi", postId: "p1", userId: "u1", createdAt: nil))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.addComment(id: "p1", comment: "hi")

        #expect(response.content == "hi")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/posts/p1/comments")
    }

    @Test("preview: GET /posts/:id/preview decodes bare array")
    func previewDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: PostPreviewResponse(posts: []))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.preview(id: "p1")

        #expect(response.posts.isEmpty)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/posts/p1/preview")
    }

    @Test("missing: GET /posts/:id/missing decodes item array")
    func missingDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: [MissingContentItemDTO(id: "m1", url: "https://x.example")])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.missing(id: "p1")

        #expect(response.count == 1)
        #expect(response[0].url == "https://x.example")
    }

    // MARK: - Error mapping

    @Test("addComment: 400 {msg} maps to .validation with message")
    func addCommentValidationError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 400, json: ["msg": "Comment cannot be empty"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.addComment(id: "p1", comment: "")
            Issue.record("expected SocialsAPIError.validation to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .validation(message: "Comment cannot be empty"))
        }
    }

    @Test("statistics: 404 {msg} maps to .notFound with message")
    func statisticsNotFoundError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Post not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.statistics(id: "missing")
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Post not found"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setPostsListResults([.success(PostsListResponse(
            posts: [], total: 0, page: 1, limit: 10, hasMore: false))])
        await stub.setAddCommentResults([.success(PostCommentDTO(
            id: "c1", content: "hi", postId: "p1", userId: "u1", createdAt: nil))])

        _ = try await stub.postsList(page: 1, limit: 10)
        _ = try await stub.addComment(id: "p1", comment: "hi")

        let postsListCalls = await stub.postsListCalls
        #expect(postsListCalls.count == 1)
        #expect(postsListCalls[0].page == 1)

        let addCommentCalls = await stub.addCommentCalls
        #expect(addCommentCalls.count == 1)
        #expect(addCommentCalls[0].comment == "hi")
    }
}

extension StubSocialsAPI {
    fileprivate func setPostsListResults(_ results: [Result<PostsListResponse, Error>]) async {
        postsListResults = results
    }

    fileprivate func setAddCommentResults(_ results: [Result<PostCommentDTO, Error>]) async {
        addCommentResults = results
    }
}
