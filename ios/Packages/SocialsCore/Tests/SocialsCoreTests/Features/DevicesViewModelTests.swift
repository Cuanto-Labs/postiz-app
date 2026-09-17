import Foundation
import Testing

@testable import SocialsCore

@Suite("DevicesViewModel")
@MainActor
struct DevicesViewModelTests {

    private func session(id: String, current: Bool) -> MobileSession {
        MobileSession(
            id: id, deviceId: "dev-\(id)", deviceName: "iPhone", createdAt: "2026-01-01T00:00:00Z",
            lastUsedAt: "2026-01-02T00:00:00Z", expiresAt: "2026-02-01T00:00:00Z", current: current)
    }

    private func makeSessionStore() async -> SessionStore {
        await SessionStore(keychain: .ephemeral()) { _ in
            MobileTokens(accessToken: "n", refreshToken: "n", expiresIn: 1, sessionId: "s")
        }
    }

    @Test("load populates devices and marks the current session")
    func loadMarksCurrentSession() async {
        let api = StubSocialsAPI()
        let devices = [session(id: "sess-1", current: true), session(id: "sess-2", current: false)]
        await api.setDevicesResults([.success(DevicesResponse(devices: devices))])
        let sessionStore = await makeSessionStore()
        let viewModel = DevicesViewModel(api: api, sessionStore: sessionStore)

        await viewModel.load()

        #expect(viewModel.devices.map(\.id) == ["sess-1", "sess-2"])
        #expect(viewModel.devices.first(where: { $0.id == "sess-1" })?.current == true)
        #expect(viewModel.devices.first(where: { $0.id == "sess-2" })?.current == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("revoke deletes the device and reloads without signing out for a non-current device")
    func revokeNonCurrentDevice() async {
        let api = StubSocialsAPI()
        let devices = [session(id: "sess-1", current: true), session(id: "sess-2", current: false)]
        await api.setDevicesResults([.success(DevicesResponse(devices: devices))])
        await api.setDeleteDeviceResults([.success(OkResponse(ok: true))])
        let sessionStore = await makeSessionStore()
        let authResponse = MobileAuthResponse(
            accessToken: "a", refreshToken: "r", expiresIn: 3600, sessionId: "sess-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: [MobileOrg(id: "org-1", name: "Org One", role: "owner", disabled: false)])
        try? await sessionStore.signIn(authResponse)
        let viewModel = DevicesViewModel(api: api, sessionStore: sessionStore)
        await viewModel.load()
        await api.setDevicesResults([.success(DevicesResponse(devices: [devices[0]]))])

        await viewModel.revoke(id: "sess-2")

        let calls = await api.deleteDeviceCalls
        #expect(calls == ["sess-2"])
        #expect(viewModel.devices.map(\.id) == ["sess-1"])
        let state = await sessionStore.state
        #expect(state != .signedOut)
    }

    @Test("revoking the current device signs out")
    func revokeCurrentDeviceSignsOut() async {
        let api = StubSocialsAPI()
        let devices = [session(id: "sess-1", current: true)]
        await api.setDevicesResults([.success(DevicesResponse(devices: devices))])
        await api.setDeleteDeviceResults([.success(OkResponse(ok: true))])
        let sessionStore = await makeSessionStore()
        let authResponse = MobileAuthResponse(
            accessToken: "a", refreshToken: "r", expiresIn: 3600, sessionId: "sess-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: [MobileOrg(id: "org-1", name: "Org One", role: "owner", disabled: false)])
        try? await sessionStore.signIn(authResponse)
        let viewModel = DevicesViewModel(api: api, sessionStore: sessionStore)
        await viewModel.load()
        await api.setDevicesResults([.success(DevicesResponse(devices: []))])

        await viewModel.revoke(id: "sess-1")

        let calls = await api.deleteDeviceCalls
        #expect(calls == ["sess-1"])
        let state = await sessionStore.state
        #expect(state == .signedOut)
    }
}

extension StubSocialsAPI {
    fileprivate func setDevicesResults(_ results: [Result<DevicesResponse, Error>]) {
        devicesResults = results
    }

    fileprivate func setDeleteDeviceResults(_ results: [Result<OkResponse, Error>]) {
        deleteDeviceResults = results
    }
}
