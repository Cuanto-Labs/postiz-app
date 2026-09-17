import CuantoUI
import SocialsCore
import SwiftUI

/// One channel's live "how this will look" preview, mirroring the web composer's Post Preview
/// panel. Dispatches rendering by `channel.identifier` — Instagram gets the aspect-framed media +
/// truncated caption, LinkedIn gets avatar/name/text with a "see more" fold, everything else gets
/// a minimal generic card. The one place in the preview layer allowed to know provider names,
/// mirroring `ProviderCrossFieldValidator`'s dispatch convention.
struct ChannelPreviewCard: View {
    let channel: ChannelDTO
    let draft: ComposerDraft
    let mediaAttributes: (String) -> SelectedMediaAttributes?

    @Environment(\.cuantoTheme) private var theme
    /// Debounced so a fast typist doesn't re-render the preview on every keystroke.
    @State private var debouncedContent = ""
    @ScaledMetric(relativeTo: .footnote) private var avatarSize: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var cardWidth: CGFloat = 220

    /// Explicit memberwise init: `debouncedContent` above is `private`, which would make the
    /// auto-synthesized memberwise init `private` too — every other composer file constructs
    /// this one, so it needs to stay callable.
    init(channel: ChannelDTO, draft: ComposerDraft, mediaAttributes: @escaping (String) -> SelectedMediaAttributes?) {
        self.channel = channel
        self.draft = draft
        self.mediaAttributes = mediaAttributes
    }

    private var isInstagram: Bool { channel.identifier == "instagram" || channel.identifier == "instagram-standalone" }
    private var isLinkedIn: Bool { channel.identifier == "linkedin" || channel.identifier == "linkedin-page" }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            header
            if isInstagram {
                instagramBody
            } else if isLinkedIn {
                linkedInBody
            } else {
                genericBody
            }
        }
        .padding(theme.spacing.sm)
        .frame(width: cardWidth, alignment: .leading)
        .background(Color.token(.card, in: theme))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
        .task(id: draft.content) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            debouncedContent = draft.content
        }
        .onAppear { debouncedContent = draft.content }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(channel.name) preview")
    }

    private var header: some View {
        HStack(spacing: theme.spacing.xs) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: channel.picture.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(ProviderIdentity.color(for: channel.identifier).opacity(0.25))
                }
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

                ProviderBadge(identifier: channel.identifier, size: 12)
                    .offset(x: 2, y: 2)
            }

            Text(channel.name)
                .typeRole(.footnote)
                .foregroundStyle(Color.token(.cardForeground, in: theme))
                .lineLimit(1)
        }
    }

    /// The draft's first media item rendered at `ratio`, or the empty-state frame when there is
    /// none. Preview cards used to fill a flat grey rectangle whether or not media was attached,
    /// which is what made every card read as an empty box in the screenshot run.
    @ViewBuilder
    private func mediaFrame(ratio: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: theme.radius.sm)
            .fill(Color.token(.muted, in: theme))
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                if let first = draft.media.first, let url = URL(string: first.path) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView().tint(Color.token(.mutedForeground, in: theme))
                    }
                    .clipped()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.token(.mutedForeground, in: theme))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
    }

    /// Caption line: the draft's text, or a dimmed placeholder so the card still shows its shape
    /// before anything is typed.
    @ViewBuilder
    private func caption(_ text: String) -> some View {
        Text(text.isEmpty ? "Your caption will appear here" : text)
            .typeRole(.caption)
            .foregroundStyle(
                text.isEmpty
                    ? Color.token(.mutedForeground, in: theme) : Color.token(.cardForeground, in: theme))
    }

    // MARK: - Instagram: aspect-framed media + Instagram's caption truncation (~125 chars + "more")

    private var instagramBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            mediaFrame(ratio: instagramFrameRatio)
            caption(instagramTruncated(debouncedContent))
        }
    }

    /// Instagram's feed frame follows the first media item's crop (falls back to square).
    private var instagramFrameRatio: CGFloat {
        guard let first = draft.media.first, let ratio = mediaAttributes(first.id)?.aspectRatio else { return 1 }
        return ratio.height == 0 ? 1 : CGFloat(ratio.width / ratio.height)
    }

    /// Instagram folds captions in-feed at ~125 characters behind "... more".
    private func instagramTruncated(_ text: String) -> String {
        guard text.count > 125 else { return text }
        let cut = text.index(text.startIndex, offsetBy: 125)
        return "\(text[..<cut])… more"
    }

    // MARK: - LinkedIn: avatar/name/text with a "see more" fold at ~210 characters

    private var linkedInBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            caption(linkedInFolded(debouncedContent))

            if !draft.media.isEmpty {
                mediaFrame(ratio: 16.0 / 9.0)
            }
        }
    }

    private func linkedInFolded(_ text: String) -> String {
        guard text.count > 210 else { return text }
        let cut = text.index(text.startIndex, offsetBy: 210)
        return "\(text[..<cut])… see more"
    }

    // MARK: - Generic fallback for every other provider

    private var genericBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            caption(debouncedContent)
                .lineLimit(4)

            if !draft.media.isEmpty {
                mediaFrame(ratio: 1)
            }
        }
    }
}
