import Foundation
import Testing

@testable import SocialsCore

@Suite("AccountDetailsViewModel")
@MainActor
struct AccountDetailsViewModelTests {

    @Test("load populates fullname and bio")
    func loadPopulatesFields() async {
        let api = StubSocialsAPI()
        await api.setPersonalDetailsResults([
            .success(PersonalDetails(id: "u1", name: "Ada Lovelace", bio: "Mathematician"))
        ])
        let viewModel = AccountDetailsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.fullname == "Ada Lovelace")
        #expect(viewModel.bio == "Mathematician")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("save records the update call with the edited fullname")
    func saveRecordsCall() async {
        let api = StubSocialsAPI()
        await api.setUpdatePersonalDetailsResults([
            .success(PersonalDetails(id: "u1", name: "Grace Hopper", bio: "Compiler"))
        ])
        let viewModel = AccountDetailsViewModel(api: api)
        viewModel.fullname = "Grace Hopper"
        viewModel.bio = "Compiler"

        await viewModel.save()

        let calls = await api.updatePersonalDetailsCalls
        #expect(calls.first?.fullname == "Grace Hopper")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("empty fullname fails validation without calling the API")
    func emptyFullnameFailsValidation() async {
        let api = StubSocialsAPI()
        let viewModel = AccountDetailsViewModel(api: api)
        viewModel.fullname = ""
        viewModel.bio = "Something"

        await viewModel.save()

        let calls = await api.updatePersonalDetailsCalls
        #expect(calls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("save failure surfaces an error and keeps the current fields")
    func saveFailureKeepsFields() async {
        let api = StubSocialsAPI()
        await api.setUpdatePersonalDetailsResults([.failure(SocialsAPIError.offline)])
        let viewModel = AccountDetailsViewModel(api: api)
        viewModel.fullname = "Ada Lovelace"
        viewModel.bio = "Mathematician"

        await viewModel.save()

        #expect(viewModel.fullname == "Ada Lovelace")
        #expect(viewModel.bio == "Mathematician")
        #expect(viewModel.errorMessage != nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setPersonalDetailsResults(_ results: [Result<PersonalDetails, Error>]) {
        personalDetailsResults = results
    }

    fileprivate func setUpdatePersonalDetailsResults(
        _ results: [Result<PersonalDetails, Error>]
    ) {
        updatePersonalDetailsResults = results
    }
}
