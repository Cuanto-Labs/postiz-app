import CuantoCore
import Foundation
import Testing

@testable import SocialsCore

@Suite("RegisterViewModel")
@MainActor
struct RegisterViewModelTests {

    private func authResponse() -> MobileAuthResponse {
        MobileAuthResponse(
            accessToken: "access-1", refreshToken: "refresh-1", expiresIn: 3600,
            sessionId: "session-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: [MobileOrg(id: "org-1", name: "Org", role: "owner", disabled: false)])
    }

    private func makeSessionStore() async -> SessionStore {
        await SessionStore(keychain: .ephemeral()) { _ in
            MobileTokens(accessToken: "n", refreshToken: "n", expiresIn: 1, sessionId: "s")
        }
    }

    private func makeViewModel(api: StubSocialsAPI, sessionStore: SessionStore) -> RegisterViewModel {
        RegisterViewModel(
            api: api, sessionStore: sessionStore, deviceId: "device-1", deviceName: "iPhone")
    }

    @Test("canSubmit requires a non-empty email, password 3-64, and company 3-128")
    func canSubmitValidatesFieldBounds() async {
        let viewModel = makeViewModel(api: StubSocialsAPI(), sessionStore: await makeSessionStore())
        #expect(!viewModel.canSubmit)

        viewModel.email = "a@b.com"
        #expect(!viewModel.canSubmit)

        viewModel.password = "ab"
        #expect(!viewModel.canSubmit)

        viewModel.password = "secret"
        #expect(!viewModel.canSubmit)

        viewModel.company = "Ac"
        #expect(!viewModel.canSubmit)

        viewModel.company = "Acme"
        #expect(viewModel.canSubmit)

        viewModel.password = String(repeating: "a", count: 65)
        #expect(!viewModel.canSubmit)
    }

    @Test("register sends the entered fields and signs the session in when authenticated")
    func registerSucceedsAuthenticated() async {
        let api = StubSocialsAPI()
        await api.setRegisterResults([.success(.authenticated(authResponse()))])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)
        viewModel.email = "a@b.com"
        viewModel.password = "secret"
        viewModel.company = "Acme"
        viewModel.inviteCode = "invite-1"

        await viewModel.register()

        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.needsActivation)
        let calls = await api.registerCalls
        #expect(calls.count == 1)
        #expect(calls.first?.email == "a@b.com")
        #expect(calls.first?.company == "Acme")
        #expect(calls.first?.inviteCode == "invite-1")
        #expect(calls.first?.deviceId == "device-1")
        if case .signedIn(let user, _, _) = await sessionStore.state {
            #expect(user.id == "u1")
        } else {
            Issue.record("expected signed in after successful registration")
        }
    }

    @Test("register surfaces needsActivation when the backend requires email verification")
    func registerNeedsActivation() async {
        let api = StubSocialsAPI()
        await api.setRegisterResults([.success(.activate)])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)
        viewModel.email = "a@b.com"
        viewModel.password = "secret"
        viewModel.company = "Acme"

        await viewModel.register()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.needsActivation)
        #expect(await sessionStore.state == .signedOut)
    }

    @Test("register surfaces a message on a bad invite code / disabled registration and does not sign in")
    func registerForbidden() async {
        let api = StubSocialsAPI()
        await api.setRegisterResults([.failure(SocialsAPIError.forbidden(message: "Bad invite code"))])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)
        viewModel.email = "a@b.com"
        viewModel.password = "secret"
        viewModel.company = "Acme"

        await viewModel.register()

        #expect(viewModel.errorMessage == "Bad invite code")
        #expect(!viewModel.needsActivation)
        #expect(await sessionStore.state == .signedOut)
    }

    @Test("register does nothing when fields are out of bounds")
    func registerBlocksInvalidFields() async {
        let api = StubSocialsAPI()
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)

        await viewModel.register()

        #expect(viewModel.errorMessage != nil)
        let calls = await api.registerCalls
        #expect(calls.isEmpty)
    }
}

extension StubSocialsAPI {
    fileprivate func setRegisterResults(_ results: [Result<RegisterResult, Error>]) {
        registerResults = results
    }
}
