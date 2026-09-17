import Foundation
#if canImport(Network)
import Network
#endif

/// Seam `SyncEngine` reads network reachability through. Real code uses
/// `NetworkConnectivity`; tests drive `ManualConnectivity` by hand.
public protocol Connectivity: Sendable {
    /// Emits the current online state on subscription, then again on every change.
    var isOnline: AsyncStream<Bool> { get }
}

#if canImport(Network)
/// `NWPathMonitor`-backed `Connectivity` for app code.
public final class NetworkConnectivity: Connectivity, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    public let isOnline: AsyncStream<Bool>

    public init(monitorQueue: DispatchQueue = DispatchQueue(label: "socialscore.connectivity")) {
        self.monitor = NWPathMonitor()
        self.monitorQueue = monitorQueue
        let monitor = self.monitor
        self.isOnline = AsyncStream { continuation in
            continuation.yield(monitor.currentPath.status == .satisfied)
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
#endif

/// Test fake: reports whatever `set(online:)` was last called with, starting
/// from `online` at init. Every call re-broadcasts, even redundant repeats,
/// so a test can force a wake signal into `SyncEngine`'s drain loop.
public final class ManualConnectivity: Connectivity, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Bool>.Continuation?
    public let isOnline: AsyncStream<Bool>

    public init(online: Bool = false) {
        var capturedContinuation: AsyncStream<Bool>.Continuation?
        self.isOnline = AsyncStream { continuation in
            continuation.yield(online)
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    public func set(online: Bool) {
        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.yield(online)
    }
}
