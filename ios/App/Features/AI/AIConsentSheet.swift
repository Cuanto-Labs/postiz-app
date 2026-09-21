import SocialsCore
import SwiftUI

/// AI consent gate — presented automatically whenever an AI call throws
/// `SocialsAPIError.aiConsentRequired`. Explains in plain language what is sent to the AI
/// provider, links to the current privacy policy (from `SocialsAPI.config()`, same source
/// `AddProviderSheet` uses), and grants/revokes consent through `AIConsentViewModel`.
struct AIConsentSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let viewModel: AIConsentViewModel

    @State private var privacyURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "When you use AI features, your post content is sent to our AI provider to generate suggestions, images, or video. It isn't used to train the provider's models."
                    )
                    .accessibilityLabel("What we send to the AI provider")

                    if let privacyURL {
                        Link("Privacy policy", destination: privacyURL)
                            .accessibilityLabel("Read our privacy policy")
                    }
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("AI consent error")
                    }
                }

                Section {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.isGranted {
                        Button("Revoke AI consent", role: .destructive) {
                            Task { await viewModel.revoke() }
                        }
                        .accessibilityLabel("Revoke AI consent")
                    } else {
                        Button("Allow AI features") {
                            Task {
                                await viewModel.grant()
                                if viewModel.isGranted {
                                    dismiss()
                                }
                            }
                        }
                        .accessibilityLabel("Allow AI features")
                    }
                }
            }
            .navigationTitle("AI features")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
            }
            .task {
                await viewModel.load()
                if let config = try? await environment.api.config() {
                    privacyURL = URL(string: config.links.privacy)
                }
            }
        }
    }
}
