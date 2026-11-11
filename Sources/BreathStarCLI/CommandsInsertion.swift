import BreathStar
import Foundation

/// `insertion`: the diaphragm's insertional pull (Insertion.swift), a feasibility scan: with the
/// diaphragm alone, does the lower ribcage widen at the sides while its front moves in (Estenne 1985,
/// supine)? Bodies as fitted without it; the breath held at 0.56 L.
func runInsertion(_ args: ArraySlice<String>) {
    let drive = Drive()
    func row(_ label: String, _ c: BodyConfiguration, strength: Double, slope: Double, silence: Set<A2Muscles>) {
        var b = BodyGenerator.general(c, drive: drive).body
        if strength > 0 { b = b.withInsertion(strength: strength, frontSlope: slope) }
        b = b.silenced(silence)
        let t = SidedBreath.measure(b.simulate(drive: drive), period: drive.period).tidalVolume
        b.peakForce = b.peakForce.map { $0 * 0.56 / t }
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let a = b.anatomy
        let front = a.sectorMotion(z: 18...25, psi: -40...40, side: .left, st).y
        let side = a.sectorMotion(z: 18...25, psi: 80...100, side: .left, st).x
        let upperFront = a.sectorMotion(z: 25...43, psi: -30...30, side: .left, st).y
        print("  " + pad(label, 30) + pad(f(strength, 1), 10) + pad(f(slope, 0), 8)
              + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))", 18)
              + pad(f(front, 2), 12) + pad(f(side, 2), 12) + f(upperFront, 2))
    }
    print("Insertional pull (strength 1 = Laplace, R 10 cm), breath held at 0.56 L. mm: lower front AP, lower side, upper front AP.")
    print("  " + pad("", 30) + pad("strength", 10) + pad("slope", 8) + pad("shares u/l/a", 18) + pad("lower fr", 12) + pad("lower side", 12) + "upper fr")
    for (label, c, sil) in [("supine, diaphragm alone", BodyConfiguration.supine, Set<A2Muscles>([.ribs])),
                            ("seated, diaphragm alone", .seated, [.ribs]),
                            ("supine, healthy", .supine, []), ("seated, healthy", .seated, [])] {
        for (s, sl) in (args.contains("--steep") ? [(1.0, 60.0), (1, 75), (1, 85), (2, 85)] : [(0.0, 45.0), (0.5, 45), (1, 45), (2, 45), (1, 0)]) { row(label, c, strength: s, slope: sl, silence: sil) }
    }
    print("  Estenne 1985 (tetraplegia, supine, diaphragm alone): lower front inward, lower sides out, upper front inward.")
}
