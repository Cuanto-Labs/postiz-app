import Foundation
import Testing

@testable import SocialsCore

@Suite("RootViewModel")
@MainActor
struct RootViewModelTests {

    private func orgs() -> [MobileOrg] {
        [MobileOrg(id: "org-1", name: "Org One", role: "owner", disabled: false)]
    }

    private func authResponse() -> MobileAuthResponse {
        MobileAuthResponse(
            accessToken: "access-1", refreshToken: "refresh-1", expiresIn: 3600,
            sessionId: "session-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: orgs())
    }

    private func configResponse(minVersion: String = "1.0.0") -> ConfigResponse {
        ConfigResponse(
            minVersion: minVersion, providers: [],
            links: ConfigLinks(support: "https://x", terms: "https://x", privacy: "https://x"))
    }

    private func makeSessionStore() async -> SessionStore {
        await SessionStore(keychain: .ephemeral()) { _ in
            MobileTokens(accessToken: "n", refreshToken: "n", expiresIn: 1, sessionId: "s")
        }
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    @Test("start routes to signedOut when there is no session and the version is current")
    func startRoutesSignedOut() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse())])
        let sessionStore = await makeSessionStore()
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: makeDefaults())

        await viewModel.start()

        #expect(viewModel.phase == .signedOut)
    }

    @Test("start routes to onboarding when signed in but onboarding not yet seen")
    func startRoutesOnboarding() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse())])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse())
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: makeDefaults())

        await viewModel.start()

        #expect(viewModel.phase == .onboarding)
    }

    @Test("start routes to signedIn when signed in and onboarding already seen")
    func startRoutesSignedIn() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse())])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse())
        let defaults = makeDefaults()
        defaults.set(true, forKey: "com.cuantolabs.socials.hasSeenOnboarding")
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: defaults)

        await viewModel.start()

        #expect(
            viewModel.phase
                == .signedIn(
                    user: authResponse().user, orgs: orgs(), orgId: "org-1"))
    }

    @Test("start routes to updateRequired when installed version is below minVersion")
    func startRoutesUpdateRequired() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse(minVersion: "2.0.0"))])
        let sessionStore = await makeSessionStore()
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: makeDefaults())

        await viewModel.start()

        #expect(viewModel.phase == .updateRequired(minimum: AppVersion(major: 2)))
    }

    @Test("a config() failure fails open to session routing")
    func configFailureFailsOpen() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.failure(SocialsAPIError.offline)])
        let sessionStore = await makeSessionStore()
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: makeDefaults())

        await viewModel.start()

        #expect(viewModel.phase == .signedOut)
    }

    @Test("finishOnboarding persists the flag and moves to signedIn")
    func finishOnboardingMovesToSignedIn() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse()), .success(configResponse())])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse())
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: makeDefaults())
        await viewModel.start()
        #expect(viewModel.phase == .onboarding)

        await viewModel.finishOnboarding()

        #expect(
            viewModel.phase
                == .signedIn(user: authResponse().user, orgs: orgs(), orgId: "org-1"))
    }

    @Test("a signedOut session event forces the phase back to signedOut")
    func signedOutEventForcesPhase() async {
        let api = StubSocialsAPI()
        await api.setConfigResults([.success(configResponse())])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse())
        let defaults = makeDefaults()
        defaults.set(true, forKey: "com.cuantolabs.socials.hasSeenOnboarding")
        let viewModel = RootViewModel(
            api: api, sessionStore: sessionStore, installedVersion: AppVersion(major: 1),
            defaults: defaults)
        await viewModel.start()
        #expect(
            viewModel.phase
                == .signedIn(user: authResponse().user, orgs: orgs(), orgId: "org-1"))

        await sessionStore.signOut()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.phase == .signedOut)
    }
}

extension StubSocialsAPI {
    fileprivate func setConfigResults(_ results: [Result<ConfigResponse, Error>]) {
        configResults = results
    }
}
