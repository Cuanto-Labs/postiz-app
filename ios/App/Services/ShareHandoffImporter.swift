import Foundation
import SocialsCore

/// Drains the Share extension's App Group inbox on foreground: each pending `ShareHandoffItem`
/// gets autosaved as a `DraftPostSnapshot` via `SwiftDataDraftStore`, then removed from the
/// inbox. The extension has no channel picker/upload flow, so it can't create a real post —
/// turning a handoff item into an actual post via `SocialsAPI.createPost` is deferred to a
/// later card (T171+); this just makes sure nothing the user shared gets lost before then.
public struct ShareHandoffImporter: Sendable {
    private let store: any ShareHandoffStoring
    private let draftStore: SwiftDataDraftStore
    private let orgId: @Sendable () async -> String?

    public init(
        store: any ShareHandoffStoring, draftStore: SwiftDataDraftStore,
        orgId: @escaping @Sendable () async -> String?
    ) {
        self.store = store
        self.draftStore = draftStore
        self.orgId = orgId
    }

    /// Best-effort: a failure reading/writing one item doesn't stop the rest from being tried.
    /// No-ops if there's no signed-in org to attribute the drafts to — items stay queued until
    /// the next foreground after sign-in.
    public func importPending() async {
        guard let orgId = await orgId(), let items = try? store.pendingItems(), !items.isEmpty
        else { return }

        for item in items where !item.isEmpty {
            let text = Self.draftText(for: item)
            if !text.isEmpty {
                _ = try? await draftStore.save(DraftPostSnapshot(orgId: orgId, text: text))
            }
            // Drained either way: `attachmentFilenames` are Share-extension-local filenames, a
            // different id namespace from `mediaLocalIds` (the app's own upload pipeline), and
            // there's no copy path from the share inbox into that pipeline yet — so an
            // attachment-only item (no text/urls) has nothing useful to autosave and would
            // otherwise sit in the inbox forever.
            try? store.remove(id: item.id)
        }
    }

    private static func draftText(for item: ShareHandoffItem) -> String {
        ([item.text] + item.urls).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
