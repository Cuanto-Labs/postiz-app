import Foundation

/// Attempt/backoff shape for `SyncEngine`. Delay grows as `base * 2^attempts`,
/// clamped to `maxDelay`; after `maxAttempts` a retryable action is marked failed.
public struct SyncPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var maxDelay: Duration

    public init(maxAttempts: Int = 5, baseDelay: Duration = .seconds(2), maxDelay: Duration = .seconds(300)) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
}

extension Duration {
    fileprivate var asTimeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// Drains `OutboxStore` while online, replaying each `PendingAction` through
/// `ActionExecutor` with clock-injected exponential backoff on retryable
/// failures. Generic over `Clock` so tests inject `ManualClock` (docs/IOS-APP-PLAN.md §10.2)
/// instead of ever sleeping for real.
///
/// The loop never busy-waits: it either awaits `clock.sleep(until:)` for the
/// earliest `nextAttemptAt`, or suspends on a wake signal (an `AsyncStream`
/// continuation fed by `kick()` and connectivity changes) — see `waitForWakeOrDeadline`.
public actor SyncEngine<C: Clock> where C.Duration == Duration {
    private let outbox: any OutboxStore
    private let executor: any ActionExecutor
    private let connectivity: any Connectivity
    private let clock: C
    private let policy: SyncPolicy

    // Anchors the clock's virtual `now` to a wall-clock `Date` so `Date`-based
    // persistence (`nextAttemptAt`) stays meaningful under a `ManualClock`,
    // whose `Instant` is an opaque offset, not a timestamp. Captured in
    // `start()` (not `init`) so anything enqueued before `start()` is already
    // due — the anchor reflects "now" when the loop actually begins draining.
    private var anchorDate: Date
    private var anchorInstant: C.Instant

    private var isOnline = false
    private var loopTask: Task<Void, Never>?
    private var connectivityTask: Task<Void, Never>?
    private var wakeWaiter: CheckedContinuation<Void, Never>?

    public init(
        outbox: any OutboxStore,
        executor: any ActionExecutor,
        connectivity: any Connectivity,
        clock: C,
        policy: SyncPolicy = SyncPolicy()
    ) {
        self.outbox = outbox
        self.executor = executor
        self.connectivity = connectivity
        self.clock = clock
        self.policy = policy
        self.anchorDate = Date()
        self.anchorInstant = clock.now
    }

    /// Starts the drain loop. A second call while already running is a no-op.
    public func start() {
        guard loopTask == nil else { return }
        anchorDate = Date()
        anchorInstant = clock.now

        connectivityTask = Task { [weak self] in
            guard let self else { return }
            for await online in await self.connectivityUpdates() {
                await self.setOnline(online)
            }
        }
        loopTask = Task { [weak self] in
            await self?.drain()
        }
    }

    /// Cancels the drain loop and the connectivity subscription.
    public func stop() {
        loopTask?.cancel()
        connectivityTask?.cancel()
        loopTask = nil
        connectivityTask = nil
        resumeWaiter()
    }

    /// Wakes the drain loop immediately (e.g. right after `enqueue`) instead
    /// of waiting for the next scheduled `nextAttemptAt` or connectivity change.
    public func kick() {
        resumeWaiter()
    }

    private func connectivityUpdates() -> AsyncStream<Bool> {
        connectivity.isOnline
    }

    private func setOnline(_ online: Bool) {
        isOnline = online
        resumeWaiter()
    }

    /// Resumes whoever is currently suspended in `waitForWakeSignal()`, if
    /// anyone. Single in-flight waiter at a time — the drain loop only ever
    /// awaits one wake signal.
    private func resumeWaiter() {
        guard let waiter = wakeWaiter else { return }
        wakeWaiter = nil
        waiter.resume()
    }

    /// Suspends until `kick()` or a connectivity change resumes it. Backed by
    /// a plain continuation (not an `AsyncStream` iterator) so cancellation —
    /// e.g. when `waitForWakeOrDeadline` races it against `clock.sleep` and
    /// the sleep wins — reliably resumes it instead of leaking the await.
    private func waitForWakeSignal() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                wakeWaiter = continuation
            }
        } onCancel: { [weak self] in
            Task { await self?.resumeWaiter() }
        }
    }

    private func currentDate() -> Date {
        let elapsed = anchorInstant.duration(to: clock.now)
        return anchorDate.addingTimeInterval(elapsed.asTimeInterval)
    }

    private func drain() async {
        while !Task.isCancelled {
            guard isOnline else {
                await waitForWakeOrDeadline(nil)
                continue
            }

            let due = (try? await outbox.pending(before: currentDate())) ?? []
            guard let action = due.first else {
                let deadline = (try? await outbox.pending(before: .distantFuture))?
                    .map(\.nextAttemptAt).min()
                await waitForWakeOrDeadline(deadline)
                continue
            }

            await process(action)
        }
    }

    /// Suspends until either a wake signal arrives (`kick()`, a connectivity
    /// change) or, when `deadline` is given, until that instant — whichever
    /// comes first. Never polls: both branches are genuine suspensions.
    private func waitForWakeOrDeadline(_ deadline: Date?) async {
        guard let deadline else {
            await waitForWakeSignal()
            return
        }

        let secondsUntil = deadline.timeIntervalSince(currentDate())
        guard secondsUntil > 0 else { return }
        let sleepDuration = Duration.seconds(secondsUntil)

        await withTaskGroup(of: Void.self) { [clock] group in
            group.addTask {
                try? await clock.sleep(for: sleepDuration)
            }
            group.addTask { [weak self] in
                await self?.waitForWakeSignal()
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func process(_ action: PendingActionSnapshot) async {
        do {
            try await outbox.markInFlight(id: action.id)
        } catch {
            return
        }

        do {
            try await executor.execute(action)
            try? await outbox.markDone(id: action.id)
        } catch let syncError as SyncError {
            switch syncError {
            case .permanent(let message):
                try? await outbox.markFailed(id: action.id, error: message)
            case .retryable(let message):
                await handleRetryable(action, message: message)
            }
        } catch {
            await handleRetryable(action, message: String(describing: error))
        }
    }

    private func handleRetryable(_ action: PendingActionSnapshot, message: String) async {
        let attempts = action.attempts + 1
        guard attempts < policy.maxAttempts else {
            try? await outbox.markFailed(id: action.id, error: message)
            return
        }

        let baseSeconds = policy.baseDelay.asTimeInterval
        let maxSeconds = policy.maxDelay.asTimeInterval
        let delaySeconds = min(baseSeconds * pow(2.0, Double(attempts)), maxSeconds)
        let nextAttemptAt = currentDate().addingTimeInterval(delaySeconds)

        try? await outbox.reschedule(
            id: action.id, attempts: attempts, nextAttemptAt: nextAttemptAt, error: message
        )
    }
}
