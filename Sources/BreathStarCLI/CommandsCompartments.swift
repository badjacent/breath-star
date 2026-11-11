import BreathStar
import Foundation

/// `compartments`: the breath's shares with the model's flat margin and with OEP's arched one.
func runCompartments(_ args: ArraySlice<String>) {
    let drive = Drive()
    func row(_ label: String, _ c: BodyConfiguration, lateral: Double = 13) {
        let b = BodyGenerator.general(c, drive: drive).body
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let st = b.anatomy.sidedState(zip(hi.q, lo.q).map { $0 - $1 })
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let own = [m.upperShare, m.lowerShare, m.abdomenShare]
        let a = b.anatomy
        let flat = a.fluxCompartments(st) { _ in a.costalMargin }
        let arch = a.fluxCompartments(st) { a.oepMargin(psi: $0, lateralMargin: lateral) }
        let tf = flat.reduce(0, +), ta = arch.reduce(0, +)
        let corrected = (0..<3).map { own[$0] + arch[$0] / ta - flat[$0] / tf }
        func p(_ v: [Double]) -> String { v.map { f($0 * 100) }.joined(separator: "/") }
        print("  " + pad(label, 24) + pad(p(own), 20) + pad(p(flat.map { $0 / tf }), 20) + pad(p(arch.map { $0 / ta }), 20) + p(corrected))
    }
    print("Shares u/l/a % — model (material rings, flat margin) | flux, flat | flux, OEP arch | model + (arch − flat)")
    print("  " + pad("", 24) + pad("model", 20) + pad("flux flat", 20) + pad("flux arch", 20) + "OEP-like")
    row("seated", .seated)
    row("reclined 45°", .reclined45)
    row("supine", .supine)
    row("prone", .prone)
    print("  seated, lateral margin 15 / 11 cm:")
    row("  15 cm", .seated, lateral: 15)
    row("  11 cm", .seated, lateral: 11)
    print("  Data: Mendes men seated 37.4/21.9/40.8, 45° 31.0/14.3/55.4, supine 19.5/11.5/69.8; Kouyama supine 14/18/66.")
}
