import SocialsCore
import SwiftUI

/// Intro panels + a "pick your first channel" step. Owns one `OnboardingViewModel`, wired to
/// the app's real `SocialsAPI` from `AppEnvironment`. Mirrors `RegisterView`'s structure.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: OnboardingViewModel?

    /// Called when the user taps "Get started" on the last panel. `RootView` persists that
    /// onboarding is done and swaps to the signed-in home.
    var onFinish: () -> Void = {}

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = OnboardingViewModel(api: environment.api)
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: OnboardingViewModel) -> some View {
        VStack(spacing: 20) {
            Spacer()

            switch viewModel.panel {
            case .welcome:
                panel(
                    title: "Welcome to Postiz",
                    subtitle: "Plan and publish posts across every channel from one place.")
            case .schedule:
                panel(
                    title: "Schedule ahead",
                    subtitle: "Drop posts on the calendar and they go out at the right time.")
            case .analytics:
                panel(
                    title: "Track performance",
                    subtitle: "See how every post lands with built-in analytics.")
            case .firstChannel:
                firstChannelStep(viewModel)
            }

            Spacer()

            HStack {
                Button("Back") { viewModel.back() }
                    .disabled(!viewModel.canGoBack)
                    .accessibilityLabel("Back")

                Spacer()

                if viewModel.isOnFirstChannelStep {
                    Button("Get started") { onFinish() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canFinish)
                        .accessibilityLabel("Get started")
                } else {
                    Button("Next") { viewModel.advance() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Next")
                }
            }
        }
        .padding()
    }

    private func panel(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityLabel(title)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func firstChannelStep(_ viewModel: OnboardingViewModel) -> some View {
        VStack(spacing: 16) {
            Text("Connect your first channel")
                .font(.title2.bold())
                .accessibilityLabel("Connect your first channel")

            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Onboarding error")
            } else {
                // Provider count (28+ channels, see project CLAUDE.md) overflows the screen in a
                // plain VStack with no scroll container — the list, and the Next/Get started
                // buttons below it, get pushed off-screen. Wrap in a ScrollView so every provider
                // and the bottom controls stay reachable.
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.providers, id: \.identifier) { provider in
                            Button {
                                viewModel.selectProvider(provider.identifier)
                            } label: {
                                HStack {
                                    Text(provider.name)
                                    Spacer()
                                    if viewModel.selectedProviderId == provider.identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .padding()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Select \(provider.name)")
                        }
                    }
                }
            }
        }
    }
}
