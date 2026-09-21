import CuantoCore
import CuantoNet
import Foundation

/// Sign-in state as `SessionStore` sees it: either nobody is signed in, or someone is, with
/// the orgs they belong to and which one is active.
public enum SessionState: Sendable, Equatable {
    case signedOut
    case signedIn(user: MobileUser, orgs: [MobileOrg], orgId: String?)
}

/// Lifecycle events other parts of the app (cache store, router) react to.
public enum SessionEvent: Sendable, Equatable {
    case signedOut
}

/// Owns the signed-in session: Keychain-backed persistence, `TokenProvider` conformance for
/// `APIClient`'s 401 → refresh → retry path, and sign-out.
///
/// Tokens are never logged and never touch `UserDefaults` — the only place they live is the
/// Keychain item this actor reads/writes via `KeychainStore.getCodable`/`setCodable`.
public actor SessionStore: TokenProvider {
    private static let key = "session"

    private let keychain: KeychainStore
    private let refreshClosure: @Sendable (_ refreshToken: String) async throws -> MobileTokens
    private let clock: any Clock<Duration>

    private var session: StoredSession?
    private var refreshTask: Task<MobileTokens, Error>?
    private let eventsContinuation: AsyncStream<SessionEvent>.Continuation

    /// Session lifecycle events (currently just `.signedOut`) — one stream, multiple readers
    /// each get their own `AsyncStream` iteration since this is a broadcast, not a queue.
    public let events: AsyncStream<SessionEvent>

    /// - Parameters:
    ///   - keychain: where the session is persisted. Tests pass an ephemeral, in-memory one;
    ///     the app wires a real `KeychainStore(service:accessGroup:)` (see `AppIdentifiers`).
    ///   - refresh: exchanges a refresh token for new `MobileTokens`. Never called directly by
    ///     this type's own network code — this actor has none; the app injects the live call.
    ///   - clock: injected for deterministic tests (`ManualClock`); defaults to the real clock.
    public init(
        keychain: KeychainStore,
        refresh: @escaping @Sendable (_ refreshToken: String) async throws -> MobileTokens,
        clock: any Clock<Duration> = ContinuousClock()
    ) async {
        self.keychain = keychain
        self.refreshClosure = refresh
        self.clock = clock
        var continuation: AsyncStream<SessionEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
        self.session = nil
        // Cold start: restore whatever is already in the Keychain, if anything.
        self.session = try? await keychain.getCodable(Self.key, as: StoredSession.self)
    }

    public var state: SessionState {
        guard let session else { return .signedOut }
        return .signedIn(user: session.user, orgs: session.orgs, orgId: session.currentOrgId)
    }

    public var currentOrgId: String? { session?.currentOrgId }

    /// The refresh token for the active session, if any — needed by callers (e.g. the settings
    /// sign-out flow) that must include it in the `/mobile/v1/auth/logout` request body so the
    /// server can revoke that specific session.
    public var currentRefreshToken: String? { session?.tokens.refreshToken }

    /// Persists a fresh sign-in (defaults the active org to the first one returned).
    public func signIn(_ auth: MobileAuthResponse) async throws {
        let tokens = MobileTokens(
            accessToken: auth.accessToken, refreshToken: auth.refreshToken,
            expiresIn: auth.expiresIn, sessionId: auth.sessionId)
        let newSession = StoredSession(
            tokens: tokens, user: auth.user, orgs: auth.orgs, currentOrgId: auth.orgs.first?.id,
            issuedAt: Date())
        session = newSession
        try await keychain.setCodable(newSession, for: Self.key)
    }

    /// Switches the active org and persists the choice.
    public func setCurrentOrgId(_ orgId: String?) async throws {
        guard var updated = session else { return }
        updated.currentOrgId = orgId
        session = updated
        try await keychain.setCodable(updated, for: Self.key)
    }

    /// Clears the session: deletes the Keychain item, drops in-memory state, emits
    /// `.signedOut`. Safe to call when already signed out.
    public func signOut() async {
        session = nil
        refreshTask = nil
        try? await keychain.delete(Self.key)
        eventsContinuation.yield(.signedOut)
    }

    // MARK: - TokenProvider

    public func token() async -> String? {
        session?.tokens.accessToken
    }

    /// Single-flight: concurrent callers all await the one in-flight refresh instead of each
    /// triggering their own. On a hard 401 the session is torn down and `nil` is returned (the
    /// caller should treat that as signed out); on a transport/offline failure the error is
    /// rethrown and the session is left intact so the caller can retry later.
    public func refresh() async throws -> String? {
        if let refreshTask {
            return try await awaitRefresh(refreshTask)
        }
        guard let session else { return nil }
        let closure = refreshClosure
        let refreshToken = session.tokens.refreshToken
        let task = Task<MobileTokens, Error> { try await closure(refreshToken) }
        refreshTask = task
        return try await awaitRefresh(task)
    }

    private func awaitRefresh(_ task: Task<MobileTokens, Error>) async throws -> String? {
        defer { refreshTask = nil }
        do {
            let newTokens = try await task.value
            try await persist(newTokens)
            return newTokens.accessToken
        } catch APIError.unauthorized, APIError.status(code: 401, body: _) {
            await signOut()
            return nil
        }
        // Any other error (`.offline`, `.transport`, etc.) rethrows as-is and the session
        // above is left untouched.
    }

    private func persist(_ newTokens: MobileTokens) async throws {
        guard var updated = session else { return }
        updated.tokens = newTokens
        updated.issuedAt = Date()
        session = updated
        try await keychain.setCodable(updated, for: Self.key)
    }
}
