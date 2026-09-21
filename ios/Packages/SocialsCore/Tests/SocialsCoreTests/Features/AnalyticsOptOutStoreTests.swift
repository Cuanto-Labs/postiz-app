import Foundation
import Testing

@testable import SocialsCore

@Suite("AnalyticsOptOutStore")
@MainActor
struct AnalyticsOptOutStoreTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AnalyticsOptOutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("defaults to opted-in")
    func defaultsToOptedIn() {
        let store = AnalyticsOptOutStore(defaults: makeDefaults())

        #expect(store.isOptedOut == false)
    }

    @Test("setOptedOut persists across a second store instance on the same suite")
    func persistsAcrossInstances() {
        let defaults = makeDefaults()
        let store = AnalyticsOptOutStore(defaults: defaults)

        store.setOptedOut(true)

        let second = AnalyticsOptOutStore(defaults: defaults)
        #expect(second.isOptedOut == true)
    }

    @Test("observer closure fires on change")
    func observerFires() {
        let store = AnalyticsOptOutStore(defaults: makeDefaults())
        var observed: Bool?
        store.observe { value in observed = value }

        store.setOptedOut(true)

        #expect(observed == true)
    }
}
