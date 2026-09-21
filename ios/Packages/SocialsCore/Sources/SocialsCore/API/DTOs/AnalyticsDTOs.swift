import Foundation

// MARK: - Analytics (mobile-analytics.controller.ts)

/// `date` query param for `GET /mobile/v1/analytics/channel/:integration` and
/// `GET /mobile/v1/analytics/post/:postId` — days window, sent as a string (mirrors
/// `MobileAnalyticsQueryDto.date`, `@IsNumberString`).
public enum AnalyticsRange: String, Sendable, Equatable, CaseIterable {
    case sevenDays = "7"
    case thirtyDays = "30"
    case ninetyDays = "90"
}

/// One point of `AnalyticsSeries.data` (`social.integrations.interface.ts`'s `AnalyticsData.data`
/// entries) — `total` is a string, mirroring the provider analytics payloads verbatim.
public struct AnalyticsPoint: Codable, Sendable, Equatable {
    public let total: String
    public let date: String

    public init(total: String, date: String) {
        self.total = total
        self.date = date
    }
}

/// `GET /mobile/v1/analytics/channel/:integration` and `GET /mobile/v1/analytics/post/:postId`
/// response item (`IntegrationService.checkAnalytics` / `PostsService.checkPostAnalytics`,
/// `AnalyticsData` in `social.integrations.interface.ts`). Web renders one chart per series.
public struct AnalyticsSeries: Codable, Sendable, Equatable {
    public let label: String
    public let data: [AnalyticsPoint]
    public let percentageChange: Double

    public init(label: String, data: [AnalyticsPoint], percentageChange: Double) {
        self.label = label
        self.data = data
        self.percentageChange = percentageChange
    }
}
