import Foundation
import Observation

/// Drives the AI consent gate: loads the org's consent state from `GET /mobile/v1/ai/consent`
/// and grants/revokes it via `POST /mobile/v1/ai/consent`. Consent is server-authoritative — this
/// view model never flips `isGranted` locally without a successful round trip, so a failed grant
/// leaves the previous state (and its error) visible rather than optimistically unlocking AI.
/// Presented automatically by any feature whose AI call throws `SocialsAPIError.aiConsentRequired`.
@MainActor
@Observable
public final class AIConsentViewModel {
    public private(set) var aiConsentAt: String?
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    public var isGranted: Bool { aiConsentAt != nil }

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Refreshes consent state from the server. Call on sheet appear.
    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.aiConsent()
            aiConsentAt = response.aiConsentAt
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Grants AI consent for the org. On failure the previous `aiConsentAt` is kept and
    /// `errorMessage` is set.
    public func grant() async {
        await setConsent(true)
    }

    /// Revokes AI consent for the org. On failure the previous `aiConsentAt` is kept and
    /// `errorMessage` is set.
    public func revoke() async {
        await setConsent(false)
    }

    private func setConsent(_ granted: Bool) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let response = try await api.setAIConsent(AIConsentRequest(granted: granted))
            aiConsentAt = response.aiConsentAt
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .server, .notFound, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted,
            .aiConsentRequired:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
