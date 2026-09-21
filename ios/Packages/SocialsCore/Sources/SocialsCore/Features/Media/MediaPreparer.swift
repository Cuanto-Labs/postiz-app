import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One picked file, in a shape the backend actually accepts.
public struct PreparedMedia: Equatable, Sendable {
    public let data: Data
    public let fileName: String
    public let contentType: String

    public init(data: Data, fileName: String, contentType: String) {
        self.data = data
        self.fileName = fileName
        self.contentType = contentType
    }
}

/// Normalizes what `PhotosPicker` hands back into what `/mobile/v1/media/uploads` accepts.
///
/// Two things the picker gets wrong on its own:
///
/// * `PhotosPickerItem.itemIdentifier` is a PHAsset identifier (`…/L0/001`) — no extension and
///   with slashes in it. The backend derives the storage extension from the file name, so an
///   identifier is rejected outright as an unsupported file type.
/// * The camera writes HEIC stills and QuickTime video. Neither is in the backend's allow-list
///   (and no social network takes them), so they have to be re-encoded before upload.
public enum MediaPreparer {
    /// Mirrors the backend's allow-list (`mobile-media-upload.service.ts`).
    static let extensionsByMime: [String: String] = [
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/gif": "gif",
        "image/webp": "webp",
        "image/avif": "avif",
        "video/mp4": "mp4",
    ]

    public static func isSupported(contentType: String) -> Bool {
        extensionsByMime[contentType.lowercased()] != nil
    }

    /// Returns bytes/name/type ready to hand to ``UploadQueue``, re-encoding when needed.
    /// `nil` means the file cannot be made acceptable (unreadable image, failed export).
    public static func prepare(data: Data, contentType: String) async -> PreparedMedia? {
        let mime = contentType.lowercased()

        if let ext = extensionsByMime[mime] {
            return PreparedMedia(data: data, fileName: name(ext: ext), contentType: mime)
        }

        if mime.hasPrefix("video/") {
            guard let mp4 = await transcodeToMP4(data: data, contentType: mime) else { return nil }
            return PreparedMedia(data: mp4, fileName: name(ext: "mp4"), contentType: "video/mp4")
        }

        guard let jpeg = encodeAsJPEG(data: data) else { return nil }
        return PreparedMedia(data: jpeg, fileName: name(ext: "jpg"), contentType: "image/jpeg")
    }

    /// The backend generates its own storage key; this name only has to carry a usable extension
    /// and survive being echoed back as `originalName`.
    static func name(ext: String) -> String {
        "media-\(UUID().uuidString).\(ext)"
    }

    static func encodeAsJPEG(data: Data, quality: Double = 0.9) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }

        // Keep the orientation the camera recorded; dropping it rotates every portrait photo.
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        if let source = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let orientation = source[kCGImagePropertyOrientation]
        {
            properties[kCGImagePropertyOrientation] = orientation
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func transcodeToMP4(data: Data, contentType: String) async -> Data? {
        let sourceExt = contentType.split(separator: "/").last.map(String.init) ?? "mov"
        let directory = FileManager.default.temporaryDirectory
        let input = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(sourceExt)
        let output = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")

        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }

        do {
            try data.write(to: input)
            let asset = AVURLAsset(url: input)
            guard
                let session = AVAssetExportSession(
                    asset: asset, presetName: AVAssetExportPresetHighestQuality)
            else { return nil }

            try await session.export(to: output, as: .mp4)
            return try Data(contentsOf: output)
        } catch {
            return nil
        }
    }
}
