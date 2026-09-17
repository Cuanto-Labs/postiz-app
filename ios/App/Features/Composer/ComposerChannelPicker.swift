import SocialsCore
import SwiftUI

/// Channel-pick chips: one avatar per selectable channel, tinted border while selected —
/// mirrors web's `PicksSocialsComponent` (grayscale + transparent border when unpicked,
/// `#622FF6`-bordered when picked). Tapping toggles the pick via
/// `ComposerViewModel.toggleChannel`.
struct ComposerChannelPicker: View {
    let channels: [ChannelDTO]
    let isSelected: (ChannelDTO) -> Bool
    let onToggle: (ChannelDTO) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
            AsyncImage(url: channel.picture.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.secondary.opacity(0.2))
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .saturation(selected ? 1 : 0)
            .overlay(
                Circle()
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(channel.name)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
