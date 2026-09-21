import SocialsCore
import SwiftUI

/// Comment list + add-comment field for a post. Mirrors web's `comment.component.tsx`
/// `CommentBox` (textarea + "Add comment" button, disabled under 2 characters) backed by
/// `PostDetailViewModel.comments`/`loadComments()`/`addComment(_:)`.
struct PostCommentsView: View {
    let viewModel: PostDetailViewModel
    @State private var newComment = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("No comments yet")
            } else {
                List(viewModel.comments, id: \.id) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comment.content ?? "")
                            .font(.body)
                        if let createdAt = comment.createdAt {
                            Text(createdAt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Comment")
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Add comment", text: $newComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Add comment")

                Button {
                    let text = newComment
                    newComment = ""
                    Task { await viewModel.addComment(text) }
                } label: {
                    if viewModel.isAddingComment {
                        ProgressView()
                    } else {
                        Text("Add comment")
                    }
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                .accessibilityLabel("Submit comment")
            }
            .padding()
        }
        .navigationTitle("Comments")
        .task { await viewModel.loadComments() }
    }
}
