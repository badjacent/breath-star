import BreathStar
import Foundation

/// `prone`: where the breath goes face down, and contact variants (LoMauro 2024: abdomen 42.5%).
func runProne(_ args: ArraySlice<String>) {
    let drive = Drive()
    func row(_ label: String, _ c: BodyConfiguration, _ r: GravityRules = GravityRules()) {
        let g = BodyGenerator.general(c, rules: r, drive: drive), b = g.body
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let a = b.anatomy
        func mo(_ z: ClosedRange<Double>, _ p: ClosedRange<Double>) -> (x: Double, y: Double, z: Double) { a.sectorMotion(z: z, psi: p, side: .left, st) }
        print("  " + pad(label, 34) + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))", 17)
              + pad(f(mo(2...16, 0...40).y, 2), 10) + pad(f(mo(2...16, 60...120).x, 2), 10) + pad(f(mo(2...16, 140...180).y, 2), 10)
              + pad(f(mo(18...25, 60...120).x, 2), 10) + pad(f(mo(25...43, 0...40).y, 2), 10) + f(g.driveScale, 2))
    }
    print("Face down (LoMauro 2024: abdomen 42.5%, Q1–Q3 38.7–46.5; 45° 52.0%). Motion mm, left side, outward.")
    print("  " + pad("", 34) + pad("shares u/l/a", 17) + pad("belly fr", 10) + pad("belly lat", 10) + pad("belly bk", 10) + pad("lo rib lat", 10) + pad("chest fr", 10) + "drive")
    let g = (x: 0.0, y: 1.0, z: 0.0)
    row("default (front ψ 0–40°)", .prone)
    for p in [60.0, 80.0, 100.0] {
        row("front to \(Int(p))°", BodyConfiguration(name: "prone", gravity: g, contacts: [ContactPatch(.frontTo(p))]))
    }
    row("no floor", BodyConfiguration(name: "prone", gravity: g))
    var u0 = GravityRules(); u0.uprightUpperDrive = 0
    row("default, no postural loss (u 0)", .prone, u0)
    row("front to 80°, u 0", BodyConfiguration(name: "prone", gravity: g, contacts: [ContactPatch(.frontTo(80))]), u0)
    row("reference: supine", .supine)
    row("reference: 45°", .reclined45)
    print("  Free lift (contacts resist only uneven motion), no refit:")
    var fl = GravityRules(); fl.contactFreeLift = true
    for (l, c) in [("face down", BodyConfiguration.prone), ("supine", .supine), ("45°", .reclined45), ("right side down", .rightSideDown), ("seated", .seated)] {
        row("free lift: " + l, c, fl)
    }
    var fl0 = fl; fl0.uprightUpperDrive = 0
    row("free lift, u 0: face down", .prone, fl0)
    print("  Anchoring a (0 free lift … 1 today), face down and right side down (floor lung: stage3):")
    for a in [0.0, 0.25, 0.5, 0.75] {
        var r = GravityRules(); r.contactAnchoring = a
        row("a \(f(a, 2)): face down", .prone, r)
        var r0 = r; r0.uprightUpperDrive = 0
        row("a \(f(a, 2)): face down, u 0", .prone, r0)
    }
    print("  Flank stiffness × k (all postures; right side down: floor lung % after the shares):")
    for k in [2.0, 4.0, 8.0] {
        var r = GravityRules(); r.flankStiffness = k
        row("k \(f(k, 0)): face down", .prone, r)
        row("k \(f(k, 0)): seated", .seated, r)
        row("k \(f(k, 0)): supine", .supine, r)
        row("k \(f(k, 0)): 45°", .reclined45, r)
        row("k \(f(k, 0)): right side down", .rightSideDown, r)
    }
}
