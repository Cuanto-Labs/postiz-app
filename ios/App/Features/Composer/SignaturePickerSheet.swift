import SocialsCore
import SwiftUI

/// Signature picker: pick a saved signature to insert into the current post, or manage the
/// list. Mirrors web's `signatures.component.tsx` — a list of signatures (content preview +
/// auto-add flag) with a "Use Signature" action, plus inline create/edit/delete.
struct SignaturePickerSheet: View {
    let viewModel: SignaturesViewModel
    /// Called with the chosen signature's content when the user taps "Use Signature", mirrors
    /// web's `appendSignature` callback that inserts the content into the composer.
    var onUse: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var newContent = ""
    @State private var newAutoAdd = false
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Signatures") {
                    if viewModel.signatures.isEmpty && !viewModel.isLoading {
                        Text("No signatures yet.")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("No signatures yet")
                    }
                    ForEach(viewModel.signatures, id: \.id) { signature in
                        row(for: signature)
                    }
                }

                Section("Add Signature") {
                    TextField("Signature content", text: $newContent, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("New signature content")
                    Toggle("Auto-add to new posts", isOn: $newAutoAdd)
                        .accessibilityLabel("New signature auto-add")
                    Button("Add Signature") {
                        Task {
                            isAdding = true
                            _ = await viewModel.createSignature(
                                content: newContent, autoAdd: newAutoAdd)
                            isAdding = false
                            newContent = ""
                            newAutoAdd = false
                        }
                    }
                    .disabled(
                        newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isAdding)
                    .accessibilityLabel("Add signature")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Signatures error")
                }
            }
            .navigationTitle("Signatures")
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
    private func row(for signature: SignatureDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(signature.content ?? "")
                .lineLimit(2)
            HStack {
                Text(signature.autoAdd == true ? "Auto-add: Yes" : "Auto-add: No")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Use Signature") {
                    onUse(signature.content ?? "")
                    dismiss()
                }
                .font(.caption)
                .accessibilityLabel("Use this signature")
            }
        }
        .accessibilityLabel("Signature: \(signature.content ?? "")")
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSignature(signature) }
            }
            .accessibilityLabel("Delete signature")
        }
    }
}
