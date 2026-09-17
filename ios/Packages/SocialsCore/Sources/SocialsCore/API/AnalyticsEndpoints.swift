import CuantoNet
import Foundation

/// Analytics builders — split from `SocialsEndpoints` for the same reason as
/// `LibraryEndpoints.swift`. Mirrors `mobile-analytics.controller.ts`.
public enum AnalyticsEndpoints {
    private static var basePath: String { SocialsEndpoints.basePath }

    /// `GET /mobile/v1/analytics/channel/:integration?date=` — `IntegrationService.checkAnalytics`.
    public static func channel(
        integration: String, date: AnalyticsRange, orgId: String? = nil
    ) -> Endpoint<[AnalyticsSeries]> {
        let endpoint = Endpoint<[AnalyticsSeries]>(
            path: "\(basePath)/analytics/channel/\(integration)"
        ).query("date", date.rawValue)
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/analytics/post/:postId?date=` — `PostsService.checkPostAnalytics`.
    public static func post(
        postId: String, date: AnalyticsRange, orgId: String? = nil
    ) -> Endpoint<[AnalyticsSeries]> {
        let endpoint = Endpoint<[AnalyticsSeries]>(
            path: "\(basePath)/analytics/post/\(postId)"
        ).query("date", date.rawValue)
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }
}
