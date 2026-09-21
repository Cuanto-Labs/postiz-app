import AVFoundation
import Foundation
import ImageIO

/// Probes a locally-picked file's dimensions/duration into a ``SelectedMediaAttributes`` for the
/// media-constraints checks (``MediaLimits``) — the only place this data can come from, since
/// `MediaDTO` (the server's upload response) carries neither. Runs against the raw bytes the
/// picker already loaded, before/independent of the upload itself.
public enum MediaProbe {
    /// `id` is a caller-supplied placeholder (e.g. the in-flight `UploadItem.id`); callers should
    /// re-tag the result with the real `MediaDTO.id` once upload completes, so violations key off
    /// the same id the composer's media list uses.
    public static func attributes(id: String, data: Data, contentType: String) async -> SelectedMediaAttributes? {
        if contentType.hasPrefix("video/") {
            return await videoAttributes(id: id, data: data, contentType: contentType)
        }
        return imageAttributes(id: id, data: data, contentType: contentType)
    }

    private static func imageAttributes(id: String, data: Data, contentType: String) -> SelectedMediaAttributes? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double, width > 0, height > 0
        else {
            return SelectedMediaAttributes(
                id: id, kind: .image, aspectRatio: nil, durationSeconds: nil,
                byteCount: data.count, mimeType: contentType)
        }
        return SelectedMediaAttributes(
            id: id, kind: .image, aspectRatio: MediaAspectRatio(width: width, height: height),
            durationSeconds: nil, byteCount: data.count, mimeType: contentType)
    }

    private static func videoAttributes(id: String, data: Data, contentType: String) async -> SelectedMediaAttributes?
    {
        let ext = contentType.split(separator: "/").last.map(String.init) ?? "mp4"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return SelectedMediaAttributes(
                    id: id, kind: .video, aspectRatio: nil, durationSeconds: duration,
                    byteCount: data.count, mimeType: contentType)
            }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformed = size.applying(transform)
            let width = abs(transformed.width)
            let height = abs(transformed.height)
            guard width > 0, height > 0 else {
                return SelectedMediaAttributes(
                    id: id, kind: .video, aspectRatio: nil, durationSeconds: duration,
                    byteCount: data.count, mimeType: contentType)
            }
            return SelectedMediaAttributes(
                id: id, kind: .video, aspectRatio: MediaAspectRatio(width: width, height: height),
                durationSeconds: duration, byteCount: data.count, mimeType: contentType)
        } catch {
            return SelectedMediaAttributes(
                id: id, kind: .video, aspectRatio: nil, durationSeconds: nil,
                byteCount: data.count, mimeType: contentType)
        }
    }
}
