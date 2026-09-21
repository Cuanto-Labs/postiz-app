import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives the `AccountSettingsEndpoints` builders through a real `APIClient` + scripted
/// `MockTransport`, asserting on the request `APIClient` actually sent (mirrors
/// `OrgEndpointTests`). Mirrors `mobile-me.controller.ts`/`mobile-account.controller.ts`.
@Suite("AccountSettingsEndpoints")
struct AccountSettingsEndpointTests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    @Test("personal: GET /me/personal decodes response")
    func personal() async throws {
        let endpoint = AccountSettingsEndpoints.personal()
        let transport = MockTransport()
        try await transport.enqueue(json: PersonalDetails(id: "u1", name: "Ada", bio: "hi"))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/me/personal")
        #expect(result.name == "Ada")
    }

    @Test("updatePersonal: POST /me/personal with JSON body")
    func updatePersonal() async throws {
        let body = PersonalDetailsRequest(fullname: "Ada Lovelace", bio: "hi")
        let endpoint = try AccountSettingsEndpoints.updatePersonal(body)
        let transport = MockTransport()
        try await transport.enqueue(json: PersonalDetails(id: "u1", name: "Ada Lovelace", bio: "hi"))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/me/personal")
        #expect(result.name == "Ada Lovelace")
    }

    @Test("emailNotifications: GET /me/email-notifications decodes response")
    func emailNotifications() async throws {
        let endpoint = AccountSettingsEndpoints.emailNotifications()
        let transport = MockTransport()
        try await transport.enqueue(
            json: EmailNotificationPrefs(
                sendSuccessEmails: true, sendFailureEmails: false, sendStreakEmails: true))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/me/email-notifications")
        #expect(result.sendSuccessEmails == true)
    }

    @Test("updateEmailNotifications: POST /me/email-notifications with JSON body")
    func updateEmailNotifications() async throws {
        let body = EmailNotificationPrefs(
            sendSuccessEmails: false, sendFailureEmails: false, sendStreakEmails: false)
        let endpoint = try AccountSettingsEndpoints.updateEmailNotifications(body)
        let transport = MockTransport()
        try await transport.enqueue(json: body)
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/me/email-notifications")
        #expect(result.sendSuccessEmails == false)
    }

    @Test("deletionPreview: GET /account/deletion-preview decodes response")
    func deletionPreview() async throws {
        let endpoint = AccountSettingsEndpoints.deletionPreview()
        let transport = MockTransport()
        try await transport.enqueue(
            json: DeletionPreview(
                orgsToDelete: [DeletionPreviewOrg(id: "o1", name: "Org 1")],
                orgsToLeave: []))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/account/deletion-preview")
        #expect(result.orgsToDelete.first?.id == "o1")
    }

    @Test("deleteAccount: DELETE /account with JSON body")
    func deleteAccount() async throws {
        let endpoint = try AccountSettingsEndpoints.deleteAccount(DeleteAccountRequest())
        let transport = MockTransport()
        try await transport.enqueue(
            json: DeleteAccountResponse(ok: true, deletedOrgs: [], leftOrgs: []))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/account")
        #expect(result.ok == true)
    }
}
