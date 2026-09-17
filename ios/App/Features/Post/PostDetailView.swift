import SocialsCore
import SwiftUI

/// Post detail: status timeline, per-channel results, actions (edit/duplicate/delete/retry),
/// a share preview of the post's own content, comments, and statistics. Owns one
/// `PostDetailViewModel`, wired to the app's real `SocialsAPI` from `AppEnvironment` (mirrors
/// `ChannelsListView`'s composition). Web has no single matching screen — this composes the
/// same server endpoints web splits across `calendar.tsx` (edit/duplicate/delete), the post
/// preview link, `comments/comment.component.tsx`, and `statistics.tsx`.
///
/// `onEdit`/`onDuplicate` are injected rather than presenting the composer directly: opening an
/// existing post for editing or prefilling a duplicate requires `ComposerViewModel` to support a
/// non-`nil` group / prefilled draft, which it doesn't yet (create-only today) and which is out
/// of scope here — that view model lives in another lane's folder. Callers that own navigation
/// (and can react once that support lands) pass real closures; until then the buttons stay
/// visible and disabled with an explanatory message rather than silently doing nothing.
struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: PostDetailViewModel?
    @State private var showDeleteConfirm = false

    let postId: String
    var onEdit: ((PostGroupDTO) -> Void)?
    var onDuplicate: ((PostGroupDTO) -> Void)?

    init(postId: String, onEdit: ((PostGroupDTO) -> Void)? = nil, onDuplicate: ((PostGroupDTO) -> Void)? = nil) {
        self.postId = postId
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Post")
        .toolbar {
            if let viewModel {
                ToolbarItem(placement: .primaryAction) {
                    actionsMenu(for: viewModel)
                }
            }
        }
        .task {
            if viewModel == nil {
                let model = PostDetailViewModel(postId: postId, api: environment.api)
                viewModel = model
                await model.load()
                await model.loadPreview()
            }
        }
        .onChange(of: viewModel?.isDeleted) { _, isDeleted in
            if isDeleted == true { dismiss() }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsMenu(for viewModel: PostDetailViewModel) -> some View {
        Menu {
            if let post = viewModel.post {
                Button("Edit") { onEdit?(post) }
                    .disabled(onEdit == nil)
                    .accessibilityLabel("Edit post")

                Button("Duplicate") { onDuplicate?(post) }
                    .disabled(onDuplicate == nil)
                    .accessibilityLabel("Duplicate post")
            }

            if viewModel.statusTimeline?.isFailed == true {
                Button("Retry") { Task { await viewModel.retry() } }
                    .accessibilityLabel("Retry post")
            }

            Button("Delete", role: .destructive) { showDeleteConfirm = true }
                .accessibilityLabel("Delete post")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Post actions")
        .confirmationDialog(
            "Are you sure you want to delete this post?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for viewModel: PostDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading && viewModel.post == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let post = viewModel.post {
                    statusSection(post: post, viewModel: viewModel)
                    contentSection(post: post)
                    shareSection(post: post)
                    channelResultsSection(viewModel: viewModel)

                    NavigationLink {
                        PostCommentsView(viewModel: viewModel)
                    } label: {
                        Label("Comments (\(viewModel.comments.count))", systemImage: "bubble.left")
                    }
                    .accessibilityLabel("View comments")

                    NavigationLink {
                        PostStatisticsView(viewModel: viewModel)
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                    .accessibilityLabel("View statistics")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Post detail error")
                }
            }
            .padding()
        }
        .task { await viewModel.loadComments() }
    }

    @ViewBuilder
    private func statusSection(post: PostGroupDTO, viewModel: PostDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(PostStatusTimeline.steps, id: \.self) { step in
                    Text(step.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            (viewModel.statusTimeline?.isReached(step) ?? false)
                                ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1)
                        )
                        .clipShape(Capsule())
                }
                if viewModel.statusTimeline?.isFailed == true {
                    Text("Failed")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .accessibilityLabel("Post status timeline")

            if let date = post.publishDate {
                Text(date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isRetrying {
                ProgressView().accessibilityLabel("Retrying post")
            }
        }
    }

    @ViewBuilder
    private func contentSection(post: PostGroupDTO) -> some View {
        if !Self.text(from: post.content).isEmpty {
            Text(Self.text(from: post.content))
                .font(.body)
                .accessibilityLabel("Post content")
        }
        if let channel = post.integration {
            Text(channel.name ?? channel.providerIdentifier ?? "Channel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Post channel")
        }
    }

    @ViewBuilder
    private func shareSection(post: PostGroupDTO) -> some View {
        let text = Self.text(from: post.content)
        if !text.isEmpty {
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Share post content")
        }
    }

    @ViewBuilder
    private func channelResultsSection(viewModel: PostDetailViewModel) -> some View {
        if viewModel.isLoadingPreview {
            ProgressView().accessibilityLabel("Loading channel results")
        } else if !viewModel.previewPosts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Channel results")
                    .font(.headline)
                    .accessibilityLabel("Channel results")
                ForEach(viewModel.previewPosts, id: \.id) { channelPost in
                    HStack {
                        Text(channelPost.integration?.name ?? "Channel")
                        Spacer()
                        Text(PostStatusStep(rawStatus: channelPost.status).rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private static func text(from content: PostContentValue?) -> String {
        switch content {
        case .string(let value): return value
        case .items(let items): return items.compactMap(\.content).joined(separator: "\n\n")
        case .none: return ""
        }
    }
}
