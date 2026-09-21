import SocialsCore
import SwiftUI

/// Org settings: shortlink preference picker + read-only webhooks list. Owns one
/// `OrgSettingsViewModel`, wired to the app's real `SocialsAPI` from `AppEnvironment`. Mirrors
/// web's `shortlink-preference.component.tsx` (picker, saved on change) + `webhooks.tsx` (list).
struct OrgSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: OrgSettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Org Settings")
        .task {
            if viewModel == nil {
                let viewModel = OrgSettingsViewModel(api: environment.api)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: OrgSettingsViewModel) -> some View {
        List {
            Section("Shortlink") {
                Picker(
                    "Shortlink preference",
                    selection: Binding(
                        get: { viewModel.shortlink ?? .ask },
                        set: { newValue in
                            Task { await viewModel.setShortlink(newValue) }
                        })
                ) {
                    Text("Ask each time").tag(ShortlinkPreference.ask)
                    Text("Always shorten").tag(ShortlinkPreference.yes)
                    Text("Never shorten").tag(ShortlinkPreference.no)
                }
                .accessibilityLabel("Shortlink preference")
            }

            Section("Webhooks") {
                WebhooksListView(webhooks: viewModel.webhooks)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Org settings error")
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.webhooks.isEmpty && viewModel.shortlink == nil {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
}
