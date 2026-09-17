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

    // MARK: - Channel management (settings, lifecycle, connect, function)

    public var customersResults: [Result<[ChannelCustomer], Error>] = []
    public private(set) var customersCallCount = 0
    public func customers() async throws -> [ChannelCustomer] {
        customersCallCount += 1
        return try next(&customersResults, "customers")
    }

    public var updateChannelCustomerNameResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var updateChannelCustomerNameCalls:
        [(id: String, body: ChannelCustomerNameRequest)] = []
    public func updateChannelCustomerName(_ id: String, body: ChannelCustomerNameRequest)
        async throws -> OpaqueJSONResult
    {
        updateChannelCustomerNameCalls.append((id: id, body: body))
        return try next(&updateChannelCustomerNameResults, "updateChannelCustomerName")
    }

    public var updateChannelGroupResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var updateChannelGroupCalls: [(id: String, body: ChannelGroupRequest)] = []
    public func updateChannelGroup(_ id: String, body: ChannelGroupRequest) async throws
        -> OpaqueJSONResult
    {
        updateChannelGroupCalls.append((id: id, body: body))
        return try next(&updateChannelGroupResults, "updateChannelGroup")
    }

    public var setChannelTimesResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var setChannelTimesCalls: [(id: String, body: ChannelTimeRequest)] = []
    public func setChannelTimes(_ id: String, body: ChannelTimeRequest) async throws
        -> OpaqueJSONResult
    {
        setChannelTimesCalls.append((id: id, body: body))
        return try next(&setChannelTimesResults, "setChannelTimes")
    }

    public var updateChannelSettingsResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var updateChannelSettingsCalls:
        [(id: String, body: ChannelSettingsRequest)] = []
    public func updateChannelSettings(_ id: String, body: ChannelSettingsRequest) async throws
        -> OpaqueJSONResult
    {
        updateChannelSettingsCalls.append((id: id, body: body))
        return try next(&updateChannelSettingsResults, "updateChannelSettings")
    }

    public var channelMentionsResults: [Result<ChannelMentionsResult, Error>] = []
    public private(set) var channelMentionsCalls: [ChannelFunctionRequest] = []
    public func channelMentions(_ body: ChannelFunctionRequest) async throws
        -> ChannelMentionsResult
    {
        channelMentionsCalls.append(body)
        return try next(&channelMentionsResults, "channelMentions")
    }

    public var channelFunctionResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var channelFunctionCalls: [ChannelFunctionRequest] = []
    public func channelFunction(_ body: ChannelFunctionRequest) async throws -> OpaqueJSONResult {
        channelFunctionCalls.append(body)
        return try next(&channelFunctionResults, "channelFunction")
    }

    public var disableChannelResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var disableChannelCalls: [String] = []
    public func disableChannel(_ id: String) async throws -> OpaqueJSONResult {
        disableChannelCalls.append(id)
        return try next(&disableChannelResults, "disableChannel")
    }

    public var enableChannelResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var enableChannelCalls: [String] = []
    public func enableChannel(_ id: String) async throws -> OpaqueJSONResult {
        enableChannelCalls.append(id)
        return try next(&enableChannelResults, "enableChannel")
    }

    public var deleteChannelResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var deleteChannelCalls: [String] = []
    public func deleteChannel(_ id: String) async throws -> OpaqueJSONResult {
        deleteChannelCalls.append(id)
        return try next(&deleteChannelResults, "deleteChannel")
    }

    public var connectStartResults: [Result<ChannelConnectResponse, Error>] = []
    public private(set) var connectStartCalls:
        [(provider: String, refresh: String?, externalUrl: String?)] = []
    public func connectStart(provider: String, refresh: String?, externalUrl: String?)
        async throws -> ChannelConnectResponse
    {
        connectStartCalls.append((provider: provider, refresh: refresh, externalUrl: externalUrl))
        return try next(&connectStartResults, "connectStart")
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

    // MARK: - Posts extras

    public var postsListResults: [Result<PostsListResponse, Error>] = []
    public private(set) var postsListCalls: [(page: Int?, limit: Int?)] = []
    public func postsList(page: Int?, limit: Int?) async throws -> PostsListResponse {
        postsListCalls.append((page: page, limit: limit))
        return try next(&postsListResults, "postsList")
    }

    public var oldPostsResults: [Result<OldPostsResponse, Error>] = []
    public private(set) var oldPostsCalls: [String] = []
    public func oldPosts(date: String) async throws -> OldPostsResponse {
        oldPostsCalls.append(date)
        return try next(&oldPostsResults, "oldPosts")
    }

    public var findSlotResults: [Result<FindSlotResponse, Error>] = []
    public private(set) var findSlotCalls: [String?] = []
    public func findSlot(integrationId: String?) async throws -> FindSlotResponse {
        findSlotCalls.append(integrationId)
        return try next(&findSlotResults, "findSlot")
    }

    public var statisticsResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var statisticsCalls: [String] = []
    public func statistics(id: String) async throws -> OpaqueJSONResult {
        statisticsCalls.append(id)
        return try next(&statisticsResults, "statistics")
    }

    public var commentsResults: [Result<PostCommentsResponse, Error>] = []
    public private(set) var commentsCalls: [String] = []
    public func comments(id: String) async throws -> PostCommentsResponse {
        commentsCalls.append(id)
        return try next(&commentsResults, "comments")
    }

    public var addCommentResults: [Result<PostCommentDTO, Error>] = []
    public private(set) var addCommentCalls: [(id: String, comment: String)] = []
    public func addComment(id: String, comment: String) async throws -> PostCommentDTO {
        addCommentCalls.append((id: id, comment: comment))
        return try next(&addCommentResults, "addComment")
    }

    public var previewResults: [Result<PostPreviewResponse, Error>] = []
    public private(set) var previewCalls: [String] = []
    public func preview(id: String) async throws -> PostPreviewResponse {
        previewCalls.append(id)
        return try next(&previewResults, "preview")
    }

    public var missingResults: [Result<[MissingContentItemDTO], Error>] = []
    public private(set) var missingCalls: [String] = []
    public func missing(id: String) async throws -> [MissingContentItemDTO] {
        missingCalls.append(id)
        return try next(&missingResults, "missing")
    }

    // MARK: - Tags

    public var tagsResults: [Result<TagsListResponse, Error>] = []
    public private(set) var tagsCallCount = 0
    public func tags() async throws -> TagsListResponse {
        tagsCallCount += 1
        return try next(&tagsResults, "tags")
    }

    public var createTagResults: [Result<TagDTO, Error>] = []
    public private(set) var createTagCalls: [CreateTagRequest] = []
    public func createTag(_ body: CreateTagRequest) async throws -> TagDTO {
        createTagCalls.append(body)
        return try next(&createTagResults, "createTag")
    }

    public var updateTagResults: [Result<TagDTO, Error>] = []
    public private(set) var updateTagCalls: [(id: String, body: CreateTagRequest)] = []
    public func updateTag(_ id: String, body: CreateTagRequest) async throws -> TagDTO {
        updateTagCalls.append((id: id, body: body))
        return try next(&updateTagResults, "updateTag")
    }

    public var deleteTagResults: [Result<TagDTO, Error>] = []
    public private(set) var deleteTagCalls: [String] = []
    public func deleteTag(_ id: String) async throws -> TagDTO {
        deleteTagCalls.append(id)
        return try next(&deleteTagResults, "deleteTag")
    }

    // MARK: - Signatures

    public var signaturesResults: [Result<[SignatureDTO], Error>] = []
    public private(set) var signaturesCallCount = 0
    public func signatures() async throws -> [SignatureDTO] {
        signaturesCallCount += 1
        return try next(&signaturesResults, "signatures")
    }

    public var defaultSignatureResults: [Result<SignatureDTO, Error>] = []
    public private(set) var defaultSignatureCallCount = 0
    public func defaultSignature() async throws -> SignatureDTO {
        defaultSignatureCallCount += 1
        return try next(&defaultSignatureResults, "defaultSignature")
    }

    public var createSignatureResults: [Result<SignatureDTO, Error>] = []
    public private(set) var createSignatureCalls: [SignatureRequest] = []
    public func createSignature(_ body: SignatureRequest) async throws -> SignatureDTO {
        createSignatureCalls.append(body)
        return try next(&createSignatureResults, "createSignature")
    }

    public var updateSignatureResults: [Result<SignatureDTO, Error>] = []
    public private(set) var updateSignatureCalls: [(id: String, body: SignatureRequest)] = []
    public func updateSignature(_ id: String, body: SignatureRequest) async throws
        -> SignatureDTO
    {
        updateSignatureCalls.append((id: id, body: body))
        return try next(&updateSignatureResults, "updateSignature")
    }

    public var deleteSignatureResults: [Result<SignatureDTO, Error>] = []
    public private(set) var deleteSignatureCalls: [String] = []
    public func deleteSignature(_ id: String) async throws -> SignatureDTO {
        deleteSignatureCalls.append(id)
        return try next(&deleteSignatureResults, "deleteSignature")
    }

    // MARK: - Media library

    public var mediaListResults: [Result<MediaListResponse, Error>] = []
    public private(set) var mediaListCalls: [Int?] = []
    public func mediaList(page: Int?) async throws -> MediaListResponse {
        mediaListCalls.append(page)
        return try next(&mediaListResults, "mediaList")
    }

    public var deleteMediaResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var deleteMediaCalls: [String] = []
    public func deleteMedia(_ id: String) async throws -> OpaqueJSONResult {
        deleteMediaCalls.append(id)
        return try next(&deleteMediaResults, "deleteMedia")
    }

    public var saveMediaInformationResults: [Result<OpaqueJSONResult, Error>] = []
    public private(set) var saveMediaInformationCalls: [MediaInformationRequest] = []
    public func saveMediaInformation(_ body: MediaInformationRequest) async throws
        -> OpaqueJSONResult
    {
        saveMediaInformationCalls.append(body)
        return try next(&saveMediaInformationResults, "saveMediaInformation")
    }

    public var createUploadResults: [Result<MediaCreateUploadResponse, Error>] = []
    public private(set) var createUploadCalls: [MediaCreateUploadRequest] = []
    public func createUpload(_ body: MediaCreateUploadRequest) async throws
        -> MediaCreateUploadResponse
    {
        createUploadCalls.append(body)
        return try next(&createUploadResults, "createUpload")
    }

    public var completeUploadResults: [Result<MediaCompleteUploadResponse, Error>] = []
    public private(set) var completeUploadCalls: [MediaCompleteUploadRequest] = []
    public func completeUpload(_ body: MediaCompleteUploadRequest) async throws
        -> MediaCompleteUploadResponse
    {
        completeUploadCalls.append(body)
        return try next(&completeUploadResults, "completeUpload")
    }

    // MARK: - Notifications

    public var notificationsCountResults: [Result<NotificationsCountResponse, Error>] = []
    public private(set) var notificationsCountCallCount = 0
    public func notificationsCount() async throws -> NotificationsCountResponse {
        notificationsCountCallCount += 1
        return try next(&notificationsCountResults, "notificationsCount")
    }

    public var notificationsListResults: [Result<NotificationsListResponse, Error>] = []
    public private(set) var notificationsListCallCount = 0
    public func notificationsList() async throws -> NotificationsListResponse {
        notificationsListCallCount += 1
        return try next(&notificationsListResults, "notificationsList")
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

    public var aiConsentResults: [Result<AIConsentResponse, Error>] = []
    public private(set) var aiConsentCallCount = 0
    public func aiConsent() async throws -> AIConsentResponse {
        aiConsentCallCount += 1
        return try next(&aiConsentResults, "aiConsent")
    }

    public var setAIConsentResults: [Result<AIConsentResponse, Error>] = []
    public private(set) var setAIConsentCalls: [Bool] = []
    public func setAIConsent(_ body: AIConsentRequest) async throws -> AIConsentResponse {
        setAIConsentCalls.append(body.granted)
        return try next(&setAIConsentResults, "setAIConsent")
    }

    public var aiSuggestResults: [Result<AISuggestResponse, Error>] = []
    public private(set) var aiSuggestCalls: [AISuggestRequest] = []
    public func aiSuggest(_ body: AISuggestRequest) async throws -> AISuggestResponse {
        aiSuggestCalls.append(body)
        return try next(&aiSuggestResults, "aiSuggest")
    }

    // MARK: - Analytics

    public var channelAnalyticsResults: [Result<[AnalyticsSeries], Error>] = []
    public private(set) var channelAnalyticsCalls: [(String, AnalyticsRange)] = []
    public func channelAnalytics(integrationId: String, range: AnalyticsRange) async throws
        -> [AnalyticsSeries]
    {
        channelAnalyticsCalls.append((integrationId, range))
        return try next(&channelAnalyticsResults, "channelAnalytics")
    }

    public var postAnalyticsResults: [Result<[AnalyticsSeries], Error>] = []
    public private(set) var postAnalyticsCalls: [(String, AnalyticsRange)] = []
    public func postAnalytics(postId: String, range: AnalyticsRange) async throws
        -> [AnalyticsSeries]
    {
        postAnalyticsCalls.append((postId, range))
        return try next(&postAnalyticsResults, "postAnalytics")
    }

    // MARK: - Org settings

    public var teamMembersResults: [Result<TeamListResponse, Error>] = []
    public func teamMembers() async throws -> TeamListResponse {
        try next(&teamMembersResults, "teamMembers")
    }

    public var addTeamMemberResults: [Result<OkResponse, Error>] = []
    public private(set) var addTeamMemberCalls: [AddTeamMemberRequest] = []
    public func addTeamMember(_ body: AddTeamMemberRequest) async throws -> OkResponse {
        addTeamMemberCalls.append(body)
        return try next(&addTeamMemberResults, "addTeamMember")
    }

    public var removeTeamMemberResults: [Result<OkResponse, Error>] = []
    public private(set) var removeTeamMemberCalls: [String] = []
    public func removeTeamMember(_ id: String) async throws -> OkResponse {
        removeTeamMemberCalls.append(id)
        return try next(&removeTeamMemberResults, "removeTeamMember")
    }

    public var shortlinkResults: [Result<ShortlinkPreferenceResponse, Error>] = []
    public func shortlinkPreference() async throws -> ShortlinkPreferenceResponse {
        try next(&shortlinkResults, "shortlinkPreference")
    }

    public var setShortlinkResults: [Result<ShortlinkPreferenceResponse, Error>] = []
    public private(set) var setShortlinkCalls: [ShortlinkPreference] = []
    public func setShortlinkPreference(_ shortlink: ShortlinkPreference) async throws
        -> ShortlinkPreferenceResponse
    {
        setShortlinkCalls.append(shortlink)
        return try next(&setShortlinkResults, "setShortlinkPreference")
    }

    public var webhooksResults: [Result<[MobileWebhook], Error>] = []
    public func webhooks() async throws -> [MobileWebhook] {
        try next(&webhooksResults, "webhooks")
    }

    // MARK: - Account settings

    public var personalDetailsResults: [Result<PersonalDetails, Error>] = []
    public func personalDetails() async throws -> PersonalDetails {
        try next(&personalDetailsResults, "personalDetails")
    }

    public var updatePersonalDetailsResults: [Result<PersonalDetails, Error>] = []
    public private(set) var updatePersonalDetailsCalls: [PersonalDetailsRequest] = []
    public func updatePersonalDetails(_ body: PersonalDetailsRequest) async throws
        -> PersonalDetails
    {
        updatePersonalDetailsCalls.append(body)
        return try next(&updatePersonalDetailsResults, "updatePersonalDetails")
    }

    public var emailPrefsResults: [Result<EmailNotificationPrefs, Error>] = []
    public func emailNotificationPrefs() async throws -> EmailNotificationPrefs {
        try next(&emailPrefsResults, "emailNotificationPrefs")
    }

    public var updateEmailPrefsResults: [Result<EmailNotificationPrefs, Error>] = []
    public private(set) var updateEmailPrefsCalls: [EmailNotificationPrefs] = []
    public func updateEmailNotificationPrefs(_ body: EmailNotificationPrefs) async throws
        -> EmailNotificationPrefs
    {
        updateEmailPrefsCalls.append(body)
        return try next(&updateEmailPrefsResults, "updateEmailNotificationPrefs")
    }

    public var deletionPreviewResults: [Result<DeletionPreview, Error>] = []
    public func deletionPreview() async throws -> DeletionPreview {
        try next(&deletionPreviewResults, "deletionPreview")
    }

    public var deleteAccountResults: [Result<DeleteAccountResponse, Error>] = []
    public private(set) var deleteAccountCalls: Int = 0
    public func deleteAccount() async throws -> DeleteAccountResponse {
        deleteAccountCalls += 1
        return try next(&deleteAccountResults, "deleteAccount")
    }
}
