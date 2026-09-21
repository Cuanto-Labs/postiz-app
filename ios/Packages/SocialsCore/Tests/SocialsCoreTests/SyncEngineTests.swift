import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

// `.serialized`: swift-testing runs tests in a suite concurrently by default,
// which was intermittently crashing (SIGSEGV) from multiple in-memory
// `ModelContainer`s (see `makeOutbox`) being created in parallel — a known
// SwiftData thread-safety hazard, not a bug in `SyncEngine` itself.
@Suite("SyncEngine", .serialized)
struct SyncEngineTests {

    /// One executor outcome, consumed in order per `execute` call.
    private enum Outcome {
        case succeed
        case retryable(String)
        case permanent(String)
    }

    /// Records every `execute` call (id + the idempotencyKey it was replayed
    /// with) and answers with the next queued `Outcome`.
    private actor RecordingExecutor: ActionExecutor {
        private(set) var calls: [(id: UUID, idempotencyKey: String)] = []
        private var outcomes: [Outcome]

        init(outcomes: [Outcome]) {
            self.outcomes = outcomes
        }

        func execute(_ action: PendingActionSnapshot) async throws {
            calls.append((id: action.id, idempotencyKey: action.idempotencyKey))
            guard !outcomes.isEmpty else { return }
            switch outcomes.removeFirst() {
            case .succeed:
                return
            case .retryable(let message):
                throw SyncError.retryable(message)
            case .permanent(let message):
                throw SyncError.permanent(message)
            }
        }
    }

    private func makeOutbox() throws -> PendingActionOutbox {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        return PendingActionOutbox(modelContainer: container)
    }

    /// Polls a condition every 5ms up to `timeout` — used only to observe the
    /// engine's *final* persisted state after driving the `ManualClock`
    /// forward; never used to wait out a sleep or backoff.
    private func waitUntil(
        timeout: Duration = .seconds(2), _ condition: () async throws -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if try await condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        _ = try await condition()
    }

    @Test("fail-fail-succeed retries with the original idempotencyKey, then marks done")
    func failFailSucceed() async throws {
        let outbox = try makeOutbox()
        let executor = RecordingExecutor(outcomes: [.retryable("e1"), .retryable("e2"), .succeed])
        let connectivity = ManualConnectivity(online: true)
        let clock = ManualClock()
        let engine = SyncEngine(
            outbox: outbox, executor: executor, connectivity: connectivity, clock: clock,
            policy: SyncPolicy(maxAttempts: 5, baseDelay: .milliseconds(1), maxDelay: .seconds(1))
        )

        let id = try await outbox.enqueue(kind: .createPost, payload: Data(), orgId: "org-1")
        await engine.start()

        await clock.waitForSleeps(1)
        await clock.advance(by: .seconds(1))
        // `waitForSleeps` counts registrations cumulatively (never decrements), so the
        // second backoff sleep is awaited via count 2, not another `waitForSleeps(1)`
        // (which would already be satisfied by the first sleep and return immediately).
        await clock.waitForSleeps(2)
        await clock.advance(by: .seconds(1))

        try await waitUntil {
            try await outbox.snapshot(id: id)?.status == .done
        }

        await engine.stop()

        let calls = await executor.calls
        #expect(calls.count == 3)
        #expect(Set(calls.map(\.idempotencyKey)).count == 1)
        #expect(try await outbox.snapshot(id: id)?.status == .done)
    }

    @Test("permanent error fails after a single attempt, no retry")
    func permanentErrorFailsImmediately() async throws {
        let outbox = try makeOutbox()
        let executor = RecordingExecutor(outcomes: [.permanent("nope")])
        let connectivity = ManualConnectivity(online: true)
        let clock = ManualClock()
        let engine = SyncEngine(
            outbox: outbox, executor: executor, connectivity: connectivity, clock: clock
        )

        let id = try await outbox.enqueue(kind: .createPost, payload: Data(), orgId: "org-1")
        await engine.start()

        try await waitUntil {
            try await outbox.snapshot(id: id)?.status == .failed
        }
        await engine.stop()

        let calls = await executor.calls
        #expect(calls.count == 1)
        #expect(try await outbox.snapshot(id: id)?.status == .failed)
        #expect(try await outbox.snapshot(id: id)?.lastError == "nope")
    }

    @Test("offline blocks execution until connectivity flips online")
    func offlineBlocksUntilOnline() async throws {
        let outbox = try makeOutbox()
        let executor = RecordingExecutor(outcomes: [.succeed])
        let connectivity = ManualConnectivity(online: false)
        let clock = ManualClock()
        let engine = SyncEngine(
            outbox: outbox, executor: executor, connectivity: connectivity, clock: clock
        )

        let id = try await outbox.enqueue(kind: .createPost, payload: Data(), orgId: "org-1")
        await engine.start()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await executor.calls.isEmpty)

        connectivity.set(online: true)

        try await waitUntil {
            try await outbox.snapshot(id: id)?.status == .done
        }
        await engine.stop()

        #expect(await executor.calls.count == 1)
    }

    @Test("maxAttempts exhausted marks failed with the last retryable error")
    func maxAttemptsExhaustedFails() async throws {
        let outbox = try makeOutbox()
        let executor = RecordingExecutor(
            outcomes: [.retryable("e1"), .retryable("e2"), .retryable("e3")]
        )
        let connectivity = ManualConnectivity(online: true)
        let clock = ManualClock()
        let engine = SyncEngine(
            outbox: outbox, executor: executor, connectivity: connectivity, clock: clock,
            policy: SyncPolicy(maxAttempts: 3, baseDelay: .milliseconds(1), maxDelay: .seconds(1))
        )

        let id = try await outbox.enqueue(kind: .createPost, payload: Data(), orgId: "org-1")
        await engine.start()

        await clock.waitForSleeps(1)
        await clock.advance(by: .seconds(1))
        await clock.waitForSleeps(2)
        await clock.advance(by: .seconds(1))

        try await waitUntil {
            try await outbox.snapshot(id: id)?.status == .failed
        }
        await engine.stop()

        let calls = await executor.calls
        #expect(calls.count == 3)
        #expect(try await outbox.snapshot(id: id)?.status == .failed)
        #expect(try await outbox.snapshot(id: id)?.lastError == "e3")
    }
}
