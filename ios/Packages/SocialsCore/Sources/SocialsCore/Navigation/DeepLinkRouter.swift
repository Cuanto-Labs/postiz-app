import Foundation
import Observation

/// One of the app's five primary tabs — the subset of `DeepLinkRoute` that just needs to bring a
/// tab to the front, no further navigation once there. Raw values are also the path/host segment
/// a link uses to name the tab (`cuantosocials://channels`, `https://.../m/channels`).
public enum DeepLinkTab: String, Equatable, Hashable, Sendable, CaseIterable {
    case calendar
    case channels
    case media
    case notifications
    case analytics
    case settings
}

/// Where a universal link, custom-scheme URL, or (via `PushPayloadRoute`) a push notification
/// wants the app to go. `DeepLinkRouter` only ever produces these from a URL/payload — resolving
/// a route into an actual screen push is `RootView`/`MainTabView`'s job.
public enum DeepLinkRoute: Equatable, Sendable {
    case tab(DeepLinkTab)
    case postDetail(postId: String, retryOnOpen: Bool)
    case channelsReconnect(provider: String, internalId: String)
}

/// Parses `cuantosocials://…` and `https://<universal-link host>/m/…` URLs into a `DeepLinkRoute`
/// and holds the most recent one until a view consumes it. OAuth bounce URLs
/// (`cuantosocials://connected`, `/m/auth/callback`) are normally intercepted by
/// `ASWebAuthenticationSession` before they ever reach `onOpenURL`, but `handle(_:)` still parses
/// them safely to `nil` rather than misrouting if one slips through.
///
/// Lives in `SocialsCore` rather than the App target, so it can't reach the App-target-only
/// `AppIdentifiers` constants — `scheme`/`universalLinkPathPrefix` are passed in at init instead,
/// defaulting to the values `AppIdentifiers.urlScheme` and the `/m/*` prefix the
/// apple-app-site-association file declares.
@MainActor
@Observable
public final class DeepLinkRouter {
    public private(set) var pendingRoute: DeepLinkRoute?

    private let scheme: String
    private let universalLinkPathPrefix: String

    public init(scheme: String = "cuantosocials", universalLinkPathPrefix: String = "m") {
        self.scheme = scheme
        self.universalLinkPathPrefix = universalLinkPathPrefix
    }

    /// Parses `url` and, if it resolves to a route, stores it as `pendingRoute`. Returns whether
    /// the URL was recognized at all, so callers (e.g. `onOpenURL`) can decide whether to treat
    /// it as handled.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        guard let route = Self.route(for: url, scheme: scheme, universalLinkPathPrefix: universalLinkPathPrefix)
        else { return false }
        pendingRoute = route
        return true
    }

    /// Directly enqueues an already-resolved route (e.g. from `PushPayloadRoute`, which has no
    /// URL to parse).
    public func enqueue(_ route: DeepLinkRoute) {
        pendingRoute = route
    }

    /// Hands back and clears `pendingRoute` — call once a view has acted on it, so the same
    /// route doesn't re-fire on the next unrelated state change.
    @discardableResult
    public func consume() -> DeepLinkRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    // `nonisolated`: pure parsing, touches no actor-isolated state — lets `PushPayloadRoute`
    // (which has no MainActor context of its own) call it synchronously.
    nonisolated static func route(for url: URL, scheme: String, universalLinkPathPrefix: String) -> DeepLinkRoute? {
        let isCustomScheme = url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame
        let isUniversalLink = url.scheme == "https" || url.scheme == "http"
        guard isCustomScheme || isUniversalLink else { return nil }

        var segments = url.pathComponents.filter { $0 != "/" }
        if isUniversalLink {
            guard segments.first == universalLinkPathPrefix else { return nil }
            segments.removeFirst()
        } else if let host = url.host, !host.isEmpty {
            // Custom-scheme URLs put the route name in the host: `cuantosocials://post/123` has
            // `host == "post"`, `path == "/123"`.
            segments.insert(host, at: 0)
        }

        guard let head = segments.first else { return nil }

        // "channels/reconnect" is a distinct route from the "channels" tab, so it has to be
        // checked before the generic tab lookup below (which would otherwise also match on
        // `head == "channels"` and drop the "reconnect" segment on the floor).
        if head == "channels", segments.count > 1, segments[1] == "reconnect" {
            guard let provider = queryValue("provider", in: url),
                let internalId = queryValue("id", in: url)
            else { return nil }
            return .channelsReconnect(provider: provider, internalId: internalId)
        }

        switch head {
        case "connected", "auth":
            // OAuth bounce — handled by ASWebAuthenticationSession before it reaches us.
            return nil

        case "post":
            guard segments.count > 1 else { return nil }
            let postId = segments[1]
            let retryOnOpen = queryValue("retry", in: url) == "1"
            return .postDetail(postId: postId, retryOnOpen: retryOnOpen)

        default:
            guard let tab = DeepLinkTab(rawValue: head) else { return nil }
            return .tab(tab)
        }
    }

    nonisolated private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}
