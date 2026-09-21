import CuantoCore
import Foundation
import Testing

@testable import SocialsCore

@Suite("SignInViewModel")
@MainActor
struct SignInViewModelTests {

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

    private func makeViewModel(
        api: StubSocialsAPI, sessionStore: SessionStore, webAuth: StubWebAuth = StubWebAuth()
    ) -> SignInViewModel {
        SignInViewModel(
            api: api, sessionStore: sessionStore, deviceId: "device-1", deviceName: "iPhone",
            webAuth: webAuth, callbackURLScheme: "cuantosocials")
    }

    @Test("email + password is disabled until both fields are non-empty")
    func canSubmitEmailRequiresBothFields() async {
        let viewModel = makeViewModel(api: StubSocialsAPI(), sessionStore: await makeSessionStore())
        #expect(!viewModel.canSubmitEmail)
        viewModel.email = "a@b.com"
        #expect(!viewModel.canSubmitEmail)
        viewModel.password = "secret"
        #expect(viewModel.canSubmitEmail)
    }

    @Test("signInWithEmail sends the entered credentials and signs the session in on success")
    func signInWithEmailSucceeds() async {
        let api = StubSocialsAPI()
        await api.setLoginResults([.success(authResponse())])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)
        viewModel.email = "a@b.com"
        viewModel.password = "secret"

        await viewModel.signInWithEmail()

        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
        let calls = await api.loginCalls
        #expect(calls.count == 1)
        #expect(calls.first?.email == "a@b.com")
        #expect(calls.first?.deviceId == "device-1")
        if case .signedIn(let user, _, _) = await sessionStore.state {
            #expect(user.id == "u1")
        } else {
            Issue.record("expected signed in after successful email sign-in")
        }
    }

    @Test("signInWithEmail surfaces a message on 401 and does not sign in")
    func signInWithEmailUnauthorized() async {
        let api = StubSocialsAPI()
        await api.setLoginResults([.failure(SocialsAPIError.unauthorized)])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)
        viewModel.email = "a@b.com"
        viewModel.password = "wrong"

        await viewModel.signInWithEmail()

        #expect(viewModel.errorMessage != nil)
        #expect(await sessionStore.state == .signedOut)
    }

    @Test("signInWithApple exchanges the identity token and signs in on success")
    func signInWithAppleSucceeds() async {
        let api = StubSocialsAPI()
        await api.setSignInWithAppleResults([.success(authResponse())])
        let sessionStore = await makeSessionStore()
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore)

        await viewModel.signInWithApple(AppleSignInResult(identityToken: "token-1", fullName: "A B"))

        #expect(viewModel.errorMessage == nil)
        let calls = await api.signInWithAppleCalls
        #expect(calls.first?.identityToken == "token-1")
        if case .signedIn = await sessionStore.state {} else {
            Issue.record("expected signed in after Apple sign-in")
        }
    }

    @Test("signInWithGoogle round-trips PKCE: start, web redirect, exchange, sign in")
    func signInWithGoogleSucceeds() async {
        let api = StubSocialsAPI()
        await api.setOauthStartResults([
            .success(OAuthStartResponse(url: "https://accounts.example.com/authorize", state: "state-1"))
        ])
        await api.setOauthExchangeResults([.success(authResponse())])
        let sessionStore = await makeSessionStore()
        let webAuth = StubWebAuth(
            result: .success(URL(string: "cuantosocials://callback?code=abc123&state=state-1")!))
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore, webAuth: webAuth)

        await viewModel.signInWithGoogle()

        #expect(viewModel.errorMessage == nil)
        let startCalls = await api.oauthStartCalls
        #expect(startCalls.first?.provider == "google")
        #expect(!(startCalls.first?.codeChallenge.isEmpty ?? true))
        let exchangeCalls = await api.oauthExchangeCalls
        #expect(exchangeCalls.first?.code == "abc123")
        #expect(exchangeCalls.first?.state == "state-1")
        #expect(!(exchangeCalls.first?.codeVerifier.isEmpty ?? true))
        if case .signedIn = await sessionStore.state {} else {
            Issue.record("expected signed in after Google sign-in")
        }
    }

    @Test("signInWithGoogle rejects a redirect whose state doesn't match the one oauthStart issued")
    func signInWithGoogleStateMismatch() async {
        let api = StubSocialsAPI()
        await api.setOauthStartResults([
            .success(OAuthStartResponse(url: "https://accounts.example.com/authorize", state: "state-1"))
        ])
        let sessionStore = await makeSessionStore()
        let webAuth = StubWebAuth(
            result: .success(URL(string: "cuantosocials://callback?code=abc123&state=WRONG")!))
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore, webAuth: webAuth)

        await viewModel.signInWithGoogle()

        #expect(viewModel.errorMessage != nil)
        let exchangeCalls = await api.oauthExchangeCalls
        #expect(exchangeCalls.isEmpty)
        #expect(await sessionStore.state == .signedOut)
    }

    @Test("signInWithGoogle treats a cancelled web session as silent, not an error message")
    func signInWithGoogleCancelled() async {
        let api = StubSocialsAPI()
        await api.setOauthStartResults([
            .success(OAuthStartResponse(url: "https://accounts.example.com/authorize", state: "state-1"))
        ])
        let sessionStore = await makeSessionStore()
        let webAuth = StubWebAuth(result: .failure(CancellationError()))
        let viewModel = makeViewModel(api: api, sessionStore: sessionStore, webAuth: webAuth)

        await viewModel.signInWithGoogle()

        #expect(viewModel.errorMessage == "")
        #expect(!viewModel.isLoading)
    }
}

/// Scripted `SignInWebAuthenticating` double — returns (or throws) one canned result per call,
/// so tests never spin up a real `ASWebAuthenticationSession`.
private final class StubWebAuth: SignInWebAuthenticating, @unchecked Sendable {
    private let result: Result<URL, Error>

    init(result: Result<URL, Error> = .failure(SignInError.missingCode)) {
        self.result = result
    }

    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        try result.get()
    }
}

extension StubSocialsAPI {
    fileprivate func setLoginResults(_ results: [Result<MobileAuthResponse, Error>]) {
        loginResults = results
    }
    fileprivate func setSignInWithAppleResults(_ results: [Result<MobileAuthResponse, Error>]) {
        signInWithAppleResults = results
    }
    fileprivate func setOauthStartResults(_ results: [Result<OAuthStartResponse, Error>]) {
        oauthStartResults = results
    }
    fileprivate func setOauthExchangeResults(_ results: [Result<MobileAuthResponse, Error>]) {
        oauthExchangeResults = results
    }
}
