import Foundation
import Testing

@testable import SocialsCore

@Suite("TeamViewModel")
@MainActor
struct TeamViewModelTests {

    private func member(id: String = "u-1", email: String = "a@b.com", role: String = "USER")
        -> TeamMember
    {
        TeamMember(role: role, user: TeamMemberUser(id: id, email: email))
    }

    @Test("load populates members")
    func loadPopulates() async {
        let api = StubSocialsAPI()
        let m = member()
        await api.setTeamMembersResults([.success(TeamListResponse(users: [m]))])
        let viewModel = TeamViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.members == [m])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("invite records the call and reloads")
    func inviteRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setTeamMembersResults([
            .success(TeamListResponse(users: [])),
            .success(TeamListResponse(users: [member()])),
        ])
        await api.setAddTeamMemberResults([.success(OkResponse(ok: true))])
        let viewModel = TeamViewModel(api: api)

        await viewModel.invite(email: "new@example.com", role: .admin, sendEmail: false)

        let calls = await api.addTeamMemberCalls
        #expect(calls.count == 1)
        #expect(calls[0].email == "new@example.com")
        #expect(calls[0].role == .admin)
        #expect(calls[0].sendEmail == false)
        let teamCalls = await api.teamMembersCalls
        #expect(teamCalls == 1)
    }

    @Test("invalid email surfaces a validation error and makes no call")
    func invalidEmailNoCall() async {
        let api = StubSocialsAPI()
        let viewModel = TeamViewModel(api: api)

        await viewModel.invite(email: "not-an-email", role: .user, sendEmail: true)

        let calls = await api.addTeamMemberCalls
        #expect(calls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("remove records the id and reloads")
    func removeRecordsIdAndReloads() async {
        let api = StubSocialsAPI()
        await api.setTeamMembersResults([
            .success(TeamListResponse(users: [member()])),
            .success(TeamListResponse(users: [])),
        ])
        await api.setRemoveTeamMemberResults([.success(OkResponse(ok: true))])
        let viewModel = TeamViewModel(api: api)
        await viewModel.load()

        await viewModel.remove(id: "u-1")

        let removeCalls = await api.removeTeamMemberCalls
        #expect(removeCalls == ["u-1"])
        let teamCalls = await api.teamMembersCalls
        #expect(teamCalls == 2)
    }
}

extension StubSocialsAPI {
    fileprivate func setTeamMembersResults(_ results: [Result<TeamListResponse, Error>]) {
        teamMembersResults = results
    }

    fileprivate func setAddTeamMemberResults(_ results: [Result<OkResponse, Error>]) {
        addTeamMemberResults = results
    }

    fileprivate func setRemoveTeamMemberResults(_ results: [Result<OkResponse, Error>]) {
        removeTeamMemberResults = results
    }
}
