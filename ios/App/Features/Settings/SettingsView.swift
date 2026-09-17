import SocialsCore
import SwiftUI

/// Root settings screen: header with the signed-in user/org (from `SettingsViewModel`), grouped
/// links to every sub-screen, AI consent + analytics opt-out toggles, sign out, and app version.
/// Mirrors the web `global.settings.tsx` tab order (Profile, Team, Webhooks, Email notifications,
/// Shortlink, Delete account) as grouped `List` sections. Webhooks live under Organization
/// (`OrgSettingsView` already links to `WebhooksListView`), matching that screen's existing
/// nesting rather than duplicating a top-level row here.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SettingsViewModel?
    @State private var aiConsentViewModel: AIConsentViewModel?
    @State private var isSigningOut = false

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Settings")
        .task {
            if viewModel == nil {
                let viewModel = SettingsViewModel(
                    api: environment.api, sessionStore: environment.sessionStore)
                self.viewModel = viewModel
                let aiConsentViewModel = AIConsentViewModel(api: environment.api)
                self.aiConsentViewModel = aiConsentViewModel
                await viewModel.load()
                await aiConsentViewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: SettingsViewModel) -> some View {
        @Bindable var analyticsOptOutStore: AnalyticsOptOutStore = environment.analyticsOptOutStore
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.user?.name ?? viewModel.user?.email ?? "—")
                        .font(.headline)
                    if let email = viewModel.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let orgName = viewModel.org?.name {
                        Text(orgName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Signed in as \(viewModel.user?.name ?? viewModel.user?.email ?? "")")
            }

            Section("Profile") {
                NavigationLink {
                    AccountDetailsView()
                } label: {
                    SettingsRow(icon: "person.crop.circle", title: "Account details")
                }
            }

            Section("Organization") {
                NavigationLink {
                    OrgSettingsView()
                } label: {
                    SettingsRow(icon: "building.2", title: "Organization")
                }
                NavigationLink {
                    TeamView()
                } label: {
                    SettingsRow(icon: "person.3", title: "Team")
                }
            }

            Section("Devices & notifications") {
                NavigationLink {
                    DevicesView()
                } label: {
                    SettingsRow(icon: "iphone", title: "Devices")
                }
                NavigationLink {
                    NotificationPrefsView()
                } label: {
                    SettingsRow(icon: "bell", title: "Notifications")
                }
            }

            Section("About") {
                NavigationLink {
                    LegalView()
                } label: {
                    SettingsRow(icon: "doc.text.magnifyingglass", title: "Legal")
                }
            }

            Section("Privacy") {
                if let aiConsentViewModel {
                    Toggle(
                        "AI features",
                        isOn: Binding(
                            get: { aiConsentViewModel.isGranted },
                            set: { newValue in
                                Task {
                                    if newValue {
                                        await aiConsentViewModel.grant()
                                    } else {
                                        await aiConsentViewModel.revoke()
                                    }
                                }
                            }
                        )
                    )
                    .disabled(aiConsentViewModel.isSaving)
                    .accessibilityLabel("AI features")
                    if let errorMessage = aiConsentViewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("AI consent error")
                    }
                }

                Toggle(
                    "Opt out of analytics",
                    isOn: Binding(
                        get: { analyticsOptOutStore.isOptedOut },
                        set: { newValue in analyticsOptOutStore.setOptedOut(newValue) }
                    )
                )
                .accessibilityLabel("Opt out of analytics")
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        isSigningOut = true
                        await viewModel.signOut()
                        isSigningOut = false
                    }
                } label: {
                    if isSigningOut || viewModel.isSigningOut {
                        ProgressView()
                    } else {
                        Text("Sign out")
                    }
                }
                .disabled(isSigningOut || viewModel.isSigningOut)
                .accessibilityLabel("Sign out")

                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("Delete account")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Delete account")
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Settings error")
                }
            }

            Section {
                // ViewThatFits: side-by-side at normal text sizes, stacked at large Dynamic Type
                // so the version string never truncates/clips against the row's fixed width.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version")
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("App version \(viewModel.appVersion)")
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        // The floating tab bar overlays the bottom of the screen rather than reserving its own
        // safe-area space, so the last `List` section (Privacy/App version) clips underneath it
        // without this — mirrors `ComposerView`'s bottom action bar in reserving explicit space
        // instead of relying on the system safe area.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 49)
        }
    }
}
