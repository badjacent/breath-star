import BreathStar
import Foundation

/// `legs`: lying on the back with the legs placed (docs/LESSON_ADAPTATION.md §4.6), each ingredient in turn.
func runLegs(_ args: ArraySlice<String>) {
    let drive = Drive()
    func report(_ label: String, _ c: BodyConfiguration) {
        let r = BodyGenerator.general(c, drive: drive)
        let b = r.body
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        func front(_ z: ClosedRange<Double>) -> Double {
            Side.allCases.map { b.anatomy.sectorMotion(z: z, psi: 0...40, side: $0, st).y }.reduce(0, +) / 2
        }
        let lat = Side.allCases.map { b.anatomy.sectorMotion(z: 18...25, psi: 80...100, side: $0, st).x }
        print("  " + pad(label, 34) + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))", 17)
              + pad(f(front(2...8), 2), 9) + pad(f(front(10...16), 2), 9) + pad("\(f(lat[0], 2))/\(f(lat[1], 2))", 12)
              + pad("\(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))", 11) + f(r.driveScale, 2))
    }
    let s = BodyConfiguration.supine
    let bent = Legs.kneesBent
    print("Lying on the back, legs placed (every size ASSUMED; Legs in Configuration.swift).")
    print("  " + pad("", 34) + pad("shares u/l/a %", 17) + pad("low bel", 9) + pad("high bel", 9) + pad("lat ribs L/R", 12) + pad("wall L/R", 11) + "drive")
    print("  " + pad("", 34) + pad("", 17) + pad("mm fwd", 9) + pad("mm fwd", 9) + pad("mm", 12) + pad("mL", 11))
    report("legs long", s)
    var onlyBend = s; onlyBend.spine.lumbarFlexion = bent.lumbarFlexion
    report("knees bent: pelvis roll only", onlyBend)
    var withContact = onlyBend; withContact.contacts.append(ContactPatch(.lowBack))
    report("  + lower back on the floor", withContact)
    report("  + low wall slack (all: kneesBent)", s.with(bent))
    report("knees bent, feet off the floor", s.with(Legs(left: 60, right: 60, feetStanding: false)))
    report("right foot standing, left leg long", s.with(Legs(left: 0, right: 60)))
    report("right knee to chest, left foot stands", s.with(Legs(left: 60, right: 110)))
    report("both knees to chest (feet off)", s.with(Legs(left: 110, right: 110, feetStanding: false)))
    print("  low/high belly: front wall (ψ 0–40°) at 2–8 and 10–16 cm above the iliac crests; lat ribs: z 18–25, ψ 80–100°.")
}
