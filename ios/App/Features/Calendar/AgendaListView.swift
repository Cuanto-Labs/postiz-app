import SocialsCore
import SwiftUI

/// Flat post list, shared by two `CalendarDisplay` modes: `.day` (single-day agenda, sorted by
/// publish time — mirrors web's day column in `calendar.tsx`) and `.list` (paginated, mirrors
/// web's `time.table.tsx` / list SWR key, backed by `CalendarViewModel.listPosts`).
struct AgendaListView: View {
    let viewModel: CalendarViewModel

    var body: some View {
        Group {
            if viewModel.display == .list {
                listBody
            } else {
                dayBody
            }
        }
    }

    // MARK: - Day/agenda

    private var dayBody: some View {
        Group {
            if viewModel.posts.isEmpty {
                emptyState("No posts scheduled for this day")
            } else {
                List(sortedDayPosts, id: \.id) { post in
                    CalendarPostCard(
                        publishDate: post.publishDate, status: post.status,
                        channelName: post.integration?.name, channelPicture: post.integration?.picture,
                        content: post.content)
                }
                .listStyle(.plain)
            }
        }
    }

    private var sortedDayPosts: [PostGroupDTO] {
        viewModel.posts.sorted { ($0.publishDate ?? "") < ($1.publishDate ?? "") }
    }

    // MARK: - List (paginated)

    private var listBody: some View {
        VStack(spacing: 0) {
            if viewModel.listPosts.isEmpty {
                emptyState("No posts yet")
            } else {
                List(viewModel.listPosts, id: \.id) { post in
                    CalendarPostCard(
                        publishDate: post.publishDate, status: post.state,
                        channelName: post.integration?.name, channelPicture: post.integration?.picture,
                        content: post.content)
                }
                .listStyle(.plain)
            }

            if viewModel.listTotalPages > 1 {
                paginationBar
            }
        }
    }

    private var paginationBar: some View {
        HStack {
            Button {
                Task { await viewModel.previousListPage() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.listPage == 0)
            .accessibilityLabel("Previous page")

            Spacer()

            Text("Page \(viewModel.listPage + 1) of \(viewModel.listTotalPages)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Page \(viewModel.listPage + 1) of \(viewModel.listTotalPages)")

            Spacer()

            Button {
                Task { await viewModel.nextListPage() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.listPage + 1 >= viewModel.listTotalPages)
            .accessibilityLabel("Next page")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(message)
    }
}
