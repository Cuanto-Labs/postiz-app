import SocialsCore
import SwiftUI

/// New-post composer: channel picker chips, a global editor shared across every selected
/// channel, and per-channel customize tabs for overriding content on a single channel. Mirrors
/// web's `new-launch` modal (`add.edit.modal.tsx` + `PicksSocialsComponent` + `SelectCurrent` +
/// `editor.tsx`) collapsed into one screen. Owns one `ComposerViewModel`, wired to the app's
/// real `SocialsAPI` from `AppEnvironment` (mirrors `ChannelsListView`'s composition).
struct ComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ComposerViewModel?
    @State private var selectedTab = ComposerTab.global
    @State private var isLoadingChannels = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(for: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    postButton
                }
            }
            .task {
                if viewModel == nil {
                    let model = ComposerViewModel(
                        api: environment.api, draftStore: UserDefaultsDraftStore())
                    model.restoreDraft()
                    viewModel = model
                    await loadChannels(into: model)
                }
            }
        }
    }

    @ViewBuilder
    private var postButton: some View {
        if let viewModel, viewModel.isSaving {
            ProgressView()
        } else {
            Button("Post") {
                guard let viewModel else { return }
                Task {
                    if await viewModel.submit(type: "now") {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel?.isValid != true)
            .accessibilityLabel("Post")
        }
    }

    private func loadChannels(into model: ComposerViewModel) async {
        isLoadingChannels = true
        loadError = nil
        defer { isLoadingChannels = false }
        do {
            let response = try await environment.api.channels()
            model.setChannels(response.channels)
        } catch let error as SocialsAPIError {
            loadError = Self.message(for: error)
        } catch {
            loadError = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .notFound: return "That couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }

    @ViewBuilder
    private func content(for viewModel: ComposerViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingChannels && viewModel.channels.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let loadError, viewModel.channels.isEmpty {
                    VStack(spacing: 12) {
                        Text(loadError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Channels error")
                        Button("Retry") { Task { await loadChannels(into: viewModel) } }
                            .accessibilityLabel("Retry loading channels")
                    }
                } else {
                    ComposerChannelPicker(
                        channels: viewModel.selectableChannels,
                        isSelected: { viewModel.isSelected($0) },
                        onToggle: { channel in
                            viewModel.toggleChannel(channel)
                            if !viewModel.isSelected(channel), selectedTab == .channel(channel.internalId) {
                                selectedTab = .global
                            }
                        })

                    if !viewModel.selectedChannels.isEmpty {
                        tabBar(for: viewModel)
                        Divider()
                        tabContent(for: viewModel)
                    } else {
                        Text("Pick at least one channel to start a post.")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Pick at least one channel to start a post")
                    }

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Post error")
                    }
                }
            }
            .padding()
        }
        .onChange(of: viewModel.globalDraft) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.selectedChannelIds) { _, _ in viewModel.persistDraft() }
    }

    // MARK: - Tabs

    @ViewBuilder
    private func tabBar(for viewModel: ComposerViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabButton(title: "Global", isSelected: selectedTab == .global, systemImage: "globe") {
                    selectedTab = .global
                }
                ForEach(viewModel.selectedChannels, id: \.internalId) { channel in
                    tabButton(
                        title: channel.name, isSelected: selectedTab == .channel(channel.internalId),
                        systemImage: viewModel.isCustomized(channel.internalId) ? "person.crop.circle.fill" : nil
                    ) {
                        selectedTab = .channel(channel.internalId)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tabButton(
        title: String, isSelected: Bool, systemImage: String?, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func tabContent(for viewModel: ComposerViewModel) -> some View {
        switch selectedTab {
        case .global:
            let limit = viewModel.selectedChannels.map(viewModel.charLimit(for:)).min()
                ?? ComposerViewModel.defaultCharLimit
            ComposerEditorPane(
                content: Binding(
                    get: { viewModel.globalDraft.content },
                    set: { viewModel.setGlobalContent($0) }),
                charCount: viewModel.globalDraft.content.count,
                charLimit: limit,
                accessibilityLabel: "Global post content")
        case .channel(let channelId):
            if let channel = viewModel.selectedChannels.first(where: { $0.internalId == channelId }) {
                perChannelPane(for: channel, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func perChannelPane(for channel: ChannelDTO, viewModel: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "Customize for \(channel.name)",
                isOn: Binding(
                    get: { viewModel.isCustomized(channel.internalId) },
                    set: { _ in viewModel.toggleCustomize(for: channel.internalId) })
            )
            .accessibilityLabel("Customize for \(channel.name)")

            ComposerEditorPane(
                content: Binding(
                    get: { viewModel.draft(for: channel.internalId).content },
                    set: { viewModel.setContent($0, for: channel.internalId) }),
                charCount: viewModel.charCount(for: channel),
                charLimit: viewModel.charLimit(for: channel),
                accessibilityLabel: "\(channel.name) post content")
            .disabled(!viewModel.isCustomized(channel.internalId))
            .opacity(viewModel.isCustomized(channel.internalId) ? 1 : 0.5)
        }
    }
}

/// Which draft the customize area is showing: the shared global draft, or a single selected
/// channel's override. Purely view-local navigation state — `ComposerViewModel` tracks
/// customize on/off per channel independently of which tab is currently visible.
private enum ComposerTab: Hashable {
    case global
    case channel(String)
}
