import SocialsCore
import SwiftUI

/// One connected channel: picture, name, and a status/action affordance. Reconnect surfaces
/// directly on the row (mirrors web's `menu.tsx` "Reconnect channel" button when
/// `refreshNeeded`); everything else lives behind `ChannelMenu`.
struct ChannelRow: View {
    let channel: ChannelDTO
    let isPending: Bool
    var onReconnect: () -> Void = {}
    var onSettings: () -> Void = {}
    var onDisable: () -> Void = {}
    var onEnable: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.picture.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                // Brand mark rather than a flat grey disc: most connected channels come back
                // with no `picture`, and a list of identical grey circles gives no clue which
                // row is which network.
                ProviderBadge(identifier: channel.identifier, size: 40)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                    .foregroundStyle(channel.disabled ? .secondary : .primary)
                if let customerName = channel.customer?.name {
                    Text(customerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isPending {
                ProgressView()
            } else if channel.refreshNeeded {
                Button("Reconnect", action: onReconnect)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Reconnect \(channel.name)")
            }

            ChannelMenu(
                channel: channel, onSettings: onSettings, onDisable: onDisable,
                onEnable: onEnable, onDelete: onDelete)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(channel.name)\(channel.disabled ? ", disabled" : "")\(channel.refreshNeeded ? ", needs reconnect" : "")"
        )
    }
}
