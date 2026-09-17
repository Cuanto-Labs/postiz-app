import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

/// Named JSON fixtures bundled under `Fixtures/` in this test target.
public enum Fixture: String {
    case config
    case authLogin = "auth_login"
    case me
    case channels
    case posts

    /// Decodes this fixture's JSON into `T` via `JSONFixture`.
    func decode<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        try JSONFixture.decode(rawValue, as: type, bundle: .module)
    }
}

extension MockTransport {
    /// Queues a named `Fixture`'s JSON as the next response body.
    public func enqueue(_ fixture: Fixture, status: Int = 200) throws {
        try enqueueFixture(fixture.rawValue, status: status, bundle: .module)
    }
}

@Suite("Fixtures decode into m8-dtos types")
struct FixtureTests {

    @Test("auth_login.json decodes into MobileAuthResponse with 2 orgs")
    func authLoginFixture() throws {
        let value: MobileAuthResponse = try Fixture.authLogin.decode()
        #expect(value.orgs.count == 2)
        #expect(value.orgs.contains { $0.disabled == false })
    }

    @Test("me.json decodes into MeResponse")
    func meFixture() throws {
        let value: MeResponse = try Fixture.me.decode()
        #expect(value.orgs.count == 2)
        #expect(!value.plan.tier.isEmpty)
    }

    @Test("channels.json decodes into ChannelsResponse with 3 channels")
    func channelsFixture() throws {
        let value: ChannelsResponse = try Fixture.channels.decode()
        #expect(value.channels.count == 3)
        #expect(value.channels.contains { $0.identifier == "x" && $0.refreshNeeded })
        #expect(value.channels.contains { $0.disabled })
        let limits = Set(value.channels.map { $0.limits.maxCharacters })
        #expect(limits.count == 3)
    }

    @Test("posts.json decodes into PostsResponse with 3 post groups")
    func postsFixture() throws {
        let value: PostsResponse = try Fixture.posts.decode()
        #expect(value.posts.count == 3)
        let statuses = Set(value.posts.compactMap { $0.status })
        #expect(statuses == ["scheduled", "published", "failed"])
    }
}
