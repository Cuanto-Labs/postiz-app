import SocialsCore
import SwiftUI

/// Legal links: privacy policy and terms of service, both sourced live from `GET
/// /mobile/v1/config` (`ConfigResponse.links`) — never hardcoded, since the URLs are
/// server-configured and can change without an app release. Also links to
/// `OpenSourceNoticesView` for bundled third-party license notices.
struct LegalView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var privacyURL: URL?
    @State private var termsURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Legal") {
                if let privacyURL {
                    Link("Privacy policy", destination: privacyURL)
                        .accessibilityLabel("Privacy policy")
                }
                if let termsURL {
                    Link("Terms of service", destination: termsURL)
                        .accessibilityLabel("Terms of service")
                }
            }

            Section {
                NavigationLink {
                    OpenSourceNoticesView()
                } label: {
                    SettingsRow(icon: "doc.text", title: "Open source notices")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Legal links error")
                }
            }
        }
        .navigationTitle("Legal")
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            guard privacyURL == nil, termsURL == nil else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let config = try await environment.api.config()
                privacyURL = URL(string: config.links.privacy)
                termsURL = URL(string: config.links.terms)
            } catch {
                errorMessage = "Couldn't load legal links. Please try again."
            }
        }
    }
}
