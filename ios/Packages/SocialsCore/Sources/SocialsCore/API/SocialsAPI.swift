import Foundation

/// One async throwing method per mobile-app feature need, hiding `CuantoNet` (`Endpoint`,
/// `APIClient`, `APIError`) behind `SocialsAPIError` so feature code never imports `CuantoNet`
/// directly. `LiveSocialsAPI` is the real, network-backed conformer; `StubSocialsAPI` is a
/// scripted test double.
public protocol SocialsAPI: Sendable {
    // MARK: - Auth

    func login(_ body: LoginRequest) async throws -> MobileAuthResponse
    func register(_ body: RegisterRequest) async throws -> RegisterResult
    func refresh(_ body: RefreshRequest) async throws -> MobileTokens
    func logout(_ body: LogoutRequest) async throws -> OkResponse
    func signInWithApple(_ body: AppleNativeRequest) async throws -> MobileAuthResponse
    func oauthStart(_ body: OAuthStartRequest) async throws -> OAuthStartResponse
    func oauthExchange(_ body: OAuthExchangeRequest) async throws -> MobileAuthResponse
    func config() async throws -> ConfigResponse

    // MARK: - Account

    func me() async throws -> MeResponse
    func devices() async throws -> DevicesResponse
    func deleteDevice(_ id: String) async throws -> OkResponse
    func channels() async throws -> ChannelsResponse

    // MARK: - Channel management (settings, lifecycle, connect, function)

    func customers() async throws -> [ChannelCustomer]
    func updateChannelCustomerName(_ id: String, body: ChannelCustomerNameRequest) async throws
        -> OpaqueJSONResult
    func updateChannelGroup(_ id: String, body: ChannelGroupRequest) async throws
        -> OpaqueJSONResult
    func setChannelTimes(_ id: String, body: ChannelTimeRequest) async throws -> OpaqueJSONResult
    func updateChannelSettings(_ id: String, body: ChannelSettingsRequest) async throws
        -> OpaqueJSONResult
    func channelMentions(_ body: ChannelFunctionRequest) async throws -> ChannelMentionsResult
    func channelFunction(_ body: ChannelFunctionRequest) async throws -> OpaqueJSONResult
    func disableChannel(_ id: String) async throws -> OpaqueJSONResult
    func enableChannel(_ id: String) async throws -> OpaqueJSONResult
    func deleteChannel(_ id: String) async throws -> OpaqueJSONResult
    func connectStart(provider: String, refresh: String?, externalUrl: String?) async throws
        -> ChannelConnectResponse

    // MARK: - Posts

    func posts(from: String, to: String, customer: String?) async throws -> PostsResponse
    func post(group: String) async throws -> PostGroupDTO
    func createPost(body: CreatePostBody, key: IdempotencyKey?) async throws -> PostGroupDTO
    func updatePost(group: String, body: CreatePostBody, key: IdempotencyKey?) async throws
        -> PostGroupDTO
    func reschedule(group: String, date: String, action: String?) async throws
        -> RescheduleResponse
    func deletePost(group: String) async throws -> OkResponse

    // MARK: - Push

    func upsertPushDevice(_ body: PushDeviceUpsert) async throws -> PushDeviceResponse
    func deletePushDevice(token: String) async throws -> OkResponse
    func pushPrefs(token: String) async throws -> PushPrefsResponse
    func updatePushPrefs(_ body: PushPrefsUpdateRequest) async throws -> PushPrefsResponse

    // MARK: - AI

    func aiCredits(type: String) async throws -> AICreditsResponse
    func aiGenerateImage(prompt: String) async throws -> AIMediaResult
    func aiGenerateVideo(_ body: AIVideoRequest) async throws -> AIMediaResult
}

/// Typed errors `SocialsAPI` conformers surface, mapped from `CuantoNet.APIError` + the mobile
/// API's error body shapes (docs/MOBILE-API.md). `.offline`/`.cancelled` pass an underlying
/// `APIError` straight through unchanged.
public enum SocialsAPIError: Error, Sendable, Equatable {
    case unauthorized
    case forbidden(message: String?)
    case notFound(message: String?)
    /// 422 on `createPost`/`updatePost` — the `Idempotency-Key` was already used for a
    /// different request body.
    case idempotencyConflict
    case validation(message: String?)
    case server(code: Int, message: String?)
    case offline
    case cancelled
    /// 402 on AI credits/image/video endpoints — the org's plan doesn't include AI at
    /// all (`Sections.AI` policy check, `SubscriptionException`).
    case aiNotInPlan
    /// 402 on AI credits/image/video endpoints — the org's plan includes AI, but its
    /// image/video generation credits are used up for the current billing period.
    case aiCreditsExhausted
}
