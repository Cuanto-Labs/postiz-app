import Foundation
import Testing

@testable import SocialsCore

@Suite("ShareComposerViewModel")
@MainActor
struct ShareComposerViewModelTests {

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

    @Test("starts signed out until refreshSignInState runs")
    func startsSignedOut() async {
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: InMemoryShareHandoffStore())
        #expect(!viewModel.isSignedIn)
        #expect(viewModel.signedOutMessage?.contains("Open Cuanto Socials to sign in") == true)
    }

    @Test("refreshSignInState reflects a signed-in session")
    func refreshSignInStateSignedIn() async {
        let sessionStore = await makeSessionStore()
        try? await sessionStore.signIn(authResponse())
        let viewModel = ShareComposerViewModel(
            sessionStore: sessionStore, handoffStore: InMemoryShareHandoffStore())

        await viewModel.refreshSignInState()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedOutMessage == nil)
    }

    @Test("refreshSignInState reflects a signed-out session")
    func refreshSignInStateSignedOut() async {
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: InMemoryShareHandoffStore())

        await viewModel.refreshSignInState()

        #expect(!viewModel.isSignedIn)
        #expect(viewModel.signedOutMessage != nil)
    }

    @Test("canSubmit is false with no caption, urls, or attachments")
    func canSubmitFalseWhenEmpty() async {
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: InMemoryShareHandoffStore())
        #expect(!viewModel.canSubmit)
    }

    @Test("canSubmit is true once a caption is entered")
    func canSubmitTrueWithCaption() async {
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: InMemoryShareHandoffStore())
        viewModel.caption = "Check this out"
        #expect(viewModel.canSubmit)
    }

    @Test("canSubmit is true from incoming urls alone")
    func canSubmitTrueWithIncomingURL() async {
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: InMemoryShareHandoffStore(),
            incomingURLs: ["https://example.com"])
        #expect(viewModel.canSubmit)
    }

    @Test("submit enqueues a handoff item with the caption and incoming content")
    func submitEnqueuesHandoffItem() async {
        let store = InMemoryShareHandoffStore()
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: store,
            incomingURLs: ["https://example.com"], incomingAttachmentFilenames: ["photo.jpg"])
        viewModel.caption = "Check this out"

        viewModel.submit()

        #expect(viewModel.submitState == .saved)
        #expect(store.items.count == 1)
        #expect(store.items.first?.text == "Check this out")
        #expect(store.items.first?.urls == ["https://example.com"])
        #expect(store.items.first?.attachmentFilenames == ["photo.jpg"])
    }

    @Test("submit is a no-op when nothing can be submitted")
    func submitNoOpWhenEmpty() async {
        let store = InMemoryShareHandoffStore()
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: store)

        viewModel.submit()

        #expect(viewModel.submitState == .idle)
        #expect(store.items.isEmpty)
    }

    @Test("submit still saves the draft when signed out")
    func submitSavesWhenSignedOut() async {
        let store = InMemoryShareHandoffStore()
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: store)
        viewModel.caption = "Draft while signed out"

        viewModel.submit()

        #expect(viewModel.submitState == .saved)
        #expect(store.items.count == 1)
    }

    @Test("submit surfaces a failure when the handoff store throws")
    func submitSurfacesFailure() async {
        let store = InMemoryShareHandoffStore()
        store.enqueueError = ShareHandoffError.noContainer
        let viewModel = ShareComposerViewModel(
            sessionStore: await makeSessionStore(), handoffStore: store)
        viewModel.caption = "Won't save"

        viewModel.submit()

        guard case .failed = viewModel.submitState else {
            Issue.record("expected .failed, got \(viewModel.submitState)")
            return
        }
    }
}
