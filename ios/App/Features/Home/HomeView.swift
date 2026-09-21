import SocialsCore
import SwiftUI

/// Signed-in home: the active org switcher in the toolbar, the signed-in user's own
/// name/email (from `SessionState.signedIn`, no extra network call), and sign-out. `RootView`
/// shows this once onboarding is done; sign-out routes back to `SignInView` via the
/// `SessionStore.events` `.signedOut` stream `RootView` already listens to.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    let user: MobileUser
    let orgs: [MobileOrg]
    let orgId: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Name", value: user.name ?? user.email)
                    LabeledContent("Email", value: user.email)
                }

                if let currentOrg = orgs.first(where: { $0.id == orgId }) {
                    Section("Organization") {
                        LabeledContent("Name", value: currentOrg.name)
                        LabeledContent("Role", value: currentOrg.role)
                    }
                }
            }
            .navigationTitle("Cuanto Socials")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    OrgSwitcherMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        Task { await environment.sessionStore.signOut() }
                    }
                    .accessibilityLabel("Sign out")
                    .accessibilityIdentifier("home.signOut")
                }
            }
        }
    }
}
