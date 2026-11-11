import BreathStar
import Foundation

/// `patients`: three clinical patterns, sitting against lying on the back, on the current bodies
/// (`BodyGenerator.general`), with one muscle group silenced; first with the breath held at the quiet
/// tidal volume (the model's convention everywhere; Higenbottam's paradox grows with breath size),
/// then with the remaining drive unchanged.
///   Estenne 1985: the diaphragm alone, supine: the lower ribcage's front moves inward.
///   Mortola 1978: the rib muscles paralysed: the ribcage moves paradoxically, more so lying down.
///   Higenbottam 1977: the diaphragm paralysed: the belly moves paradoxically, clearest lying down.
func runPatients(_ args: ArraySlice<String>) {
    let drive = Drive()
    func row(_ label: String, _ c: BodyConfiguration, silence: Set<A2Muscles>, matched: Bool) -> (rc: Double, ab: Double, front: Double, belly: Double) {
        var b = BodyGenerator.general(c, drive: drive).body.silenced(silence)
        if matched {  // the same breath as everywhere else in the model (quiet tidal held)
            let t = SidedBreath.measure(b.simulate(drive: drive), period: drive.period).tidalVolume
            b.peakForce = b.peakForce.map { $0 * 0.56 / t }
        }
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let rc = (m.upper[0] + m.upper[1] + m.lower[0] + m.lower[1]) * 1000, ab = (m.abdomen[0] + m.abdomen[1]) * 1000
        let front = b.anatomy.sectorMotion(z: 18...25, psi: -40...40, side: .left, st).y
        let belly = b.anatomy.sectorMotion(z: 4...14, psi: -20...20, side: .left, st).y
        print("  " + pad(label, 40) + pad(f(m.tidalVolume * 1000, 0), 10) + pad(f(rc, 0), 12) + pad(f(ab, 0), 12) + pad(f(front, 2), 14) + f(belly, 2))
        return (rc, ab, front, belly)
    }
    func v(_ ok: Bool) -> String { ok ? "✓" : "✗" }
    for matched in [true, false] {
        print((matched ? "" : "\n") + "Patients (acute: one group silenced), " + (matched ? "the breath held at 0.56 L (the model's convention):" : "the remaining drive unchanged:"))
        print("  " + pad("", 40) + pad("tidal", 10) + pad("ribcage", 12) + pad("belly", 12) + pad("lower front", 14) + "belly front AP (mm)")
        let ds = row("diaphragm alone, seated", .seated, silence: [.ribs], matched: matched)
        let dp = row("diaphragm alone, supine", .supine, silence: [.ribs], matched: matched)
        let rs = row("rib muscles alone, seated", .seated, silence: [.diaphragm], matched: matched)
        let rp = row("rib muscles alone, supine", .supine, silence: [.diaphragm], matched: matched)
        print("  Estenne 1985, diaphragm alone supine: lower ribcage front inward: \(f(dp.front, 2)) mm \(v(dp.front < 0))")
        print("  Mortola 1978, ribcage paradox worse supine: ribcage \(f(ds.rc, 0)) seated → \(f(dp.rc, 0)) mL supine \(v(dp.rc < ds.rc))")
        print("  Higenbottam 1977 (front belly AP), paradox best seen recumbent: \(f(rs.belly, 2)) seated → \(f(rp.belly, 2)) mm supine \(v(rp.belly < rs.belly));"
              + " none upright (Kreitzer 1978): \(v(rs.belly > -0.5))")
    }
}
