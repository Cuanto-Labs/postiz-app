import SocialsCore
import SwiftUI

/// Renders `text` with a typewriter reveal, one character per tick, driven by the pure
/// `AIRevealPhase` sequencer (VISION decision 9). Under Reduce Motion the phase itself collapses
/// to the full text on the first tick, so this view degrades to a plain cross-fade rather than an
/// animated reveal.
struct TypewriterText: View {
    let text: String
    var tickInterval: TimeInterval = 0.03

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tick = 0

    private var revealPhase: AIRevealPhase {
        AIRevealPhase(text: text, reduceMotion: reduceMotion)
    }

    var body: some View {
        Text(revealPhase.revealed(atTick: tick))
            .accessibilityLabel(text)
            .task(id: text) {
                tick = 0
                while !revealPhase.isComplete(atTick: tick) && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(tickInterval))
                    tick += 1
                }
            }
    }
}
