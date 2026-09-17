import Foundation
import Testing

@testable import SocialsCore

@Suite("PushPayloadRoute")
struct PushPayloadRouteTests {
    @Test("post.published with no recognizable link falls back to the Calendar tab")
    func postPublishedFallsBackToCalendar() {
        let payload: [AnyHashable: Any] = [
            "kind": "post.published",
            "link": "https://instagram.com/p/abc123",
        ]
        #expect(PushPayloadRoute.route(from: payload) == .tab(.calendar))
    }

    @Test("post.failed with no link falls back to the Calendar tab")
    func postFailedFallsBackToCalendar() {
        let payload: [AnyHashable: Any] = ["kind": "post.failed"]
        #expect(PushPayloadRoute.route(from: payload) == .tab(.calendar))
    }

    @Test("channel.reconnect_needed falls back to the Channels tab")
    func reconnectFallsBackToChannels() {
        let payload: [AnyHashable: Any] = ["kind": "channel.reconnect_needed"]
        #expect(PushPayloadRoute.route(from: payload) == .tab(.channels))
    }

    @Test("a link that resolves to a real deep link wins over the kind-based fallback")
    func recognizedLinkWinsOverFallback() {
        let payload: [AnyHashable: Any] = [
            "kind": "post.published",
            "link": "cuantosocials://post/post-9",
        ]
        #expect(PushPayloadRoute.route(from: payload) == .postDetail(postId: "post-9", retryOnOpen: false))
    }

    @Test("unknown kind and no recognizable link yields no route")
    func unknownKindYieldsNoRoute() {
        let payload: [AnyHashable: Any] = ["kind": "something.else"]
        #expect(PushPayloadRoute.route(from: payload) == nil)
    }

    @Test("payload with neither kind nor link yields no route")
    func emptyPayloadYieldsNoRoute() {
        #expect(PushPayloadRoute.route(from: [:]) == nil)
    }
}
