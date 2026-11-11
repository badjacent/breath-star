import BreathStar
import Foundation

/// `breathstar configure [seated|reclined|supine|right|left|prone|x,y,z] [--no-contact] [--hand-fitted]`:
/// configuration in, body out (the general rules; `--hand-fitted`: stage 2's per-posture bodies).
/// Prints what the generator built, what each ingredient rests on, and the breath.
func runConfigure(_ args: ArraySlice<String>) {
    let drive = Drive()
    let spec = args.dropFirst().first { !$0.hasPrefix("--") } ?? "seated"
    var c: BodyConfiguration
    switch spec {
    case "seated": c = .seated
    case "supine": c = .supine
    case "right": c = .rightSideDown
    case "left": c = .leftSideDown
    case "reclined": c = .reclined45
    case "prone": c = .prone
    default:
        let v = spec.split(separator: ",").compactMap { Double($0) }
        guard v.count == 3 else { fail("give seated, supine, right, left, or gravity as x,y,z (x left, y forward, z head)") }
        c = BodyConfiguration(name: "gravity \(spec)", gravity: (v[0], v[1], v[2]))
    }
    if args.contains("--no-contact") { c.contacts = [] }
    print("Configuration: \(c.name); gravity (x left, y forward, z head) = (\(f(c.gravity.x, 2)), \(f(c.gravity.y, 2)), \(f(c.gravity.z, 2)));"
          + " contacts: " + (c.contacts.isEmpty ? "none" : c.contacts.map(\.label).joined(separator: ", ")))
    do {
        let g = args.contains("--hand-fitted") ? try BodyGenerator.handFitted(c, drive: drive) : BodyGenerator.body(c, drive: drive)
        for line in g.provenance { print("  · " + line) }
        let m = SidedBreath.measure(g.body.simulate(drive: drive), period: drive.period)
        print("  breath: tidal \(f(m.tidalVolume, 3)) L; shares upper/lower/abdomen \(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%;"
              + " lungs left/right \(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0)) mL; chest wall left/right \(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0)) mL")
    } catch {
        print("  \(error)")
        exit(1)
    }
}
