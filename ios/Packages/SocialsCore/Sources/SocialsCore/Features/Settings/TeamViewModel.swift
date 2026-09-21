import Foundation
import Observation

/// Team members: loads from `api.teamMembers()`, invites via `api.addTeamMember`, removes via
/// `api.removeTeamMember`. Mirrors web's `teams.component.tsx`: list with role, add member
/// (email, USER|ADMIN, sendEmail toggle default off), remove with confirmation owned by the view.
@MainActor
@Observable
public final class TeamViewModel {
    public private(set) var members: [TeamMember] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Refreshes `members` from the backend. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.teamMembers()
            members = response.users
        } catch {
            errorMessage = "Couldn't load your team. Please try again."
        }
    }

    /// Invites a new team member. Validates the email locally (mirrors `AddTeamMemberDto`'s
    /// `@ValidateIf((o) => o.sendEmail) @IsEmail()` — email is only required/validated when
    /// `sendEmail` is on, since otherwise web just returns a copyable invite link) before calling
    /// the API — an invalid email never reaches `addTeamMember`.
    public func invite(email: String, role: TeamRole, sendEmail: Bool) async {
        errorMessage = nil
        guard !sendEmail || Self.isValidEmail(email) else {
            errorMessage = "Enter a valid email address."
            return
        }
        do {
            _ = try await api.addTeamMember(
                AddTeamMemberRequest(email: email, role: role, sendEmail: sendEmail))
            await load()
        } catch {
            errorMessage = "Couldn't invite that member. Please try again."
        }
    }

    /// Removes the member whose user id is `id`, then reloads the list.
    public func remove(id: String) async {
        errorMessage = nil
        do {
            _ = try await api.removeTeamMember(id)
            await load()
        } catch {
            errorMessage = "Couldn't remove that member. Please try again."
        }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
