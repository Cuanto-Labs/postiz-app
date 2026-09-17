import CuantoNet
import CuantoTesting
import Foundation
import HTTPTypes
import Testing

@testable import SocialsCore

/// Drives every `SocialsEndpoints` builder through a real `APIClient` + scripted
/// `MockTransport`, asserting on the request `APIClient` actually sent.
@Suite("SocialsEndpoints")
struct EndpointTests {
    private static let showorgHeader = HTTPField.Name("showorg")!

    private func makeClient(_ transport: MockTransport) -> APIClient {
        APIClient(baseURL: .fixture("https://api.socials.cuantolabs.com"), transport: transport)
    }

    private func bodyKeys(_ data: Data?) throws -> Set<String> {
        guard let data else { return [] }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set(object.map { Array($0.keys) } ?? [])
    }

    // MARK: - Auth (public)

    @Test("login: POST, public, JSON body")
    func login() async throws {
        let endpoint = try SocialsEndpoints.login(
            LoginRequest(email: "e@x.com", password: "pw", deviceId: "d1", deviceName: nil))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(
            json: MobileAuthResponse(
                accessToken: "a", refreshToken: "r", expiresIn: 900, sessionId: "s1",
                user: MobileUser(id: "u1", email: "e@x.com", name: nil, lastName: nil, pictureId: nil),
                orgs: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/auth/login")
        #expect(try bodyKeys(recorded.body) == ["email", "password", "deviceId", "deviceName"])
    }

    @Test("register: POST, public")
    func register() async throws {
        let endpoint = try SocialsEndpoints.register(
            RegisterRequest(email: "e@x.com", password: "pw", deviceId: "d1", deviceName: "iPhone"))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(json: RegisterResult.activate)
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/auth/register")
    }

    @Test("refresh: POST, public")
    func refresh() async throws {
        let endpoint = try SocialsEndpoints.refresh(RefreshRequest(refreshToken: "rt"))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(
            json: MobileTokens(accessToken: "a", refreshToken: "r", expiresIn: 900, sessionId: "s1"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/auth/refresh")
        #expect(try bodyKeys(recorded.body) == ["refreshToken"])
    }

    @Test("logout: POST, public")
    func logout() async throws {
        let endpoint = try SocialsEndpoints.logout(LogoutRequest(refreshToken: "rt"))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/auth/logout")
    }

    @Test("appleNative: POST, public")
    func appleNative() async throws {
        let endpoint = try SocialsEndpoints.appleNative(
            AppleNativeRequest(identityToken: "tok", deviceId: "d1", deviceName: nil, fullName: nil))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(
            json: MobileAuthResponse(
                accessToken: "a", refreshToken: "r", expiresIn: 900, sessionId: "s1",
                user: MobileUser(id: "u1", email: "e@x.com", name: nil, lastName: nil, pictureId: nil),
                orgs: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/auth/apple/native")
    }

    @Test("oauthStart: POST, public")
    func oauthStart() async throws {
        let endpoint = try SocialsEndpoints.oauthStart(
            OAuthStartRequest(provider: "google", codeChallenge: String(repeating: "c", count: 43)))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(json: OAuthStartResponse(url: "https://x", state: "st"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/auth/oauth/start")
        #expect(try bodyKeys(recorded.body) == ["provider", "codeChallenge"])
    }

    @Test("oauthExchange: POST, public")
    func oauthExchange() async throws {
        let endpoint = try SocialsEndpoints.oauthExchange(
            OAuthExchangeRequest(
                provider: "google", code: "c", state: "st",
                codeVerifier: String(repeating: "v", count: 43), deviceId: "d1", deviceName: nil))
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(
            json: MobileAuthResponse(
                accessToken: "a", refreshToken: "r", expiresIn: 900, sessionId: "s1",
                user: MobileUser(id: "u1", email: "e@x.com", name: nil, lastName: nil, pictureId: nil),
                orgs: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/auth/oauth/exchange")
    }

    @Test("config: GET, public")
    func config() async throws {
        let endpoint = SocialsEndpoints.config()
        #expect(endpoint.requiresAuth == false)

        let transport = MockTransport()
        try await transport.enqueue(
            json: ConfigResponse(
                minVersion: "1.0", providers: [],
                links: ConfigLinks(support: "s", terms: "t", privacy: "p")))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/config")
    }

    // MARK: - Account (authenticated + showorg)

    @Test("me: GET, authed, sets showorg when orgId given")
    func me() async throws {
        let endpoint = SocialsEndpoints.me(orgId: "org1")
        #expect(endpoint.requiresAuth == true)

        let transport = MockTransport()
        try await transport.enqueue(
            json: MeResponse(
                user: MobileUser(id: "u1", email: "e@x.com", name: nil, lastName: nil, pictureId: nil),
                org: MobileOrg(id: "org1", name: "Org", role: "owner", disabled: false), orgs: [],
                plan: MobilePlan(tier: "free", options: [:]), sessionId: "s1"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.path == "/mobile/v1/me")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("me: no showorg header when orgId is nil")
    func meNoOrg() async throws {
        let endpoint = SocialsEndpoints.me()
        let transport = MockTransport()
        try await transport.enqueue(
            json: MeResponse(
                user: MobileUser(id: "u1", email: "e@x.com", name: nil, lastName: nil, pictureId: nil),
                org: MobileOrg(id: "org1", name: "Org", role: "owner", disabled: false), orgs: [],
                plan: MobilePlan(tier: "free", options: [:]), sessionId: "s1"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.headerFields[Self.showorgHeader] == nil)
    }

    @Test("devices: GET, authed")
    func devices() async throws {
        let endpoint = SocialsEndpoints.devices(orgId: "org1")
        #expect(endpoint.requiresAuth == true)

        let transport = MockTransport()
        try await transport.enqueue(json: DevicesResponse(devices: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/devices")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("deleteDevice: DELETE with id in path")
    func deleteDevice() async throws {
        let endpoint = SocialsEndpoints.deleteDevice("dev1", orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/devices/dev1")
    }

    @Test("channels: GET, authed")
    func channels() async throws {
        let endpoint = SocialsEndpoints.channels(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: ChannelsResponse(channels: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/channels")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    // MARK: - Posts

    @Test("posts: GET with from/to/customer query")
    func posts() async throws {
        let endpoint = SocialsEndpoints.posts(from: "2026-01-01", to: "2026-01-31", customer: "cust1")
        let transport = MockTransport()
        try await transport.enqueue(json: PostsResponse(posts: []))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/posts?"))
        #expect(path.contains("from=2026-01-01"))
        #expect(path.contains("to=2026-01-31"))
        #expect(path.contains("customer=cust1"))
    }

    @Test("post(group): GET with group in path")
    func post() async throws {
        let endpoint = SocialsEndpoints.post("grp1")
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostGroupDTO(id: "grp1", group: "grp1", publishDate: nil, status: nil, integration: nil, content: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/posts/grp1")
    }

    @Test("createPost: POST with Idempotency-Key header and JSON body")
    func createPost() async throws {
        let key = IdempotencyKey()
        let endpoint = try SocialsEndpoints.createPost(
            CreatePostBody(type: "schedule", posts: []), idempotencyKey: key)
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostGroupDTO(id: "g1", group: "g1", publishDate: nil, status: nil, integration: nil, content: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/posts")
        #expect(recorded.request.headerFields[IdempotencyKey.headerName] == key.value)
        // Web `CreatePostDto` contract: `shortLink`/`date`/`tags` are always sent.
        #expect(try bodyKeys(recorded.body) == ["type", "posts", "shortLink", "date", "tags"])
    }

    @Test("updatePost: PUT with group in path and Idempotency-Key header")
    func updatePost() async throws {
        let key = IdempotencyKey()
        let endpoint = try SocialsEndpoints.updatePost(
            "g1", body: CreatePostBody(type: "update", posts: []), idempotencyKey: key)
        let transport = MockTransport()
        try await transport.enqueue(
            json: PostGroupDTO(id: "g1", group: "g1", publishDate: nil, status: nil, integration: nil, content: nil))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/posts/g1")
        #expect(recorded.request.headerFields[IdempotencyKey.headerName] == key.value)
    }

    @Test("reschedule: PATCH date, JSON body")
    func reschedule() async throws {
        let endpoint = try SocialsEndpoints.reschedule("g1", date: "2026-02-01", action: "schedule")
        let transport = MockTransport()
        try await transport.enqueue(json: RescheduleResponse(group: "g1", date: "2026-02-01"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .patch)
        #expect(recorded.request.path == "/mobile/v1/posts/g1/date")
        #expect(try bodyKeys(recorded.body) == ["date", "action"])
    }

    @Test("deletePost: DELETE with group in path")
    func deletePost() async throws {
        let endpoint = SocialsEndpoints.deletePost("g1")
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/posts/g1")
    }

    // MARK: - Push

    @Test("upsertPushDevice: PUT, JSON body")
    func upsertPushDevice() async throws {
        let endpoint = try SocialsEndpoints.upsertPushDevice(
            PushDeviceUpsert(
                apnsToken: "tok", environment: "sandbox", bundleId: nil, locale: nil, timezone: nil,
                prefs: nil))
        let transport = MockTransport()
        try await transport.enqueue(
            json: PushDeviceResponse(
                device: PushDeviceUpsert(
                    apnsToken: "tok", environment: "sandbox", bundleId: nil, locale: nil,
                    timezone: nil, prefs: nil)))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/push/devices")
        #expect(try bodyKeys(recorded.body) == ["apnsToken", "environment"])
    }

    @Test("deletePushDevice: DELETE with token in path")
    func deletePushDevice() async throws {
        let endpoint = SocialsEndpoints.deletePushDevice("tok1")
        let transport = MockTransport()
        try await transport.enqueue(json: OkResponse(ok: true))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/push/devices/tok1")
    }

    @Test("pushPrefs: GET with token query")
    func pushPrefs() async throws {
        let endpoint = SocialsEndpoints.pushPrefs(token: "tok1")
        let transport = MockTransport()
        try await transport.enqueue(json: PushPrefsResponse(prefs: PushPrefs()))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/push/prefs?token=tok1")
    }

    @Test("updatePushPrefs: PUT, JSON body")
    func updatePushPrefs() async throws {
        let endpoint = try SocialsEndpoints.updatePushPrefs(
            PushPrefsUpdateRequest(apnsToken: "tok1", prefs: PushPrefs(values: ["post.published": false])))
        let transport = MockTransport()
        try await transport.enqueue(json: PushPrefsResponse(prefs: PushPrefs()))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/push/prefs")
        #expect(try bodyKeys(recorded.body) == ["apnsToken", "prefs"])
    }

    // MARK: - Channel management

    @Test("customers: GET, authed")
    func customers() async throws {
        let endpoint = SocialsEndpoints.customers(orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: [ChannelCustomer]())
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        #expect(recorded.request.path == "/mobile/v1/channels/customers")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("updateChannelCustomerName: PUT with id in path, JSON body")
    func updateChannelCustomerName() async throws {
        let endpoint = try SocialsEndpoints.updateChannelCustomerName(
            "ch1", body: ChannelCustomerNameRequest(name: "New Name"))
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/customer-name")
        #expect(try bodyKeys(recorded.body) == ["name"])
    }

    @Test("updateChannelGroup: PUT with id in path, JSON body")
    func updateChannelGroup() async throws {
        let endpoint = try SocialsEndpoints.updateChannelGroup(
            "ch1", body: ChannelGroupRequest(group: "team-a"))
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .put)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/group")
        #expect(try bodyKeys(recorded.body) == ["group"])
    }

    @Test("setChannelTimes: POST with id in path, JSON body")
    func setChannelTimes() async throws {
        let endpoint = try SocialsEndpoints.setChannelTimes(
            "ch1", body: ChannelTimeRequest(time: [ChannelTimeSlot(time: 540)]))
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/time")
        #expect(try bodyKeys(recorded.body) == ["time"])
    }

    @Test("updateChannelSettings: POST with id in path, JSON body")
    func updateChannelSettings() async throws {
        let endpoint = try SocialsEndpoints.updateChannelSettings(
            "ch1", body: ChannelSettingsRequest(additionalSettings: "[]"))
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/settings")
        #expect(try bodyKeys(recorded.body) == ["additionalSettings"])
    }

    @Test("channelMentions: POST /channels/mentions, JSON body")
    func channelMentions() async throws {
        let endpoint = try SocialsEndpoints.channelMentions(
            ChannelFunctionRequest(name: "mentions", id: "ch1", data: "{\"query\":\"a\"}"))
        let transport = MockTransport()
        try await transport.enqueue(
            json: ChannelMentionsResult(mentions: [ChannelMentionDTO(id: "u1", image: nil, label: "A")]))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/mentions")
        #expect(try bodyKeys(recorded.body) == ["name", "id", "data"])
    }

    @Test("channelFunction: POST /channels/function, JSON body")
    func channelFunction() async throws {
        let endpoint = try SocialsEndpoints.channelFunction(
            ChannelFunctionRequest(name: "someFn", id: "ch1"))
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/function")
    }

    @Test("disableChannel: POST with id in path")
    func disableChannel() async throws {
        let endpoint = SocialsEndpoints.disableChannel("ch1", orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/disable")
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    @Test("enableChannel: POST with id in path")
    func enableChannel() async throws {
        let endpoint = SocialsEndpoints.enableChannel("ch1")
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .post)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1/enable")
    }

    @Test("deleteChannel: DELETE with id in path")
    func deleteChannel() async throws {
        let endpoint = SocialsEndpoints.deleteChannel("ch1")
        let transport = MockTransport()
        try await transport.enqueue(json: "ok")
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .delete)
        #expect(recorded.request.path == "/mobile/v1/channels/ch1")
    }

    @Test("connectChannel: GET with refresh/externalUrl query")
    func connectChannel() async throws {
        let endpoint = SocialsEndpoints.connectChannel(
            "instagram", refresh: "1", externalUrl: "https://ex.com", orgId: "org1")
        let transport = MockTransport()
        try await transport.enqueue(json: ChannelConnectResponse(url: "https://auth", state: "st1"))
        _ = try await makeClient(transport).send(endpoint)

        let recorded = await transport.recordedRequests.last!
        #expect(recorded.request.method == .get)
        let path = try #require(recorded.request.path)
        #expect(path.hasPrefix("/mobile/v1/channels/connect/instagram?"))
        #expect(path.contains("refresh=1"))
        #expect(path.contains("externalUrl=https"))
        #expect(recorded.request.headerFields[Self.showorgHeader] == "org1")
    }

    // MARK: - IdempotencyKey

    @Test("IdempotencyKey(): UUID-based, 36 chars")
    func idempotencyKeyGenerated() {
        #expect(IdempotencyKey().value.count == 36)
    }

    @Test("IdempotencyKey(rawValue:) enforces 8...128")
    func idempotencyKeyRawValue() {
        #expect(IdempotencyKey(rawValue: "short") == nil)
        #expect(IdempotencyKey(rawValue: String(repeating: "x", count: 129)) == nil)
        #expect(IdempotencyKey(rawValue: "12345678")?.value == "12345678")
        #expect(IdempotencyKey(rawValue: String(repeating: "x", count: 128)) != nil)
    }
}
