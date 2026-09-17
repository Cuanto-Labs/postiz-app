import SocialsCore
import SwiftUI

/// Signed-in tab shell: Calendar, Channels, Media, Notifications, Analytics, Settings, each
/// wrapped in its own `NavigationStack` with the org switcher in the toolbar. `RootView` shows
/// this once the session gate resolves to `.signedIn`.
///
/// Also reacts to `DeepLinkRouter.pendingRoute` (from `RootView`'s `onOpenURL`, or a push
/// notification via `PushPayloadRoute`): a `.tab` route just switches `selectedTab`; `.postDetail`
/// and `.channelsReconnect` land on the closest tab that surfaces them today, since neither
/// `PostDetailView` nor an in-tab reconnect flow is wired into the tab tree yet.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DeepLinkRouter.self) private var deepLinkRouter

    let orgId: String?

    /// Separate from `NotificationsView`'s own internal view model — this one exists solely to
    /// surface `unreadCount` as a tab badge, mirroring how every other tab's screen owns its
    /// view model independently.
    @State private var badgeViewModel: NotificationsViewModel?
    @State private var selectedTab: DeepLinkTab = .calendar

    var body: some View {
        TabView(selection: $selectedTab) {
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
            .tag(DeepLinkTab.calendar)

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
            .tag(DeepLinkTab.channels)

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
            .tag(DeepLinkTab.media)

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
            .tag(DeepLinkTab.notifications)

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
            .tag(DeepLinkTab.analytics)

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
            .tag(DeepLinkTab.settings)
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
        .onChange(of: deepLinkRouter.pendingRoute) { _, route in
            guard let route else { return }
            switch route {
            case .tab(let tab):
                selectedTab = tab
            case .postDetail:
                // Not wired to a dedicated screen yet — Calendar is the closest tab that
                // surfaces individual posts.
                selectedTab = .calendar
            case .channelsReconnect:
                selectedTab = .channels
            }
            deepLinkRouter.consume()
        }
    }
}
