import Foundation

/// `GET /mobile/v1/me/personal` response. Mirrors `UsersRepository.getPersonal`'s `select`
/// (`id`, `name`, `bio`) — the Prisma column is `name`, distinct from the `fullname` field the
/// update request uses (`UserDetailDto`).
public struct PersonalDetails: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let bio: String?

    public init(id: String, name: String, bio: String?) {
        self.id = id
        self.name = name
        self.bio = bio
    }
}

/// `POST /mobile/v1/me/personal` body. Mirrors `UserDetailDto` (`fullname`, `bio`).
public struct PersonalDetailsRequest: Sendable, Codable, Equatable {
    public let fullname: String
    public let bio: String?

    public init(fullname: String, bio: String?) {
        self.fullname = fullname
        self.bio = bio
    }
}

/// `GET`/`POST /mobile/v1/me/email-notifications`. Mirrors `EmailNotificationsDto` — same shape
/// for both directions.
public struct EmailNotificationPrefs: Sendable, Codable, Equatable {
    public let sendSuccessEmails: Bool
    public let sendFailureEmails: Bool
    public let sendStreakEmails: Bool

    public init(sendSuccessEmails: Bool, sendFailureEmails: Bool, sendStreakEmails: Bool) {
        self.sendSuccessEmails = sendSuccessEmails
        self.sendFailureEmails = sendFailureEmails
        self.sendStreakEmails = sendStreakEmails
    }
}

/// One org entry in `AccountDeletionPreview`/the `DELETE /account` response. Mirrors
/// `AccountOrgSummary` (`mobile-account.service.ts`).
public struct DeletionPreviewOrg: Sendable, Codable, Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// `GET /mobile/v1/account/deletion-preview` response. Mirrors `AccountDeletionPreview` —
/// orgs where the caller is the sole `SUPERADMIN` land in `orgsToDelete`, the rest in
/// `orgsToLeave`.
public struct DeletionPreview: Sendable, Codable, Equatable {
    public let orgsToDelete: [DeletionPreviewOrg]
    public let orgsToLeave: [DeletionPreviewOrg]

    public init(orgsToDelete: [DeletionPreviewOrg], orgsToLeave: [DeletionPreviewOrg]) {
        self.orgsToDelete = orgsToDelete
        self.orgsToLeave = orgsToLeave
    }
}

/// `DELETE /mobile/v1/account` body. Mirrors `MobileDeleteAccountDto` — `confirm` must be
/// exactly `"DELETE"`.
public struct DeleteAccountRequest: Sendable, Codable, Equatable {
    public let confirm: String

    public init(confirm: String = "DELETE") {
        self.confirm = confirm
    }
}

/// `DELETE /mobile/v1/account` response. Mirrors the controller's literal
/// `{ ok: true, deletedOrgs, leftOrgs }` return shape.
public struct DeleteAccountResponse: Sendable, Codable, Equatable {
    public let ok: Bool
    public let deletedOrgs: [DeletionPreviewOrg]
    public let leftOrgs: [DeletionPreviewOrg]

    public init(ok: Bool, deletedOrgs: [DeletionPreviewOrg], leftOrgs: [DeletionPreviewOrg]) {
        self.ok = ok
        self.deletedOrgs = deletedOrgs
        self.leftOrgs = leftOrgs
    }
}
