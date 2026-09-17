import PhotosUI
import SocialsCore
import SwiftUI

/// Composer media tray: pick photos/videos from the library via `PhotosPicker`, upload them
/// through `UploadQueue`, and show per-item progress/failure. Mirrors web's media drop zone in
/// the composer (upload-then-attach flow, docs/MOBILE-API.md § Media upload).
struct MediaTrayView: View {
    let uploadQueue: UploadQueue
    /// Called with each successfully uploaded item, mirrors web's "attach uploaded media to the
    /// post" callback.
    var onUploaded: (MediaDTO) -> Void = { _ in }

    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showLibraryPicker = false
    let mediaLibraryViewModel: MediaLibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if !uploadQueue.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(uploadQueue.items) { item in
                            uploadItemView(item)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            MediaLibraryPickerSheet(viewModel: mediaLibraryViewModel, onSelect: onUploaded)
        }
    }

    @ViewBuilder
    private func uploadItemView(_ item: UploadItem) -> some View {
        VStack(spacing: 4) {
            switch item.status {
            case .uploading:
                ProgressView()
                    .accessibilityLabel("Uploading \(item.fileName)")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Uploaded \(item.fileName)")
            case .failed(let message):
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Button("Remove") { uploadQueue.remove(item.id) }
                        .font(.caption2)
                }
                .accessibilityLabel("Failed to upload \(item.fileName): \(message)")
            }
            Text(item.fileName)
                .font(.caption2)
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
    }

    private func uploadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let fileName = item.itemIdentifier ?? "upload-\(UUID().uuidString).jpg"
            let contentType = Self.contentType(for: item, data: data)
            if let media = await uploadQueue.upload(
                data: data, fileName: fileName, contentType: contentType)
            {
                onUploaded(media)
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
