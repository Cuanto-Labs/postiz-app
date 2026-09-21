import SocialsCore
import SwiftUI

/// Media library picker: browse the org's uploaded media, pick one to attach to the post, edit
/// alt text, or delete unused files. Mirrors web's media library modal (`media.component.tsx`) —
/// a paged grid with delete + alt-text edit and a "Select" action.
struct MediaLibraryPickerSheet: View {
    let viewModel: MediaLibraryViewModel
    /// Called with the chosen media item when the user taps "Select", mirrors web's
    /// "attach existing media" callback.
    var onSelect: (MediaDTO) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var editingAlt: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section("Media") {
                    if viewModel.media.isEmpty && !viewModel.isLoading {
                        Text("No media yet.")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("No media yet")
                    }
                    ForEach(viewModel.media, id: \.id) { item in
                        row(for: item)
                            .onAppear {
                                if item.id == viewModel.media.last?.id {
                                    Task { await viewModel.loadNextPageIfNeeded() }
                                }
                            }
                    }
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Media library error")
                }
            }
            .navigationTitle("Media Library")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                }
            }
            .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func row(for item: MediaDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.originalName ?? item.name)
                .lineLimit(1)
            TextField(
                "Alt text",
                text: Binding(
                    get: { editingAlt[item.id] ?? item.alt ?? "" },
                    set: { editingAlt[item.id] = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .accessibilityLabel("Alt text for \(item.originalName ?? item.name)")
            .onSubmit {
                Task { await viewModel.updateAlt(item, alt: editingAlt[item.id] ?? "") }
            }

            HStack {
                Spacer()
                Button("Select") {
                    onSelect(item)
                    dismiss()
                }
                .font(.caption)
                .accessibilityLabel("Select \(item.originalName ?? item.name)")
            }
        }
        .accessibilityLabel("Media: \(item.originalName ?? item.name)")
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteMedia(item) }
            }
            .accessibilityLabel("Delete \(item.originalName ?? item.name)")
        }
    }
}
