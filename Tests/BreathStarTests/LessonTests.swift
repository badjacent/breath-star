import Foundation
import Testing
@testable import BreathStar

/// Stage 5 (Lesson.swift): the pilot lesson as data runs, its reference positions reproduce the
/// rules' postures, and its mirrored steps mirror.
@Suite struct Lesson {
    static let drive = Drive()
    static func breath(_ c: BodyConfiguration) -> SidedBreath {
        SidedBreath.measure(BodyGenerator.general(c, drive: drive).body.simulate(drive: drive), period: drive.period)
    }
    static let steps = Dictionary(uniqueKeysWithValues: Lessons.example.steps.map { ($0.id, $0) })

    @Test func encodedSteps() {
        #expect(Lessons.example.steps.count >= 8)
        #expect(Set(Lessons.example.steps.map(\.id)).count == Lessons.example.steps.count)
    }

    @Test func scanIsSupine() {
        let a = Self.breath(Self.steps["scan"]!.configuration), b = Self.breath(.supine)
        #expect(abs(a.abdomenShare - b.abdomenShare) < 1e-9)
    }

    @Test func leftMirrorsRight() {
        let r = Self.breath(Self.steps["right-foot"]!.configuration), l = Self.breath(Self.steps["left-foot"]!.configuration)
        #expect(abs(r.chestWall[0] - l.chestWall[1]) < 5e-4 && abs(r.chestWall[1] - l.chestWall[0]) < 5e-4)
        // Which side's wall moves more is a few mL either way and has flipped with each refit
        // (2026-11-10: the short side by 4 mL): not asserted.
    }

    /// A lesson file round trip: unknown fields are reported, the before/after steps must exist.
    @Test func lessonFileErrors() {
        let bad = #"{"name": "x", "steps": [{"id": "a", "label": "a", "posture": "upside down"}]}"#
        #expect(throws: LessonFileError.self) { try BreathStar.Lesson.decode(Data(bad.utf8)) }
        let missing = #"{"name": "x", "before": "nope", "steps": [{"id": "a", "label": "a", "posture": "seated"}]}"#
        #expect(throws: LessonFileError.self) { try BreathStar.Lesson.decode(Data(missing.utf8)) }
        #expect(Lessons.example.step(Lessons.example.before) != nil && Lessons.example.step(Lessons.example.after) != nil)
    }

    /// Tone on a region stiffens exactly its coordinates.
    @Test func toneStiffensItsRegion() {
        let b = BodyGenerator.general(.seated).body
        let t = b.toned([RegionTone(.flanks, side: .right, 2)])
        for c in SidedCoordinate.allCases {
            #expect(t.stiffness[c.rawValue] == b.stiffness[c.rawValue] * (c == .flankR ? 2 : 1))
        }
    }

    /// The grip takes the belly out of the breath (the gauge, read mechanically).
    @Test func gripReducesBelly() {
        #expect(Self.breath(Self.steps["brace"]!.configuration).abdomenShare
                < Self.breath(Self.steps["light"]!.configuration).abdomenShare)
    }

    /// Knees bent (`Legs`, docs/LESSON_ADAPTATION.md §4.6): the low belly moves more, the high belly not more;
    /// the belly's share rises. Unequal hips tilt the pelvis toward the more flexed side.
    @Test func kneesBentMovesTheLowBelly() {
        func front(_ c: BodyConfiguration, _ z: ClosedRange<Double>) -> Double {
            let b = BodyGenerator.general(c).body, d = Drive()
            let sim = b.simulate(drive: d).suffix(Int(d.period / 0.002))
            let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
            return b.anatomy.sectorMotion(z: z, psi: 0...40, side: .left, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 })).y
        }
        let g = BodyConfiguration.supine, h = g.with(Legs.kneesBent)
        #expect(front(h, 2...8) > 1.15 * front(g, 2...8))
        #expect(front(h, 10...16) <= front(g, 10...16))
        #expect(Self.breath(h).abdomenShare > Self.breath(g).abdomenShare)
        #expect(Legs(left: 0, right: 60).lumbarSideBend < 0 && Legs.kneesBent.lowBackOnFloor && !Legs(left: 0, right: 60).lowBackOnFloor)
    }
}
