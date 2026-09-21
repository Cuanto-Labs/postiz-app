import Foundation
import Observation

/// Drives the AI image generation screen: `GET /mobile/v1/ai/credits?type=ai_images` for the
/// remaining-credits meter and `POST /mobile/v1/ai/image` to generate (mirrors web's
/// `ai.image.tsx`). Generated images are already saved to the org's media library server-side
/// (`AIMediaResult`), so there's nothing further to persist here. Out-of-credits/not-in-plan
/// states are plain status text with no purchase/upgrade copy (VISION decision 8 — AI limits
/// reuse the web backend's existing plan/credit gate, no in-app store).
@MainActor
@Observable
public final class AIImageViewModel {

    public enum Phase: Equatable {
        case idle
        case loadingCredits
        case ready(credits: Int)
        case generating
        case generated(AIMediaResult)
        case outOfCredits
        case notInPlan
        case consentRequired
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    /// Last-known remaining credits, kept in sync across phases so the meter can render
    /// regardless of whether `phase` is currently `.ready`/`.generating`/`.generated`.
    public private(set) var credits: Int?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    /// Fetches the remaining `ai_images` credits and sets `phase` to `.ready`/`.outOfCredits`.
    public func loadCredits() async {
        phase = .loadingCredits
        do {
            let response = try await api.aiCredits(type: "ai_images")
            credits = response.credits
            phase = response.credits > 0 ? .ready(credits: response.credits) : .outOfCredits
        } catch let error as SocialsAPIError {
            phase = Self.phase(for: error)
        } catch {
            phase = .failed("Something went wrong. Please try again.")
        }
    }

    /// Generates an image from `prompt`. Refuses locally (no API call) once `credits` is known
    /// to be 0. On success, decrements the local credit count immediately, then re-fetches from
    /// the server to reconcile.
    public func generate(prompt: String) async {
        guard let credits, credits > 0 else {
            phase = .outOfCredits
            return
        }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("Type a prompt first.")
            return
        }

        phase = .generating
        do {
            let result = try await api.aiGenerateImage(prompt: prompt)
            self.credits = max(0, credits - 1)
            phase = .generated(result)
            await refreshCredits()
        } catch let error as SocialsAPIError {
            phase = Self.phase(for: error)
        } catch {
            phase = .failed("Something went wrong. Please try again.")
        }
    }

    /// Resets back to `.idle`, e.g. when the caller dismisses the sheet.
    public func reset() {
        phase = .idle
    }

    private func refreshCredits() async {
        if let response = try? await api.aiCredits(type: "ai_images") {
            credits = response.credits
        }
    }

    private static func phase(for error: SocialsAPIError) -> Phase {
        switch error {
        case .aiCreditsExhausted: return .outOfCredits
        case .aiNotInPlan: return .notInPlan
        case .aiConsentRequired: return .consentRequired
        default: return .failed(message(for: error))
        }
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
