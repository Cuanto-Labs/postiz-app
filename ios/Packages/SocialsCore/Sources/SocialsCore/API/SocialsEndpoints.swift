import CuantoNet
import Foundation
import HTTPTypes

/// One static builder per route in `docs/MOBILE-API.md`, path-prefixed `/mobile/v1`.
/// Authenticated builders take `orgId: String?` and, when non-nil, set the `showorg`
/// header (docs/MOBILE-API.md § Base URL & auth — org selection).
public enum SocialsEndpoints {
    private static let basePath = "/mobile/v1"
    private static let showorgHeader = HTTPField.Name("showorg")!

    private static func withOrg<Response>(
        _ endpoint: Endpoint<Response>, _ orgId: String?
    ) -> Endpoint<Response> {
        guard let orgId else { return endpoint }
        return endpoint.header(showorgHeader, orgId)
    }

    // MARK: - Auth (public)

    public static func login(_ body: LoginRequest) throws -> Endpoint<MobileAuthResponse> {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/login", body: .json(body), requiresAuth: false)
    }

    public static func register(_ body: RegisterRequest) throws -> Endpoint<RegisterResult> {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/register", body: .json(body),
            requiresAuth: false)
    }

    public static func refresh(_ body: RefreshRequest) throws -> Endpoint<MobileTokens> {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/refresh", body: .json(body), requiresAuth: false
        )
    }

    public static func logout(_ body: LogoutRequest) throws -> Endpoint<OkResponse> {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/logout", body: .json(body), requiresAuth: false)
    }

    public static func appleNative(_ body: AppleNativeRequest) throws -> Endpoint<
        MobileAuthResponse
    > {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/apple/native", body: .json(body),
            requiresAuth: false)
    }

    public static func oauthStart(_ body: OAuthStartRequest) throws -> Endpoint<
        OAuthStartResponse
    > {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/oauth/start", body: .json(body),
            requiresAuth: false)
    }

    public static func oauthExchange(_ body: OAuthExchangeRequest) throws -> Endpoint<
        MobileAuthResponse
    > {
        try Endpoint(
            method: .post, path: "\(basePath)/auth/oauth/exchange", body: .json(body),
            requiresAuth: false)
    }

    public static func config() -> Endpoint<ConfigResponse> {
        Endpoint(path: "\(basePath)/config", requiresAuth: false)
    }

    // MARK: - Account (authenticated)

    public static func me(orgId: String? = nil) -> Endpoint<MeResponse> {
        withOrg(Endpoint(path: "\(basePath)/me"), orgId)
    }

    public static func devices(orgId: String? = nil) -> Endpoint<DevicesResponse> {
        withOrg(Endpoint(path: "\(basePath)/devices"), orgId)
    }

    public static func deleteDevice(_ id: String, orgId: String? = nil) -> Endpoint<OkResponse> {
        withOrg(Endpoint(method: .delete, path: "\(basePath)/devices/\(id)"), orgId)
    }

    public static func channels(orgId: String? = nil) -> Endpoint<ChannelsResponse> {
        withOrg(Endpoint(path: "\(basePath)/channels"), orgId)
    }

    // MARK: - Posts

    public static func posts(
        from: String, to: String, customer: String? = nil, orgId: String? = nil
    ) -> Endpoint<PostsResponse> {
        var endpoint = Endpoint<PostsResponse>(path: "\(basePath)/posts")
            .query("from", from)
            .query("to", to)
        if let customer {
            endpoint = endpoint.query("customer", customer)
        }
        return withOrg(endpoint, orgId)
    }

    public static func post(_ group: String, orgId: String? = nil) -> Endpoint<PostGroupDTO> {
        withOrg(Endpoint(path: "\(basePath)/posts/\(group)"), orgId)
    }

    public static func createPost(
        _ body: CreatePostBody, idempotencyKey: IdempotencyKey? = nil, orgId: String? = nil
    ) throws -> Endpoint<PostGroupDTO> {
        var endpoint = try Endpoint<PostGroupDTO>(
            method: .post, path: "\(basePath)/posts", body: .json(body))
        if let idempotencyKey {
            endpoint = endpoint.header(IdempotencyKey.headerName, idempotencyKey.value)
        }
        return withOrg(endpoint, orgId)
    }

    public static func updatePost(
        _ group: String, body: CreatePostBody, idempotencyKey: IdempotencyKey? = nil,
        orgId: String? = nil
    ) throws -> Endpoint<PostGroupDTO> {
        var endpoint = try Endpoint<PostGroupDTO>(
            method: .put, path: "\(basePath)/posts/\(group)", body: .json(body))
        if let idempotencyKey {
            endpoint = endpoint.header(IdempotencyKey.headerName, idempotencyKey.value)
        }
        return withOrg(endpoint, orgId)
    }

    public static func reschedule(
        _ group: String, date: String, action: String? = nil, orgId: String? = nil
    ) throws -> Endpoint<RescheduleResponse> {
        let body = RescheduleRequest(date: date, action: action)
        let endpoint = try Endpoint<RescheduleResponse>(
            method: .patch, path: "\(basePath)/posts/\(group)/date", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func deletePost(_ group: String, orgId: String? = nil) -> Endpoint<OkResponse> {
        withOrg(Endpoint(method: .delete, path: "\(basePath)/posts/\(group)"), orgId)
    }

    // MARK: - Push

    public static func upsertPushDevice(
        _ body: PushDeviceUpsert, orgId: String? = nil
    ) throws -> Endpoint<PushDeviceResponse> {
        let endpoint = try Endpoint<PushDeviceResponse>(
            method: .put, path: "\(basePath)/push/devices", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func deletePushDevice(
        _ token: String, orgId: String? = nil
    ) -> Endpoint<OkResponse> {
        withOrg(Endpoint(method: .delete, path: "\(basePath)/push/devices/\(token)"), orgId)
    }

    public static func pushPrefs(
        token: String, orgId: String? = nil
    ) -> Endpoint<PushPrefsResponse> {
        withOrg(Endpoint(path: "\(basePath)/push/prefs").query("token", token), orgId)
    }

    public static func updatePushPrefs(
        _ body: PushPrefsUpdateRequest, orgId: String? = nil
    ) throws -> Endpoint<PushPrefsResponse> {
        let endpoint = try Endpoint<PushPrefsResponse>(
            method: .put, path: "\(basePath)/push/prefs", body: .json(body))
        return withOrg(endpoint, orgId)
    }
}
