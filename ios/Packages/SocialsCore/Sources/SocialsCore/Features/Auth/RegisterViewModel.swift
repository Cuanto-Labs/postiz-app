import Foundation
import Observation

/// Drives the email/password sign-up flow: validates the fields the backend enforces
/// (`docs/MOBILE-API.md` § `MobileRegisterDto` — password 3–64, company 3–128, optional
/// invite code) client-side before submitting, then either signs the session in
/// (`RegisterResult.authenticated`) or surfaces the activation-required state
/// (`RegisterResult.activate`, when `EmailService.hasProvider()` gates registration behind
/// email verification). Lives in `SocialsCore` (not the App target) so it's testable with
/// `StubSocialsAPI`, mirroring `SignInViewModel`.
@MainActor
@Observable
public final class RegisterViewModel {
    public var email: String = ""
    public var password: String = ""
    public var company: String = ""
    public var inviteCode: String = ""
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var needsActivation = false

    private let api: any SocialsAPI
    private let sessionStore: SessionStore
    private let deviceId: String
    private let deviceName: String?

    public init(
        api: any SocialsAPI,
        sessionStore: SessionStore,
        deviceId: String,
        deviceName: String?
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.deviceId = deviceId
        self.deviceName = deviceName
    }

    public var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (3...64).contains(password.count)
            && (3...128).contains(company.count)
    }

    public func register() async {
        guard canSubmit else {
            errorMessage = Self.message(for: .missingOrInvalidFields)
            return
        }
        isLoading = true
        errorMessage = nil
        needsActivation = false
        defer { isLoading = false }
        do {
            let result = try await api.register(
                RegisterRequest(
                    email: email, password: password, company: company,
                    inviteCode: inviteCode.isEmpty ? nil : inviteCode, deviceId: deviceId,
                    deviceName: deviceName))
            switch result {
            case .authenticated(let response):
                try await sessionStore.signIn(response)
            case .activate:
                needsActivation = true
            }
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private enum RegisterError: Error, Sendable, Equatable {
        case missingOrInvalidFields
    }

    private static func message(for error: RegisterError) -> String {
        switch error {
        case .missingOrInvalidFields:
            return "Enter a valid email, a password (3–64 characters), and a company name (3–128 characters)."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .forbidden(let message):
            return message ?? "Registration isn't available right now, or that invite code isn't valid."
        case .validation(let message):
            return message ?? "Check your details and try again."
        case .unauthorized:
            return "Something went wrong. Please try again."
        case .offline: return "You're offline. Check your connection and try again."
        case .server, .notFound, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted,
            .aiConsentRequired:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
