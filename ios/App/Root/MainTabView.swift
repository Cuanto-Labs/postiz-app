import Foundation
import SocialsCore
import SwiftUI

/// The tabs `MainTabView` actually renders — one fewer than `DeepLinkTab`, since Analytics and
/// Settings live inside the "More" tab rather than getting one each. Kept separate from
/// `DeepLinkTab` (which also names URL route segments, and has no "more" of its own) so this
/// stays a pure UI/tab-selection concern.
private enum MainTab: Hashable {
    case calendar
    case channels
    case media
    case notifications
    case more
}

/// Row shown in the "More" tab's list — the destinations that don't get a tab of their own.
private enum MoreDestination: Hashable {
    case analytics
    case settings
}

/// Signed-in tab shell: Calendar, Channels, Media, Notifications, and a "More" tab holding
/// Analytics and Settings, each of the first four wrapped in its own `NavigationStack` with the
/// org switcher in the toolbar. `RootView` shows this once the session gate resolves to
/// `.signedIn`.
///
/// Analytics and Settings aren't real tabs: with all six as tabs, iPhone's compact width
/// collapses the last two into UIKit's automatic "More" tab, whose `UIMoreNavigationController`
/// wraps our own `NavigationStack` — any push inside then shows two stacked back buttons. A
/// single hand-rolled "More" tab (list of rows, one `NavigationStack`) avoids the double wrapper.
///
/// Also reacts to `DeepLinkRouter.pendingRoute` (from `RootView`'s `onOpenURL`, or a push
/// notification via `PushPayloadRoute`): a `.tab` route to `.calendar`/`.channels`/`.media`/
/// `.notifications` just switches `selectedTab`; `.analytics`/`.settings` select the More tab and
/// push the matching row onto `morePath`. `.postDetail` and `.channelsReconnect` land on the
/// closest tab that surfaces them today, since neither `PostDetailView` nor an in-tab reconnect
/// flow is wired into the tab tree yet.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DeepLinkRouter.self) private var deepLinkRouter

    let orgId: String?

    /// Separate from `NotificationsView`'s own internal view model — this one exists solely to
    /// surface `unreadCount` as a tab badge, mirroring how every other tab's screen owns its
    /// view model independently.
    @State private var badgeViewModel: NotificationsViewModel?
    /// Owned here rather than constructed inline in `body`: a fresh `MediaLibraryViewModel` per
    /// render replaced the loaded one every time anything else in this view changed (the
    /// notification badge arriving was enough), and since the view's identity never changed its
    /// `.task` didn't re-run — the Media tab went permanently back to "No media yet."
    @State private var mediaViewModel: MediaLibraryViewModel?
    @State private var mediaUploadQueue: UploadQueue?
    @State private var selectedTab: MainTab = MainTabView.initialTab()
    @State private var morePath = NavigationPath()

    /// `-uiTestTab <name>` (`ScreenshotUITests`) picks which tab a stub-mode relaunch lands on
    /// directly — tapping a tab-bar button reports a `{-1,-1}` hit point on this app, so the
    /// screenshot harness relaunches per tab instead of tapping. Inert outside `-uiTestStub`.
    private static func initialTab() -> MainTab {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestStub"),
            let raw = UITestFixtures.launchArgValue("-uiTestTab")
        else { return .calendar }
        switch raw {
        case "channels": return .channels
        case "media": return .media
        case "notifications": return .notifications
        case "more": return .more
        default: return .calendar
        }
    }

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
            .tag(MainTab.calendar)

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
            .tag(MainTab.channels)

            NavigationStack {
                Group {
                    if let mediaViewModel, let mediaUploadQueue {
                        MediaLibraryView(viewModel: mediaViewModel, uploadQueue: mediaUploadQueue)
                    } else {
                        ProgressView().accessibilityLabel("Loading media")
                    }
                }
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
            .tag(MainTab.media)

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
            .tag(MainTab.notifications)

            NavigationStack(path: $morePath) {
                List {
                    NavigationLink("Analytics", value: MoreDestination.analytics)
                    NavigationLink("Settings", value: MoreDestination.settings)
                }
                .navigationTitle("More")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        OrgSwitcherMenu()
                    }
                }
                .navigationDestination(for: MoreDestination.self) { destination in
                    switch destination {
                    case .analytics:
                        AnalyticsView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            .tag(MainTab.more)
        }
        .task {
            if mediaViewModel == nil {
                mediaViewModel = MediaLibraryViewModel(api: environment.api)
                mediaUploadQueue = UploadQueue(api: environment.api)
            }
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
            case .tab(.calendar):
                selectedTab = .calendar
            case .tab(.channels):
                selectedTab = .channels
            case .tab(.media):
                selectedTab = .media
            case .tab(.notifications):
                selectedTab = .notifications
            case .tab(.analytics):
                selectedTab = .more
                morePath = NavigationPath([MoreDestination.analytics])
            case .tab(.settings):
                selectedTab = .more
                morePath = NavigationPath([MoreDestination.settings])
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
