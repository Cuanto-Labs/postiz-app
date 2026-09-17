import SocialsCore
import SwiftUI

/// Per-channel overflow menu: disable/enable, delete. Mirrors web's `menu.tsx` context menu —
/// disable and delete both confirm first since they're disruptive (delete additionally can be
/// rejected by the backend with a dedicated message when posts still reference the channel).
struct ChannelMenu: View {
    let channel: ChannelDTO
    var onSettings: () -> Void = {}
    var onDisable: () -> Void = {}
    var onEnable: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var showDisableConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            Button("Channel settings", action: onSettings)
                .accessibilityLabel("Settings for \(channel.name)")

            if channel.disabled {
                Button("Enable channel", action: onEnable)
                    .accessibilityLabel("Enable \(channel.name)")
            } else {
                Button("Disable channel") { showDisableConfirm = true }
                    .accessibilityLabel("Disable \(channel.name)")
            }

            Button("Delete channel", role: .destructive) { showDeleteConfirm = true }
                .accessibilityLabel("Delete \(channel.name)")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More actions for \(channel.name)")
        .confirmationDialog(
            "Disable \(channel.name)?", isPresented: $showDisableConfirm, titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive, action: onDisable)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Posts won't publish to this channel while it's disabled.")
        }
        .confirmationDialog(
            "Delete \(channel.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}
