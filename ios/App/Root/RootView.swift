import Foundation
import SocialsCore
import SwiftUI

/// App root: drives `RootViewModel`'s gate — a forced update wins over everything, then
/// signed-out → `SignInView` (with a sheet to `RegisterView`), signed-in + onboarding not yet
/// seen → `OnboardingView`, signed-in + onboarding seen → `MainTabView`. Also reacts to a
/// forced sign-out (401 refresh failure, explicit sign-out) via `RootViewModel`'s own listener
/// on `SessionStore.events`.
///
/// Also owns the app's one `DeepLinkRouter` — universal links/custom-scheme URLs land here via
/// `onOpenURL` and get handed down to `MainTabView` via `.environment(_:)`; a tapped push
/// notification reaches it the same way via `PushManager.onAction` + `PushPayloadRoute`. Also
/// drains the share-handoff inbox (`ShareHandoffImporter`) every time the app comes back to the
/// foreground.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: RootViewModel?
    @State private var deepLinkRouter = DeepLinkRouter()

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .environment(deepLinkRouter)
        .task {
            if viewModel == nil {
                let model = RootViewModel(api: environment.api, sessionStore: environment.sessionStore)
                viewModel = model
                await model.start()
            }
            let router = deepLinkRouter
            PushManager.shared.onAction = { _, _, userInfo in
                guard let route = PushManager.route(from: userInfo) else { return }
                router.enqueue(route)
            }
        }
        .onOpenURL { url in
            deepLinkRouter.handle(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await importShareHandoff() }
        }
    }

    /// Drains the Share extension's App Group inbox into autosaved drafts. Uses the same App
    /// Group container/`ModelContainer` the widget snapshot and live `AppEnvironment` use.
    private func importShareHandoff() async {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
        let store = AppGroupShareHandoffStore(containerURL: containerURL)
        let draftStore = SwiftDataDraftStore(modelContainer: environment.modelContainer)
        let sessionStore = environment.sessionStore
        let importer = ShareHandoffImporter(
            store: store, draftStore: draftStore,
            orgId: { await sessionStore.currentOrgId })
        await importer.importPending()
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
