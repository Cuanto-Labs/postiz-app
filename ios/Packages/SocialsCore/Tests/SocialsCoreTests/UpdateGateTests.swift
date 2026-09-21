import Testing
@testable import SocialsCore

@Suite("AppVersion parsing and ordering")
struct AppVersionTests {
    @Test("parses full MAJOR.MINOR.PATCH")
    func parsesFull() {
        let v = AppVersion("1.2.3")
        #expect(v?.major == 1)
        #expect(v?.minor == 2)
        #expect(v?.patch == 3)
    }

    @Test("defaults missing components to 0")
    func defaultsMissingComponents() {
        #expect(AppVersion("2") == AppVersion(major: 2, minor: 0, patch: 0))
        #expect(AppVersion("2.5") == AppVersion(major: 2, minor: 5, patch: 0))
    }

    @Test("tolerates leading v")
    func toleratesLeadingV() {
        #expect(AppVersion("v1.2.3") == AppVersion(major: 1, minor: 2, patch: 3))
    }

    @Test("tolerates build suffix after + or -")
    func toleratesBuildSuffix() {
        #expect(AppVersion("1.2.3+42") == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(AppVersion("1.2.3-beta") == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(AppVersion("v1.2.3-beta+42") == AppVersion(major: 1, minor: 2, patch: 3))
    }

    @Test("returns nil on garbage input")
    func returnsNilOnGarbage() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("not-a-version") == nil)
        #expect(AppVersion("1.2.3.4") == nil)
        #expect(AppVersion("1.x.3") == nil)
        #expect(AppVersion("1..3") == nil)
    }

    @Test("strict numeric ordering, not lexicographic")
    func strictNumericOrdering() {
        #expect(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        #expect(AppVersion("1.0.0")! < AppVersion("1.0.1")!)
        #expect(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
    }

    @Test("equal versions compare equal")
    func equalVersions() {
        #expect(AppVersion("1.2.3") == AppVersion("1.2.3"))
        #expect(!(AppVersion("1.2.3")! < AppVersion("1.2.3")!))
    }

    @Test("description round-trips")
    func descriptionRoundTrips() {
        #expect(AppVersion("1.2.3")?.description == "1.2.3")
    }
}

@Suite("UpdateGate decision")
struct UpdateGateTests {
    @Test("nil minVersion fails open")
    func nilMinVersionFailsOpen() {
        let decision = UpdateGate.evaluate(minVersion: nil, installed: AppVersion(major: 1))
        #expect(decision == .ok)
    }

    @Test("unparsable minVersion fails open")
    func unparsableMinVersionFailsOpen() {
        let decision = UpdateGate.evaluate(minVersion: "garbage", installed: AppVersion(major: 1))
        #expect(decision == .ok)
    }

    @Test("equal versions are ok")
    func equalVersionsAreOk() {
        let decision = UpdateGate.evaluate(minVersion: "1.2.3", installed: AppVersion(major: 1, minor: 2, patch: 3))
        #expect(decision == .ok)
    }

    @Test("installed above minimum is ok")
    func installedAboveMinimumIsOk() {
        let decision = UpdateGate.evaluate(minVersion: "1.2.3", installed: AppVersion(major: 1, minor: 3, patch: 0))
        #expect(decision == .ok)
    }

    @Test("installed below minimum requires update")
    func installedBelowMinimumRequiresUpdate() {
        let decision = UpdateGate.evaluate(minVersion: "2.0.0", installed: AppVersion(major: 1, minor: 5, patch: 0))
        #expect(decision == .updateRequired(minimum: AppVersion(major: 2, minor: 0, patch: 0)))
    }
}
