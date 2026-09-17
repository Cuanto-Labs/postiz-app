import SocialsCore
import SwiftUI

/// Second, explicit confirmation step for account deletion: the user must type "DELETE" before
/// the destructive button enables. Presented as a sheet from `DeleteAccountView`.
struct DeleteAccountConfirmSheet: View {
    @Bindable var viewModel: DeleteAccountViewModel
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "This permanently deletes your account and all its data. Any active subscription is cancelled at the end of the current billing period, but your data is deleted immediately. This can't be undone."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section("Type DELETE to confirm") {
                    TextField("DELETE", text: $viewModel.confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Type DELETE to confirm account deletion")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Delete account error")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.delete()
                            if viewModel.phase == .deleted {
                                onDeleted()
                            }
                        }
                    } label: {
                        if viewModel.phase == .deleting {
                            ProgressView()
                        } else {
                            Text("Permanently delete my account")
                        }
                    }
                    .disabled(!viewModel.canDelete || viewModel.phase == .deleting)
                    .accessibilityLabel("Permanently delete my account")
                }
            }
            .navigationTitle("Confirm deletion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.phase == .deleting)
                        .accessibilityLabel("Cancel account deletion")
                }
            }
        }
    }
}
