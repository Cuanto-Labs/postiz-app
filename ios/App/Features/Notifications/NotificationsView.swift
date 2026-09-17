import SocialsCore
import SwiftUI

/// Notifications feed screen: unread count, list, pull-to-refresh. Mirrors web's
/// `NotificationOpenComponent`/`NotificationComponent` in `notification.component.tsx`, wired to
/// the app's real `SocialsAPI` from `AppEnvironment` (mirrors `PostDetailView`).
struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: NotificationsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Notifications")
        .task {
            if viewModel == nil {
                let model = NotificationsViewModel(api: environment.api)
                viewModel = model
                await model.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: NotificationsViewModel) -> some View {
        if viewModel.isLoading && viewModel.notifications.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.notifications.isEmpty {
            emptyState(for: viewModel)
        } else {
            List {
                if viewModel.unreadCount > 0 {
                    Section {
                        Text("\(viewModel.unreadCount) unread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(viewModel.unreadCount) unread notifications")
                    }
                }
                ForEach(Array(viewModel.notifications.enumerated()), id: \.offset) { _, notification in
                    NotificationRow(
                        notification: notification,
                        isUnread: Self.isUnread(notification, lastRead: viewModel.lastReadNotifications))
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func emptyState(for viewModel: NotificationsViewModel) -> some View {
        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Notifications error")
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .accessibilityLabel("Retry loading notifications")
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("No notifications")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("No notifications")
                .refreshable { await viewModel.refresh() }
        }
    }

    /// Mirrors web's `ShowNotification` read-state check: unread when `createdAt` is newer than
    /// the `lastReadNotifications` watermark (no per-row id/read flag exists server-side).
    private static func isUnread(_ notification: MobileNotification, lastRead: String) -> Bool {
        guard !lastRead.isEmpty else { return true }
        return notification.createdAt > lastRead
    }
}
