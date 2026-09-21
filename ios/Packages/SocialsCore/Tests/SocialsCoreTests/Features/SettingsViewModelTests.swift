import Foundation
import Testing

@testable import SocialsCore

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {

    private func user(id: String = "u1", email: String = "ada@example.com") -> MobileUser {
        MobileUser(id: id, email: email, name: "Ada Lovelace", lastName: nil, pictureId: nil)
    }

    private func org(id: String = "o1", name: String = "Analytical Engines") -> MobileOrg {
        MobileOrg(id: id, name: name, role: "SUPERADMIN", disabled: false)
    }

    private func meResponse() -> MeResponse {
        MeResponse(
            user: user(), org: org(), orgs: [org()],
            plan: MobilePlan(tier: "pro", options: [:]), sessionId: "s1")
    }

    private func makeSessionStore(refreshToken: String? = "refresh-token") async -> SessionStore {
        let store = await SessionStore(
            keychain: .ephemeral(),
            refresh: { _ in throw CancellationError() }
        )
        if let refreshToken {
            try? await store.signIn(
                MobileAuthResponse(
                    accessToken: "access", refreshToken: refreshToken, expiresIn: 3600,
                    sessionId: "s1", user: user(), orgs: [org()]))
        }
        return store
    }

    @Test("load populates user and org from me()")
    func loadPopulatesUserAndOrg() async {
        let api = StubSocialsAPI()
        await api.setMeResults([.success(meResponse())])
        let sessionStore = await makeSessionStore()
        let viewModel = SettingsViewModel(api: api, sessionStore: sessionStore)

        await viewModel.load()

        #expect(viewModel.user == user())
        #expect(viewModel.org == org())
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load failure surfaces an error")
    func loadFailureSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setMeResults([.failure(SocialsAPIError.offline)])
        let sessionStore = await makeSessionStore()
        let viewModel = SettingsViewModel(api: api, sessionStore: sessionStore)

        await viewModel.load()

        #expect(viewModel.user == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("signOut logs out server-side once and clears the local session")
    func signOutLogsOutAndClearsSession() async {
        let api = StubSocialsAPI()
        await api.setLogoutResults([.success(OkResponse(ok: true))])
        let sessionStore = await makeSessionStore()
        let viewModel = SettingsViewModel(api: api, sessionStore: sessionStore)

        await viewModel.signOut()

        let calls = await api.logoutCalls
        #expect(calls.count == 1)
        #expect(calls.first?.refreshToken == "refresh-token")
        let state = await sessionStore.state
        #expect(state == .signedOut)
    }
}

extension StubSocialsAPI {
    fileprivate func setMeResults(_ results: [Result<MeResponse, Error>]) {
        meResults = results
    }

    fileprivate func setLogoutResults(_ results: [Result<OkResponse, Error>]) {
        logoutResults = results
    }
}
