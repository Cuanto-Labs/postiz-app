import SocialsCore
import SwiftUI

/// Connected-channels screen: list, connect/reconnect (`ASWebAuthenticationSession` via
/// `WebAuthSession`), and per-row disable/enable/delete. Owns one `ChannelsViewModel`, wired to
/// the app's real `SocialsAPI` from `AppEnvironment`. Mirrors `SignInView`'s composition.
struct ChannelsListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ChannelsViewModel?
    @State private var showAddProvider = false
    @State private var settingsChannel: ChannelDTO?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let model = ChannelsViewModel(
                    api: environment.api, webAuth: WebAuthSession(),
                    callbackURLScheme: AppIdentifiers.urlScheme)
                viewModel = model
                await model.load()
            }
        }
        .navigationTitle("Channels")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddProvider = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a channel")
            }
        }
        .sheet(isPresented: $showAddProvider) {
            if let viewModel {
                AddProviderSheet(channelsViewModel: viewModel)
            }
        }
        .sheet(isPresented: settingsSheetBinding) {
            if let settingsChannel {
                ChannelSettingsSheet(api: environment.api, channel: settingsChannel)
            }
        }
    }

    private var settingsSheetBinding: Binding<Bool> {
        Binding(
            get: { settingsChannel != nil },
            set: { isPresented in if !isPresented { settingsChannel = nil } })
    }

    @ViewBuilder
    private func content(for viewModel: ChannelsViewModel) -> some View {
        if viewModel.isLoading && viewModel.channels.isEmpty {
            ProgressView()
        } else if let errorMessage = viewModel.errorMessage, viewModel.channels.isEmpty {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Channels error")
                Button("Retry") { Task { await viewModel.load() } }
                    .accessibilityLabel("Retry loading channels")
            }
        } else if viewModel.channels.isEmpty {
            Text("No channels connected yet. Tap + to add one.")
                .foregroundStyle(.secondary)
                .accessibilityLabel("No channels connected yet")
        } else {
            List {
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Channels error")
                }
                ForEach(viewModel.channels, id: \.internalId) { channel in
                    ChannelRow(
                        channel: channel, isPending: viewModel.pendingChannelId == channel.internalId,
                        onReconnect: {
                            Task {
                                await viewModel.connect(
                                    provider: channel.identifier, refresh: channel.internalId)
                            }
                        },
                        onSettings: { settingsChannel = channel },
                        onDisable: { Task { await viewModel.disable(channel) } },
                        onEnable: { Task { await viewModel.enable(channel) } },
                        onDelete: { Task { await viewModel.delete(channel) } })
                }
            }
            .refreshable { await viewModel.load() }
        }
    }
}
