import Foundation
import Observation

/// Personal profile section: loads `GET /me/personal` (`fullname`, `bio`) and saves via
/// `POST /me/personal`, mirroring the web `global.settings.tsx` personal form and its
/// `UserDetailDto` validation (`fullname` required, at least 3 characters; `bio` optional).
@MainActor
@Observable
public final class AccountDetailsViewModel {
    public var fullname: String = ""
    public var bio: String = ""
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Mirrors `UserDetailDto`: `fullname` is required and at least 3 characters.
    public var canSave: Bool {
        fullname.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    /// Loads the current profile. Call on appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let details = try await api.personalDetails()
            fullname = details.name
            bio = details.bio ?? ""
        } catch {
            errorMessage = "Couldn't load your profile. Please try again."
        }
    }

    /// Saves `fullname`/`bio`. Validates client-side first, matching `UserDetailDto`; on
    /// failure the current field values are kept so the user doesn't lose their edits.
    public func save() async {
        guard canSave else {
            errorMessage = "Full name must be at least 3 characters."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let details = try await api.updatePersonalDetails(
                PersonalDetailsRequest(fullname: fullname, bio: trimmedBio.isEmpty ? nil : bio))
            fullname = details.name
            bio = details.bio ?? ""
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Couldn't save your profile. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .validation(let message):
            return message ?? "Check your details and try again."
        case .offline:
            return "You're offline. Check your connection and try again."
        default:
            return "Couldn't save your profile. Please try again."
        }
    }
}
