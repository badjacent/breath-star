import Testing
@testable import BreathStar

/// Three clinical patterns on the current bodies (`BodyGenerator.general`, the posture rules), one
/// muscle group silenced, the rest of the drive unchanged (`breathstar patients`). The older tests in
/// MechanicsSupine check the same patterns on the earlier fitted supine body.
@Suite struct PatientsOnTheRules {
    static let drive = Drive()
    static func breath(_ c: BodyConfiguration, silence: Set<A2Muscles>) -> (m: SidedBreath, front: Double) {
        let b = BodyGenerator.general(c, drive: drive).body.silenced(silence)
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        return (SidedBreath.measure(b.simulate(drive: drive), period: drive.period),
                b.anatomy.sectorMotion(z: 18...25, psi: -40...40, side: .left, st).y)
    }
    static func ribcage(_ m: SidedBreath) -> Double { m.upper[0] + m.upper[1] + m.lower[0] + m.lower[1] }
    static func belly(_ m: SidedBreath) -> Double { m.abdomen[0] + m.abdomen[1] }

    /// Mortola 1978: with the rib muscles paralysed the ribcage moves inward, more so lying down.
    @Test func ribcageParadoxWorseSupine() {
        let s = Self.breath(.seated, silence: [.ribs]).m, p = Self.breath(.supine, silence: [.ribs]).m
        #expect(Self.ribcage(s) < 0)
        #expect(Self.ribcage(p) < Self.ribcage(s))
    }

    /// Higenbottam 1977: with the diaphragm paralysed the belly moves inward, clearest lying down.
    /// As a fraction of the (smaller) supine breath it is (−51% → −79%); in millilitres it is not
    /// (−122 → −108). Which the paper meant is not in the notes: both are recorded.
    @Test func bellyParadoxLyingDown() {
        let s = Self.breath(.seated, silence: [.diaphragm]).m, p = Self.breath(.supine, silence: [.diaphragm]).m
        #expect(Self.belly(s) < 0 && Self.belly(p) < 0)
        #expect(Self.belly(p) / p.tidalVolume < Self.belly(s) / s.tidalVolume)
        withKnownIssue("Higenbottam 1977 in millilitres: the belly's inward motion should be larger supine") {
            #expect(Self.belly(p) < Self.belly(s))
        }
    }

    /// Estenne 1985: the diaphragm alone, supine, moves the lower ribcage's front inward. The model's
    /// front barely moves either way (−0.04 mm seated, +0.02 mm supine).
    @Test func lowerFrontWithTheDiaphragmAlone() {
        let p = Self.breath(.supine, silence: [.ribs])
        #expect(abs(p.front) < 0.1)
        withKnownIssue("Estenne 1985: the lower ribcage's front should move inward, supine, diaphragm alone") {
            #expect(p.front < 0)
        }
    }
}
