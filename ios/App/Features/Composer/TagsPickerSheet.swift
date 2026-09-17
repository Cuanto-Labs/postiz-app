import SocialsCore
import SwiftUI

/// Tag picker: pick tags for the current post, create new tags inline, or delete unused ones.
/// Mirrors web's `tags.component.tsx` — a checklist of the org's tags plus an "Add New Tag" form
/// (name + color, default `#942828`) and inline delete on unselected rows.
struct TagsPickerSheet: View {
    let viewModel: TagsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var newTagName = ""
    @State private var newTagColor = "#942828"
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Tags") {
                    if viewModel.tags.isEmpty && !viewModel.isLoading {
                        Text("No tags yet.")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("No tags yet")
                    }
                    ForEach(viewModel.tags, id: \.id) { tag in
                        row(for: tag)
                    }
                }

                Section("Add Tag") {
                    TextField("Tag name", text: $newTagName)
                        .accessibilityLabel("New tag name")
                    TextField("Color (hex)", text: $newTagColor)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("New tag color")
                    Button("Add Tag") {
                        Task {
                            isAdding = true
                            _ = await viewModel.createTag(name: newTagName, color: newTagColor)
                            isAdding = false
                            newTagName = ""
                        }
                    }
                    .disabled(
                        newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isAdding)
                    .accessibilityLabel("Add tag")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Tags error")
                }
            }
            .navigationTitle("Tags")
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
    private func row(for tag: TagDTO) -> some View {
        Button {
            viewModel.toggleSelection(tag)
        } label: {
            HStack {
                Circle()
                    .fill(Self.color(fromHex: tag.color))
                    .frame(width: 12, height: 12)
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.isSelected(tag) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityLabel("\(tag.name)\(viewModel.isSelected(tag) ? ", selected" : "")")
        .accessibilityAddTraits(viewModel.isSelected(tag) ? [.isSelected] : [])
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteTag(tag) }
            }
            .accessibilityLabel("Delete \(tag.name)")
        }
    }

    private static func color(fromHex hex: String) -> Color {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.hasPrefix("#") ? String(sanitized.dropFirst()) : sanitized
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            return .gray
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
