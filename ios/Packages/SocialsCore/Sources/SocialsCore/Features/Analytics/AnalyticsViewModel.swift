import Foundation
import Observation

/// Per-channel analytics: loads the connected-channel list for the picker (`api.channels()`),
/// then fetches `AnalyticsSeries` for the selected channel + date range (`api.channelAnalytics`).
/// Mirrors web's `analytics.component.tsx` channel picker + 7/30/90 date selector, one
/// `AnalyticsSeries` per chart card.
@MainActor
@Observable
public final class AnalyticsViewModel {
    public private(set) var channels: [ChannelDTO] = []
    public private(set) var selectedChannelId: String?
    public private(set) var range: AnalyticsRange = .thirtyDays
    public private(set) var series: [AnalyticsSeries] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// `true` once loading has settled and the selected channel has no analytics series.
    public var isEmpty: Bool {
        !isLoading && errorMessage == nil && selectedChannelId != nil && series.isEmpty
    }

    /// Loads the channel picker and, on first load, selects + fetches analytics for the first
    /// connected channel (mirrors web defaulting to the first integration).
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.channels()
            channels = response.channels
            if selectedChannelId == nil, let first = channels.first {
                selectedChannelId = first.internalId
                await refresh()
            }
        } catch {
            errorMessage = "Couldn't load your channels. Please try again."
        }
    }

    /// Selects a channel from the picker and fetches its analytics for the current range.
    public func select(channelId: String) async {
        guard selectedChannelId != channelId else { return }
        selectedChannelId = channelId
        await refresh()
    }

    /// Changes the date window and refetches analytics for the selected channel.
    public func setRange(_ range: AnalyticsRange) async {
        guard self.range != range else { return }
        self.range = range
        await refresh()
    }

    /// Refetches analytics for the currently selected channel + range (retry after an error).
    public func retry() async {
        await refresh()
    }

    private func refresh() async {
        guard let selectedChannelId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            series = try await api.channelAnalytics(integrationId: selectedChannelId, range: range)
        } catch {
            errorMessage = "Couldn't load analytics for this channel. Please try again."
        }
    }
}
