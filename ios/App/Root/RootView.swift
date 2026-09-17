import SocialsCore
import SwiftUI

/// App root: drives `RootViewModel`'s gate — a forced update wins over everything, then
/// signed-out → `SignInView` (with a sheet to `RegisterView`), signed-in + onboarding not yet
/// seen → `OnboardingView`, signed-in + onboarding seen → `MainTabView`. Also reacts to a
/// forced sign-out (401 refresh failure, explicit sign-out) via `RootViewModel`'s own listener
/// on `SessionStore.events`.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: RootViewModel?

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
                let model = RootViewModel(api: environment.api, sessionStore: environment.sessionStore)
                viewModel = model
                await model.start()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: RootViewModel) -> some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .updateRequired(let minimum):
            updateRequiredView(minimum: minimum)
        case .signedOut:
            SignInView(onSignedIn: {
                Task {
                    await viewModel.signedIn()
                    // Only prompt immediately if this sign-in landed straight on the signed-in
                    // home; a returning user going through onboarding gets prompted once
                    // `OnboardingView.onFinish` lands them there instead.
                    if case .signedIn = viewModel.phase {
                        await PushManager.shared.requestAuthorizationAndRegister()
                    }
                }
            })
        case .onboarding:
            OnboardingView(onFinish: {
                Task {
                    await viewModel.finishOnboarding()
                    await PushManager.shared.requestAuthorizationAndRegister()
                }
            })
        case .signedIn(_, _, let orgId):
            MainTabView(orgId: orgId)
        }
    }

    private func updateRequiredView(minimum: AppVersion) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Update required")
                .font(.title2.bold())
            Text("Version \(minimum.description) or later is required to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityLabel("Update required, version \(minimum.description) or later")
    }
}
