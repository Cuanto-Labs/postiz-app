import CuantoNet
import Foundation

/// Org builders — split from `SocialsEndpoints` for the same reason as `LibraryEndpoints.swift`.
/// Mirrors `mobile-org.controller.ts`.
public enum OrgEndpoints {
    private static var basePath: String { SocialsEndpoints.basePath }

    /// `GET /mobile/v1/org/team` — `OrganizationService.getTeam`.
    public static func team(orgId: String? = nil) -> Endpoint<TeamListResponse> {
        SocialsEndpoints.withOrg(Endpoint(path: "\(basePath)/org/team"), orgId)
    }

    /// `POST /mobile/v1/org/team` — `OrganizationService.inviteTeamMember`.
    public static func addTeamMember(
        _ body: AddTeamMemberRequest, orgId: String? = nil
    ) throws -> Endpoint<OkResponse> {
        let endpoint = try Endpoint<OkResponse>(
            method: .post, path: "\(basePath)/org/team", body: .json(body))
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `DELETE /mobile/v1/org/team/:id` — `OrganizationService.deleteTeamMember`.
    public static func removeTeamMember(
        _ id: String, orgId: String? = nil
    ) -> Endpoint<OkResponse> {
        SocialsEndpoints.withOrg(
            Endpoint(method: .delete, path: "\(basePath)/org/team/\(id)"), orgId)
    }

    /// `GET /mobile/v1/org/shortlink` — `OrganizationService.getShortlinkPreference`.
    public static func shortlink(orgId: String? = nil) -> Endpoint<ShortlinkPreferenceResponse> {
        SocialsEndpoints.withOrg(Endpoint(path: "\(basePath)/org/shortlink"), orgId)
    }

    /// `POST /mobile/v1/org/shortlink` — `OrganizationService.updateShortlinkPreference`.
    public static func updateShortlink(
        _ body: ShortlinkPreferenceRequest, orgId: String? = nil
    ) throws -> Endpoint<ShortlinkPreferenceResponse> {
        let endpoint = try Endpoint<ShortlinkPreferenceResponse>(
            method: .post, path: "\(basePath)/org/shortlink", body: .json(body))
        return SocialsEndpoints.withOrg(endpoint, orgId)
    }

    /// `GET /mobile/v1/org/webhooks` — `WebhooksService.getWebhooks`. Read-only per VISION §7.
    public static func webhooks(orgId: String? = nil) -> Endpoint<[MobileWebhook]> {
        SocialsEndpoints.withOrg(Endpoint(path: "\(basePath)/org/webhooks"), orgId)
    }
}
