import Foundation

/// A single post's editable content: text + attached media, mirrors web's `Values`
/// (`apps/frontend/src/components/new-launch/store.ts`). One `ComposerDraft` backs either the
/// "global" content shared across channels, or a single channel's customized override.
public struct ComposerDraft: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public var content: String
    public var media: [ComposerMediaRef]

    public init(id: String = UUID().uuidString, content: String = "", media: [ComposerMediaRef] = []) {
        self.id = id
        self.content = content
        self.media = media
    }
}

/// A media attachment reference on a `ComposerDraft`, mirrors web's `Values.media`
/// (`{ id, path }`). Uploading/picking media is out of scope here — this just carries
/// whatever the media library handed back.
public struct ComposerMediaRef: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let path: String

    public init(id: String, path: String) {
        self.id = id
        self.path = path
    }
}

extension ComposerMediaRef {
    /// Cheap image/video guess from the file extension in `path`, used as a fallback for
    /// per-kind media counts (``ProviderCrossFieldValidator``) when this ref's real kind isn't
    /// known via ``SelectedMediaAttributes`` (e.g. media restored from a persisted draft, whose
    /// local probe result never survives the app relaunch).
    public var inferredKind: SelectedMediaAttributes.Kind {
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "avi"]
        let ext = (path as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext) ? .video : .image
    }
}

/// Snapshot of in-progress composer state, persisted by `DraftStoring` conformers so a
/// killed/backgrounded app can restore an unsent post — mirrors web's localStorage-backed
/// draft recovery for the new-launch modal.
public struct PersistedComposerDraft: Sendable, Equatable, Codable {
    public var selectedChannelIds: [String]
    public var global: ComposerDraft
    public var customizedChannelIds: [String]
    public var perChannel: [String: ComposerDraft]

    public init(
        selectedChannelIds: [String], global: ComposerDraft, customizedChannelIds: [String],
        perChannel: [String: ComposerDraft]
    ) {
        self.selectedChannelIds = selectedChannelIds
        self.global = global
        self.customizedChannelIds = customizedChannelIds
        self.perChannel = perChannel
    }
}

/// Persists/restores a single in-progress `ComposerDraft` snapshot. Conformers own the storage
/// medium (UserDefaults, disk, in-memory for tests) — `ComposerViewModel` only talks to this
/// protocol, mirroring how it only talks to `SocialsAPI` for networking.
public protocol DraftStoring: Sendable {
    func loadDraft() -> PersistedComposerDraft?
    func saveDraft(_ draft: PersistedComposerDraft)
    func clearDraft()
}

/// `UserDefaults`-backed `DraftStoring`. `UserDefaults` is thread-safe, so this is safe to mark
/// `Sendable` without extra locking.
public final class UserDefaultsDraftStore: DraftStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "com.cuantosocials.composer.draft") {
        self.defaults = defaults
        self.key = key
    }

    public func loadDraft() -> PersistedComposerDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedComposerDraft.self, from: data)
    }

    public func saveDraft(_ draft: PersistedComposerDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    public func clearDraft() {
        defaults.removeObject(forKey: key)
    }
}

/// In-memory `DraftStoring` for tests/previews — no persistence across process launches.
public final class InMemoryDraftStore: DraftStoring, @unchecked Sendable {
    private var stored: PersistedComposerDraft?

    public init(stored: PersistedComposerDraft? = nil) {
        self.stored = stored
    }

    public func loadDraft() -> PersistedComposerDraft? { stored }
    public func saveDraft(_ draft: PersistedComposerDraft) { stored = draft }
    public func clearDraft() { stored = nil }
}
