import CuantoNet
import Foundation

/// Builders for `/mobile/v1/me/*` and `/mobile/v1/account/*`. Mirrors
/// `mobile-me.controller.ts` and `mobile-account.controller.ts` — unlike `OrgEndpoints`, these
/// routes only inject `@GetUserFromRequest()`, no `@GetOrgFromRequest()`, so builders take no
/// `orgId`/`showorg` header.
public enum AccountSettingsEndpoints {
    private static var basePath: String { SocialsEndpoints.basePath }

    /// `GET /mobile/v1/me/personal` — `UsersService.getPersonal`.
    public static func personal() -> Endpoint<PersonalDetails> {
        Endpoint(path: "\(basePath)/me/personal")
    }

    /// `POST /mobile/v1/me/personal` — `UsersService.changePersonal`.
    public static func updatePersonal(_ body: PersonalDetailsRequest) throws -> Endpoint<
        PersonalDetails
    > {
        try Endpoint(method: .post, path: "\(basePath)/me/personal", body: .json(body))
    }

    /// `GET /mobile/v1/me/email-notifications` — `UsersService.getEmailNotifications`.
    public static func emailNotifications() -> Endpoint<EmailNotificationPrefs> {
        Endpoint(path: "\(basePath)/me/email-notifications")
    }

    /// `POST /mobile/v1/me/email-notifications` — `UsersService.updateEmailNotifications`.
    public static func updateEmailNotifications(_ body: EmailNotificationPrefs) throws
        -> Endpoint<EmailNotificationPrefs>
    {
        try Endpoint(
            method: .post, path: "\(basePath)/me/email-notifications", body: .json(body))
    }

    /// `GET /mobile/v1/account/deletion-preview` — `MobileAccountService.preview`.
    public static func deletionPreview() -> Endpoint<DeletionPreview> {
        Endpoint(path: "\(basePath)/account/deletion-preview")
    }

    /// `DELETE /mobile/v1/account` — `MobileAccountService.deleteAccount`.
    public static func deleteAccount(_ body: DeleteAccountRequest) throws -> Endpoint<
        DeleteAccountResponse
    > {
        try Endpoint(method: .delete, path: "\(basePath)/account", body: .json(body))
    }
}
