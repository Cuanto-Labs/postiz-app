import Foundation
import Testing

@testable import SocialsCore

@Suite("DeleteAccountViewModel")
@MainActor
struct DeleteAccountViewModelTests {

    private func user(id: String = "u1", email: String = "ada@example.com") -> MobileUser {
        MobileUser(id: id, email: email, name: "Ada Lovelace", lastName: nil, pictureId: nil)
    }

    private func org(id: String = "o1", name: String = "Analytical Engines") -> MobileOrg {
        MobileOrg(id: id, name: name, role: "SUPERADMIN", disabled: false)
    }

    private func makeSessionStore() async -> SessionStore {
        let store = await SessionStore(
            keychain: .ephemeral(),
            refresh: { _ in throw CancellationError() }
        )
        try? await store.signIn(
            MobileAuthResponse(
                accessToken: "access", refreshToken: "refresh-token", expiresIn: 3600,
                sessionId: "s1", user: user(), orgs: [org()]))
        return store
    }

    private func preview() -> DeletionPreview {
        DeletionPreview(
            orgsToDelete: [DeletionPreviewOrg(id: "o1", name: "Analytical Engines")],
            orgsToLeave: [DeletionPreviewOrg(id: "o2", name: "Shared Org")])
    }

    @Test("loadPreview populates orgsToDelete")
    func loadPreviewPopulatesOrgsToDelete() async {
        let api = StubSocialsAPI()
        await api.setDeletionPreviewResults([.success(preview())])
        let sessionStore = await makeSessionStore()
        let pushRegistration = PushRegistrationViewModel(api: api)
        let viewModel = DeleteAccountViewModel(
            api: api, sessionStore: sessionStore, pushRegistration: pushRegistration)

        await viewModel.loadPreview()

        #expect(viewModel.preview?.orgsToDelete == preview().orgsToDelete)
        #expect(viewModel.preview?.orgsToLeave == preview().orgsToLeave)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("delete with wrong confirmation text does not call the API")
    func deleteWithWrongTextDoesNotCallAPI() async {
        let api = StubSocialsAPI()
        let sessionStore = await makeSessionStore()
        let pushRegistration = PushRegistrationViewModel(api: api)
        let viewModel = DeleteAccountViewModel(
            api: api, sessionStore: sessionStore, pushRegistration: pushRegistration)
        viewModel.confirmText = "delete"

        await viewModel.delete()

        let calls = await api.deleteAccountCalls
        #expect(calls == 0)
        #expect(viewModel.phase == .preview)
    }

    @Test("delete with correct text deletes account, unregisters push, and clears session")
    func deleteWithCorrectTextSucceeds() async {
        let api = StubSocialsAPI()
        await api.setUpsertPushDeviceResults([
            .success(
                PushDeviceResponse(
                    device: PushDeviceUpsert(
                        apnsToken: "0102", environment: "production", bundleId: nil,
                        locale: nil, timezone: nil, prefs: nil)))
        ])
        await api.setDeleteAccountResults([
            .success(DeleteAccountResponse(ok: true, deletedOrgs: [], leftOrgs: []))
        ])
        await api.setDeletePushDeviceResults([.success(OkResponse(ok: true))])
        let sessionStore = await makeSessionStore()
        let pushRegistration = PushRegistrationViewModel(api: api)
        await pushRegistration.didReceiveToken(Data([0x01, 0x02]))
        #expect(pushRegistration.registeredToken != nil)

        let viewModel = DeleteAccountViewModel(
            api: api, sessionStore: sessionStore, pushRegistration: pushRegistration)
        viewModel.confirmText = "DELETE"

        await viewModel.delete()

        let deleteCalls = await api.deleteAccountCalls
        #expect(deleteCalls == 1)
        let pushCalls = await api.deletePushDeviceCalls
        #expect(pushCalls.count == 1)
        #expect(viewModel.phase == .deleted)
        let state = await sessionStore.state
        #expect(state == .signedOut)
    }

    @Test("429 throttle maps to a failed phase with a throttle message")
    func throttleMapsToFailedPhase() async {
        let api = StubSocialsAPI()
        await api.setDeleteAccountResults([
            .failure(SocialsAPIError.server(code: 429, message: "Too many requests"))
        ])
        let sessionStore = await makeSessionStore()
        let pushRegistration = PushRegistrationViewModel(api: api)
        let viewModel = DeleteAccountViewModel(
            api: api, sessionStore: sessionStore, pushRegistration: pushRegistration)
        viewModel.confirmText = "DELETE"

        await viewModel.delete()

        let deleteCalls = await api.deleteAccountCalls
        #expect(deleteCalls == 1)
        #expect(viewModel.phase == .failed("Too many requests"))
        #expect(viewModel.errorMessage == "Too many requests")
    }
}

extension StubSocialsAPI {
    fileprivate func setDeletionPreviewResults(_ results: [Result<DeletionPreview, Error>]) {
        deletionPreviewResults = results
    }

    fileprivate func setDeleteAccountResults(_ results: [Result<DeleteAccountResponse, Error>]) {
        deleteAccountResults = results
    }

    fileprivate func setDeletePushDeviceResults(_ results: [Result<OkResponse, Error>]) {
        deletePushDeviceResults = results
    }

    fileprivate func setUpsertPushDeviceResults(_ results: [Result<PushDeviceResponse, Error>]) {
        upsertPushDeviceResults = results
    }
}
