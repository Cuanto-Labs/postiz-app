import Foundation
import Observation

/// Drives a single channel's settings sheet: customer assignment (autocomplete against
/// `SocialsAPI.customers()`), moving to a group, the posting-time table, and raw provider
/// preferences. Lives in `SocialsCore` (not the App target) so it's testable with
/// `StubSocialsAPI`, mirroring `ChannelsViewModel`. One instance is scoped to one channel.
@MainActor
@Observable
public final class ChannelSettingsViewModel {
    public let channel: ChannelDTO

    /// All customers on the org, for the autocomplete suggestion list — mirrors web's customer
    /// picker in the channel settings panel.
    public private(set) var customers: [ChannelCustomer] = []
    public private(set) var timeSlots: [Int] = []
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI, channel: ChannelDTO) {
        self.api = api
        self.channel = channel
    }

    /// Suggestions matching `query`, case-insensitive prefix match, mirrors a typical
    /// autocomplete field's filtering.
    public func customerSuggestions(matching query: String) -> [ChannelCustomer] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return customers }
        return customers.filter { $0.name.range(of: trimmed, options: .caseInsensitive) != nil }
    }

    // MARK: - Loading

    public func loadCustomers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            customers = try await api.customers()
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Customer

    public func saveCustomerName(_ name: String) async {
        await save {
            _ = try await self.api.updateChannelCustomerName(
                self.channel.id, body: ChannelCustomerNameRequest(name: name))
        }
    }

    // MARK: - Group

    public func saveGroup(_ group: String) async {
        await save {
            _ = try await self.api.updateChannelGroup(
                self.channel.id, body: ChannelGroupRequest(group: group))
        }
    }

    // MARK: - Time table

    /// Loads the channel's current posting times. `ChannelDTO` doesn't carry them, so the sheet
    /// starts from whatever `setTimeSlots` seeds it with (e.g. a prior save, or none for a fresh
    /// channel) rather than a network round trip — there's no "get times" endpoint.
    public func setTimeSlots(_ slots: [Int]) {
        timeSlots = slots.sorted()
    }

    public func addTimeSlot(minutesFromMidnight: Int) {
        guard !timeSlots.contains(minutesFromMidnight) else { return }
        timeSlots.append(minutesFromMidnight)
        timeSlots.sort()
    }

    public func removeTimeSlot(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where timeSlots.indices.contains(index) {
            timeSlots.remove(at: index)
        }
    }

    public func saveTimeSlots() async {
        await save {
            let body = ChannelTimeRequest(time: self.timeSlots.map { ChannelTimeSlot(time: $0) })
            _ = try await self.api.setChannelTimes(self.channel.id, body: body)
        }
    }

    // MARK: - Provider preferences

    public func saveProviderSettings(additionalSettings: String) async {
        await save {
            _ = try await self.api.updateChannelSettings(
                self.channel.id,
                body: ChannelSettingsRequest(additionalSettings: additionalSettings))
        }
    }

    // MARK: - Shared execution + error mapping

    private func save(_ operation: @escaping () async throws -> Void) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await operation()
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .notFound: return "That channel couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }
}
