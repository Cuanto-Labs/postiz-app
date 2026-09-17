import Foundation
import Observation

/// Drives the new-post composer: channel picks, global vs per-channel content customization,
/// character-limit validation, and the `CreatePostBody` sent to `SocialsAPI.createPost`. Mirrors
/// web's `apps/frontend/src/components/new-launch/store.ts` (`selectedIntegrations`,
/// `addOrRemoveSelectedIntegration`, `global`/`internal`, `addRemoveInternal`) — thread support
/// (web's `global`/`internal` being arrays of posts, `finisher/thread.finisher.tsx`) is out of
/// scope for this card, so each channel carries exactly one `ComposerDraft`.
///
/// Character limits come from the server, not a hardcoded per-provider table: `ChannelDTO.limits`
/// (`GET /mobile/v1/channels`) already resolves the provider's dynamic `maxLength(...)` (e.g. X's
/// 280 vs 4000-for-Premium), mirroring how web's providers compute `maxLength` server-side.
@MainActor
@Observable
public final class ComposerViewModel {
    /// Fallback limit for a channel whose `limits.maxCharacters` wasn't sent by the server —
    /// generous enough to not block posting, matching how web treats a missing limit as "no cap".
    public static let defaultCharLimit = 100_000

    public private(set) var channels: [ChannelDTO]
    public private(set) var selectedChannelIds: [String] = []
    public var globalDraft = ComposerDraft()
    public private(set) var customizedChannelIds: Set<String> = []
    public private(set) var perChannelDrafts: [String: ComposerDraft] = [:]
    public private(set) var isSaving = false
    public private(set) var isFindingSlot = false
    public private(set) var errorMessage: String?

    /// Non-`nil` once the composer is editing an existing post rather than creating a new one:
    /// `submit()` calls `SocialsAPI.updatePost` instead of `createPost`, and `ComposerActionsBar`
    /// swaps in Update/Delete for Save draft/Add to calendar/Post now.
    public var existingGroup: String?
    /// The chosen schedule date (ISO 8601, server format), set by `ScheduleSheet` either from a
    /// manual pick or from `findSlot()`. `nil` means "post now".
    public var scheduleDate: String?

    private let api: any SocialsAPI
    private let draftStore: (any DraftStoring)?

    public init(
        api: any SocialsAPI, channels: [ChannelDTO] = [], draftStore: (any DraftStoring)? = nil
    ) {
        self.api = api
        self.channels = channels
        self.draftStore = draftStore
    }

    public func setChannels(_ channels: [ChannelDTO]) {
        self.channels = channels
        let validIds = Set(channels.map(\.internalId))
        selectedChannelIds.removeAll { !validIds.contains($0) }
        customizedChannelIds = customizedChannelIds.filter { validIds.contains($0) }
        perChannelDrafts = perChannelDrafts.filter { validIds.contains($0.key) }
    }

    // MARK: - Channel picks

    /// Selectable channels, mirrors web's `PicksSocialsComponent` filter: not mid-onboarding,
    /// not disabled.
    public var selectableChannels: [ChannelDTO] {
        channels.filter { !$0.inBetweenSteps && !$0.disabled }
    }

    public var selectedChannels: [ChannelDTO] {
        channels.filter { selectedChannelIds.contains($0.internalId) }
    }

    public func isSelected(_ channel: ChannelDTO) -> Bool {
        selectedChannelIds.contains(channel.internalId)
    }

    /// Toggles a channel pick, mirrors web's `addOrRemoveSelectedIntegration`: deselecting also
    /// drops its customization (web's `addRemoveInternal` state + falling back `current` to
    /// `'global'`).
    public func toggleChannel(_ channel: ChannelDTO) {
        if let index = selectedChannelIds.firstIndex(of: channel.internalId) {
            selectedChannelIds.remove(at: index)
            customizedChannelIds.remove(channel.internalId)
            perChannelDrafts.removeValue(forKey: channel.internalId)
        } else {
            selectedChannelIds.append(channel.internalId)
        }
    }

    // MARK: - Global + per-channel customize

    public func isCustomized(_ channelId: String) -> Bool {
        customizedChannelIds.contains(channelId)
    }

    /// Toggles per-channel customize; enabling seeds the channel's draft from the current global
    /// draft (mirrors web's `addRemoveInternal`, which copies `state.global` into the new
    /// `internal` entry), disabling drops the override so the channel falls back to global.
    public func toggleCustomize(for channelId: String) {
        if customizedChannelIds.contains(channelId) {
            customizedChannelIds.remove(channelId)
            perChannelDrafts.removeValue(forKey: channelId)
        } else {
            customizedChannelIds.insert(channelId)
            perChannelDrafts[channelId] = globalDraft
        }
    }

    /// The effective draft for a channel: its customized override if customize is on, otherwise
    /// the shared global draft.
    public func draft(for channelId: String) -> ComposerDraft {
        guard customizedChannelIds.contains(channelId) else { return globalDraft }
        return perChannelDrafts[channelId] ?? globalDraft
    }

    public func setGlobalContent(_ content: String) {
        globalDraft.content = content
    }

    /// No-op unless `channelId` has customize on — matches web's per-channel editors only being
    /// mounted once the channel is moved into `internal`.
    public func setContent(_ content: String, for channelId: String) {
        guard customizedChannelIds.contains(channelId) else { return }
        var draft = perChannelDrafts[channelId] ?? globalDraft
        draft.content = content
        perChannelDrafts[channelId] = draft
    }

    // MARK: - Char limits

    public func charLimit(for channel: ChannelDTO) -> Int {
        channel.limits.maxCharacters ?? Self.defaultCharLimit
    }

    public func charCount(for channel: ChannelDTO) -> Int {
        draft(for: channel.internalId).content.count
    }

    public func isOverCharLimit(for channel: ChannelDTO) -> Bool {
        charCount(for: channel) > charLimit(for: channel)
    }

    // MARK: - Validation

    public func validate() -> [ComposerValidationError] {
        var errors: [ComposerValidationError] = []
        if selectedChannelIds.isEmpty {
            errors.append(.noChannelsSelected)
        }
        for channel in selectedChannels {
            let content = draft(for: channel.internalId).content
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                errors.append(.emptyContent(channelId: channel.internalId))
            }
            let limit = charLimit(for: channel)
            if content.count > limit {
                errors.append(.overCharLimit(channelId: channel.internalId, limit: limit))
            }
        }
        return errors
    }

    public var isValid: Bool { validate().isEmpty }

    // MARK: - CreatePostBody builder

    /// Builds the `CreatePostBody` for `SocialsAPI.createPost`/`updatePost`: one `PostGroupDTO`
    /// per selected channel, each carrying that channel's effective (global or customized)
    /// content. `type` mirrors web's schedule/now/draft distinction
    /// (`libraries/nestjs-libraries/src/dtos/posts/create.post.dto.ts`).
    public func buildCreatePostBody(
        type: String = "now", date: String? = nil, tags: [PostTagRef]? = nil
    ) -> CreatePostBody {
        let posts = selectedChannels.map { channel in
            PostGroupDTO(
                id: nil,
                group: nil,
                publishDate: date,
                status: nil,
                integration: PostIntegrationRef(
                    id: channel.internalId, name: channel.name, picture: channel.picture,
                    providerIdentifier: channel.identifier),
                content: .string(draft(for: channel.internalId).content)
            )
        }
        return CreatePostBody(type: type, posts: posts, date: date, tags: tags)
    }

    // MARK: - Draft persistence

    public func restoreDraft() {
        guard let saved = draftStore?.loadDraft() else { return }
        selectedChannelIds = saved.selectedChannelIds
        globalDraft = saved.global
        customizedChannelIds = Set(saved.customizedChannelIds)
        perChannelDrafts = saved.perChannel
    }

    public func persistDraft() {
        draftStore?.saveDraft(
            PersistedComposerDraft(
                selectedChannelIds: selectedChannelIds, global: globalDraft,
                customizedChannelIds: Array(customizedChannelIds), perChannel: perChannelDrafts))
    }

    public func clearDraft() {
        selectedChannelIds = []
        globalDraft = ComposerDraft()
        customizedChannelIds = []
        perChannelDrafts = [:]
        existingGroup = nil
        scheduleDate = nil
        draftStore?.clearDraft()
    }

    // MARK: - Schedule

    /// Fetches the next free posting slot via `SocialsAPI.findSlot` and stores it as
    /// `scheduleDate`, mirrors web's "find a slot for me" button in the schedule picker.
    public func findSlot(integrationId: String? = nil) async {
        isFindingSlot = true
        errorMessage = nil
        defer { isFindingSlot = false }
        do {
            let response = try await api.findSlot(integrationId: integrationId)
            scheduleDate = response.date
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Submit

    /// Creates a new post, or updates `existingGroup` when editing one, mirrors web's
    /// `add.edit.modal.tsx` submit which branches on whether a post `group` is already known.
    public func submit(type: String = "now", date: String? = nil, tags: [PostTagRef]? = nil)
        async -> Bool
    {
        guard isValid else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let body = buildCreatePostBody(type: type, date: date, tags: tags)
            if let group = existingGroup {
                _ = try await api.updatePost(group: group, body: body, key: nil)
            } else {
                _ = try await api.createPost(body: body, key: nil)
            }
            clearDraft()
            return true
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return false
        }
    }

    /// Deletes `existingGroup`, mirrors `PostDetailViewModel.delete()`'s destructive-action flow.
    public func delete() async -> Bool {
        guard let group = existingGroup else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.deletePost(group: group)
            clearDraft()
            return true
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return false
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .notFound: return "That couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }
}

/// Composer-level validation failure, mirrors web's inline validation before enabling the post
/// button (empty content per selected channel, over the provider's char limit).
public enum ComposerValidationError: Sendable, Equatable {
    case noChannelsSelected
    case emptyContent(channelId: String)
    case overCharLimit(channelId: String, limit: Int)
}
