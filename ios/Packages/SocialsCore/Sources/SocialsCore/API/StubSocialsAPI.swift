import Foundation

/// Scripted `SocialsAPI` test double: each method pops the next queued `Result` and
/// records the call it received, so feature/UI tests can drive success/failure paths
/// without a real `APIClient`. Public (not `@testable`) so app-level feature tests can use it.
public actor StubSocialsAPI: SocialsAPI {
    public enum StubError: Error, Sendable, Equatable {
        case notScripted(String)
    }

    public init() {}

    private func next<T>(_ queue: inout [Result<T, Error>], _ method: String) throws -> T {
        guard !queue.isEmpty else { throw StubError.notScripted(method) }
        return try queue.removeFirst().get()
    }

    // MARK: - Auth

    public var loginResults: [Result<MobileAuthResponse, Error>] = []
    public private(set) var loginCalls: [LoginRequest] = []
    public func login(_ body: LoginRequest) async throws -> MobileAuthResponse {
        loginCalls.append(body)
        return try next(&loginResults, "login")
    }

    public var registerResults: [Result<RegisterResult, Error>] = []
    public private(set) var registerCalls: [RegisterRequest] = []
    public func register(_ body: RegisterRequest) async throws -> RegisterResult {
        registerCalls.append(body)
        return try next(&registerResults, "register")
    }

    public var refreshResults: [Result<MobileTokens, Error>] = []
    public private(set) var refreshCalls: [RefreshRequest] = []
    public func refresh(_ body: RefreshRequest) async throws -> MobileTokens {
        refreshCalls.append(body)
        return try next(&refreshResults, "refresh")
    }

    public var logoutResults: [Result<OkResponse, Error>] = []
    public private(set) var logoutCalls: [LogoutRequest] = []
    public func logout(_ body: LogoutRequest) async throws -> OkResponse {
        logoutCalls.append(body)
        return try next(&logoutResults, "logout")
    }

    public var signInWithAppleResults: [Result<MobileAuthResponse, Error>] = []
    public private(set) var signInWithAppleCalls: [AppleNativeRequest] = []
    public func signInWithApple(_ body: AppleNativeRequest) async throws -> MobileAuthResponse {
        signInWithAppleCalls.append(body)
        return try next(&signInWithAppleResults, "signInWithApple")
    }

    public var oauthStartResults: [Result<OAuthStartResponse, Error>] = []
    public private(set) var oauthStartCalls: [OAuthStartRequest] = []
    public func oauthStart(_ body: OAuthStartRequest) async throws -> OAuthStartResponse {
        oauthStartCalls.append(body)
        return try next(&oauthStartResults, "oauthStart")
    }

    public var oauthExchangeResults: [Result<MobileAuthResponse, Error>] = []
    public private(set) var oauthExchangeCalls: [OAuthExchangeRequest] = []
    public func oauthExchange(_ body: OAuthExchangeRequest) async throws -> MobileAuthResponse {
        oauthExchangeCalls.append(body)
        return try next(&oauthExchangeResults, "oauthExchange")
    }

    public var configResults: [Result<ConfigResponse, Error>] = []
    public private(set) var configCallCount = 0
    public func config() async throws -> ConfigResponse {
        configCallCount += 1
        return try next(&configResults, "config")
    }

    // MARK: - Account

    public var meResults: [Result<MeResponse, Error>] = []
    public private(set) var meCallCount = 0
    public func me() async throws -> MeResponse {
        meCallCount += 1
        return try next(&meResults, "me")
    }

    public var devicesResults: [Result<DevicesResponse, Error>] = []
    public private(set) var devicesCallCount = 0
    public func devices() async throws -> DevicesResponse {
        devicesCallCount += 1
        return try next(&devicesResults, "devices")
    }

    public var deleteDeviceResults: [Result<OkResponse, Error>] = []
    public private(set) var deleteDeviceCalls: [String] = []
    public func deleteDevice(_ id: String) async throws -> OkResponse {
        deleteDeviceCalls.append(id)
        return try next(&deleteDeviceResults, "deleteDevice")
    }

    public var channelsResults: [Result<ChannelsResponse, Error>] = []
    public private(set) var channelsCallCount = 0
    public func channels() async throws -> ChannelsResponse {
        channelsCallCount += 1
        return try next(&channelsResults, "channels")
    }

    // MARK: - Posts

    public var postsResults: [Result<PostsResponse, Error>] = []
    public private(set) var postsCalls: [(from: String, to: String, customer: String?)] = []
    public func posts(from: String, to: String, customer: String?) async throws -> PostsResponse {
        postsCalls.append((from: from, to: to, customer: customer))
        return try next(&postsResults, "posts")
    }

    public var postResults: [Result<PostGroupDTO, Error>] = []
    public private(set) var postCalls: [String] = []
    public func post(group: String) async throws -> PostGroupDTO {
        postCalls.append(group)
        return try next(&postResults, "post")
    }

    public var createPostResults: [Result<PostGroupDTO, Error>] = []
    public private(set) var createPostCalls: [(body: CreatePostBody, key: IdempotencyKey?)] = []
    public func createPost(body: CreatePostBody, key: IdempotencyKey?) async throws
        -> PostGroupDTO
    {
        createPostCalls.append((body: body, key: key))
        return try next(&createPostResults, "createPost")
    }

    public var updatePostResults: [Result<PostGroupDTO, Error>] = []
    public private(set) var updatePostCalls:
        [(group: String, body: CreatePostBody, key: IdempotencyKey?)] = []
    public func updatePost(group: String, body: CreatePostBody, key: IdempotencyKey?) async throws
        -> PostGroupDTO
    {
        updatePostCalls.append((group: group, body: body, key: key))
        return try next(&updatePostResults, "updatePost")
    }

    public var rescheduleResults: [Result<RescheduleResponse, Error>] = []
    public private(set) var rescheduleCalls: [(group: String, date: String, action: String?)] = []
    public func reschedule(group: String, date: String, action: String?) async throws
        -> RescheduleResponse
    {
        rescheduleCalls.append((group: group, date: date, action: action))
        return try next(&rescheduleResults, "reschedule")
    }

    public var deletePostResults: [Result<OkResponse, Error>] = []
    public private(set) var deletePostCalls: [String] = []
    public func deletePost(group: String) async throws -> OkResponse {
        deletePostCalls.append(group)
        return try next(&deletePostResults, "deletePost")
    }

    // MARK: - Push

    public var upsertPushDeviceResults: [Result<PushDeviceResponse, Error>] = []
    public private(set) var upsertPushDeviceCalls: [PushDeviceUpsert] = []
    public func upsertPushDevice(_ body: PushDeviceUpsert) async throws -> PushDeviceResponse {
        upsertPushDeviceCalls.append(body)
        return try next(&upsertPushDeviceResults, "upsertPushDevice")
    }

    public var deletePushDeviceResults: [Result<OkResponse, Error>] = []
    public private(set) var deletePushDeviceCalls: [String] = []
    public func deletePushDevice(token: String) async throws -> OkResponse {
        deletePushDeviceCalls.append(token)
        return try next(&deletePushDeviceResults, "deletePushDevice")
    }

    public var pushPrefsResults: [Result<PushPrefsResponse, Error>] = []
    public private(set) var pushPrefsCalls: [String] = []
    public func pushPrefs(token: String) async throws -> PushPrefsResponse {
        pushPrefsCalls.append(token)
        return try next(&pushPrefsResults, "pushPrefs")
    }

    public var updatePushPrefsResults: [Result<PushPrefsResponse, Error>] = []
    public private(set) var updatePushPrefsCalls: [PushPrefsUpdateRequest] = []
    public func updatePushPrefs(_ body: PushPrefsUpdateRequest) async throws -> PushPrefsResponse {
        updatePushPrefsCalls.append(body)
        return try next(&updatePushPrefsResults, "updatePushPrefs")
    }

    // MARK: - AI

    public var aiCreditsResults: [Result<AICreditsResponse, Error>] = []
    public private(set) var aiCreditsCalls: [String] = []
    public func aiCredits(type: String) async throws -> AICreditsResponse {
        aiCreditsCalls.append(type)
        return try next(&aiCreditsResults, "aiCredits")
    }

    public var aiGenerateImageResults: [Result<AIMediaResult, Error>] = []
    public private(set) var aiGenerateImageCalls: [String] = []
    public func aiGenerateImage(prompt: String) async throws -> AIMediaResult {
        aiGenerateImageCalls.append(prompt)
        return try next(&aiGenerateImageResults, "aiGenerateImage")
    }

    public var aiGenerateVideoResults: [Result<AIMediaResult, Error>] = []
    public private(set) var aiGenerateVideoCalls: [AIVideoRequest] = []
    public func aiGenerateVideo(_ body: AIVideoRequest) async throws -> AIMediaResult {
        aiGenerateVideoCalls.append(body)
        return try next(&aiGenerateVideoResults, "aiGenerateVideo")
    }
}
