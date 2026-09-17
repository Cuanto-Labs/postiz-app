import Foundation
import Testing

@testable import SocialsCore

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

private func encodeString<T: Encodable>(_ value: T) throws -> Data {
    try JSONEncoder().encode(value)
}

@Suite("DTOs mirror MOBILE-API.md")
struct DTOTests {

    // MARK: Auth

    @Test("MobileTokens decodes")
    func mobileTokens() throws {
        let value = try decode(
            MobileTokens.self,
            """
            {"accessToken":"a","refreshToken":"r","expiresIn":900,"sessionId":"s1"}
            """)
        #expect(value == MobileTokens(accessToken: "a", refreshToken: "r", expiresIn: 900, sessionId: "s1"))
    }

    @Test("MobileAuthResponse decodes with optional user fields")
    func mobileAuthResponse() throws {
        let value = try decode(
            MobileAuthResponse.self,
            """
            {
              "accessToken":"a","refreshToken":"r","expiresIn":900,"sessionId":"s1",
              "user":{"id":"u1","email":"e@x.com","name":null,"lastName":null,"pictureId":null},
              "orgs":[{"id":"o1","name":"Org","role":"owner","disabled":false}]
            }
            """)
        #expect(value.user.id == "u1")
        #expect(value.orgs.first?.role == "owner")
    }

    @Test("RegisterResult decodes the activate shape")
    func registerResultActivate() throws {
        let value = try decode(RegisterResult.self, #"{"activate":true}"#)
        #expect(value == .activate)
    }

    @Test("RegisterResult decodes the authenticated shape")
    func registerResultAuthenticated() throws {
        let json = """
            {
              "accessToken":"a","refreshToken":"r","expiresIn":900,"sessionId":"s1",
              "user":{"id":"u1","email":"e@x.com","name":"N","lastName":"L","pictureId":"p1"},
              "orgs":[]
            }
            """
        let value = try decode(RegisterResult.self, json)
        guard case .authenticated(let response) = value else {
            Issue.record("expected .authenticated")
            return
        }
        #expect(response.user.name == "N")
    }

    @Test("MeResponse decodes")
    func meResponse() throws {
        let value = try decode(
            MeResponse.self,
            """
            {
              "user":{"id":"u1","email":"e@x.com","name":null,"lastName":null,"pictureId":null},
              "org":{"id":"o1","name":"Org","role":"owner","disabled":false},
              "orgs":[{"id":"o1","name":"Org","role":"owner","disabled":false}],
              "plan":{"tier":"pro","options":{"analytics":true}},
              "sessionId":"s1"
            }
            """)
        #expect(value.plan.tier == "pro")
        #expect(value.plan.options["analytics"] == true)
    }

    @Test("ConfigResponse decodes")
    func configResponse() throws {
        let value = try decode(
            ConfigResponse.self,
            """
            {
              "minVersion":"1.0.0",
              "providers":[{"identifier":"google","name":"Google"}],
              "links":{"support":"https://s","terms":"https://t","privacy":"https://p"}
            }
            """)
        #expect(value.providers.first?.identifier == "google")
    }

    @Test("DevicesResponse decodes")
    func devicesResponse() throws {
        let value = try decode(
            DevicesResponse.self,
            """
            {"devices":[{"id":"d1","deviceId":"dev1","deviceName":null,"createdAt":"2026-01-01T00:00:00Z","lastUsedAt":"2026-01-01T00:00:00Z","expiresAt":"2026-03-01T00:00:00Z","current":true}]}
            """)
        #expect(value.devices.first?.current == true)
    }

    @Test("OkResponse decodes")
    func okResponse() throws {
        let value = try decode(OkResponse.self, #"{"ok":true}"#)
        #expect(value.ok)
    }

    @Test("Auth request bodies round-trip encode")
    func requestBodiesEncode() throws {
        let login = LoginRequest(email: "e@x.com", password: "pw", deviceId: "d1", deviceName: nil)
        let loginData = try encodeString(login)
        #expect(try decode(LoginRequest.self, String(decoding: loginData, as: UTF8.self)) == login)

        let register = RegisterRequest(email: "e@x.com", password: "pw", deviceId: "d1", deviceName: "iPhone")
        #expect(try decode(RegisterRequest.self, String(decoding: encodeString(register), as: UTF8.self)) == register)

        let refresh = RefreshRequest(refreshToken: "r1")
        #expect(try decode(RefreshRequest.self, String(decoding: encodeString(refresh), as: UTF8.self)) == refresh)

        let logout = LogoutRequest(refreshToken: "r1")
        #expect(try decode(LogoutRequest.self, String(decoding: encodeString(logout), as: UTF8.self)) == logout)

        let apple = AppleNativeRequest(identityToken: "tok", deviceId: "d1", deviceName: nil, fullName: "F L")
        #expect(try decode(AppleNativeRequest.self, String(decoding: encodeString(apple), as: UTF8.self)) == apple)

        let oauthStart = OAuthStartRequest(provider: "google", codeChallenge: String(repeating: "a", count: 43))
        #expect(try decode(OAuthStartRequest.self, String(decoding: encodeString(oauthStart), as: UTF8.self)) == oauthStart)

        let oauthStartResponse = try decode(OAuthStartResponse.self, #"{"url":"https://u","state":"st"}"#)
        #expect(oauthStartResponse.state == "st")

        let oauthExchange = OAuthExchangeRequest(
            provider: "google", code: "c", state: "st", codeVerifier: String(repeating: "b", count: 43),
            deviceId: "d1", deviceName: nil)
        #expect(
            try decode(OAuthExchangeRequest.self, String(decoding: encodeString(oauthExchange), as: UTF8.self))
                == oauthExchange)
    }

    // MARK: Channels

    @Test("ChannelDTO decodes with nested customer and limits")
    func channelDTO() throws {
        let value = try decode(
            ChannelDTO.self,
            """
            {
              "id":"c1","internalId":"i1","name":"My Page","identifier":"facebook",
              "picture":"https://p","disabled":false,"refreshNeeded":false,"inBetweenSteps":false,
              "display":"profile-handle","type":"page",
              "customer":{"id":"cu1","name":"Acme","orgId":"o1","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","deletedAt":null},
              "limits":{"maxCharacters":280,"editor":"markdown"}
            }
            """)
        #expect(value.customer?.name == "Acme")
        #expect(value.limits.maxCharacters == 280)
    }

    @Test("ChannelDTO decodes with null optionals")
    func channelDTONulls() throws {
        let value = try decode(
            ChannelDTO.self,
            """
            {
              "id":"c1","internalId":"i1","name":"My Page","identifier":"facebook",
              "picture":null,"disabled":true,"refreshNeeded":true,"inBetweenSteps":true,
              "display":null,"type":null,"customer":null,
              "limits":{"maxCharacters":null,"editor":null}
            }
            """)
        #expect(value.customer == nil)
        #expect(value.limits.maxCharacters == nil)
    }

    @Test("ChannelsResponse decodes")
    func channelsResponse() throws {
        let value = try decode(ChannelsResponse.self, #"{"channels":[]}"#)
        #expect(value.channels.isEmpty)
    }

    @Test("PushDeviceUpsert round-trips with prefs")
    func pushDeviceUpsert() throws {
        var prefs = PushPrefs()
        prefs[PushPrefs.postPublished] = true
        prefs[PushPrefs.postFailed] = false
        prefs[PushPrefs.channelReconnectNeeded] = true
        let upsert = PushDeviceUpsert(
            apnsToken: "tok", environment: "sandbox", bundleId: "com.x", locale: "en_US",
            timezone: "America/New_York", prefs: prefs)
        let round = try decode(PushDeviceUpsert.self, String(decoding: encodeString(upsert), as: UTF8.self))
        #expect(round == upsert)
        #expect(round.prefs?[PushPrefs.postPublished] == true)
    }

    // MARK: Posts

    @Test("PostGroupDTO decodes canonical keys and ignores unknown keys")
    func postGroupCanonical() throws {
        let value = try decode(
            PostGroupDTO.self,
            """
            {
              "id":"p1","group":"g1","publishDate":"2026-01-01T00:00:00Z","status":"QUEUE",
              "integration":{"id":"i1","name":"Page","picture":null,"providerIdentifier":"facebook"},
              "content":"hello world",
              "somethingUnknown":{"nested":true}
            }
            """)
        #expect(value.id == "p1")
        #expect(value.status == "QUEUE")
        #expect(value.integration?.providerIdentifier == "facebook")
        if case .string(let text) = value.content {
            #expect(text == "hello world")
        } else {
            Issue.record("expected .string content")
        }
    }

    @Test("PostGroupDTO tolerates state/channel aliases and array content")
    func postGroupAliases() throws {
        let value = try decode(
            PostGroupDTO.self,
            """
            {
              "group":"g1","state":"DRAFT",
              "channel":{"id":"i1","name":"Page","picture":null,"providerIdentifier":"instagram"},
              "content":[{"integration":"i1","content":"part one"}]
            }
            """)
        #expect(value.status == "DRAFT")
        #expect(value.integration?.providerIdentifier == "instagram")
        if case .items(let items) = value.content {
            #expect(items.first?.content == "part one")
        } else {
            Issue.record("expected .items content")
        }
    }

    @Test("PostsResponse decodes a list of groups")
    func postsResponse() throws {
        let value = try decode(
            PostsResponse.self,
            """
            {"posts":[{"id":"p1","group":"g1","status":"QUEUE"},{"id":"p2","group":"g2","status":"DRAFT"}]}
            """)
        #expect(value.posts.count == 2)
    }

    @Test("CreatePostBody round-trips")
    func createPostBody() throws {
        let body = CreatePostBody(
            type: "draft",
            posts: [
                PostGroupDTO(
                    id: nil, group: nil, publishDate: "2026-01-01T00:00:00Z", status: nil,
                    integration: PostIntegrationRef(id: "i1", name: nil, picture: nil, providerIdentifier: "x"),
                    content: .string("hi"))
            ])
        let round = try decode(CreatePostBody.self, String(decoding: encodeString(body), as: UTF8.self))
        #expect(round == body)
    }

    @Test("RescheduleRequest and RescheduleResponse decode")
    func reschedule() throws {
        let request = try decode(RescheduleRequest.self, #"{"date":"2026-02-01T00:00:00Z","action":"schedule"}"#)
        #expect(request.action == "schedule")

        let response = try decode(RescheduleResponse.self, #"{"group":"g1","date":"2026-02-01T00:00:00Z"}"#)
        #expect(response.group == "g1")
    }

    // MARK: Server error parser

    @Test("ServerErrorMessage parses the { msg } shape")
    func serverErrorMsgShape() {
        let data = Data(#"{"msg":"Invalid Idempotency-Key"}"#.utf8)
        #expect(ServerErrorMessage.parse(data) == "Invalid Idempotency-Key")
    }

    @Test("ServerErrorMessage parses the Nest default shape with a string message")
    func serverErrorNestStringMessage() {
        let data = Data(#"{"statusCode":401,"message":"Unauthorized","error":"Unauthorized"}"#.utf8)
        #expect(ServerErrorMessage.parse(data) == "Unauthorized")
    }

    @Test("ServerErrorMessage parses the Nest default shape with an array message")
    func serverErrorNestArrayMessage() {
        let data = Data(#"{"statusCode":400,"message":["email must be an email"],"error":"Bad Request"}"#.utf8)
        #expect(ServerErrorMessage.parse(data) == "email must be an email")
    }

    @Test("ServerErrorMessage falls back to error when message is absent")
    func serverErrorFallsBackToError() {
        let data = Data(#"{"statusCode":403,"error":"Forbidden"}"#.utf8)
        #expect(ServerErrorMessage.parse(data) == "Forbidden")
    }

    @Test("ServerErrorMessage returns nil for unrecognized bodies")
    func serverErrorUnknownShape() {
        let data = Data(#"{"foo":"bar"}"#.utf8)
        #expect(ServerErrorMessage.parse(data) == nil)
    }
}
