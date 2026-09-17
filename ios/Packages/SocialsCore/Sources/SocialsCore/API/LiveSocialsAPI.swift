import CuantoNet
import Foundation

/// `SocialsAPI` backed by a real `CuantoNet.APIClient` against `/mobile/v1`
/// (`SocialsEndpoints`). `orgProvider` is asked for the current org id on every
/// authenticated call, which `SocialsEndpoints` turns into a `showorg` header
/// (docs/MOBILE-API.md § Base URL & auth — org selection); return `nil` to omit it.
public final class LiveSocialsAPI: SocialsAPI {
    private let client: APIClient
    private let orgProvider: @Sendable () async -> String?

    public init(
        client: APIClient, orgProvider: @escaping @Sendable () async -> String? = { nil }
    ) {
        self.client = client
        self.orgProvider = orgProvider
    }

    /// Sends `endpoint`, mapping any thrown `APIError` to `SocialsAPIError`.
    private func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        do {
            return try await client.send(endpoint)
        } catch {
            throw Self.mapError(error)
        }
    }

    /// Maps `APIError` (docs/MOBILE-API.md error shapes) to `SocialsAPIError`.
    /// `.offline`/`.cancelled` (and anything not itself an `APIError`) pass through unchanged.
    static func mapError(_ error: Error) -> Error {
        guard let apiError = error as? APIError else { return error }
        switch apiError {
        case .unauthorized:
            return SocialsAPIError.unauthorized
        case .status(let code, let body):
            let message = ServerErrorMessage.parse(body)
            switch code {
            case 400: return SocialsAPIError.validation(message: message)
            case 402: return mapAIPaymentError(body: body, message: message)
            case 403: return SocialsAPIError.forbidden(message: message)
            case 404: return SocialsAPIError.notFound(message: message)
            case 422: return SocialsAPIError.idempotencyConflict
            default: return SocialsAPIError.server(code: code, message: message)
            }
        case .transport, .decoding, .offline, .cancelled:
            return apiError
        }
    }

    /// 402 on AI endpoints is either `SubscriptionException`'s `{section, action}` body
    /// (plan doesn't include AI at all) or a "no credits left" message (plan includes AI,
    /// but its image/video generation credits are used up); anything else falls back to
    /// `.server`.
    private static func mapAIPaymentError(body: Data, message: String?) -> Error {
        struct SubscriptionExceptionBody: Decodable {
            let section: String
        }
        if let decoded = try? JSONDecoder().decode(SubscriptionExceptionBody.self, from: body),
            decoded.section == "ai"
        {
            return SocialsAPIError.aiNotInPlan
        }
        if let message, message.localizedCaseInsensitiveContains("credit") {
            return SocialsAPIError.aiCreditsExhausted
        }
        return SocialsAPIError.server(code: 402, message: message)
    }

    // MARK: - Auth

    public func login(_ body: LoginRequest) async throws -> MobileAuthResponse {
        try await send(SocialsEndpoints.login(body))
    }

    public func register(_ body: RegisterRequest) async throws -> RegisterResult {
        try await send(SocialsEndpoints.register(body))
    }

    public func refresh(_ body: RefreshRequest) async throws -> MobileTokens {
        try await send(SocialsEndpoints.refresh(body))
    }

    public func logout(_ body: LogoutRequest) async throws -> OkResponse {
        try await send(SocialsEndpoints.logout(body))
    }

    public func signInWithApple(_ body: AppleNativeRequest) async throws -> MobileAuthResponse {
        try await send(SocialsEndpoints.appleNative(body))
    }

    public func oauthStart(_ body: OAuthStartRequest) async throws -> OAuthStartResponse {
        try await send(SocialsEndpoints.oauthStart(body))
    }

    public func oauthExchange(_ body: OAuthExchangeRequest) async throws -> MobileAuthResponse {
        try await send(SocialsEndpoints.oauthExchange(body))
    }

    public func config() async throws -> ConfigResponse {
        try await send(SocialsEndpoints.config())
    }

    // MARK: - Account

    public func me() async throws -> MeResponse {
        try await send(SocialsEndpoints.me(orgId: orgProvider()))
    }

    public func devices() async throws -> DevicesResponse {
        try await send(SocialsEndpoints.devices(orgId: orgProvider()))
    }

    public func deleteDevice(_ id: String) async throws -> OkResponse {
        try await send(SocialsEndpoints.deleteDevice(id, orgId: orgProvider()))
    }

    public func channels() async throws -> ChannelsResponse {
        try await send(SocialsEndpoints.channels(orgId: orgProvider()))
    }

    // MARK: - Channel management (settings, lifecycle, connect, function)

    public func customers() async throws -> [ChannelCustomer] {
        try await send(SocialsEndpoints.customers(orgId: orgProvider()))
    }

    public func updateChannelCustomerName(_ id: String, body: ChannelCustomerNameRequest)
        async throws -> OpaqueJSONResult
    {
        try await send(
            SocialsEndpoints.updateChannelCustomerName(id, body: body, orgId: orgProvider()))
    }

    public func updateChannelGroup(_ id: String, body: ChannelGroupRequest) async throws
        -> OpaqueJSONResult
    {
        try await send(SocialsEndpoints.updateChannelGroup(id, body: body, orgId: orgProvider()))
    }

    public func setChannelTimes(_ id: String, body: ChannelTimeRequest) async throws
        -> OpaqueJSONResult
    {
        try await send(SocialsEndpoints.setChannelTimes(id, body: body, orgId: orgProvider()))
    }

    public func updateChannelSettings(_ id: String, body: ChannelSettingsRequest) async throws
        -> OpaqueJSONResult
    {
        try await send(SocialsEndpoints.updateChannelSettings(id, body: body, orgId: orgProvider()))
    }

    public func channelMentions(_ body: ChannelFunctionRequest) async throws
        -> ChannelMentionsResult
    {
        try await send(SocialsEndpoints.channelMentions(body, orgId: orgProvider()))
    }

    public func channelFunction(_ body: ChannelFunctionRequest) async throws -> OpaqueJSONResult {
        try await send(SocialsEndpoints.channelFunction(body, orgId: orgProvider()))
    }

    public func disableChannel(_ id: String) async throws -> OpaqueJSONResult {
        try await send(SocialsEndpoints.disableChannel(id, orgId: orgProvider()))
    }

    public func enableChannel(_ id: String) async throws -> OpaqueJSONResult {
        try await send(SocialsEndpoints.enableChannel(id, orgId: orgProvider()))
    }

    public func deleteChannel(_ id: String) async throws -> OpaqueJSONResult {
        try await send(SocialsEndpoints.deleteChannel(id, orgId: orgProvider()))
    }

    public func connectStart(provider: String, refresh: String?, externalUrl: String?)
        async throws -> ChannelConnectResponse
    {
        try await send(
            SocialsEndpoints.connectChannel(
                provider, refresh: refresh, externalUrl: externalUrl, orgId: orgProvider()))
    }

    // MARK: - Posts

    public func posts(from: String, to: String, customer: String?) async throws -> PostsResponse
    {
        try await send(
            SocialsEndpoints.posts(from: from, to: to, customer: customer, orgId: orgProvider()))
    }

    public func post(group: String) async throws -> PostGroupDTO {
        try await send(SocialsEndpoints.post(group, orgId: orgProvider()))
    }

    public func createPost(body: CreatePostBody, key: IdempotencyKey?) async throws
        -> PostGroupDTO
    {
        try await send(
            SocialsEndpoints.createPost(body, idempotencyKey: key, orgId: orgProvider()))
    }

    public func updatePost(group: String, body: CreatePostBody, key: IdempotencyKey?) async throws
        -> PostGroupDTO
    {
        try await send(
            SocialsEndpoints.updatePost(
                group, body: body, idempotencyKey: key, orgId: orgProvider()))
    }

    public func reschedule(group: String, date: String, action: String?) async throws
        -> RescheduleResponse
    {
        try await send(
            SocialsEndpoints.reschedule(group, date: date, action: action, orgId: orgProvider()))
    }

    public func deletePost(group: String) async throws -> OkResponse {
        try await send(SocialsEndpoints.deletePost(group, orgId: orgProvider()))
    }

    // MARK: - Posts extras

    public func postsList(page: Int?, limit: Int?) async throws -> PostsListResponse {
        try await send(PostsExtrasEndpoints.list(page: page, limit: limit, orgId: orgProvider()))
    }

    public func oldPosts(date: String) async throws -> OldPostsResponse {
        try await send(PostsExtrasEndpoints.old(date: date, orgId: orgProvider()))
    }

    public func findSlot(integrationId: String?) async throws -> FindSlotResponse {
        if let integrationId {
            return try await send(
                PostsExtrasEndpoints.findSlot(integrationId: integrationId, orgId: orgProvider()))
        }
        return try await send(PostsExtrasEndpoints.findSlot(orgId: orgProvider()))
    }

    public func statistics(id: String) async throws -> OpaqueJSONResult {
        try await send(PostsExtrasEndpoints.statistics(id: id, orgId: orgProvider()))
    }

    public func comments(id: String) async throws -> PostCommentsResponse {
        try await send(PostsExtrasEndpoints.comments(id: id, orgId: orgProvider()))
    }

    public func addComment(id: String, comment: String) async throws -> PostCommentDTO {
        let endpoint = try PostsExtrasEndpoints.createComment(
            id: id, comment: comment, orgId: await orgProvider())
        return try await send(endpoint)
    }

    public func preview(id: String) async throws -> PostPreviewResponse {
        try await send(PostsExtrasEndpoints.preview(id: id, orgId: orgProvider()))
    }

    public func missing(id: String) async throws -> [MissingContentItemDTO] {
        try await send(PostsExtrasEndpoints.missing(id: id, orgId: orgProvider()))
    }

    // MARK: - Tags

    public func tags() async throws -> TagsListResponse {
        try await send(SocialsEndpoints.tags(orgId: orgProvider()))
    }

    public func createTag(_ body: CreateTagRequest) async throws -> TagDTO {
        try await send(SocialsEndpoints.createTag(body, orgId: await orgProvider()))
    }

    public func updateTag(_ id: String, body: CreateTagRequest) async throws -> TagDTO {
        try await send(SocialsEndpoints.updateTag(id, body: body, orgId: await orgProvider()))
    }

    public func deleteTag(_ id: String) async throws -> TagDTO {
        try await send(SocialsEndpoints.deleteTag(id, orgId: orgProvider()))
    }

    // MARK: - Signatures

    public func signatures() async throws -> [SignatureDTO] {
        try await send(SocialsEndpoints.signatures(orgId: orgProvider()))
    }

    public func defaultSignature() async throws -> SignatureDTO {
        try await send(SocialsEndpoints.defaultSignature(orgId: orgProvider()))
    }

    public func createSignature(_ body: SignatureRequest) async throws -> SignatureDTO {
        try await send(SocialsEndpoints.createSignature(body, orgId: await orgProvider()))
    }

    public func updateSignature(_ id: String, body: SignatureRequest) async throws -> SignatureDTO {
        try await send(
            SocialsEndpoints.updateSignature(id, body: body, orgId: await orgProvider()))
    }

    public func deleteSignature(_ id: String) async throws -> SignatureDTO {
        try await send(SocialsEndpoints.deleteSignature(id, orgId: orgProvider()))
    }

    // MARK: - Media library

    public func mediaList(page: Int?) async throws -> MediaListResponse {
        try await send(SocialsEndpoints.mediaList(page: page, orgId: orgProvider()))
    }

    public func deleteMedia(_ id: String) async throws -> OpaqueJSONResult {
        try await send(SocialsEndpoints.deleteMedia(id, orgId: orgProvider()))
    }

    public func saveMediaInformation(_ body: MediaInformationRequest) async throws
        -> OpaqueJSONResult
    {
        try await send(SocialsEndpoints.saveMediaInformation(body, orgId: await orgProvider()))
    }

    public func createUpload(_ body: MediaCreateUploadRequest) async throws
        -> MediaCreateUploadResponse
    {
        try await send(SocialsEndpoints.createMediaUpload(body, orgId: await orgProvider()))
    }

    public func completeUpload(_ body: MediaCompleteUploadRequest) async throws
        -> MediaCompleteUploadResponse
    {
        try await send(SocialsEndpoints.completeMediaUpload(body, orgId: await orgProvider()))
    }

    // MARK: - Push

    public func upsertPushDevice(_ body: PushDeviceUpsert) async throws -> PushDeviceResponse {
        try await send(SocialsEndpoints.upsertPushDevice(body, orgId: orgProvider()))
    }

    public func deletePushDevice(token: String) async throws -> OkResponse {
        try await send(SocialsEndpoints.deletePushDevice(token, orgId: orgProvider()))
    }

    public func pushPrefs(token: String) async throws -> PushPrefsResponse {
        try await send(SocialsEndpoints.pushPrefs(token: token, orgId: orgProvider()))
    }

    public func updatePushPrefs(_ body: PushPrefsUpdateRequest) async throws
        -> PushPrefsResponse
    {
        try await send(SocialsEndpoints.updatePushPrefs(body, orgId: orgProvider()))
    }

    // MARK: - AI

    public func aiCredits(type: String = "ai_images") async throws -> AICreditsResponse {
        try await send(SocialsEndpoints.aiCredits(type: type, orgId: orgProvider()))
    }

    public func aiGenerateImage(prompt: String) async throws -> AIMediaResult {
        try await send(
            SocialsEndpoints.aiGenerateImage(
                AIImageRequest(prompt: prompt), orgId: orgProvider()))
    }

    public func aiGenerateVideo(_ body: AIVideoRequest) async throws -> AIMediaResult {
        try await send(SocialsEndpoints.aiGenerateVideo(body, orgId: orgProvider()))
    }
}
