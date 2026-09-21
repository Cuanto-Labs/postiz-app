import Testing
import CuantoTesting
@testable import SocialsCore

@Suite("SocialsCore package smoke")
struct PackageSmokeTests {
    @Test("config.json fixture loads and is non-empty")
    func loadsConfigFixture() throws {
        let data = try JSONFixture.data("config", bundle: .module)
        #expect(!data.isEmpty)
    }
}
