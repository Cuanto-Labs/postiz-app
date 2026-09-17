import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI` through a real `APIClient` + scripted `MockTransport`,
/// asserting both the happy-path fixture decode and the `APIError` → `SocialsAPIError`
/// mapping for the mobile API's error body shapes (docs/MOBILE-API.md).
@Suite("LiveSocialsAPI")
struct LiveSocialsAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - Happy path (fixture decode)

    @Test("me: decodes me.json fixture")
    func meDecodesFixture() async throws {
        let transport = MockTransport()
        try await transport.enqueue(.me)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.me()

        let expected: MeResponse = try Fixture.me.decode()
        #expect(response == expected)
    }

    @Test("channels: decodes channels.json fixture")
    func channelsDecodesFixture() async throws {
        let transport = MockTransport()
        try await transport.enqueue(.channels)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.channels()

        let expected: ChannelsResponse = try Fixture.channels.decode()
        #expect(response == expected)
    }

    @Test("posts: decodes posts.json fixture")
    func postsDecodesFixture() async throws {
        let transport = MockTransport()
        try await transport.enqueue(.posts)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.posts(from: "2026-01-01", to: "2026-01-31", customer: nil)

        let expected: PostsResponse = try Fixture.posts.decode()
        #expect(response == expected)
    }

    // MARK: - Error mapping

    @Test("post: 404 {msg} body maps to .notFound with message")
    func postNotFound() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Post not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.post(group: "g1")
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Post not found"))
        }
    }

    @Test("createPost: 422 maps to .idempotencyConflict")
    func createPostIdempotencyConflict() async throws {
        let transport = MockTransport()
        await transport.enqueue(status: 422)
        let api = LiveSocialsAPI(client: makeClient(transport))
        let body = CreatePostBody(type: "schedule", posts: [])

        do {
            _ = try await api.createPost(body: body, key: IdempotencyKey())
            Issue.record("expected SocialsAPIError.idempotencyConflict to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .idempotencyConflict)
        }
    }

    @Test("me: Nest-shaped 403 maps to .forbidden with message")
    func meForbidden() async throws {
        let transport = MockTransport()
        let nestBody = Data(
            """
            {"statusCode":403,"message":"Forbidden resource","error":"Forbidden"}
            """.utf8)
        await transport.enqueue(status: 403, body: nestBody)
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.me()
            Issue.record("expected SocialsAPIError.forbidden to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .forbidden(message: "Forbidden resource"))
        }
    }
}
