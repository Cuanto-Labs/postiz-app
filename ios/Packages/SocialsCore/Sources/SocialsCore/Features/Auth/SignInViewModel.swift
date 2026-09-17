import CryptoKit
import Foundation
import Observation

// MARK: - Abstractions the App target's concrete auth helpers conform to

/// The web-based half of OAuth PKCE (`signInWithGoogle`): presents `url`, waits for the
/// redirect back to `callbackURLScheme`, and returns that redirect URL. The App target's
/// `WebAuthSession` (an `ASWebAuthenticationSession` wrapper) is the live conformer; tests
/// inject a scripted stub so this type never needs `AuthenticationServices` directly.
public protocol SignInWebAuthenticating: Sendable {
    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL
}

/// What Sign in with Apple hands back once the OS-native prompt resolves. The App target's
/// `AppleSignInCoordinator` (an `ASAuthorizationController` wrapper) produces this; tests
/// construct it directly.
public struct AppleSignInResult: Sendable, Equatable {
    public let identityToken: String
    public let fullName: String?

    public init(identityToken: String, fullName: String?) {
        self.identityToken = identityToken
        self.fullName = fullName
    }
}

/// Failures specific to the sign-in flows themselves (as opposed to `SocialsAPIError`, which
/// covers the network calls each flow makes).
public enum SignInError: Error, Sendable, Equatable {
    case missingCredentials
    case cancelled
    case stateMismatch
    case missingCode
    case invalidStartURL
}

/// Drives all three sign-in entry points (email/password, Apple native, Google via web PKCE)
/// and, on success, persists the result through `SessionStore`. Lives in `SocialsCore` (not the
/// App target) so it's testable with `StubSocialsAPI` + scripted doubles for the two
/// `AuthenticationServices`-backed helpers, without booting a simulator.
@MainActor
@Observable
public final class SignInViewModel {
    public var email: String = ""
    public var password: String = ""
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI
    private let sessionStore: SessionStore
    private let deviceId: String
    private let deviceName: String?
    private let webAuth: any SignInWebAuthenticating
    private let callbackURLScheme: String

    /// - Parameters:
    ///   - deviceId: stable per-install identifier the App target derives (e.g. Keychain-backed
    ///     UUID); this type never generates or persists one itself.
    ///   - callbackURLScheme: the URL scheme `webAuth` waits for the OAuth redirect on
    ///     (`AppIdentifiers.urlScheme` in the live app).
    public init(
        api: any SocialsAPI,
        sessionStore: SessionStore,
        deviceId: String,
        deviceName: String?,
        webAuth: any SignInWebAuthenticating,
        callbackURLScheme: String
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.webAuth = webAuth
        self.callbackURLScheme = callbackURLScheme
    }

    public var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    // MARK: - Email / password

    public func signInWithEmail() async {
        guard canSubmitEmail else {
            errorMessage = Self.message(for: SignInError.missingCredentials)
            return
        }
        await run {
            let response = try await self.api.login(
                LoginRequest(
                    email: self.email, password: self.password, deviceId: self.deviceId,
                    deviceName: self.deviceName))
            try await self.sessionStore.signIn(response)
        }
    }

    // MARK: - Apple native

    public func signInWithApple(_ result: AppleSignInResult) async {
        await run {
            let response = try await self.api.signInWithApple(
                AppleNativeRequest(
                    identityToken: result.identityToken, deviceId: self.deviceId,
                    deviceName: self.deviceName, fullName: result.fullName))
            try await self.sessionStore.signIn(response)
        }
    }

    // MARK: - Google via web PKCE

    public func signInWithGoogle() async {
        await run {
            let verifier = Self.makeCodeVerifier()
            let challenge = Self.codeChallenge(for: verifier)
            let start = try await self.api.oauthStart(
                OAuthStartRequest(provider: "google", codeChallenge: challenge))
            guard let startURL = URL(string: start.url) else {
                throw SignInError.invalidStartURL
            }

            let redirect: URL
            do {
                redirect = try await self.webAuth.authenticate(
                    url: startURL, callbackURLScheme: self.callbackURLScheme)
            } catch is CancellationError {
                throw SignInError.cancelled
            }

            let query = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let code = query.first(where: { $0.name == "code" })?.value else {
                throw SignInError.missingCode
            }
            let returnedState = query.first(where: { $0.name == "state" })?.value
            guard returnedState == start.state else {
                throw SignInError.stateMismatch
            }

            let response = try await self.api.oauthExchange(
                OAuthExchangeRequest(
                    provider: "google", code: code, state: start.state, codeVerifier: verifier,
                    deviceId: self.deviceId, deviceName: self.deviceName))
            try await self.sessionStore.signIn(response)
        }
    }

    // MARK: - Shared execution + error mapping

    private func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch is CancellationError {
            // Silent: the user dismissed the system sheet, not a failure worth surfacing.
        } catch let error as SignInError {
            errorMessage = Self.message(for: error)
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private static func message(for error: SignInError) -> String {
        switch error {
        case .missingCredentials: return "Enter your email and password."
        case .cancelled: return ""
        case .stateMismatch: return "That sign-in attempt couldn't be verified. Please try again."
        case .missingCode: return "Sign-in didn't complete. Please try again."
        case .invalidStartURL: return "Sign-in isn't available right now. Please try again."
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "That email or password isn't right."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That account can't sign in right now."
        case .offline: return "You're offline. Check your connection and try again."
        case .server, .notFound, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }

    // MARK: - PKCE (RFC 7636)

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return base64URLEncode(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
