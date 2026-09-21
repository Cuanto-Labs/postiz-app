import Testing

@testable import SocialsCore

@Suite("AIRevealPhase")
struct AIRevealPhaseTests {

    @Test("revealed(atTick:) returns empty string before any ticks")
    func revealedAtZero() {
        let phase = AIRevealPhase(text: "Hello")
        #expect(phase.revealed(atTick: 0) == "")
    }

    @Test("revealed(atTick:) returns the prefix one character per tick")
    func revealedPartial() {
        let phase = AIRevealPhase(text: "Hello")
        #expect(phase.revealed(atTick: 3) == "Hel")
    }

    @Test("revealed(atTick:) caps at the full text once tick exceeds the length")
    func revealedOverflow() {
        let phase = AIRevealPhase(text: "Hi")
        #expect(phase.revealed(atTick: 100) == "Hi")
    }

    @Test("reduceMotion reveals the full text immediately, even at tick 0")
    func revealedReduceMotion() {
        let phase = AIRevealPhase(text: "Hello", reduceMotion: true)
        #expect(phase.revealed(atTick: 0) == "Hello")
    }

    @Test("isComplete is false before the text is fully revealed")
    func isCompleteFalse() {
        let phase = AIRevealPhase(text: "Hello")
        #expect(phase.isComplete(atTick: 2) == false)
    }

    @Test("isComplete is true once tick reaches the text length")
    func isCompleteTrue() {
        let phase = AIRevealPhase(text: "Hello")
        #expect(phase.isComplete(atTick: 5) == true)
    }

    @Test("isComplete is always true under reduceMotion")
    func isCompleteReduceMotion() {
        let phase = AIRevealPhase(text: "Hello", reduceMotion: true)
        #expect(phase.isComplete(atTick: 0) == true)
    }

    @Test("stagger(index:) scales linearly with the row index")
    func staggerLinear() {
        let phase = AIRevealPhase(text: "Hello")
        #expect(phase.stagger(index: 0) == 0)
        #expect(phase.stagger(index: 2) == 0.1)
    }

    @Test("stagger(index:) collapses to 0 under reduceMotion")
    func staggerReduceMotion() {
        let phase = AIRevealPhase(text: "Hello", reduceMotion: true)
        #expect(phase.stagger(index: 5) == 0)
    }

    @Test("empty text is immediately complete")
    func emptyText() {
        let phase = AIRevealPhase(text: "")
        #expect(phase.revealed(atTick: 0) == "")
        #expect(phase.isComplete(atTick: 0) == true)
    }
}
