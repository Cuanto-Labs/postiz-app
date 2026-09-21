import SwiftUI

/// Shared motion primitives for the AI image/video/copilot screens (VISION decision 9):
/// staggered spring entrance for results/suggestions and `sensoryFeedback` haptics on
/// success/failure/credit changes. Every modifier reads `accessibilityReduceMotion` and swaps
/// animated motion for a plain cross-fade or no-op — haptics never fire under Reduce Motion,
/// and entrance animation collapses to `.opacity` with no spring/delay.
extension View {
    /// Staggered spring entrance for the `index`-th row of a list keyed on `value` (e.g. the
    /// suggestions array, or a single generated result). Cross-fades under Reduce Motion.
    func aiStaggeredEntrance(index: Int, value: some Equatable) -> some View {
        modifier(AIStaggeredEntranceModifier(index: index, value: value))
    }

    /// Plays a success/error haptic via `sensoryFeedback` when `trigger` changes (e.g. a
    /// generation completing). `sensoryFeedback` itself already respects Reduce Motion/haptics
    /// system settings, so no extra guard is needed here.
    func aiResultHaptic(success: Bool, trigger: some Equatable) -> some View {
        sensoryFeedback(success ? .success : .error, trigger: trigger)
    }

    /// Small scale pulse on the credits meter when `trigger` changes (e.g. the credit count
    /// decrements after a generation). Collapses to a no-op under Reduce Motion.
    func aiCreditsPulse(trigger: some Equatable) -> some View {
        modifier(AICreditsPulseModifier(trigger: trigger))
    }
}

private struct AIStaggeredEntranceModifier<Value: Equatable>: ViewModifier {
    let index: Int
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .animation(
                reduceMotion
                    ? .default
                    : .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: value
            )
    }
}

private struct AICreditsPulseModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { scale = 1.15 }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.15)) {
                    scale = 1
                }
            }
    }
}
