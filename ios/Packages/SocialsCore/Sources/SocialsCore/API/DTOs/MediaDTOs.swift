import Foundation

// MARK: - Media

/// Superset of the media shapes returned by `GET /mobile/v1/media` (`id, name, originalName,
/// path, thumbnail, alt, thumbnailTimestamp`) and `POST /mobile/v1/media/uploads/complete`
/// (`id, name, path, status, processingError, thumbnail`) — docs/MOBILE-API.md. Every field
/// beyond `id`/`name`/`path` is optional so either shape decodes.
public struct MediaDTO: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let originalName: String?
    public let path: String
    public let thumbnail: String?
    public let alt: String?
    public let thumbnailTimestamp: Int?
    public let status: String?
    public let processingError: String?

    public init(
        id: String, name: String, originalName: String?, path: String, thumbnail: String?,
        alt: String?, thumbnailTimestamp: Int?, status: String?, processingError: String?
    ) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.path = path
        self.thumbnail = thumbnail
        self.alt = alt
        self.thumbnailTimestamp = thumbnailTimestamp
        self.status = status
        self.processingError = processingError
    }
}

/// `GET /mobile/v1/media?page=` response (docs/MOBILE-API.md: 18 per page, excludes
/// `processing` media).
public struct MediaListResponse: Sendable, Codable, Equatable {
    public let pages: Int
    public let results: [MediaDTO]

    public init(pages: Int, results: [MediaDTO]) {
        self.pages = pages
        self.results = results
    }
}

/// `POST /mobile/v1/media/information` body (`SaveMediaInformationDto`).
public struct MediaInformationRequest: Sendable, Codable, Equatable {
    public let id: String
    public let alt: String
    public let thumbnail: String?
    public let thumbnailTimestamp: Int?

    public init(id: String, alt: String, thumbnail: String?, thumbnailTimestamp: Int?) {
        self.id = id
        self.alt = alt
        self.thumbnail = thumbnail
        self.thumbnailTimestamp = thumbnailTimestamp
    }
}

// MARK: - Media upload (docs/MOBILE-API.md § Media upload)

/// `POST /mobile/v1/media/uploads` body (`MobileMediaCreateUploadDto`).
public struct MediaCreateUploadRequest: Sendable, Codable, Equatable {
    public let fileName: String
    public let contentType: String
    public let size: Int

    public init(fileName: String, contentType: String, size: Int) {
        self.fileName = fileName
        self.contentType = contentType
        self.size = size
    }
}

/// One presigned multipart-upload part on `MediaCreateUploadResponse`.
public struct MediaUploadPart: Sendable, Codable, Equatable {
    public let partNumber: Int
    public let url: String

    public init(partNumber: Int, url: String) {
        self.partNumber = partNumber
        self.url = url
    }
}

/// `POST /mobile/v1/media/uploads` response (`CreateUploadResult`).
public struct MediaCreateUploadResponse: Sendable, Codable, Equatable {
    public let uploadId: String
    public let key: String
    public let partSize: Int
    public let parts: [MediaUploadPart]
    public let expiresAt: String

    public init(
        uploadId: String, key: String, partSize: Int, parts: [MediaUploadPart], expiresAt: String
    ) {
        self.uploadId = uploadId
        self.key = key
        self.partSize = partSize
        self.parts = parts
        self.expiresAt = expiresAt
    }
}

/// One completed part (`partNumber` + the `ETag` captured from the presigned `PUT`) on
/// `MediaCompleteUploadRequest`.
public struct MediaCompleteUploadPart: Sendable, Codable, Equatable {
    public let partNumber: Int
    public let etag: String

    public init(partNumber: Int, etag: String) {
        self.partNumber = partNumber
        self.etag = etag
    }
}

/// `POST /mobile/v1/media/uploads/complete` body (`MobileMediaCompleteUploadDto`).
public struct MediaCompleteUploadRequest: Sendable, Codable, Equatable {
    public let key: String
    public let uploadId: String
    public let parts: [MediaCompleteUploadPart]
    public let originalName: String?

    public init(
        key: String, uploadId: String, parts: [MediaCompleteUploadPart], originalName: String?
    ) {
        self.key = key
        self.uploadId = uploadId
        self.parts = parts
        self.originalName = originalName
    }
}

/// `POST /mobile/v1/media/uploads/complete` response.
public struct MediaCompleteUploadResponse: Sendable, Codable, Equatable {
    public let media: MediaDTO

    public init(media: MediaDTO) {
        self.media = media
    }
}
