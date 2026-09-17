import SocialsCore
import SwiftUI

/// The Share extension's composer sheet. Deliberately minimal — no channel picker, no upload
/// progress — it only lets the person add a caption and hands everything to
/// `ShareComposerViewModel.submit()`, which always saves to the App Group inbox for the host
/// app to finish, signed in or not.
struct ShareComposerView: View {
    @Bindable var viewModel: ShareComposerViewModel
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.signedOutMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Signed out notice")
                    }
                }

                Section("Caption") {
                    TextField("Say something about this…", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityLabel("Caption")
                }

                if !viewModel.incomingURLs.isEmpty {
                    Section("Links") {
                        ForEach(viewModel.incomingURLs, id: \.self) { url in
                            Text(url)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .accessibilityLabel("Incoming links")
                }

                if !viewModel.incomingAttachmentFilenames.isEmpty {
                    Section("Attachments") {
                        ForEach(viewModel.incomingAttachmentFilenames, id: \.self) { name in
                            Text(name)
                        }
                    }
                    .accessibilityLabel("Incoming attachments")
                }

                switch viewModel.submitState {
                case .idle:
                    EmptyView()
                case .saved:
                    Section {
                        Label("Saved. Open Cuanto Socials to finish posting.", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                case .failed(let message):
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Share to Cuanto Socials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                        .accessibilityLabel("Cancel share")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.submit()
                        if viewModel.submitState == .saved {
                            onDone()
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                    .accessibilityLabel("Save shared post")
                }
            }
            .task {
                await viewModel.refreshSignInState()
            }
        }
    }
}
