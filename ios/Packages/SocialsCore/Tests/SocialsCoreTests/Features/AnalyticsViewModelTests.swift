import Foundation
import Testing

@testable import SocialsCore

@Suite("AnalyticsViewModel")
@MainActor
struct AnalyticsViewModelTests {

    private func channel(id: String = "int-1", name: String = "My Page") -> ChannelDTO {
        ChannelDTO(
            id: id, internalId: id, name: name, identifier: "facebook", picture: nil,
            disabled: false, refreshNeeded: false, inBetweenSteps: false,
            display: nil, type: nil, customer: nil,
            limits: ChannelLimits(maxCharacters: nil, editor: nil))
    }

    private func series(label: String = "Followers", change: Double = 12.5) -> AnalyticsSeries {
        AnalyticsSeries(
            label: label,
            data: [AnalyticsPoint(total: "1", date: "2026-01-01"), AnalyticsPoint(total: "2", date: "2026-01-02")],
            percentageChange: change)
    }

    @Test("load lists channels from the picker and fetches the first channel's analytics")
    func loadListsChannelsAndFetchesFirst() async {
        let api = StubSocialsAPI()
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        await api.setChannelAnalyticsResults([.success([series()])])
        let viewModel = AnalyticsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.channels == [ch])
        #expect(viewModel.selectedChannelId == "int-1")
        #expect(viewModel.series == [series()])
        let calls = await api.channelAnalyticsCalls
        #expect(calls.count == 1)
        #expect(calls[0].0 == "int-1")
        #expect(calls[0].1 == .thirtyDays)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("select records the channel + current range")
    func selectRecordsChannelAndRange() async {
        let api = StubSocialsAPI()
        let ch1 = channel(id: "int-1")
        let ch2 = channel(id: "int-2", name: "Other Page")
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch1, ch2]))])
        await api.setChannelAnalyticsResults([.success([series()]), .success([series()])])
        let viewModel = AnalyticsViewModel(api: api)
        await viewModel.load()

        await viewModel.select(channelId: "int-2")

        let calls = await api.channelAnalyticsCalls
        #expect(calls.count == 2)
        #expect(calls[0].0 == "int-1" && calls[0].1 == .thirtyDays)
        #expect(calls[1].0 == "int-2" && calls[1].1 == .thirtyDays)
        #expect(viewModel.selectedChannelId == "int-2")
    }

    @Test("range change refetches for the selected channel")
    func rangeChangeRefetches() async {
        let api = StubSocialsAPI()
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        await api.setChannelAnalyticsResults([.success([series()]), .success([series()])])
        let viewModel = AnalyticsViewModel(api: api)
        await viewModel.load()

        await viewModel.setRange(.sevenDays)

        let calls = await api.channelAnalyticsCalls
        #expect(calls.count == 2)
        #expect(calls[1].0 == "int-1" && calls[1].1 == .sevenDays)
        #expect(viewModel.range == .sevenDays)
    }

    @Test("analytics failure surfaces an error message")
    func analyticsFailureSurfacesError() async {
        let api = StubSocialsAPI()
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        await api.setChannelAnalyticsResults([.failure(SocialsAPIError.offline)])
        let viewModel = AnalyticsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.series.isEmpty)
    }

    @Test("empty series marks the view model isEmpty")
    func emptySeriesMarksIsEmpty() async {
        let api = StubSocialsAPI()
        let ch = channel()
        await api.setChannelsResults([.success(ChannelsResponse(channels: [ch]))])
        await api.setChannelAnalyticsResults([.success([])])
        let viewModel = AnalyticsViewModel(api: api)

        await viewModel.load()

        #expect(viewModel.isEmpty == true)
    }
}

extension StubSocialsAPI {
    fileprivate func setChannelsResults(_ results: [Result<ChannelsResponse, Error>]) {
        channelsResults = results
    }

    fileprivate func setChannelAnalyticsResults(_ results: [Result<[AnalyticsSeries], Error>]) {
        channelAnalyticsResults = results
    }
}
