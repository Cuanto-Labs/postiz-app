import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s account settings facade (personalDetails, updatePersonalDetails,
/// emailNotificationPrefs, updateEmailNotificationPrefs, deletionPreview, deleteAccount) through
/// a scripted `MockTransport`, mirroring `OrgAPITests`. Also exercises `StubSocialsAPI`'s call
/// recording.
@Suite("SocialsAPI account settings")
struct AccountSettingsAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - LiveSocialsAPI happy path

    @Test("personalDetails: GET /me/personal decodes response")
    func personalDetailsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: PersonalDetails(id: "u1", name: "Ada", bio: nil))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.personalDetails()

        #expect(response.name == "Ada")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/me/personal")
    }

    @Test("updatePersonalDetails: POST /me/personal")
    func updatePersonalDetailsSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: PersonalDetails(id: "u1", name: "Ada L", bio: "hi"))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.updatePersonalDetails(
            PersonalDetailsRequest(fullname: "Ada L", bio: "hi"))

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/me/personal")
    }

    @Test("emailNotificationPrefs: GET /me/email-notifications decodes response")
    func emailNotificationPrefsDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: EmailNotificationPrefs(
                sendSuccessEmails: true, sendFailureEmails: true, sendStreakEmails: false))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.emailNotificationPrefs()

        #expect(response.sendSuccessEmails == true)
    }

    @Test("updateEmailNotificationPrefs: POST /me/email-notifications")
    func updateEmailNotificationPrefsSendsRequest() async throws {
        let transport = MockTransport()
        let body = EmailNotificationPrefs(
            sendSuccessEmails: false, sendFailureEmails: false, sendStreakEmails: false)
        try await transport.enqueue(json: body)
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.updateEmailNotificationPrefs(body)

        #expect(response.sendSuccessEmails == false)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/me/email-notifications")
    }

    @Test("deletionPreview: GET /account/deletion-preview decodes response")
    func deletionPreviewDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: DeletionPreview(
                orgsToDelete: [DeletionPreviewOrg(id: "o1", name: "Org 1")],
                orgsToLeave: []))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.deletionPreview()

        #expect(response.orgsToDelete.first?.id == "o1")
    }

    @Test("deleteAccount: DELETE /account sends exactly {\"confirm\":\"DELETE\"}")
    func deleteAccountSendsConfirmDelete() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: DeleteAccountResponse(ok: true, deletedOrgs: [], leftOrgs: []))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.deleteAccount()

        #expect(response.ok == true)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/account")
        let body = try JSONDecoder().decode(DeleteAccountRequest.self, from: recorded[0].body!)
        #expect(body.confirm == "DELETE")
    }

    // MARK: - Error mapping

    @Test("deleteAccount: 429 throttle maps to .server(code: 429, ...)")
    func deleteAccountThrottleMapsToServer() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 429, json: ["msg": "Too many requests"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.deleteAccount()
            Issue.record("expected SocialsAPIError.server(code: 429) to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .server(code: 429, message: "Too many requests"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setPersonalDetailsResults([.success(PersonalDetails(id: "u1", name: "Ada", bio: nil))])
        await stub.setUpdatePersonalDetailsResults([
            .success(PersonalDetails(id: "u1", name: "Ada L", bio: "hi"))
        ])
        await stub.setEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: true, sendFailureEmails: true, sendStreakEmails: true))
        ])
        await stub.setUpdateEmailPrefsResults([
            .success(
                EmailNotificationPrefs(
                    sendSuccessEmails: false, sendFailureEmails: false, sendStreakEmails: false))
        ])
        await stub.setDeletionPreviewResults([.success(DeletionPreview(orgsToDelete: [], orgsToLeave: []))])
        await stub.setDeleteAccountResults([
            .success(DeleteAccountResponse(ok: true, deletedOrgs: [], leftOrgs: []))
        ])

        _ = try await stub.personalDetails()
        _ = try await stub.updatePersonalDetails(
            PersonalDetailsRequest(fullname: "Ada L", bio: "hi"))
        _ = try await stub.emailNotificationPrefs()
        _ = try await stub.updateEmailNotificationPrefs(
            EmailNotificationPrefs(
                sendSuccessEmails: false, sendFailureEmails: false, sendStreakEmails: false))
        _ = try await stub.deletionPreview()
        _ = try await stub.deleteAccount()

        let updatePersonalCalls = await stub.updatePersonalDetailsCalls
        #expect(updatePersonalCalls.count == 1)
        #expect(updatePersonalCalls[0].fullname == "Ada L")

        let updateEmailCalls = await stub.updateEmailPrefsCalls
        #expect(updateEmailCalls.count == 1)

        let deleteCalls = await stub.deleteAccountCalls
        #expect(deleteCalls == 1)
    }
}

extension StubSocialsAPI {
    fileprivate func setPersonalDetailsResults(_ results: [Result<PersonalDetails, Error>]) async {
        personalDetailsResults = results
    }

    fileprivate func setUpdatePersonalDetailsResults(
        _ results: [Result<PersonalDetails, Error>]
    ) async {
        updatePersonalDetailsResults = results
    }

    fileprivate func setEmailPrefsResults(
        _ results: [Result<EmailNotificationPrefs, Error>]
    ) async {
        emailPrefsResults = results
    }

    fileprivate func setUpdateEmailPrefsResults(
        _ results: [Result<EmailNotificationPrefs, Error>]
    ) async {
        updateEmailPrefsResults = results
    }

    fileprivate func setDeletionPreviewResults(
        _ results: [Result<DeletionPreview, Error>]
    ) async {
        deletionPreviewResults = results
    }

    fileprivate func setDeleteAccountResults(
        _ results: [Result<DeleteAccountResponse, Error>]
    ) async {
        deleteAccountResults = results
    }
}
