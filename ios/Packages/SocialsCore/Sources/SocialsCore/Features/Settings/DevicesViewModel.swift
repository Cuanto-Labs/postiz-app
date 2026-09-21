import Foundation
import Observation

/// Signed-in device/session list: loads from `GET /mobile/v1/devices`, and revokes via
/// `DELETE /mobile/v1/devices/:id`. Each `MobileSession` carries its own `current` flag from the
/// backend, so the view can mark the active session without this VM re-deriving it. Revoking the
/// current device signs the user out locally (the server-side session is already gone).
@MainActor
@Observable
public final class DevicesViewModel {
    public private(set) var devices: [MobileSession] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI
    private let sessionStore: SessionStore

    public init(api: any SocialsAPI, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    /// Refreshes `devices` from the backend. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.devices()
            devices = response.devices
        } catch {
            errorMessage = "Couldn't load your devices. Please try again."
        }
    }

    /// Revokes the device/session with `id`, reloads the list, and — if the revoked device was
    /// the current one — signs out locally.
    public func revoke(id: String) async {
        errorMessage = nil
        let isCurrentDevice = devices.first(where: { $0.id == id })?.current ?? false
        do {
            _ = try await api.deleteDevice(id)
            await load()
            if isCurrentDevice {
                await sessionStore.signOut()
            }
        } catch {
            errorMessage = "Couldn't revoke that device. Please try again."
        }
    }
}
