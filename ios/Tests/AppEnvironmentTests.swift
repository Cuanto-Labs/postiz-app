import Testing
import Foundation
@testable import CuantoSocials
import SocialsCore

// Composition-root smoke test: `AppEnvironment.preview()` must construct without touching the
// real Keychain/network, and the update gate must read the installed bundle version as `.ok`
// against a trivially-satisfied minimum.
@Suite("App environment")
struct AppEnvironmentTests {
    @Test @MainActor func previewConstructs() async {
        _ = await AppEnvironment.preview()
    }

    @Test func updateGateOkForInstalledVersion() {
        let decision = UpdateGate.evaluate(
            minVersion: "1.0.0", installed: AppVersion.installed(bundle: .main))
        #expect(decision == .ok)
    }
}
