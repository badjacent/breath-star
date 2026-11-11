import Testing
@testable import BreathStar

/// Three clinical patterns on the current bodies (`BodyGenerator.general`, the posture rules), one
/// muscle group silenced (`breathstar patients`), under two conventions: the remaining drive
/// unchanged, or the breath held at 0.56 L as everywhere else in the model. The "worse lying down"
/// comparisons flip between them (Mortola holds at same drive, Higenbottam at the same breath), so
/// they turn on how much a patient compensates, which the model doesn't know; only what holds under
/// both is asserted. The older tests in MechanicsSupine check the earlier fitted supine body.
@Suite struct PatientsOnTheRules {
    static let drive = Drive()
    struct Out { var ribcage: Double; var belly: Double; var lowerFront: Double; var bellyFront: Double }
    static func breath(_ c: BodyConfiguration, silence: Set<A2Muscles>, matched: Bool) -> Out {
        var b = BodyGenerator.general(c, drive: drive).body.silenced(silence)
        if matched {
            let t = SidedBreath.measure(b.simulate(drive: drive), period: drive.period).tidalVolume
            b.peakForce = b.peakForce.map { $0 * 0.56 / t }
        }
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        return Out(ribcage: m.upper[0] + m.upper[1] + m.lower[0] + m.lower[1], belly: m.abdomen[0] + m.abdomen[1],
                   lowerFront: b.anatomy.sectorMotion(z: 18...25, psi: -40...40, side: .left, st).y,
                   bellyFront: b.anatomy.sectorMotion(z: 4...14, psi: -20...20, side: .left, st).y)
    }

    /// Mortola 1978: rib muscles paralysed, the ribcage moves inward (in both postures, both conventions).
    @Test func ribcageParadox() {
        for matched in [false, true] { for c in [BodyConfiguration.seated, .supine] {
            #expect(Self.breath(c, silence: [.ribs], matched: matched).ribcage < 0)
        } }
    }

    /// Higenbottam 1977 (Thorax 32:589; magnetometers on the front belly wall): diaphragm paralysed, the
    /// front belly moves inward, best seen lying down; upright there may be none (Kreitzer 1978). The
    /// model has the paradox lying down, but also sitting (−1.6 mm same drive, −3.7 mm same breath):
    /// what masks it upright (the contents' weight, expiratory abdominal activity) is not modelled.
    @Test func bellyParadox() {
        for matched in [false, true] {
            #expect(Self.breath(.supine, silence: [.diaphragm], matched: matched).bellyFront < 0)
            withKnownIssue("Kreitzer 1978: upright, little or no belly paradox") {
                #expect(Self.breath(.seated, silence: [.diaphragm], matched: matched).bellyFront > -0.5)
            }
        }
    }

    /// Estenne 1985: the diaphragm alone, supine, moves the lower ribcage's front inward while the
    /// sides widen. Met since 2026-11-11 by the costal arch's stiffness (×5, chosen inside the window
    /// where the seated patient directions hold, `A2MuscleGroup.costalArch`): a fit, not a
    /// prediction. Small: −0.10 mm (+0.03 at the earlier ×3).
    @Test func lowerFrontWithTheDiaphragmAlone() {
        for matched in [false, true] {
            let p = Self.breath(.supine, silence: [.ribs], matched: matched)
            #expect(p.lowerFront < 0)
        }
    }
}
