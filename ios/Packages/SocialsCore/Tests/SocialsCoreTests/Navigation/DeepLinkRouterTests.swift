import Foundation
import Testing

@testable import SocialsCore

@Suite("DeepLinkRouter")
@MainActor
struct DeepLinkRouterTests {
    @Test("custom-scheme post link resolves to postDetail")
    func customSchemePostDetail() {
        let router = DeepLinkRouter()
        let handled = router.handle(URL(string: "cuantosocials://post/post-1?retry=1")!)
        #expect(handled)
        #expect(router.pendingRoute == .postDetail(postId: "post-1", retryOnOpen: true))
    }

    @Test("universal link post path resolves to postDetail without retry")
    func universalLinkPostDetail() {
        let router = DeepLinkRouter()
        let handled = router.handle(URL(string: "https://socials.cuantolabs.com/m/post/post-2")!)
        #expect(handled)
        #expect(router.pendingRoute == .postDetail(postId: "post-2", retryOnOpen: false))
    }

    @Test("custom-scheme tab link resolves to the matching tab")
    func customSchemeTab() {
        let router = DeepLinkRouter()
        #expect(router.handle(URL(string: "cuantosocials://channels")!))
        #expect(router.pendingRoute == .tab(.channels))
    }

    @Test("channels reconnect link needs both provider and id query items")
    func channelsReconnect() {
        let router = DeepLinkRouter()
        #expect(router.handle(URL(string: "cuantosocials://channels/reconnect?provider=x&id=internal-9")!))
        #expect(router.pendingRoute == .channelsReconnect(provider: "x", internalId: "internal-9"))

        let missingQuery = DeepLinkRouter()
        #expect(!missingQuery.handle(URL(string: "cuantosocials://channels/reconnect")!))
        #expect(missingQuery.pendingRoute == nil)
    }

    @Test("OAuth bounce URLs are parsed to nil, not misrouted")
    func oauthBounceIgnored() {
        let customScheme = DeepLinkRouter()
        #expect(!customScheme.handle(URL(string: "cuantosocials://connected?token=abc")!))
        #expect(customScheme.pendingRoute == nil)

        let universalLink = DeepLinkRouter()
        #expect(!universalLink.handle(URL(string: "https://socials.cuantolabs.com/m/auth/callback")!))
        #expect(universalLink.pendingRoute == nil)
    }

    @Test("unrelated schemes and unknown paths are ignored")
    func unrecognizedURLsIgnored() {
        let router = DeepLinkRouter()
        #expect(!router.handle(URL(string: "mailto:hello@example.com")!))
        #expect(!router.handle(URL(string: "cuantosocials://not-a-real-route")!))
        #expect(!router.handle(URL(string: "https://socials.cuantolabs.com/other/path")!))
        #expect(router.pendingRoute == nil)
    }

    @Test("consume() returns and clears pendingRoute")
    func consumeClearsPendingRoute() {
        let router = DeepLinkRouter()
        router.enqueue(.tab(.analytics))
        #expect(router.consume() == .tab(.analytics))
        #expect(router.pendingRoute == nil)
        #expect(router.consume() == nil)
    }
}
