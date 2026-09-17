import Foundation

/// Pure sequencer behind the AI copilot's typewriter reveal and staggered-entrance motion
/// (VISION decision 9). No `Task.sleep`/timers here — a driving `TimelineView`/`Timer` in the
/// App target advances a tick counter and asks this type what should be visible, which keeps the
/// logic itself deterministic and unit-testable.
public struct AIRevealPhase: Equatable, Sendable {
    public let text: String
    /// When true, every delay collapses to 0 and reveal jumps straight to the full text — the
    /// Reduce Motion cross-fade fallback.
    public let reduceMotion: Bool

    public init(text: String, reduceMotion: Bool = false) {
        self.text = text
        self.reduceMotion = reduceMotion
    }

    /// The prefix of `text` revealed after `tick` ticks (one character per tick). Under
    /// `reduceMotion`, or once `tick` reaches the text length, returns the full text.
    public func revealed(atTick tick: Int) -> String {
        guard !reduceMotion else { return text }
        guard tick > 0 else { return "" }
        let count = min(tick, text.count)
        return String(text.prefix(count))
    }

    /// Whether `revealed(atTick:)` has reached the full text.
    public func isComplete(atTick tick: Int) -> Bool {
        reduceMotion || tick >= text.count
    }

    /// Delay (seconds) before the `index`-th row in a staggered-entrance list should start its
    /// entrance animation. Collapses to 0 under `reduceMotion`.
    public func stagger(index: Int, unit: Double = 0.05) -> Double {
        reduceMotion ? 0 : Double(index) * unit
    }
}
