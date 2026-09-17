import Foundation

/// AI → composer handoff: turns an `AIMediaResult` from `AIImageView`/`AIVideoView`'s "Use
/// this" action into a composer attachment, and a `CopilotSheet` "Use" suggestion into editor
/// text — both pure state mutations on the existing global draft, no new network calls.
extension ComposerViewModel {
    /// Appends an AI-generated image/video to the global draft's media, mirroring how
    /// `MediaTrayView`'s upload flow attaches a freshly uploaded `MediaDTO`.
    public func attachAIMedia(_ result: AIMediaResult) {
        globalDraft.media.append(ComposerMediaRef(id: result.id, path: result.path))
    }

    /// Applies a copilot suggestion to the global draft's content. `.replace` swaps the whole
    /// body (the common "rewrite"/"fit to length" case); `.insertAtCursor` preserves whatever
    /// the user already typed and appends the suggestion after it, since `ComposerDraft` tracks
    /// no cursor position of its own. Existing `validate()`/`ComposerValidationError.overCharLimit`
    /// already surfaces any resulting over-limit content, so no new validation is needed here.
    public func applySuggestion(_ text: String, mode: SuggestionApplyMode = .replace) {
        switch mode {
        case .replace:
            globalDraft.content = text
        case .insertAtCursor:
            let prefix = globalDraft.content
            globalDraft.content = prefix.isEmpty ? text : prefix + text
        }
    }
}

/// How a copilot suggestion (`ComposerViewModel.applySuggestion(_:mode:)`) is merged into the
/// existing draft content.
public enum SuggestionApplyMode: Sendable {
    case replace
    case insertAtCursor
}
