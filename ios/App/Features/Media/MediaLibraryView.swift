import PhotosUI
import SocialsCore
import SwiftUI

/// Media library screen: searchable paginated grid of the org's uploaded media, with upload and
/// delete. Mirrors web's `media.component.tsx` full-screen media manager (search-by-name filter,
/// infinite-scroll pagination, upload button, per-item delete).
struct MediaLibraryView: View {
    let viewModel: MediaLibraryViewModel
    let uploadQueue: UploadQueue

    @State private var searchText = ""
    @State private var pickerSelection: [PhotosPickerItem] = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private var filteredMedia: [MediaDTO] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.media }
        return viewModel.media.filter { item in
            (item.originalName ?? item.name).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            if filteredMedia.isEmpty && !viewModel.isLoading {
                Text(searchText.isEmpty ? "No media yet." : "No media matches your search.")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        searchText.isEmpty ? "No media yet" : "No media matches your search")
                    .padding()
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredMedia, id: \.id) { item in
                    tile(for: item)
                        .onAppear {
                            if item.id == viewModel.media.last?.id {
                                Task { await viewModel.loadNextPageIfNeeded() }
                            }
                        }
                }
            }
            .padding()

            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Loading media")
                    .padding()
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Media library error")
                    .padding(.horizontal)
            }
        }
        .searchable(text: $searchText, prompt: "Search by file name")
        .navigationTitle("Media Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker(
                    selection: $pickerSelection,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Upload media")
                .onChange(of: pickerSelection) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    let items = newValue
                    pickerSelection = []
                    Task { await uploadPicked(items) }
                }
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func tile(for item: MediaDTO) -> some View {
        VStack(spacing: 4) {
            // The tile used to be a flat placeholder for every item, so the library rendered as a
            // grid of identical grey squares no matter what was in it.
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: item.thumbnail ?? item.path)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.originalName ?? item.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .accessibilityLabel("Media: \(item.originalName ?? item.name)")
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteMedia(item) }
            }
            .accessibilityLabel("Delete \(item.originalName ?? item.name)")
        }
    }

    private func uploadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            // Same normalization the composer tray does: the picker hands back asset identifiers
            // and HEIC/QuickTime payloads the backend rejects.
            let picked = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            guard let prepared = await MediaPreparer.prepare(data: data, contentType: picked) else { continue }
            if await uploadQueue.upload(
                data: prepared.data, fileName: prepared.fileName, contentType: prepared.contentType)
                != nil
            {
                await viewModel.load()
            }
        }
    }
}
