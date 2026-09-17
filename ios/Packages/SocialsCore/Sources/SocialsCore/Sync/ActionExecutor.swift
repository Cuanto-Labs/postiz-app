import Foundation

/// Errors an `ActionExecutor` throws to tell `SyncEngine` how to react.
/// Any other thrown error is treated the same as `.retryable`.
public enum SyncError: Error, Sendable, Equatable {
    /// Worth retrying with backoff (network blip, 5xx, timeout).
    case retryable(String)
    /// Never worth retrying (4xx incl. 422 idempotency conflict, 401) — the
    /// action is marked `failed` immediately, after a single attempt.
    case permanent(String)
}

/// Sends one queued `PendingAction` to the server. Implementations replay the
/// action's `idempotencyKey` unchanged so repeated attempts are safe to dedupe
/// server-side.
public protocol ActionExecutor: Sendable {
    func execute(_ action: PendingActionSnapshot) async throws
}
