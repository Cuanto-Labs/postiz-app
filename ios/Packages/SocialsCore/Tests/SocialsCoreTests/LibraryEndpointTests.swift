import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives the `SocialsEndpoints` tags/signatures/media-library builders (`LibraryEndpoints.swift`)
/// through a real `APIClient` + scripted `MockTransport`, asserting on the request `APIClient`
/// actually sent. Same harness as `EndpointTests`.
@Suite("LibraryEndpoints")
struct LibraryEndpointTests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    private func bodyKeys(_ data: Data?) throws -> Set<String> {
        guard let data else { return [] }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set(object.map { Array($0.keys) } ?? [])
    }

    private let tag = TagDTO(
        id: "t1", name: "Launch", color: "#fff", orgId: "o1", createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z", deletedAt: nil)

    // MARK: - Tags

    @Test("tags: GET, wrapped in tags key")
    func tags() async throws {
        let endpoint = SocialsEndpoints.tags()
        let transport = MockTransport()
        try await transport.enqueue(json: TagsListResponse(tags: [tag]))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/tags")
    }

    @Test("createTag: POST, JSON body")
    func createTag() async throws {
        let endpoint = try SocialsEndpoints.createTag(CreateTagRequest(name: "Launch", color: "#fff"))
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/tags")
        #expect(try bodyKeys(recorded.body) == ["name", "color"])
    }

    @Test("updateTag: PUT with id in path")
    func updateTag() async throws {
        let endpoint = try SocialsEndpoints.updateTag(
            "t1", body: CreateTagRequest(name: "Launch", color: "#fff"))
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/tags/t1")
    }

    @Test("deleteTag: DELETE with id in path")
    func deleteTag() async throws {
        let endpoint = SocialsEndpoints.deleteTag("t1")
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/tags/t1")
    }

    // MARK: - Signatures

    @Test("signatures: GET, plain array")
    func signatures() async throws {
        let endpoint = SocialsEndpoints.signatures()
        let transport = MockTransport()
        try await transport.enqueue(
            json: [
                SignatureDTO(
                    id: "s1", organizationId: "o1", content: "Thanks", autoAdd: true,
                    createdAt: nil, updatedAt: nil, deletedAt: nil)
            ])
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/signatures")
    }

    @Test("defaultSignature: GET /signatures/default, tolerates {}")
    func defaultSignature() async throws {
        let endpoint = SocialsEndpoints.defaultSignature()
        let transport = MockTransport()
        try await transport.enqueue(
            json: SignatureDTO(
                id: nil, organizationId: nil, content: nil, autoAdd: nil, createdAt: nil,
                updatedAt: nil, deletedAt: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/signatures/default")
    }

    @Test("createSignature: POST, JSON body")
    func createSignature() async throws {
        let endpoint = try SocialsEndpoints.createSignature(
            SignatureRequest(content: "Thanks", autoAdd: true))
        let transport = MockTransport()
        try await transport.enqueue(
            json: SignatureDTO(
                id: "s1", organizationId: "o1", content: "Thanks", autoAdd: true, createdAt: nil,
                updatedAt: nil, deletedAt: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/signatures")
        #expect(try bodyKeys(recorded.body) == ["content", "autoAdd"])
    }

    @Test("deleteSignature: DELETE with id in path")
    func deleteSignature() async throws {
        let endpoint = SocialsEndpoints.deleteSignature("s1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: SignatureDTO(
                id: "s1", organizationId: "o1", content: "Thanks", autoAdd: true, createdAt: nil,
                updatedAt: nil, deletedAt: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/signatures/s1")
    }

    // MARK: - Media

    @Test("mediaList: GET, optional page query")
    func mediaList() async throws {
        let endpoint = SocialsEndpoints.mediaList(page: 2)
        let transport = MockTransport()
        try await transport.enqueue(json: MediaListResponse(pages: 3, results: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/media?page=2")
    }

    @Test("deleteMedia: DELETE with id in path, opaque response")
    func deleteMedia() async throws {
        let endpoint = SocialsEndpoints.deleteMedia("m1")
        let transport = MockTransport()
        try await transport.enqueue(json: OpaqueJSONResult(raw: "{}"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/media/m1")
    }

    @Test("saveMediaInformation: POST /media/information, JSON body")
    func saveMediaInformation() async throws {
        let endpoint = try SocialsEndpoints.saveMediaInformation(
            MediaInformationRequest(id: "m1", alt: "A photo", thumbnail: nil, thumbnailTimestamp: nil))
        let transport = MockTransport()
        try await transport.enqueue(json: OpaqueJSONResult(raw: "{}"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/media/information")
        #expect(try bodyKeys(recorded.body) == ["id", "alt"])
    }

    @Test("createMediaUpload: POST /media/uploads, JSON body")
    func createMediaUpload() async throws {
        let endpoint = try SocialsEndpoints.createMediaUpload(
            MediaCreateUploadRequest(fileName: "a.jpg", contentType: "image/jpeg", size: 1024))
        let transport = MockTransport()
        try await transport.enqueue(
            json: MediaCreateUploadResponse(
                uploadId: "u1", key: "k1", partSize: 8_388_608, parts: [], expiresAt: "2026-01-01T00:00:00Z"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/media/uploads")
        #expect(try bodyKeys(recorded.body) == ["fileName", "contentType", "size"])
    }

    @Test("completeMediaUpload: POST /media/uploads/complete, JSON body")
    func completeMediaUpload() async throws {
        let endpoint = try SocialsEndpoints.completeMediaUpload(
            MediaCompleteUploadRequest(
                key: "k1", uploadId: "u1", parts: [MediaCompleteUploadPart(partNumber: 1, etag: "e1")],
                originalName: "a.jpg"))
        let transport = MockTransport()
        try await transport.enqueue(
            json: MediaCompleteUploadResponse(
                media: MediaDTO(
                    id: "m1", name: "a.jpg", originalName: nil, path: "p", thumbnail: nil,
                    alt: nil, thumbnailTimestamp: nil, status: "ready", processingError: nil)))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/media/uploads/complete")
        #expect(try bodyKeys(recorded.body) == ["key", "uploadId", "parts", "originalName"])
    }
}
