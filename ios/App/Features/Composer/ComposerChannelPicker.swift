import CuantoUI
import SocialsCore
import SwiftUI

/// Channel-pick chips: one avatar per selectable channel, tinted border while selected —
/// mirrors web's `PicksSocialsComponent` (grayscale + transparent border when unpicked,
/// brand-bordered when picked). Tapping toggles the pick via
/// `ComposerViewModel.toggleChannel`.
///
/// Each chip carries the provider's own badge and its name: the avatar alone made Instagram and
/// LinkedIn two identical circles whenever the picture hadn't loaded (App Store screenshot run,
/// `02-channels`/`03-composer`).
struct ComposerChannelPicker: View {
    let channels: [ChannelDTO]
    let isSelected: (ChannelDTO) -> Bool
    let onToggle: (ChannelDTO) -> Void

    @Environment(\.cuantoTheme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(channels, id: \.internalId) { channel in
                    chip(for: channel)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func chip(for channel: ChannelDTO) -> some View {
        let selected = isSelected(channel)
        Button {
            onToggle(channel)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: channel.picture.flatMap(URL.init(string:))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(ProviderIdentity.color(for: channel.identifier).opacity(0.25))
                            .overlay {
                                Image(systemName: ProviderIdentity.symbol(for: channel.identifier))
                                    .foregroundStyle(ProviderIdentity.color(for: channel.identifier))
                            }
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .saturation(selected ? 1 : 0)
                    .overlay(
                        Circle()
                            .strokeBorder(selected ? Color.token(.primary, in: theme) : .clear, lineWidth: 2)
                    )

                    ProviderBadge(identifier: channel.identifier, size: 16)
                        .saturation(selected ? 1 : 0)
                        .offset(x: 2, y: 2)
                }

                Text(channel.name)
                    .typeRole(.caption)
                    .foregroundStyle(
                        selected
                            ? Color.token(.foreground, in: theme) : Color.token(.mutedForeground, in: theme)
                    )
                    .lineLimit(1)
                    .frame(maxWidth: 58)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(channel.name)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
