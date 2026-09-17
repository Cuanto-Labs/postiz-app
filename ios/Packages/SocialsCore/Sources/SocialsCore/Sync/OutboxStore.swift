import Foundation
import SwiftData

/// Plain, `Sendable` view of `PendingAction` — the only shape `OutboxStore`
/// hands across the actor boundary. Never return a `@Model` instance from it.
public struct PendingActionSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let orgId: String
    public let kind: PendingActionKind
    public let payload: Data
    public let idempotencyKey: String
    public let createdAt: Date
    public let attempts: Int
    public let nextAttemptAt: Date
    public let lastError: String?
    public let status: PendingActionStatus

    public init(
        id: UUID, orgId: String, kind: PendingActionKind, payload: Data, idempotencyKey: String,
        createdAt: Date, attempts: Int, nextAttemptAt: Date, lastError: String?,
        status: PendingActionStatus
    ) {
        self.id = id
        self.orgId = orgId
        self.kind = kind
        self.payload = payload
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.attempts = attempts
        self.nextAttemptAt = nextAttemptAt
        self.lastError = lastError
        self.status = status
    }

    init(model: PendingAction) {
        self.init(
            id: model.id, orgId: model.orgId,
            kind: PendingActionKind(rawValue: model.kind) ?? .createPost, payload: model.payload,
            idempotencyKey: model.idempotencyKey, createdAt: model.createdAt,
            attempts: model.attempts, nextAttemptAt: model.nextAttemptAt,
            lastError: model.lastError, status: PendingActionStatus(rawValue: model.status) ?? .pending
        )
    }
}

/// Actor-isolated seam `SyncEngine` drains through. `PendingActionOutbox` is
/// the SwiftData-backed production implementation; tests can fake this
/// protocol directly instead of standing up a `ModelContainer`.
public protocol OutboxStore: Sendable {
    /// Pending actions whose `nextAttemptAt <= date`, ordered by `createdAt`.
    func pending(before date: Date) async throws -> [PendingActionSnapshot]
    func markInFlight(id: UUID) async throws
    func markDone(id: UUID) async throws
    func markFailed(id: UUID, error: String) async throws
    /// Re-pends a retryable action for another attempt, replaying the same `id`
    /// (and therefore the same persisted `idempotencyKey`).
    func reschedule(id: UUID, attempts: Int, nextAttemptAt: Date, error: String?) async throws
    /// Queues a new action, generating a fresh `idempotencyKey` reused on every retry.
    @discardableResult
    func enqueue(kind: PendingActionKind, payload: Data, orgId: String) async throws -> UUID
    /// Current state of one action, regardless of status — test/inspection seam.
    func snapshot(id: UUID) async throws -> PendingActionSnapshot?
}

/// SwiftData-backed `OutboxStore` over the shared `SocialsSchema` container.
@ModelActor
public actor PendingActionOutbox: OutboxStore {
    public func pending(before date: Date) throws -> [PendingActionSnapshot] {
        let pendingStatus = PendingActionStatus.pending.rawValue
        return try modelContext.fetch(
            FetchDescriptor<PendingAction>(
                predicate: #Predicate { $0.status == pendingStatus && $0.nextAttemptAt <= date },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        ).map(PendingActionSnapshot.init)
    }

    public func markInFlight(id: UUID) throws {
        guard let model = try fetchOne(id) else { return }
        model.status = PendingActionStatus.inFlight.rawValue
        try modelContext.save()
    }

    public func markDone(id: UUID) throws {
        guard let model = try fetchOne(id) else { return }
        model.status = PendingActionStatus.done.rawValue
        try modelContext.save()
    }

    public func markFailed(id: UUID, error: String) throws {
        guard let model = try fetchOne(id) else { return }
        model.status = PendingActionStatus.failed.rawValue
        model.lastError = error
        try modelContext.save()
    }

    public func reschedule(id: UUID, attempts: Int, nextAttemptAt: Date, error: String?) throws {
        guard let model = try fetchOne(id) else { return }
        model.status = PendingActionStatus.pending.rawValue
        model.attempts = attempts
        model.nextAttemptAt = nextAttemptAt
        model.lastError = error
        try modelContext.save()
    }

    @discardableResult
    public func enqueue(kind: PendingActionKind, payload: Data, orgId: String) throws -> UUID {
        let action = PendingAction(
            orgId: orgId, kind: kind, payload: payload, idempotencyKey: IdempotencyKey().value
        )
        modelContext.insert(action)
        try modelContext.save()
        return action.id
    }

    public func snapshot(id: UUID) throws -> PendingActionSnapshot? {
        try fetchOne(id).map(PendingActionSnapshot.init)
    }

    private func fetchOne(_ id: UUID) throws -> PendingAction? {
        try modelContext.fetch(FetchDescriptor<PendingAction>(predicate: #Predicate { $0.id == id }))
            .first
    }
}
