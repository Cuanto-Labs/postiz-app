import SocialsCore
import SwiftUI

/// Provider picker sheet for connecting a new channel. Loads the connectable provider list from
/// `SocialsAPI.config()` (same source `OnboardingViewModel` uses) and starts the OAuth flow via
/// the given `ChannelsViewModel` on selection.
struct AddProviderSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let channelsViewModel: ChannelsViewModel

    @State private var providers: [ConfigProvider] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Couldn't load providers")
                } else {
                    List(providers, id: \.identifier) { provider in
                        Button {
                            Task {
                                await channelsViewModel.connect(provider: provider.identifier)
                                dismiss()
                            }
                        } label: {
                            Text(provider.name)
                        }
                        .accessibilityLabel("Connect \(provider.name)")
                    }
                }
            }
            .navigationTitle("Add a channel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
            }
            .task {
                guard providers.isEmpty else { return }
                await loadProviders()
            }
        }
    }

    private func loadProviders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let config = try await environment.api.config()
            providers = config.providers
        } catch {
            errorMessage = "Couldn't load channels. Please try again."
        }
    }
}
