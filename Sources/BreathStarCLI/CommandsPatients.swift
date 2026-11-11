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
    if args.contains("--arch") { runPatientsArch(drive); return }
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

/// `patients --arch`: the costal arch's stiffness against Estenne's pattern (diaphragm alone, supine:
/// the lower front in, the sides out) and what it costs elsewhere (the markers, the shares).
func runPatientsArch(_ drive: Drive) {
    print("Costal arch (× the lower pump's spring; default \(f(A2MuscleGroup.costalArch, 0)), fitted): diaphragm alone supine, breath 0.56 L.")
    print("  " + pad("arch", 7) + pad("lower front", 13) + pad("lower side", 12) + pad("upper front", 13) + pad("markers χ²", 12) + pad("seated u/l/a", 18) + "supine u/l/a")
    for arch in (CommandLine.arguments.contains("--fine") ? [3.0, 4, 5, 6, 8] : [1.0, 3, 10, 30, 100]) {
        var r = GravityRules(); r.costalArch = arch
        var b = BodyGenerator.general(.supine, rules: r, drive: drive).body.silenced([.ribs])
        let t = SidedBreath.measure(b.simulate(drive: drive), period: drive.period).tidalVolume
        b.peakForce = b.peakForce.map { $0 * 0.56 / t }
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let a = b.anatomy
        var passive = A2MuscleGroup.defaultPassive; passive.sternalCoupling = arch
        let fit = A2Body.fitMuscleGroups(anatomy: AnatomyModel(), markers: TakashimaMarkers.sitting, tidal: 0.56, passive: passive,
                                         lowerBandStiffness: A2MuscleGroup.lowerBandStiffness, volumes: .mendesMenSeated)
        func shares(_ c: BodyConfiguration) -> String {
            let m = SidedBreath.measure(BodyGenerator.general(c, rules: r, drive: drive).body.simulate(drive: drive), period: drive.period)
            return "\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))"
        }
        print("  " + pad(f(arch, 0), 7) + pad(f(a.sectorMotion(z: 18...25, psi: -40...40, side: .left, st).y, 2), 13)
              + pad(f(a.sectorMotion(z: 18...25, psi: 80...100, side: .left, st).x, 2), 12)
              + pad(f(a.sectorMotion(z: 25...43, psi: -30...30, side: .left, st).y, 2), 13)
              + pad(f(fit.chiSquared, 2), 12) + pad(shares(.seated), 18) + shares(.supine))
    }
    print("  Estenne 1985: lower front in, lower sides out (tetraplegia, supine). Mendes men seated 37.4/21.9/40.8, supine 19.5/11.5/69.8.")
}
