import CuantoUI
import PhotosUI
import SocialsCore
import SwiftUI
import UIKit

/// Composer media tray: pick photos/videos from the library via `PhotosPicker`, upload them
/// through `UploadQueue`, and show per-item progress/failure. Mirrors web's media drop zone in
/// the composer (upload-then-attach flow, docs/MOBILE-API.md § Media upload).
///
/// Each item renders queued -> uploading (determinate progress ring) -> verifying -> ready/failed,
/// with retry/cancel per item and inline aspect-ratio/duration violations — never a generic
/// banner (ios/brand-spec.md § Motion: state colour changes use `SocialsMotion.control`, items
/// appearing/leaving use `SocialsMotion.entrance`).
struct MediaTrayView: View {
    let uploadQueue: UploadQueue
    /// Called with each successfully uploaded item and its locally-probed technical attributes
    /// (`nil` for media picked from the library, which was never local bytes to probe).
    var onUploaded: (MediaDTO, SelectedMediaAttributes?) -> Void = { _, _ in }
    /// Forwards to `ComposerViewModel.attachAIMedia(_:)`: called once an AI-generated result's
    /// "Use this" flight animation (`AIMediaHandoff.swift`) lands in this tray, mirroring
    /// `onUploaded` for regular uploads/library picks.
    var attachAIMedia: (AIMediaResult) -> Void = { _ in }
    /// AI result currently flying into the tray from `AIImageView`/`AIVideoView`, tagged with
    /// `.aiMediaHandoffDestination` so it shares a `matchedGeometryEffect` with the source
    /// thumbnail. `nil` when no handoff is in flight.
    var incomingAIMedia: AIMediaResult?
    /// Namespace shared with the presenting AI sheet; `nil` disables the flight animation (e.g.
    /// previews) and just calls `attachAIMedia` directly.
    var aiHandoffNamespace: Namespace.ID?
    /// Provider identifiers whose media rules apply to whatever draft this tray feeds — one
    /// channel's identifier for a per-channel tab, every selected channel's for the global tab.
    /// Drives the inline violations under each thumbnail; empty means "don't check".
    var providerIdentifiers: [String] = []

    @Environment(\.cuantoTheme) private var theme
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showLibraryPicker = false
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var probedAttributes: [String: SelectedMediaAttributes]
    @ScaledMetric(relativeTo: .footnote) private var thumbnailSize: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var cellWidth: CGFloat = 96
    let mediaLibraryViewModel: MediaLibraryViewModel

    /// Explicit memberwise init: a struct's auto-synthesized one would be `private` here (several
    /// stored properties above are `private`), which would make this uncallable from any other
    /// file — every other composer view constructs this one, so it needs to stay callable.
    init(
        uploadQueue: UploadQueue,
        onUploaded: @escaping (MediaDTO, SelectedMediaAttributes?) -> Void = { _, _ in },
        attachAIMedia: @escaping (AIMediaResult) -> Void = { _ in },
        incomingAIMedia: AIMediaResult? = nil,
        aiHandoffNamespace: Namespace.ID? = nil,
        providerIdentifiers: [String] = [],
        /// Seeds `probedAttributes` for items already sitting in `uploadQueue` at construction
        /// time (keyed by `UploadItem.id`, same key space as `SelectedMediaAttributes.id` for
        /// items seeded via `UploadQueue.seedCompleted`) — otherwise a pre-attached item (test
        /// fixtures, `UploadQueue.seedCompleted`) would show no inline violation text since
        /// `probedAttributes` is normally only populated by this view's own picker flow.
        initialProbedAttributes: [String: SelectedMediaAttributes] = [:],
        mediaLibraryViewModel: MediaLibraryViewModel
    ) {
        self.uploadQueue = uploadQueue
        self.onUploaded = onUploaded
        self.attachAIMedia = attachAIMedia
        self.incomingAIMedia = incomingAIMedia
        self.aiHandoffNamespace = aiHandoffNamespace
        self.providerIdentifiers = providerIdentifiers
        self._probedAttributes = State(initialValue: initialProbedAttributes)
        self.mediaLibraryViewModel = mediaLibraryViewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                PhotosPicker(
                    selection: $pickerSelection,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    Label("Add Photo or Video", systemImage: "photo.badge.plus")
                }
                .accessibilityLabel("Add photo or video")
                .onChange(of: pickerSelection) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    let items = newValue
                    pickerSelection = []
                    Task { await uploadPicked(items) }
                }

                Spacer()

                Button {
                    showLibraryPicker = true
                } label: {
                    Label("Media Library", systemImage: "photo.on.rectangle")
                }
                .accessibilityLabel("Open media library")
            }

            if !uploadQueue.items.isEmpty || incomingAIMedia != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: theme.spacing.sm) {
                        if let incomingAIMedia {
                            aiHandoffThumbnail(incomingAIMedia)
                        }
                        ForEach(uploadQueue.items) { item in
                            uploadItemView(item)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .animation(SocialsMotion.entrance, value: uploadQueue.items.map(\.id))
                }

                violationList
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            MediaLibraryPickerSheet(viewModel: mediaLibraryViewModel, onSelect: { onUploaded($0, nil) })
        }
        .onChange(of: incomingAIMedia) { _, newValue in
            guard let result = newValue else { return }
            attachAIMedia(result)
        }
    }

    @ViewBuilder
    private func aiHandoffThumbnail(_ result: AIMediaResult) -> some View {
        Group {
            if let namespace = aiHandoffNamespace {
                thumbnailImage(result).aiMediaHandoffDestination(result, in: namespace)
            } else {
                thumbnailImage(result)
            }
        }
        .accessibilityLabel(result.name ?? "AI generated media")
    }

    private func thumbnailImage(_ result: AIMediaResult) -> some View {
        AsyncImage(url: URL(string: result.path)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.token(.muted, in: theme)
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
    }

    // MARK: - Per-item cell

    @ViewBuilder
    private func uploadItemView(_ item: UploadItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            ZStack(alignment: .topTrailing) {
                thumbnailBase(for: item)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))

                statusOverlay(for: item)
                    .animation(SocialsMotion.control, value: progressValue(for: item))

                if isCancellable(item.status) {
                    Button {
                        uploadQueue.cancel(item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.token(.cardForeground, in: theme))
                            .background(Color.token(.card, in: theme).clipShape(Circle()))
                    }
                    .accessibilityLabel("Cancel upload of \(item.fileName)")
                    .offset(x: 6, y: -6)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)

            Text(item.fileName)
                .typeRole(.caption)
                .foregroundStyle(Color.token(.mutedForeground, in: theme))
                .lineLimit(1)
                .frame(maxWidth: 96, alignment: .leading)

            if case .failed(let message) = item.status {
                Text(message)
                    .typeRole(.caption)
                    .foregroundStyle(Color.token(.destructive, in: theme))
                    .frame(maxWidth: 96, alignment: .leading)
                    .accessibilityLabel("Failed to upload \(item.fileName): \(message)")

                HStack(spacing: theme.spacing.sm) {
                    Button("Retry") { Task { _ = await uploadQueue.retry(item.id) } }
                        .accessibilityLabel("Retry uploading \(item.fileName)")
                    Button("Remove") { uploadQueue.remove(item.id) }
                        .accessibilityLabel("Remove \(item.fileName)")
                }
                .typeRole(.caption)
                .foregroundStyle(Color.token(.primary, in: theme))
            }
        }
        .frame(width: cellWidth, alignment: .leading)
    }

    @ViewBuilder
    private func thumbnailBase(for item: UploadItem) -> some View {
        if let uiImage = thumbnails[item.id] {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let url = remoteThumbnailURL(for: item) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                kindPlaceholder(for: item)
            }
        } else {
            kindPlaceholder(for: item)
        }
    }

    /// Media that never passed through this view's picker (library picks, `seedCompleted`, AI
    /// results) has no local `UIImage` — its bytes live on the server, so the thumbnail comes from
    /// the completed `MediaDTO`.
    private func remoteThumbnailURL(for item: UploadItem) -> URL? {
        guard case .completed(let media) = item.status else { return nil }
        return URL(string: media.thumbnail ?? media.path)
    }

    /// Fallback glyph while there is no image to show. It follows the item's actual kind — a
    /// blanket `video.fill` labelled every photo in the tray as a video.
    private func kindPlaceholder(for item: UploadItem) -> some View {
        ZStack {
            Color.token(.muted, in: theme)
            Image(systemName: isVideo(item) ? "video.fill" : "photo.fill")
                .foregroundStyle(Color.token(.mutedForeground, in: theme))
        }
    }

    private func isVideo(_ item: UploadItem) -> Bool {
        if let kind = probedAttributes[item.id]?.kind { return kind == .video }
        if let mime = probedAttributes[item.id]?.mimeType { return mime.hasPrefix("video/") }
        let ext = (item.fileName as NSString).pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "webm", "avi"].contains(ext)
    }

    @ViewBuilder
    private func statusOverlay(for item: UploadItem) -> some View {
        switch item.status {
        case .queued:
            Color.token(.background, in: theme).opacity(0.35)
                .accessibilityLabel("Queued to upload \(item.fileName)")
        case .uploading(let progress):
            Circle()
                .trim(from: 0, to: max(progress, 0.03))
                .stroke(Color.token(.primary, in: theme), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(theme.spacing.xs)
                .background(Color.token(.background, in: theme).opacity(0.25))
                .clipShape(Circle())
                .accessibilityLabel("Uploading \(item.fileName), \(Int(progress * 100)) percent")
        case .verifying:
            ProgressView()
                .tint(Color.token(.accent, in: theme))
                .accessibilityLabel("Verifying \(item.fileName)")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.token(.primary, in: theme))
                .accessibilityLabel("Uploaded \(item.fileName)")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.token(.destructive, in: theme))
        }
    }

    private func isCancellable(_ status: UploadItem.Status) -> Bool {
        switch status {
        case .queued, .uploading: return true
        case .verifying, .completed, .failed: return false
        }
    }

    private func progressValue(for item: UploadItem) -> Double {
        if case .uploading(let progress) = item.status { return progress }
        return 0
    }

    /// Technical violations for everything in the tray, listed full-width under the thumbnail row
    /// and naming the file they belong to. They used to render inside each 96pt cell, where
    /// "Instagram needs a 1:1, 4:5 or 1.91:1 crop — this is 16:9." wrapped across four lines.
    @ViewBuilder
    private var violationList: some View {
        let entries = uploadQueue.items.flatMap { item in
            violations(for: item.id).map { (item: item, violation: $0) }
        }
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                ForEach(entries, id: \.violation.id) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        // The offending file is only worth naming when there's more than one
                        // thumbnail to tell apart. The message itself stays its own element so it
                        // reads (and is queryable) verbatim.
                        if uploadQueue.items.count > 1 {
                            Text(entry.item.fileName)
                                .lineLimit(1)
                                .foregroundStyle(Color.token(.mutedForeground, in: theme))
                        }
                        Text(entry.violation.message)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .typeRole(.caption)
                    .foregroundStyle(Color.token(.destructive, in: theme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func violations(for itemId: String) -> [MediaLimitViolation] {
        guard let attributes = probedAttributes[itemId], !providerIdentifiers.isEmpty else { return [] }
        return providerIdentifiers.flatMap { MediaLimits.violations(for: [attributes], providerIdentifier: $0) }
    }

    // MARK: - Upload

    private func uploadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let fileName = item.itemIdentifier ?? "upload-\(UUID().uuidString).jpg"
            let contentType = Self.contentType(for: item, data: data)
            let itemId = UUID().uuidString

            if let uiImage = UIImage(data: data) {
                thumbnails[itemId] = uiImage
            }
            let attributes = await MediaProbe.attributes(id: itemId, data: data, contentType: contentType)
            probedAttributes[itemId] = attributes

            if let media = await uploadQueue.upload(id: itemId, data: data, fileName: fileName, contentType: contentType)
            {
                let finalAttributes = attributes.map {
                    SelectedMediaAttributes(
                        id: media.id, kind: $0.kind, aspectRatio: $0.aspectRatio, durationSeconds: $0.durationSeconds)
                }
                onUploaded(media, finalAttributes)
            }
        }
    }

    private static func contentType(for item: PhotosPickerItem, data: Data) -> String {
        if let utType = item.supportedContentTypes.first, let mime = utType.preferredMIMEType {
            return mime
        }
        return "image/jpeg"
    }
}
