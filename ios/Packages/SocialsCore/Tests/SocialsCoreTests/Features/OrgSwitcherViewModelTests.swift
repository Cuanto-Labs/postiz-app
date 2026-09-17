import Foundation
import Testing

@testable import SocialsCore

@Suite("OrgSwitcherViewModel")
@MainActor
struct OrgSwitcherViewModelTests {

    private func orgs() -> [MobileOrg] {
        [
            MobileOrg(id: "org-1", name: "Org One", role: "owner", disabled: false),
            MobileOrg(id: "org-2", name: "Org Two", role: "member", disabled: false),
        ]
    }

    private func meResponse(currentOrg: MobileOrg) -> MeResponse {
        MeResponse(
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            org: currentOrg, orgs: orgs(),
            plan: MobilePlan(tier: "free", options: [:]), sessionId: "session-1")
    }

    private func authResponse(currentOrg: MobileOrg) -> MobileAuthResponse {
        MobileAuthResponse(
            accessToken: "access-1", refreshToken: "refresh-1", expiresIn: 3600,
            sessionId: "session-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: orgs())
    }

    private func makeSessionStore() async -> SessionStore {
        await SessionStore(keychain: .ephemeral()) { _ in
            MobileTokens(accessToken: "n", refreshToken: "n", expiresIn: 1, sessionId: "s")
        }
    }

    @Test("load populates orgs and the active org id from me()")
    func loadPopulatesOrgs() async {
        let api = StubSocialsAPI()
        let currentOrg = orgs()[0]
        await api.setMeResults([.success(meResponse(currentOrg: currentOrg))])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse(currentOrg: currentOrg))
        let viewModel = OrgSwitcherViewModel(api: api, sessionStore: sessionStore)

        await viewModel.load()

        #expect(viewModel.orgs.map(\.id) == ["org-1", "org-2"])
        #expect(viewModel.currentOrgId == "org-1")
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("load surfaces a message on failure")
    func loadSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setMeResults([.failure(SocialsAPIError.offline)])
        let sessionStore = await makeSessionStore()
        let viewModel = OrgSwitcherViewModel(api: api, sessionStore: sessionStore)

        await viewModel.load()

        #expect(viewModel.orgs.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("selectOrg switches the active org and persists it through SessionStore")
    func selectOrgSwitchesActiveOrg() async {
        let api = StubSocialsAPI()
        let currentOrg = orgs()[0]
        await api.setMeResults([.success(meResponse(currentOrg: currentOrg))])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse(currentOrg: currentOrg))
        let viewModel = OrgSwitcherViewModel(api: api, sessionStore: sessionStore)
        await viewModel.load()

        await viewModel.selectOrg("org-2")

        #expect(viewModel.currentOrgId == "org-2")
        #expect(await sessionStore.currentOrgId == "org-2")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("selectOrg is a no-op when the org is already active")
    func selectOrgNoOpWhenAlreadyActive() async {
        let api = StubSocialsAPI()
        let currentOrg = orgs()[0]
        await api.setMeResults([.success(meResponse(currentOrg: currentOrg))])
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse(currentOrg: currentOrg))
        let viewModel = OrgSwitcherViewModel(api: api, sessionStore: sessionStore)
        await viewModel.load()

        await viewModel.selectOrg("org-1")

        #expect(viewModel.currentOrgId == "org-1")
        #expect(await sessionStore.currentOrgId == "org-1")
    }
}

extension StubSocialsAPI {
    fileprivate func setMeResults(_ results: [Result<MeResponse, Error>]) {
        meResults = results
    }
}
