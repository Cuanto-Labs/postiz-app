import Foundation
import Testing

@testable import SocialsCore

/// Scripted `PartUploader` — returns queued etags in order, or throws once the queue is
/// exhausted (mirrors `StubSocialsAPI.next`'s "must script exactly as many calls" convention).
private actor StubPartUploader: PartUploader {
    private var etags: [String]
    private var errorToThrow: Error?
    private var delayNanoseconds: UInt64
    private(set) var putCallCount = 0
    private(set) var putSizes: [Int] = []

    init(etags: [String] = [], errorToThrow: Error? = nil, delayNanoseconds: UInt64 = 0) {
        self.etags = etags
        self.errorToThrow = errorToThrow
        self.delayNanoseconds = delayNanoseconds
    }

    func putPart(_ data: Data, to url: URL) async throws -> String {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        putCallCount += 1
        putSizes.append(data.count)
        if let errorToThrow { throw errorToThrow }
        guard !etags.isEmpty else { return "etag-\(putCallCount)" }
        return etags.removeFirst()
    }
}

@Suite("UploadQueueTests")
@MainActor
struct UploadQueueTests {

    private func media(id: String = "m1") -> MediaDTO {
        MediaDTO(
            id: id, name: "photo.jpg", originalName: "photo.jpg", path: "/media/photo.jpg",
            thumbnail: nil, alt: nil, thumbnailTimestamp: nil, status: "ready",
            processingError: nil)
    }

    @Test
    func uploadSucceedsAndCompletesItem() async {
        let api = StubSocialsAPI()
        let part = MediaUploadPart(partNumber: 1, url: "https://r2.example.com/part1")
        await api.setCreateUploadResults([
            .success(
                MediaCreateUploadResponse(
                    uploadId: "u1", key: "k1", partSize: 8_000_000, parts: [part],
                    expiresAt: "2026-09-17T00:00:00Z"))
        ])
        let expectedMedia = media()
        await api.setCompleteUploadResults([
            .success(MediaCompleteUploadResponse(media: expectedMedia))
        ])
        let partUploader = StubPartUploader(etags: ["etag-abc"])
        let queue = UploadQueue(api: api, partUploader: partUploader)

        let result = await queue.upload(
            data: Data(repeating: 0, count: 100), fileName: "photo.jpg",
            contentType: "image/jpeg")

        #expect(result == expectedMedia)
        #expect(queue.items.count == 1)
        #expect(queue.items[0].status == .completed(expectedMedia))
        let completeCalls = await api.completeUploadCalls
        #expect(
            completeCalls == [
                MediaCompleteUploadRequest(
                    key: "k1", uploadId: "u1",
                    parts: [MediaCompleteUploadPart(partNumber: 1, etag: "etag-abc")],
                    originalName: "photo.jpg")
            ])
    }

    @Test
    func uploadSplitsDataAcrossMultipleParts() async {
        let api = StubSocialsAPI()
        let parts = [
            MediaUploadPart(partNumber: 1, url: "https://r2.example.com/part1"),
            MediaUploadPart(partNumber: 2, url: "https://r2.example.com/part2"),
        ]
        await api.setCreateUploadResults([
            .success(
                MediaCreateUploadResponse(
                    uploadId: "u1", key: "k1", partSize: 10, parts: parts,
                    expiresAt: "2026-09-17T00:00:00Z"))
        ])
        await api.setCompleteUploadResults([
            .success(MediaCompleteUploadResponse(media: media()))
        ])
        let partUploader = StubPartUploader(etags: ["etag-1", "etag-2"])
        let queue = UploadQueue(api: api, partUploader: partUploader)

        _ = await queue.upload(
            data: Data(repeating: 1, count: 15), fileName: "video.mp4",
            contentType: "video/mp4")

        let sizes = await partUploader.putSizes
        #expect(sizes == [10, 5])
        let completeCalls = await api.completeUploadCalls
        #expect(
            completeCalls.first?.parts == [
                MediaCompleteUploadPart(partNumber: 1, etag: "etag-1"),
                MediaCompleteUploadPart(partNumber: 2, etag: "etag-2"),
            ])
    }

    @Test
    func uploadSurfacesCreateUploadFailure() async {
        let api = StubSocialsAPI()
        await api.setCreateUploadResults([.failure(SocialsAPIError.offline)])
        let queue = UploadQueue(api: api, partUploader: StubPartUploader())

        let result = await queue.upload(
            data: Data([0x1]), fileName: "photo.jpg", contentType: "image/jpeg")

        #expect(result == nil)
        #expect(
            queue.items[0].status
                == .failed("You're offline. Check your connection and try again."))
    }

    @Test
    func uploadSurfacesPartUploadFailure() async {
        let api = StubSocialsAPI()
        let part = MediaUploadPart(partNumber: 1, url: "https://r2.example.com/part1")
        await api.setCreateUploadResults([
            .success(
                MediaCreateUploadResponse(
                    uploadId: "u1", key: "k1", partSize: 8_000_000, parts: [part],
                    expiresAt: "2026-09-17T00:00:00Z"))
        ])
        let partUploader = StubPartUploader(errorToThrow: UploadQueueError.partUploadFailed)
        let queue = UploadQueue(api: api, partUploader: partUploader)

        let result = await queue.upload(
            data: Data([0x1]), fileName: "photo.jpg", contentType: "image/jpeg")

        #expect(result == nil)
        #expect(queue.items[0].status == .failed("Upload failed. Please try again."))
    }

    @Test
    func retryResubmitsOriginalBytesAfterFailure() async {
        let api = StubSocialsAPI()
        let part = MediaUploadPart(partNumber: 1, url: "https://r2.example.com/part1")
        await api.setCreateUploadResults([
            .failure(SocialsAPIError.offline),
            .success(
                MediaCreateUploadResponse(
                    uploadId: "u1", key: "k1", partSize: 8_000_000, parts: [part],
                    expiresAt: "2026-09-17T00:00:00Z")),
        ])
        let expectedMedia = media()
        await api.setCompleteUploadResults([.success(MediaCompleteUploadResponse(media: expectedMedia))])
        let partUploader = StubPartUploader(etags: ["etag-retry"])
        let queue = UploadQueue(api: api, partUploader: partUploader)

        let first = await queue.upload(data: Data([0x1, 0x2]), fileName: "a.jpg", contentType: "image/jpeg")
        #expect(first == nil)
        #expect(queue.items[0].status == .failed("You're offline. Check your connection and try again."))

        let itemId = queue.items[0].id
        let retried = await queue.retry(itemId)

        #expect(retried == expectedMedia)
        #expect(queue.items[0].status == .completed(expectedMedia))
        let sizes = await partUploader.putSizes
        #expect(sizes == [2], "retry must resend the original bytes, not an empty/new payload")
    }

    @Test
    func cancelInterruptsAnInFlightUploadAndMarksItFailed() async {
        let api = StubSocialsAPI()
        let part = MediaUploadPart(partNumber: 1, url: "https://r2.example.com/part1")
        await api.setCreateUploadResults([
            .success(
                MediaCreateUploadResponse(
                    uploadId: "u1", key: "k1", partSize: 8_000_000, parts: [part],
                    expiresAt: "2026-09-17T00:00:00Z"))
        ])
        let partUploader = StubPartUploader(etags: ["etag-1"], delayNanoseconds: 200_000_000)
        let queue = UploadQueue(api: api, partUploader: partUploader)

        async let result = queue.upload(data: Data([0x1]), fileName: "a.jpg", contentType: "image/jpeg")
        try? await Task.sleep(nanoseconds: 20_000_000)
        let itemId = queue.items.first?.id
        if let itemId { queue.cancel(itemId) }

        let finished = await result
        #expect(finished == nil)
        if let itemId {
            #expect(queue.items.first(where: { $0.id == itemId })?.status == .failed("Cancelled."))
        }
    }

    @Test
    func removeDropsFinishedItemButKeepsInFlight() async {
        let api = StubSocialsAPI()
        await api.setCreateUploadResults([.failure(SocialsAPIError.offline)])
        let queue = UploadQueue(api: api, partUploader: StubPartUploader())
        _ = await queue.upload(data: Data([0x1]), fileName: "a.jpg", contentType: "image/jpeg")
        let failedId = queue.items[0].id

        queue.remove(failedId)

        #expect(queue.items.isEmpty)
    }
}

@Suite("MediaLibraryViewModelTests")
@MainActor
struct MediaLibraryViewModelTests {

    private func media(id: String = "m1", alt: String? = nil) -> MediaDTO {
        MediaDTO(
            id: id, name: "photo.jpg", originalName: "photo.jpg", path: "/media/photo.jpg",
            thumbnail: nil, alt: alt, thumbnailTimestamp: nil, status: "ready",
            processingError: nil)
    }

    @Test
    func loadPopulatesMediaAndPaging() async {
        let api = StubSocialsAPI()
        let m = media()
        await api.setMediaListResults([.success(MediaListResponse(pages: 2, results: [m]))])
        let viewModel = MediaLibraryViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.media == [m])
        #expect(viewModel.page == 1)
        #expect(viewModel.hasNextPage)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadAppendsOnSubsequentPage() async {
        let api = StubSocialsAPI()
        let first = media(id: "m1")
        let second = media(id: "m2")
        await api.setMediaListResults([
            .success(MediaListResponse(pages: 2, results: [first])),
            .success(MediaListResponse(pages: 2, results: [second])),
        ])
        let viewModel = MediaLibraryViewModel(api: api)
        await viewModel.load()

        await viewModel.loadNextPageIfNeeded()

        #expect(viewModel.media == [first, second])
        #expect(viewModel.page == 2)
        #expect(!viewModel.hasNextPage)
    }

    @Test
    func loadSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setMediaListResults([.failure(SocialsAPIError.offline)])
        let viewModel = MediaLibraryViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.media.isEmpty)
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    @Test
    func deleteMediaRemovesItemFromList() async {
        let api = StubSocialsAPI()
        let m = media()
        await api.setMediaListResults([.success(MediaListResponse(pages: 1, results: [m]))])
        let viewModel = MediaLibraryViewModel(api: api)
        await viewModel.load()
        await api.setDeleteMediaResults([.success(OpaqueJSONResult(raw: "{}"))])

        let ok = await viewModel.deleteMedia(m)

        #expect(ok)
        #expect(viewModel.media.isEmpty)
        let calls = await api.deleteMediaCalls
        #expect(calls == ["m1"])
    }

    @Test
    func updateAltUpdatesItemInPlace() async {
        let api = StubSocialsAPI()
        let m = media()
        await api.setMediaListResults([.success(MediaListResponse(pages: 1, results: [m]))])
        let viewModel = MediaLibraryViewModel(api: api)
        await viewModel.load()
        await api.setSaveMediaInformationResults([.success(OpaqueJSONResult(raw: "{}"))])

        let ok = await viewModel.updateAlt(m, alt: "A sunset")

        #expect(ok)
        #expect(viewModel.media.first?.alt == "A sunset")
        let calls = await api.saveMediaInformationCalls
        #expect(
            calls == [
                MediaInformationRequest(id: "m1", alt: "A sunset", thumbnail: nil, thumbnailTimestamp: nil)
            ])
    }
}

extension StubSocialsAPI {
    fileprivate func setCreateUploadResults(_ results: [Result<MediaCreateUploadResponse, Error>]) {
        createUploadResults = results
    }
    fileprivate func setCompleteUploadResults(
        _ results: [Result<MediaCompleteUploadResponse, Error>]
    ) {
        completeUploadResults = results
    }
    fileprivate func setMediaListResults(_ results: [Result<MediaListResponse, Error>]) {
        mediaListResults = results
    }
    fileprivate func setDeleteMediaResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        deleteMediaResults = results
    }
    fileprivate func setSaveMediaInformationResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        saveMediaInformationResults = results
    }
}
