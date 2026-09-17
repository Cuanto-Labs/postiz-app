import SocialsCore
import SwiftUI

/// Entry point for the account-deletion flow: shows a preview of which orgs are deleted outright
/// (sole owner) vs merely left (shared, owned by someone else), then hands off to
/// `DeleteAccountConfirmSheet` for the "type DELETE" confirmation. Constructs its view model and
/// a local `PushRegistrationViewModel` per-appearance, mirroring `NotificationPrefsView`'s
/// pattern, so the deletion flow can unregister this device's push token as part of the teardown.
struct DeleteAccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: DeleteAccountViewModel?
    @State private var isPresentingConfirm = false
    @State private var isDeleted = false

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Delete account")
        .task {
            if viewModel == nil {
                let pushRegistration = PushRegistrationViewModel(api: environment.api)
                let viewModel = DeleteAccountViewModel(
                    api: environment.api, sessionStore: environment.sessionStore,
                    pushRegistration: pushRegistration)
                self.viewModel = viewModel
                await viewModel.loadPreview()
            }
        }
        .sheet(isPresented: $isPresentingConfirm) {
            if let viewModel {
                DeleteAccountConfirmSheet(viewModel: viewModel) {
                    isPresentingConfirm = false
                    isDeleted = true
                }
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: DeleteAccountViewModel) -> some View {
        if isDeleted {
            ContentUnavailableView(
                "Account deleted", systemImage: "checkmark.circle",
                description: Text("Your account and data have been permanently deleted."))
        } else {
            List {
                if let preview = viewModel.preview {
                    if !preview.orgsToDelete.isEmpty {
                        Section("Deleted permanently") {
                            ForEach(preview.orgsToDelete, id: \.id) { org in
                                Text(org.name)
                                    .accessibilityLabel("\(org.name), deleted permanently")
                            }
                        }
                    }
                    if !preview.orgsToLeave.isEmpty {
                        Section("You'll leave these") {
                            ForEach(preview.orgsToLeave, id: \.id) { org in
                                Text(org.name)
                                    .accessibilityLabel("\(org.name), you'll leave this organization")
                            }
                        }
                    }
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
                    Text(
                        "Any active subscription is cancelled at the end of the current billing period. Your data is deleted immediately and can't be recovered."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        isPresentingConfirm = true
                    } label: {
                        Text("Delete account")
                    }
                    .accessibilityLabel("Delete account")
                }
            }
            .overlay {
                if viewModel.isLoadingPreview {
                    ProgressView()
                }
            }
        }
    }
}
