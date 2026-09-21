import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives the `OrgEndpoints` builders through a real `APIClient` + scripted `MockTransport`,
/// asserting on the request `APIClient` actually sent (mirrors `AnalyticsEndpointTests`).
/// Mirrors `mobile-org.controller.ts`.
@Suite("OrgEndpoints")
struct OrgEndpointTests {
    private static let showorgHeader = HTTPField.Name("showorg")!

    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    @Test("team: GET /org/team with org header")
    func team() async throws {
        let endpoint = OrgEndpoints.team(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: TeamListResponse(users: [
                TeamMember(role: "ADMIN", user: TeamMemberUser(id: "u1", email: "a@b.com"))
            ]))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/org/team")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
        #expect(result.users.first?.user.email == "a@b.com")
    }

    @Test("addTeamMember: POST /org/team with JSON body")
    func addTeamMember() async throws {
        let body = AddTeamMemberRequest(email: "new@b.com", role: .user, sendEmail: true)
        let endpoint = try OrgEndpoints.addTeamMember(body, orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/org/team")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("removeTeamMember: DELETE /org/team/:id")
    func removeTeamMember() async throws {
        let endpoint = OrgEndpoints.removeTeamMember("u1", orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/org/team/u1")
    }

    @Test("shortlink: GET /org/shortlink")
    func shortlink() async throws {
        let endpoint = OrgEndpoints.shortlink(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: ShortlinkPreferenceResponse(shortlink: .yes))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/org/shortlink")
        #expect(result.shortlink == .yes)
    }

    @Test("updateShortlink: POST /org/shortlink with JSON body")
    func updateShortlink() async throws {
        let body = ShortlinkPreferenceRequest(shortlink: .no)
        let endpoint = try OrgEndpoints.updateShortlink(body, orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: ShortlinkPreferenceResponse(shortlink: .no))
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/org/shortlink")
        #expect(result.shortlink == .no)
    }

    @Test("webhooks: GET /org/webhooks decodes list")
    func webhooks() async throws {
        let endpoint = OrgEndpoints.webhooks(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: [
                MobileWebhook(
                    id: "w1", name: "hook", url: "https://x.com",
                    integrations: [
                        WebhookIntegrationEntry(
                            integration: WebhookIntegrationRef(
                                id: "i1", name: "fb", picture: nil))
                    ])
            ])
        let result = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/org/webhooks")
        #expect(result.first?.id == "w1")
        #expect(result.first?.integrations.first?.integration.id == "i1")
    }
}
