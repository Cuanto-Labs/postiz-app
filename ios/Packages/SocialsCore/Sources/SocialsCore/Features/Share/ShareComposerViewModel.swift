import Foundation
import Observation

/// Drives the Share extension's composer sheet. `ShareViewController` extracts whatever text/
/// URLs/attachments `NSExtensionContext` handed it (copying attachment bytes into
/// `ShareHandoffStoring.attachmentsDirectory` before this type ever sees them) and passes the
/// result in; this type only owns the caption field and the submit → enqueue flow.
///
/// Deliberately does not depend on `SocialsAPI`: the extension has no channel picker and no
/// media-upload flow, so it never calls `createPost` itself — it always hands the draft to
/// `ShareHandoffStoring`, whether or not the person is signed in. Signed-out only changes what
/// `signedOutMessage` tells them; it never blocks `submit()`, so nothing shared is lost if
/// they're logged out at share time.
@MainActor
@Observable
public final class ShareComposerViewModel {
    public enum SubmitState: Sendable, Equatable {
        case idle
        case saved
        case failed(String)
    }

    public let incomingURLs: [String]
    public let incomingAttachmentFilenames: [String]
    public var caption: String = ""
    public private(set) var isSignedIn = false
    public private(set) var submitState: SubmitState = .idle

    private let sessionStore: SessionStore
    private let handoffStore: any ShareHandoffStoring

    public init(
        sessionStore: SessionStore,
        handoffStore: any ShareHandoffStoring,
        incomingURLs: [String] = [],
        incomingAttachmentFilenames: [String] = []
    ) {
        self.sessionStore = sessionStore
        self.handoffStore = handoffStore
        self.incomingURLs = incomingURLs
        self.incomingAttachmentFilenames = incomingAttachmentFilenames
    }

    /// Message shown instead of (or above) the composer when signed out — the extension has no
    /// sign-in UI of its own, so the only recovery path is the host app.
    public var signedOutMessage: String? {
        guard !isSignedIn else { return nil }
        return "Open Cuanto Socials to sign in. Your draft is saved and will be here when you do."
    }

    public var canSubmit: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !incomingURLs.isEmpty
            || !incomingAttachmentFilenames.isEmpty
    }

    /// Reads `sessionStore.state` (Keychain-backed, shared with the host app via the App Group
    /// keychain access group) so the composer reflects sign-in status without the extension
    /// ever making a network call of its own.
    public func refreshSignInState() async {
        switch await sessionStore.state {
        case .signedIn: isSignedIn = true
        case .signedOut: isSignedIn = false
        }
    }

    /// Enqueues the current draft into the App Group inbox. Works signed-in or signed-out —
    /// see the type doc for why this never calls `SocialsAPI` directly.
    public func submit() {
        guard canSubmit else { return }
        let item = ShareHandoffItem(
            text: caption, urls: incomingURLs, attachmentFilenames: incomingAttachmentFilenames)
        do {
            try handoffStore.enqueue(item)
            submitState = .saved
        } catch {
            submitState = .failed("Couldn't save this post. Try sharing again from the app.")
        }
    }
}
