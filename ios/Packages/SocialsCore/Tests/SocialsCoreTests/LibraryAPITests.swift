import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s tags/signatures/media-library methods through a scripted
/// `MockTransport`, mirroring `PostsExtrasAPITests`. Also exercises `StubSocialsAPI`'s call
/// recording for the same set.
@Suite("SocialsAPI library (tags/signatures/media)")
struct LibraryAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    private let tag = TagDTO(
        id: "t1", name: "Launch", color: "#fff", orgId: "o1", createdAt: nil, updatedAt: nil,
        deletedAt: nil)

    private let signature = SignatureDTO(
        id: "s1", organizationId: "o1", content: "Thanks", autoAdd: true, createdAt: nil,
        updatedAt: nil, deletedAt: nil)

    // MARK: - LiveSocialsAPI happy path

    @Test("tags: GET /tags decodes wrapped response")
    func tagsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: TagsListResponse(tags: [tag]))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.tags()

        #expect(response.tags.count == 1)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/tags")
    }

    @Test("createTag: POST /tags sends {name, color} body")
    func createTagSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.createTag(CreateTagRequest(name: "Launch", color: "#fff"))

        #expect(response.name == "Launch")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/tags")
    }

    @Test("updateTag: PUT /tags/:id")
    func updateTagSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.updateTag("t1", body: CreateTagRequest(name: "Launch", color: "#fff"))

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .put)
        #expect(recorded[0].request.path == "/mobile/v1/tags/t1")
    }

    @Test("deleteTag: DELETE /tags/:id")
    func deleteTagSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: tag)
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.deleteTag("t1")

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/tags/t1")
    }

    @Test("signatures: GET /signatures decodes plain array")
    func signaturesDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: [signature])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.signatures()

        #expect(response.count == 1)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/signatures")
    }

    @Test("defaultSignature: GET /signatures/default")
    func defaultSignatureDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: signature)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.defaultSignature()

        #expect(response.content == "Thanks")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/signatures/default")
    }

    @Test("createSignature: POST /signatures sends {content, autoAdd} body")
    func createSignatureSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: signature)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.createSignature(
            SignatureRequest(content: "Thanks", autoAdd: true))

        #expect(response.content == "Thanks")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/signatures")
    }

    @Test("updateSignature: PUT /signatures/:id")
    func updateSignatureSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: signature)
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.updateSignature(
            "s1", body: SignatureRequest(content: "Thanks", autoAdd: true))

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .put)
        #expect(recorded[0].request.path == "/mobile/v1/signatures/s1")
    }

    @Test("deleteSignature: DELETE /signatures/:id")
    func deleteSignatureSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: signature)
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.deleteSignature("s1")

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/signatures/s1")
    }

    @Test("mediaList: GET /media decodes response")
    func mediaListDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: MediaListResponse(pages: 3, results: []))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.mediaList(page: 2)

        #expect(response.pages == 3)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/media?page=2")
    }

    @Test("deleteMedia: DELETE /media/:id")
    func deleteMediaSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: OpaqueJSONResult(raw: "{}"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.deleteMedia("m1")

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/media/m1")
    }

    @Test("saveMediaInformation: POST /media/information")
    func saveMediaInformationSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: OpaqueJSONResult(raw: "{}"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.saveMediaInformation(
            MediaInformationRequest(id: "m1", alt: "A photo", thumbnail: nil, thumbnailTimestamp: nil))

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/media/information")
    }

    @Test("createUpload: POST /media/uploads decodes response")
    func createUploadDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: MediaCreateUploadResponse(
                uploadId: "u1", key: "k1", partSize: 8_388_608, parts: [],
                expiresAt: "2026-01-01T00:00:00Z"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.createUpload(
            MediaCreateUploadRequest(fileName: "a.jpg", contentType: "image/jpeg", size: 1024))

        #expect(response.uploadId == "u1")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/media/uploads")
    }

    @Test("completeUpload: POST /media/uploads/complete decodes response")
    func completeUploadDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: MediaCompleteUploadResponse(
                media: MediaDTO(
                    id: "m1", name: "a.jpg", originalName: nil, path: "p", thumbnail: nil,
                    alt: nil, thumbnailTimestamp: nil, status: "ready", processingError: nil)))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.completeUpload(
            MediaCompleteUploadRequest(
                key: "k1", uploadId: "u1",
                parts: [MediaCompleteUploadPart(partNumber: 1, etag: "e1")],
                originalName: "a.jpg"))

        #expect(response.media.id == "m1")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/media/uploads/complete")
    }

    // MARK: - Error mapping

    @Test("createTag: 400 {msg} maps to .validation with message")
    func createTagValidationError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 400, json: ["msg": "Name is required"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.createTag(CreateTagRequest(name: "", color: "#fff"))
            Issue.record("expected SocialsAPIError.validation to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .validation(message: "Name is required"))
        }
    }

    @Test("deleteMedia: 404 {msg} maps to .notFound with message")
    func deleteMediaNotFoundError() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Media not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.deleteMedia("missing")
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Media not found"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setTagsResults([.success(TagsListResponse(tags: [tag]))])
        await stub.setDeleteMediaResults([.success(OpaqueJSONResult(raw: "{}"))])

        _ = try await stub.tags()
        _ = try await stub.deleteMedia("m1")

        let tagsCallCount = await stub.tagsCallCount
        #expect(tagsCallCount == 1)

        let deleteMediaCalls = await stub.deleteMediaCalls
        #expect(deleteMediaCalls == ["m1"])
    }
}

extension StubSocialsAPI {
    fileprivate func setTagsResults(_ results: [Result<TagsListResponse, Error>]) async {
        tagsResults = results
    }

    fileprivate func setDeleteMediaResults(_ results: [Result<OpaqueJSONResult, Error>]) async {
        deleteMediaResults = results
    }
}
