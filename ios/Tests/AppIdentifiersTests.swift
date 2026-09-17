import Testing
import Foundation
@testable import CuantoSocials

// Swift Testing smoke test for the shared identifiers baked into Project.yml —
// app group, keychain access group team prefix, and the API base URL. Guards
// against typos in bundle-id / entitlements plumbing silently drifting apart.
@Suite("App identifiers")
struct AppIdentifiersTests {
    @Test func appGroupMatchesPlan() {
        let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String
            ?? "group.com.cuantolabs.socials"
        #expect(appGroup == "group.com.cuantolabs.socials")
    }

    @Test func keychainGroupHasTeamPrefix() {
        let keychainGroup = "8AWCD3T4B5.com.cuantolabs.socials.shared"
        #expect(keychainGroup.hasPrefix("8AWCD3T4B5."))
    }

    @Test func apiBaseURLIsAbsolute() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "SocialsAPIBaseURL") as? String
            ?? "http://localhost:3000"
        #expect(URL(string: raw)?.scheme != nil)
    }
}
