import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Drives `LiveSocialsAPI`'s org settings facade (teamMembers, addTeamMember, removeTeamMember,
/// shortlinkPreference, setShortlinkPreference, webhooks) through a scripted `MockTransport`,
/// mirroring `ChannelSettingsAPITests`. Also exercises `StubSocialsAPI`'s call recording.
@Suite("SocialsAPI org settings")
struct OrgAPITests {
    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    // MARK: - LiveSocialsAPI happy path

    @Test("teamMembers: GET /org/team decodes list")
    func teamMembersDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: TeamListResponse(users: [
                TeamMember(role: "ADMIN", user: TeamMemberUser(id: "u1", email: "a@b.com"))
            ]))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.teamMembers()

        #expect(response.users.first?.user.email == "a@b.com")
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.path == "/mobile/v1/org/team")
    }

    @Test("addTeamMember: POST /org/team")
    func addTeamMemberSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.addTeamMember(
            AddTeamMemberRequest(email: "new@b.com", role: .user, sendEmail: true))

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/org/team")
    }

    @Test("removeTeamMember: DELETE /org/team/:id")
    func removeTeamMemberSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        let api = LiveSocialsAPI(client: makeClient(transport))

        _ = try await api.removeTeamMember("u1")

        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .delete)
        #expect(recorded[0].request.path == "/mobile/v1/org/team/u1")
    }

    @Test("shortlinkPreference: GET /org/shortlink decodes value")
    func shortlinkPreferenceDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: ShortlinkPreferenceResponse(shortlink: .yes))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.shortlinkPreference()

        #expect(response.shortlink == .yes)
    }

    @Test("setShortlinkPreference: POST /org/shortlink")
    func setShortlinkPreferenceSendsRequest() async throws {
        let transport = MockTransport()
        try await transport.enqueue(json: ShortlinkPreferenceResponse(shortlink: .no))
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.setShortlinkPreference(.no)

        #expect(response.shortlink == .no)
        let recorded = await transport.recordedRequests
        #expect(recorded[0].request.method == .post)
        #expect(recorded[0].request.path == "/mobile/v1/org/shortlink")
    }

    @Test("webhooks: GET /org/webhooks decodes list")
    func webhooksDecodesResponse() async throws {
        let transport = MockTransport()
        try await transport.enqueue(
            json: [
                MobileWebhook(
                    id: "w1", name: "hook", url: "https://x.com",
                    integrations: [])
            ])
        let api = LiveSocialsAPI(client: makeClient(transport))

        let response = try await api.webhooks()

        #expect(response.first?.id == "w1")
    }

    // MARK: - Error mapping

    @Test("removeTeamMember: 404 {msg} maps to .notFound with message")
    func removeTeamMemberNotFound() async throws {
        let transport = MockTransport()
        try await transport.enqueue(status: 404, json: ["msg": "Member not found"])
        let api = LiveSocialsAPI(client: makeClient(transport))

        do {
            _ = try await api.removeTeamMember("missing")
            Issue.record("expected SocialsAPIError.notFound to be thrown")
        } catch let error as SocialsAPIError {
            #expect(error == .notFound(message: "Member not found"))
        }
    }

    // MARK: - StubSocialsAPI call recording

    @Test("StubSocialsAPI: records calls and replays scripted results")
    func stubRecordsCallsAndReplays() async throws {
        let stub = StubSocialsAPI()
        await stub.setTeamMembersResults([.success(TeamListResponse(users: []))])
        await stub.setAddTeamMemberResults([.success(OkResponse(ok: true))])
        await stub.setRemoveTeamMemberResults([.success(OkResponse(ok: true))])
        await stub.setShortlinkResultsStub([.success(ShortlinkPreferenceResponse(shortlink: .ask))])
        await stub.setSetShortlinkResults([.success(ShortlinkPreferenceResponse(shortlink: .yes))])
        await stub.setWebhooksResults([.success([])])

        _ = try await stub.teamMembers()
        _ = try await stub.addTeamMember(
            AddTeamMemberRequest(email: "e@b.com", role: .admin, sendEmail: false))
        _ = try await stub.removeTeamMember("u1")
        _ = try await stub.shortlinkPreference()
        _ = try await stub.setShortlinkPreference(.yes)
        _ = try await stub.webhooks()

        let addCalls = await stub.addTeamMemberCalls
        #expect(addCalls.count == 1)
        #expect(addCalls[0].email == "e@b.com")

        let removeCalls = await stub.removeTeamMemberCalls
        #expect(removeCalls == ["u1"])

        let setShortlinkCalls = await stub.setShortlinkCalls
        #expect(setShortlinkCalls == [.yes])
    }
}

extension StubSocialsAPI {
    fileprivate func setTeamMembersResults(_ results: [Result<TeamListResponse, Error>]) async {
        teamMembersResults = results
    }

    fileprivate func setAddTeamMemberResults(_ results: [Result<OkResponse, Error>]) async {
        addTeamMemberResults = results
    }

    fileprivate func setRemoveTeamMemberResults(_ results: [Result<OkResponse, Error>]) async {
        removeTeamMemberResults = results
    }

    fileprivate func setShortlinkResultsStub(
        _ results: [Result<ShortlinkPreferenceResponse, Error>]
    ) async {
        shortlinkResults = results
    }

    fileprivate func setSetShortlinkResults(
        _ results: [Result<ShortlinkPreferenceResponse, Error>]
    ) async {
        setShortlinkResults = results
    }

    fileprivate func setWebhooksResults(_ results: [Result<[MobileWebhook], Error>]) async {
        webhooksResults = results
    }
}
