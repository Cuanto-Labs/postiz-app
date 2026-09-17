import Foundation
import Observation

/// Failures specific to the channel-connect flow itself (as opposed to `SocialsAPIError`, which
/// covers the network calls it makes).
public enum ChannelConnectError: Error, Sendable, Equatable {
    case cancelled
    case invalidStartURL
}

/// Channels list + connect/reconnect (via `SignInWebAuthenticating`, the same
/// `ASWebAuthenticationSession` abstraction `SignInViewModel` uses for Google) and lifecycle
/// management (disable/enable/delete). Lives in `SocialsCore` (not the App target) so it's
/// testable with `StubSocialsAPI` + a scripted web-auth double, mirroring `SignInViewModel`.
@MainActor
@Observable
public final class ChannelsViewModel {
    public private(set) var channels: [ChannelDTO] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    /// Set while a connect/reconnect/disable/enable/delete is in flight for a specific channel
    /// (by `internalId`), so the row UI can show a spinner without disabling the whole list.
    public private(set) var pendingChannelId: String?

    private let api: any SocialsAPI
    private let webAuth: any SignInWebAuthenticating
    private let callbackURLScheme: String

    public init(
        api: any SocialsAPI,
        webAuth: any SignInWebAuthenticating,
        callbackURLScheme: String
    ) {
        self.api = api
        self.webAuth = webAuth
        self.callbackURLScheme = callbackURLScheme
    }

    // MARK: - List

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.channels()
            channels = response.channels
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Connect / reconnect

    /// Starts the OAuth flow for `provider` (fresh connect), or reconnects an existing channel
    /// when `refresh` is that channel's `internalId` (mirrors web's `menu.tsx` "Reconnect
    /// channel"). On success, reloads the list so the new/refreshed channel shows up.
    public func connect(provider: String, refresh: String? = nil) async {
        pendingChannelId = refresh
        errorMessage = nil
        defer { pendingChannelId = nil }
        do {
            let start = try await api.connectStart(
                provider: provider, refresh: refresh, externalUrl: nil)
            guard let startURL = URL(string: start.url) else {
                throw ChannelConnectError.invalidStartURL
            }
            do {
                _ = try await webAuth.authenticate(
                    url: startURL, callbackURLScheme: callbackURLScheme)
            } catch is CancellationError {
                throw ChannelConnectError.cancelled
            }
            await load()
        } catch is CancellationError {
            // Silent: the user dismissed the system sheet, not a failure worth surfacing.
        } catch let error as ChannelConnectError {
            errorMessage = Self.message(for: error)
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Lifecycle

    public func disable(_ channel: ChannelDTO) async {
        await withPendingChannel(channel) {
            _ = try await self.api.disableChannel(channel.id)
        }
    }

    public func enable(_ channel: ChannelDTO) async {
        await withPendingChannel(channel) {
            _ = try await self.api.enableChannel(channel.id)
        }
    }

    /// Deletes `channel`. Surfaces a dedicated message on HTTP 406 (the backend refuses to
    /// delete a channel with posts still scheduled against it — mirrors web's `menu.tsx`
    /// `deleteIntegration.status === 406` handling) rather than the generic error text.
    public func delete(_ channel: ChannelDTO) async {
        await withPendingChannel(channel) {
            _ = try await self.api.deleteChannel(channel.id)
        }
    }

    private func withPendingChannel(_ channel: ChannelDTO, _ operation: @escaping () async throws -> Void) async {
        pendingChannelId = channel.internalId
        errorMessage = nil
        defer { pendingChannelId = nil }
        do {
            try await operation()
            await load()
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Error mapping

    private static func message(for error: ChannelConnectError) -> String {
        switch error {
        case .cancelled: return ""
        case .invalidStartURL: return "Couldn't start that connection. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .server(let code, let message) where code == 406:
            return message
                ?? "You have to delete all the posts associated with this channel before deleting it."
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .notFound: return "That channel couldn't be found."
        case .cancelled: return ""
        case .unauthorized, .idempotencyConflict, .server, .aiNotInPlan, .aiCreditsExhausted,
            .aiConsentRequired:
            return "Something went wrong. Please try again."
        }
    }
}
