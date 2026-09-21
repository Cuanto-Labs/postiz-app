import Foundation

/// Drains the outbox by replaying each `PendingActionSnapshot` against the real `SocialsAPI`:
/// decodes the per-kind JSON `payload`, calls the matching `SocialsAPI` method, and reconstructs
/// the action's `idempotencyKey` via `IdempotencyKey(rawValue:)` so retries reuse the same key
/// the action was enqueued with, letting the server dedupe (docs/MOBILE-API.md § Idempotency-Key).
/// Maps `SocialsAPIError` to `SyncError` so `SyncEngine`'s backoff/give-up logic (`ActionExecutor`
/// doc comment) knows which failures are worth retrying.
public struct LiveActionExecutor: ActionExecutor {
    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    public func execute(_ action: PendingActionSnapshot) async throws {
        do {
            switch action.kind {
            case .createPost:
                let body = try JSONDecoder().decode(CreatePostBody.self, from: action.payload)
                _ = try await api.createPost(body: body, key: idempotencyKey(for: action))
            case .updatePost:
                let payload = try JSONDecoder().decode(UpdatePostPayload.self, from: action.payload)
                _ = try await api.updatePost(
                    group: payload.group, body: payload.body, key: idempotencyKey(for: action))
            case .reschedulePost:
                let payload = try JSONDecoder().decode(ReschedulePostPayload.self, from: action.payload)
                _ = try await api.reschedule(
                    group: payload.group, date: payload.date, action: payload.action)
            case .deletePost:
                let payload = try JSONDecoder().decode(DeletePostPayload.self, from: action.payload)
                _ = try await api.deletePost(group: payload.group)
            case .upsertPushDevice:
                let body = try JSONDecoder().decode(PushDeviceUpsert.self, from: action.payload)
                _ = try await api.upsertPushDevice(body)
            }
        } catch let error as SocialsAPIError {
            throw Self.syncError(for: error)
        } catch is DecodingError {
            throw SyncError.permanent("Malformed queued action payload")
        }
    }

    private func idempotencyKey(for action: PendingActionSnapshot) -> IdempotencyKey? {
        IdempotencyKey(rawValue: action.idempotencyKey)
    }

    /// 401/403/404/409-shaped and validation errors won't resolve by retrying — mark the action
    /// failed. `.offline`/`.server`/`.cancelled` are transient, so `SyncEngine` backs off and
    /// retries them.
    private static func syncError(for error: SocialsAPIError) -> SyncError {
        switch error {
        case .offline, .server, .cancelled:
            return .retryable(message(for: error))
        case .unauthorized, .forbidden, .notFound, .idempotencyConflict, .validation,
            .aiNotInPlan, .aiCreditsExhausted, .aiConsentRequired:
            return .permanent(message(for: error))
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Unauthorized"
        case .forbidden(let message): return message ?? "Forbidden"
        case .notFound(let message): return message ?? "Not found"
        case .idempotencyConflict: return "Idempotency conflict"
        case .validation(let message): return message ?? "Validation failed"
        case .server(let code, let message): return message ?? "Server error (\(code))"
        case .offline: return "Offline"
        case .cancelled: return "Cancelled"
        case .aiNotInPlan: return "AI not in plan"
        case .aiCreditsExhausted: return "AI credits exhausted"
        case .aiConsentRequired: return "AI consent required"
        }
    }
}

struct UpdatePostPayload: Codable, Sendable {
    let group: String
    let body: CreatePostBody
}

struct ReschedulePostPayload: Codable, Sendable {
    let group: String
    let date: String
    let action: String?
}

struct DeletePostPayload: Codable, Sendable {
    let group: String
}
