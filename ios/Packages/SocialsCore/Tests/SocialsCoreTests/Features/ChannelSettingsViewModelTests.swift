import Foundation
import Testing

@testable import SocialsCore

@Suite("ChannelSettingsViewModel")
@MainActor
struct ChannelSettingsViewModelTests {

    private func channel(internalId: String = "int-1") -> ChannelDTO {
        ChannelDTO(
            id: "1", internalId: internalId, name: "My Page", identifier: "facebook",
            picture: nil, disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: nil, editor: nil))
    }

    private func customer(id: String = "cust-1", name: String = "Acme Corp") -> ChannelCustomer {
        ChannelCustomer(
            id: id, name: name, orgId: "org-1", createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z", deletedAt: nil)
    }

    // MARK: - Customers

    @Test
    func loadCustomersPopulatesList() async {
        let api = StubSocialsAPI()
        let c = customer()
        await api.setCustomersResults([.success([c])])
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel())

        await viewModel.loadCustomers()

        #expect(viewModel.customers == [c])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func customerSuggestionsFiltersByPrefix() async {
        let api = StubSocialsAPI()
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel())
        await api.setCustomersResults([
            .success([customer(id: "1", name: "Acme Corp"), customer(id: "2", name: "Beta LLC")])
        ])
        await viewModel.loadCustomers()

        let matches = viewModel.customerSuggestions(matching: "ac")

        #expect(matches.map(\.name) == ["Acme Corp"])
    }

    @Test
    func saveCustomerNameSendsRequest() async {
        let api = StubSocialsAPI()
        await api.setUpdateChannelCustomerNameResults([.success(OpaqueJSONResult(raw: "{}"))])
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel(internalId: "int-9"))

        await viewModel.saveCustomerName("New Name")

        let calls = await api.updateChannelCustomerNameCalls
        #expect(calls.count == 1)
        #expect(calls.first?.id == "int-9")
        #expect(calls.first?.body.name == "New Name")
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Group

    @Test
    func saveGroupSendsRequestAndSurfacesError() async {
        let api = StubSocialsAPI()
        await api.setUpdateChannelGroupResults([.failure(SocialsAPIError.offline)])
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel())

        await viewModel.saveGroup("Group A")

        let calls = await api.updateChannelGroupCalls
        #expect(calls.first?.body.group == "Group A")
        #expect(viewModel.errorMessage == "You're offline. Check your connection and try again.")
    }

    // MARK: - Time table

    @Test
    func addAndRemoveTimeSlotMutateLocalState() {
        let viewModel = ChannelSettingsViewModel(api: StubSocialsAPI(), channel: channel())

        viewModel.addTimeSlot(minutesFromMidnight: 600)
        viewModel.addTimeSlot(minutesFromMidnight: 480)
        viewModel.addTimeSlot(minutesFromMidnight: 600)

        #expect(viewModel.timeSlots == [480, 600])

        viewModel.removeTimeSlot(at: IndexSet(integer: 0))

        #expect(viewModel.timeSlots == [600])
    }

    @Test
    func saveTimeSlotsSendsSortedTimes() async {
        let api = StubSocialsAPI()
        await api.setSetChannelTimesResults([.success(OpaqueJSONResult(raw: "{}"))])
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel(internalId: "int-2"))
        viewModel.setTimeSlots([540, 60])

        await viewModel.saveTimeSlots()

        let calls = await api.setChannelTimesCalls
        #expect(calls.first?.id == "int-2")
        #expect(calls.first?.body.time.map(\.time) == [60, 540])
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Provider preferences

    @Test
    func saveProviderSettingsSendsRawJSON() async {
        let api = StubSocialsAPI()
        await api.setUpdateChannelSettingsResults([.success(OpaqueJSONResult(raw: "{}"))])
        let viewModel = ChannelSettingsViewModel(api: api, channel: channel(internalId: "int-3"))

        await viewModel.saveProviderSettings(additionalSettings: "{\"tone\":\"formal\"}")

        let calls = await api.updateChannelSettingsCalls
        #expect(calls.first?.id == "int-3")
        #expect(calls.first?.body.additionalSettings == "{\"tone\":\"formal\"}")
        #expect(viewModel.errorMessage == nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setCustomersResults(_ results: [Result<[ChannelCustomer], Error>]) {
        customersResults = results
    }

    fileprivate func setUpdateChannelCustomerNameResults(
        _ results: [Result<OpaqueJSONResult, Error>]
    ) {
        updateChannelCustomerNameResults = results
    }

    fileprivate func setUpdateChannelGroupResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        updateChannelGroupResults = results
    }

    fileprivate func setSetChannelTimesResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        setChannelTimesResults = results
    }

    fileprivate func setUpdateChannelSettingsResults(
        _ results: [Result<OpaqueJSONResult, Error>]
    ) {
        updateChannelSettingsResults = results
    }
}
