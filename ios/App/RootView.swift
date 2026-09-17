import SocialsCore
import SwiftUI

/// App root: routes on `SessionStore.state` — signed out → `SignInView` (with a sheet to
/// `RegisterView`); signed in, onboarding not yet seen → `OnboardingView`; signed in,
/// onboarding seen → `HomeView`. Also listens to `SessionStore.events` so a forced sign-out
/// (401 refresh failure, explicit sign-out) always routes back to `SignInView`.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var sessionState: SessionState?
    @AppStorage("com.cuantolabs.socials.hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            switch sessionState {
            case nil:
                ProgressView()
            case .signedOut:
                SignInView(onSignedIn: refreshSessionState)
            case .signedIn(let user, let orgs, let orgId):
                if hasSeenOnboarding {
                    HomeView(user: user, orgs: orgs, orgId: orgId)
                } else {
                    OnboardingView(onFinish: { hasSeenOnboarding = true })
                }
            }
        }
        .task {
            sessionState = await environment.sessionStore.state
        }
        .task {
            let events = await environment.sessionStore.events
            for await event in events where event == .signedOut {
                sessionState = .signedOut
            }
        }
    }

    private func refreshSessionState() {
        Task {
            sessionState = await environment.sessionStore.state
        }
    }
}
