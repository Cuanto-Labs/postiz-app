import Foundation
import Observation

/// Drives the post-sign-up onboarding flow: a handful of static intro panels, followed by a
/// "pick your first channel" step that lists the connectable providers from
/// `SocialsAPI.config()`. Lives in `SocialsCore` (not the App target) so it's testable with
/// `StubSocialsAPI`, mirroring `RegisterViewModel`. Actually starting a connection
/// (`SocialsAPI.connectStart`) is a later task's concern — this type only surfaces the
/// provider list and tracks which one the user picked.
@MainActor
@Observable
public final class OnboardingViewModel {
    /// Ordered steps of the flow. `firstChannel` is the only one backed by a network call.
    public enum Panel: Int, CaseIterable, Sendable {
        case welcome
        case schedule
        case analytics
        case firstChannel
    }

    public private(set) var panel: Panel = .welcome
    public private(set) var providers: [ConfigProvider] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var selectedProviderId: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    public var isOnFirstChannelStep: Bool { panel == .firstChannel }
    public var canGoBack: Bool { panel != .welcome }
    public var canFinish: Bool { selectedProviderId != nil }

    /// Moves to the next panel; entering `firstChannel` triggers the (one-shot) provider load.
    public func advance() {
        guard let next = Panel(rawValue: panel.rawValue + 1) else { return }
        panel = next
        if next == .firstChannel, providers.isEmpty, !isLoading {
            Task { await loadProviders() }
        }
    }

    public func back() {
        guard let previous = Panel(rawValue: panel.rawValue - 1) else { return }
        panel = previous
    }

    public func selectProvider(_ id: String) {
        selectedProviderId = id
    }

    public func loadProviders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let config = try await api.config()
            providers = config.providers
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        default: return "Couldn't load channels. Please try again."
        }
    }
}
