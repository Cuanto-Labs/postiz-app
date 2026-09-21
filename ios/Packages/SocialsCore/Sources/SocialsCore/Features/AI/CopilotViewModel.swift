import Foundation
import Observation

/// Drives the AI copilot text-assist sheet: `POST /mobile/v1/ai/suggest`
/// (`MobileAiService.suggest`, mirrors web's copilot rewrite/fit-to-length flow). `content` is
/// capped at 5000 chars server-side — validated client-side too so the error shows before the
/// round trip. A 403 `{msg: 'AI consent required'}` surfaces as `consentRequired`, letting the
/// caller present `AIConsentSheet`; a 402 surfaces as `notInPlan` with no purchase/upgrade copy
/// (VISION decision 8 — AI limits reuse the web's existing plan/credit gate, no in-app store).
@MainActor
@Observable
public final class CopilotViewModel {
    public static let maxContentLength = 5000

    public private(set) var isLoading = false
    public private(set) var suggestions: [String] = []
    public private(set) var errorMessage: String?
    public private(set) var consentRequired = false
    public private(set) var notInPlan = false

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Requests AI suggestions for `content`. `mode` selects `.variations` (rewrite) or
    /// `.fit` (shorten to `maxLength`). Clears prior results/errors before the round trip.
    public func suggest(content: String, mode: AISuggestMode, maxLength: Int? = nil) async {
        suggestions = []
        errorMessage = nil
        consentRequired = false
        notInPlan = false

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Type something first."
            return
        }
        guard content.count <= Self.maxContentLength else {
            errorMessage = "That's too long — please shorten it to \(Self.maxContentLength) characters."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.aiSuggest(
                AISuggestRequest(content: content, mode: mode, maxLength: maxLength))
            suggestions = response.suggestions
        } catch let error as SocialsAPIError {
            switch error {
            case .aiConsentRequired: consentRequired = true
            case .aiNotInPlan: notInPlan = true
            default: errorMessage = Self.message(for: error)
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Clears suggestions and any error/gate state, e.g. after the caller applies a suggestion.
    public func reset() {
        suggestions = []
        errorMessage = nil
        consentRequired = false
        notInPlan = false
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .server, .notFound, .idempotencyConflict, .aiCreditsExhausted, .aiNotInPlan,
            .aiConsentRequired:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
