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

    /// Higenbottam 1977 (Thorax 32:589; magnetometers on the front belly wall): with the diaphragm
    /// paralysed the front belly moves inward on inspiration, best seen lying down; upright there may
    /// be none (Kreitzer 1978). The model's front belly moves inward 1.59 mm seated and 1.37 supine:
    /// paradox in both, larger seated. What masks it upright (the contents' weight, expiratory
    /// abdominal activity that recoils outward at inspiration) is not in the model.
    @Test func bellyParadoxLyingDown() {
        func front(_ c: BodyConfiguration) -> Double {
            let b = BodyGenerator.general(c, drive: Self.drive).body.silenced([.diaphragm])
            let sim = b.simulate(drive: Self.drive).suffix(Int(Self.drive.period / 0.002))
            let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
            return b.anatomy.sectorMotion(z: 4...14, psi: -20...20, side: .left, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 })).y
        }
        let s = front(.seated), p = front(.supine)
        #expect(p < 0)
        withKnownIssue("Higenbottam 1977: the front belly's inward motion should be larger lying down") { #expect(p < s) }
        withKnownIssue("Kreitzer 1978: upright, little or no paradox") { #expect(s > -0.5) }
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
