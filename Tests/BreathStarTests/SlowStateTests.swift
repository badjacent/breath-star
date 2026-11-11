import Testing
@testable import BreathStar

/// Stage 6 (SlowState.swift): slow-state hypotheses are off by default and, switched on, change the
/// final rest against the opening scan. Their sizes are unsourced; these tests pin behaviour, not truth.
@Suite struct SlowState {
    static let lesson = Lessons.example
    static func scanAndRest(_ h: SlowHypotheses) -> (scan: SidedBreath, rest: SidedBreath) {
        let r = LessonRunner.run(lesson.steps, h)
        return (r.first { $0.step.id == lesson.before }!.breath, r.first { $0.step.id == lesson.after }!.breath)
    }

    @Test func offByDefaultNoChange() {
        let (s, r) = Self.scanAndRest(.off)
        #expect(abs(s.abdomenShare - r.abdomenShare) < 1e-9)
    }

    /// H2 (use loosens, stillness stiffens) at gain 0.3, τ 5 min: the lesson's movements loosen the
    /// walls they bend, and the final rest takes more belly than the scan.
    @Test func useAndStillnessChangesFinalRest() {
        var h = SlowHypotheses(); h.useAndStillness = true
        let (s, r) = Self.scanAndRest(h)
        #expect(r.abdomenShare > s.abdomenShare + 0.01)
        #expect(abs(r.tidalVolume - 0.56) < 0.005)
    }
}
