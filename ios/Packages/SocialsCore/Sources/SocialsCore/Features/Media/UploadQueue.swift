import Foundation
import Observation

/// PUTs one presigned multipart-upload part and returns the response's `ETag` header, mirrors
/// web's direct-to-R2 XHR uploader (docs/MOBILE-API.md § Media upload, step 2). Abstracted behind
/// a protocol so tests can script part uploads without a real network call.
public protocol PartUploader: Sendable {
    func putPart(_ data: Data, to url: URL) async throws -> String
}

/// Default `PartUploader` backed by `URLSession` — presigned R2 URLs carry their own auth in the
/// query string, so these PUTs never go through `SocialsAPI`/`LiveSocialsAPI`.
public struct URLSessionPartUploader: PartUploader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func putPart(_ data: Data, to url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        let (_, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UploadQueueError.partUploadFailed
        }
        guard let etag = http.value(forHTTPHeaderField: "ETag") ?? http.value(forHTTPHeaderField: "Etag")
        else {
            throw UploadQueueError.missingETag
        }
        return etag
    }
}

public enum UploadQueueError: Error, Equatable {
    case partUploadFailed
    case missingETag
}

/// One tracked upload, from the moment media is picked until it completes or fails.
public struct UploadItem: Sendable, Identifiable, Equatable {
    public enum Status: Sendable, Equatable {
        /// Picked, waiting for a prior item (or a retry) to start its request.
        case queued
        /// Part `N`/`M` in flight; `progress` is the fraction of parts PUT so far (0...1).
        case uploading(progress: Double)
        /// All parts uploaded, waiting on `completeUpload` to hand back the ready `MediaDTO`.
        case verifying
        case completed(MediaDTO)
        case failed(String)

        /// Terminal states are safe to drop from the tray; in-flight ones are not.
        var isTerminal: Bool {
            switch self {
            case .completed, .failed: return true
            case .queued, .uploading, .verifying: return false
            }
        }
    }

    public let id: String
    public var fileName: String
    public var status: Status

    public init(id: String = UUID().uuidString, fileName: String, status: Status = .queued) {
        self.id = id
        self.fileName = fileName
        self.status = status
    }
}

/// Drives the presigned multipart upload flow (docs/MOBILE-API.md § Media upload):
/// `createUpload` for presigned part URLs, `PUT` every part capturing its `ETag`, then
/// `completeUpload` to finish and get back the ready `MediaDTO`. Tracks in-flight/finished
/// uploads so the composer's media tray can render progress.
@MainActor
@Observable
public final class UploadQueue {
    public private(set) var items: [UploadItem] = []

    /// Original bytes for each tracked item, kept only until it reaches a terminal state, so
    /// `retry(_:)` can resubmit the exact same file without the caller re-picking it.
    private var pending: [String: (data: Data, fileName: String, contentType: String)] = [:]
    /// The in-flight request `Task` per item, so `cancel(_:)` can interrupt a real upload rather
    /// than just relabeling its status.
    private var tasks: [String: Task<MediaDTO?, Never>] = [:]

    private let api: any SocialsAPI
    private let partUploader: any PartUploader

    public init(api: any SocialsAPI, partUploader: any PartUploader = URLSessionPartUploader()) {
        self.api = api
        self.partUploader = partUploader
    }

    /// Uploads `data` end-to-end, tracking an `UploadItem` for the caller's tray UI. Returns the
    /// finished `MediaDTO` on success, `nil` on failure/cancellation (see `errorMessage(for:)`).
    /// `id` lets a caller pre-generate the item's id (e.g. to tag a local media probe result
    /// before the upload finishes) — defaults to a fresh one, same as before this parameter existed.
    @discardableResult
    public func upload(id: String = UUID().uuidString, data: Data, fileName: String, contentType: String) async
        -> MediaDTO?
    {
        let itemId = id
        items.append(UploadItem(id: itemId, fileName: fileName, status: .queued))
        pending[itemId] = (data, fileName, contentType)
        return await run(itemId)
    }

    /// Resubmits a failed (or cancelled) item using its original bytes. No-op if the item was
    /// already dropped from the tray (`remove(_:)`) or never existed.
    @discardableResult
    public func retry(_ id: String) async -> MediaDTO? {
        guard pending[id] != nil else { return nil }
        update(id, .queued)
        return await run(id)
    }

    /// Interrupts an in-flight upload and marks it failed with a "Cancelled" reason. Safe to call
    /// on an item that already finished — it's just a no-op then.
    public func cancel(_ id: String) {
        tasks[id]?.cancel()
    }

    /// Drops a finished (completed or failed) item from the tray, e.g. once the user dismisses
    /// its failure banner or it's been attached to the post. In-flight items are never removed.
    public func remove(_ id: String) {
        items.removeAll { $0.id == id && $0.status.isTerminal }
        pending[id] = nil
        tasks[id] = nil
    }

    private func run(_ itemId: String) async -> MediaDTO? {
        guard let file = pending[itemId] else { return nil }
        let task = Task<MediaDTO?, Never> { [weak self] in
            await self?.performUpload(itemId, data: file.data, fileName: file.fileName, contentType: file.contentType)
        }
        tasks[itemId] = task
        let result = await task.value
        tasks[itemId] = nil
        return result
    }

    private func performUpload(_ itemId: String, data: Data, fileName: String, contentType: String) async -> MediaDTO?
    {
        update(itemId, .uploading(progress: 0))
        do {
            try Task.checkCancellation()
            let created = try await api.createUpload(
                MediaCreateUploadRequest(fileName: fileName, contentType: contentType, size: data.count))
            var completedParts: [MediaCompleteUploadPart] = []
            let totalParts = max(created.parts.count, 1)
            for part in created.parts {
                try Task.checkCancellation()
                let start = (part.partNumber - 1) * created.partSize
                guard start < data.count else { continue }
                let end = min(start + created.partSize, data.count)
                let chunk = data.subdata(in: start..<end)
                guard let url = URL(string: part.url) else {
                    throw UploadQueueError.partUploadFailed
                }
                let etag = try await partUploader.putPart(chunk, to: url)
                completedParts.append(MediaCompleteUploadPart(partNumber: part.partNumber, etag: etag))
                update(itemId, .uploading(progress: Double(completedParts.count) / Double(totalParts)))
            }
            try Task.checkCancellation()
            update(itemId, .verifying)
            let completed = try await api.completeUpload(
                MediaCompleteUploadRequest(
                    key: created.key, uploadId: created.uploadId, parts: completedParts,
                    originalName: fileName))
            update(itemId, .completed(completed.media))
            pending[itemId] = nil
            return completed.media
        } catch is CancellationError {
            update(itemId, .failed("Cancelled."))
            return nil
        } catch let error as SocialsAPIError {
            update(itemId, .failed(Self.message(for: error)))
            return nil
        } catch {
            update(itemId, .failed("Upload failed. Please try again."))
            return nil
        }
    }

    private func update(_ id: String, _ status: UploadItem.Status) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your file and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .cancelled: return ""
        default: return "Upload failed. Please try again."
        }
    }
}
