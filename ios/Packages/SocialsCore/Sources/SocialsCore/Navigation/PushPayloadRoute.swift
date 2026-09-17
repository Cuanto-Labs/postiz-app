import Foundation

/// Maps a push notification's payload (the `userInfo`/`aps` dictionary APNs hands to
/// `UNUserNotificationCenterDelegate`) to a `DeepLinkRoute`, so tapping a notification lands in
/// the same place a matching in-app deep link would.
///
/// Mirrors the payload `PushService.notifyOrg` actually sends (`push.service.ts`,
/// `docs/MOBILE-API.md` § Push): `{ aps: { alert, sound, category, thread-id }, kind, link }`.
/// `kind` is one of `PushEventKind` (`post.published`, `post.failed`,
/// `channel.reconnect_needed`); `link` is whatever URL (if any) the backend's `URL_REGEX` found
/// in the notification's message text — not guaranteed to be an internal deep link (e.g. it can
/// be the published post's URL on the external platform), so it's only used when it actually
/// parses as one via `DeepLinkRouter`'s own URL parsing.
public enum PushPayloadRoute {
    /// `payload` is the raw notification `userInfo` — straight off
    /// `UNNotificationContent.userInfo` or a background push's `[AnyHashable: Any]`.
    public static func route(
        from payload: [AnyHashable: Any], scheme: String = "cuantosocials",
        universalLinkPathPrefix: String = "m"
    ) -> DeepLinkRoute? {
        if let linkString = payload["link"] as? String, let url = URL(string: linkString),
            let route = DeepLinkRouter.route(
                for: url, scheme: scheme, universalLinkPathPrefix: universalLinkPathPrefix)
        {
            return route
        }

        guard let kind = payload["kind"] as? String else { return nil }
        switch kind {
        case "post.published", "post.failed":
            // No postId in the payload (`link` is the external post URL, not an internal one) —
            // Calendar is the closest tab that surfaces the post itself.
            return .tab(.calendar)
        case "channel.reconnect_needed":
            // No provider/internalId in the payload, so `.channelsReconnect` (which requires
            // both) isn't reachable from push alone — land on the Channels tab instead.
            return .tab(.channels)
        default:
            return nil
        }
    }
}
