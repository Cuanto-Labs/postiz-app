import Foundation
import Observation

/// State machine for the destructive account-deletion flow. Mirrors web's
/// `delete-account.component.tsx`: show a preview of what's deleted vs left, require the user to
/// type "DELETE" to confirm, then call the API and tear down the local session + push
/// registration. Per product decision: any active subscription is cancelled at period end
/// server-side, but the account's data is deleted immediately — callers should surface that in
/// copy, this type only owns the state transitions.
public enum DeleteAccountPhase: Equatable, Sendable {
    case preview
    case confirming
    case deleting
    case deleted
    case failed(String)
}

@MainActor
@Observable
public final class DeleteAccountViewModel {
    public private(set) var preview: DeletionPreview?
    public private(set) var phase: DeleteAccountPhase = .preview
    public private(set) var isLoadingPreview = false
    public private(set) var errorMessage: String?

    /// Bound to the "type DELETE to confirm" text field.
    public var confirmText: String = ""

    /// Client-side gate: `delete()` is a no-op unless this is `true`, so a mistyped confirmation
    /// never reaches the network.
    public var canDelete: Bool { confirmText == "DELETE" }

    private let api: any SocialsAPI
    private let sessionStore: SessionStore
    private let pushRegistration: PushRegistrationViewModel

    public init(
        api: any SocialsAPI, sessionStore: SessionStore, pushRegistration: PushRegistrationViewModel
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.pushRegistration = pushRegistration
    }

    /// Loads which orgs would be deleted outright (the user is the sole owner) vs merely left
    /// (shared orgs owned by someone else). Call on appear.
    public func loadPreview() async {
        isLoadingPreview = true
        errorMessage = nil
        defer { isLoadingPreview = false }
        do {
            preview = try await api.deletionPreview()
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Couldn't load your account details. Please try again."
        }
    }

    /// Permanently deletes the account. No-ops unless `canDelete` (the user typed "DELETE"
    /// exactly). On success: unregisters the device's push token, then clears the local session,
    /// then moves to `.deleted` so the caller can show a farewell screen before navigating away.
    /// On failure (including a 429 throttle from the 3/min server-side limit) moves to `.failed`
    /// with a user-facing message.
    public func delete() async {
        guard canDelete else { return }
        phase = .deleting
        errorMessage = nil
        do {
            _ = try await api.deleteAccount()
            await pushRegistration.signOut()
            await sessionStore.signOut()
            phase = .deleted
        } catch let error as SocialsAPIError {
            let message = Self.message(for: error)
            errorMessage = message
            phase = .failed(message)
        } catch {
            let message = "Couldn't delete your account. Please try again."
            errorMessage = message
            phase = .failed(message)
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .server(let code, let message):
            if code == 429 {
                return message
                    ?? "Too many attempts. Please wait a minute before trying again."
            }
            return "Something went wrong. Please try again."
        case .notFound, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted,
            .aiConsentRequired:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
