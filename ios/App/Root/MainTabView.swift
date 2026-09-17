import SocialsCore
import SwiftUI

/// Signed-in tab shell: Calendar, Channels, Media, Notifications, Analytics, Settings, each
/// wrapped in its own `NavigationStack` with the org switcher in the toolbar. `RootView` shows
/// this once the session gate resolves to `.signedIn`.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    let orgId: String?

    /// Separate from `NotificationsView`'s own internal view model — this one exists solely to
    /// surface `unreadCount` as a tab badge, mirroring how every other tab's screen owns its
    /// view model independently.
    @State private var badgeViewModel: NotificationsViewModel?

    var body: some View {
        TabView {
            NavigationStack {
                CalendarView(orgId: orgId ?? "")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            OrgSwitcherMenu()
                        }
                    }
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            NavigationStack {
                ChannelsListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            OrgSwitcherMenu()
                        }
                    }
            }
            .tabItem {
                Label("Channels", systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationStack {
                MediaLibraryView(
                    viewModel: MediaLibraryViewModel(api: environment.api),
                    uploadQueue: UploadQueue(api: environment.api)
                )
                .navigationTitle("Media")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        OrgSwitcherMenu()
                    }
                }
            }
            .tabItem {
                Label("Media", systemImage: "photo.on.rectangle")
            }

            NavigationStack {
                NotificationsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            OrgSwitcherMenu()
                        }
                    }
            }
            .tabItem {
                Label("Notifications", systemImage: "bell")
            }
            .badge(badgeViewModel?.unreadCount ?? 0)

            NavigationStack {
                AnalyticsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            OrgSwitcherMenu()
                        }
                    }
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            OrgSwitcherMenu()
                        }
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            if badgeViewModel == nil {
                let model = NotificationsViewModel(api: environment.api)
                badgeViewModel = model
                await model.load()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let badgeViewModel else { return }
            Task { await badgeViewModel.refresh() }
        }
    }
}
