import AuthenticationServices
import SocialsCore
import UIKit

/// `ASWebAuthenticationSession` wrapper — the App target's live conformer to `SocialsCore`'s
/// `SignInWebAuthenticating`, used by `SignInViewModel.signInWithGoogle()` to present the
/// provider's consent page and capture the PKCE redirect. Ephemeral (no shared cookies) so a
/// Google sign-in never silently reuses a stale browser session left over from a different
/// account on the device.
final class WebAuthSession: NSObject, SignInWebAuthenticating, @unchecked Sendable {
    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                        authError.code == .canceledLogin
                    {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            DispatchQueue.main.async {
                session.start()
            }
        }
    }
}

extension WebAuthSession: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
