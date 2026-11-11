import BreathStar
import Foundation

/// `muscles`: fixed-sign muscle groups (MuscleGroups.swift) against the free per-coordinate forces,
/// seated. Every row is a dynamic breath (sourced onset timing, matched to 0.56 L); marker motion is
/// end expiration → end inspiration, judged against Takashima's 12 components.
func runMuscles(_ args: ArraySlice<String>) {
    let drive = Drive()
    let anatomy = AnatomyModel()
    let markers = TakashimaMarkers.sitting
    let se = (15.0).squareRoot()

    struct Row { var label: String; var body: A2Body; var pressures: String }
    var rows: [Row] = []
    // The old calibration (one free force per coordinate, exact fit), for comparison.
    let free = A2Body.calibrate(anatomy: anatomy, reference: anatomy.a2Coordinates(anatomy.fitToMarkers(markers, tidal: 0.56).state))
        .timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
    let freeP = A2Coordinate.allCases.map { f(free.forceAsPressure($0.rawValue), 1) }.joined(separator: " ")
    rows.append(Row(label: "free forces (old)", body: free, pressures: "per coordinate: " + freeP))
    for k in [1.0, 1.5, 2, 3, 4, 6] {
        let fit = A2Body.fitMuscleGroups(anatomy: anatomy, markers: markers, tidal: 0.56, passive: A2MuscleGroup.defaultPassive, lowerBandStiffness: k)
        let b = fit.body.timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
        rows.append(Row(label: "groups, lower band ×\(f(k, 1))", body: b,
                        pressures: "dia/upper/lower " + fit.pressures.map { f($0, 1) }.joined(separator: "/")))
    }

    func breathMarkers(_ b: A2Body) -> AnatomyObservables {
        let sim = b.simulate(drive: drive)
        let cyc = sim.filter { $0.time > sim.last!.time - drive.period }
        let lo = cyc.min { $0.lung < $1.lung }!, hi = cyc.max { $0.lung < $1.lung }!
        var o = b.anatomy.observe(b.anatomy.a2State(hi.q))
        let o0 = b.anatomy.observe(b.anatomy.a2State(lo.q))
        for (key, v) in o.markers { let w = o0.markers[key]!; o.markers[key] = (v.x - w.x, v.y - w.y, v.z - w.z) }
        return o
    }

    print("Fixed-sign muscle groups vs free per-coordinate forces (seated A2; dynamic breath, sourced onset timing,")
    print("matched to 0.56 L). Groups: diaphragm, upper rib cage, lower rib cage; each a pressure ≥ 0 on its wall.")
    print("Fitted: the 3 pressures to Takashima's 12 components + tidal volume. Scanned: the lower band's stiffness.\n")
    print("  " + pad("body", 26) + pad("in SD", 7) + pad("χ²(SD)", 8) + pad("χ²(SE)", 8) + pad("shares u/l/a", 18)
          + pad("rc–abd", 8) + pad("checks", 8) + pad("lower w.", 9) + "hand on lower ribs: side wall out (mm)")
    for r in rows {
        let o = breathMarkers(r.body)
        let within = markers.filter { abs($0.value(o) - $0.mean) <= $0.sd }.count
        let chi = markers.reduce(0.0) { $0 + pow(($1.value(o) - $1.mean) / $1.sd, 2) }
        let chiSE = markers.reduce(0.0) { $0 + pow(($1.value(o) - $1.mean) / ($1.sd / se), 2) }
        let sim = r.body.simulate(drive: drive)
        let m = SignedBreath.measure(sim, period: drive.period), t = BreathTiming.measure(sim, period: drive.period)
        let checks = seatedSourceChecks(a2Cases(r.body), drive: drive)
        let widen = r.body.diameterChanges(atHeight: 21.5, drive: drive).transverse * 10
        let side = "left lateral lower ribcage"
        let held = breathMarkers(r.body.stiffened(A2Coordinate.lowerBand, by: 5))
        print("  " + pad(r.label, 26) + pad("\(within)/12", 7) + pad(f(chi, 1), 8) + pad(f(chiSE, 0), 8)
              + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 18)
              + pad(f(t.ribcageAbdomen, 1) + "°", 8) + pad("\(checks.filter(\.ok).count)/7", 8) + pad(f(widen, 1), 9)
              + "\(f(o.markers[side]!.x, 2)) → \(f(held.markers[side]!.x, 2))")
        print("  " + pad("", 26) + "pressures (cmH2O): " + r.pressures
              + (checks.contains { !$0.ok } ? "   misses: " + checks.filter { !$0.ok }.map(\.name).joined(separator: "; ") : ""))
    }
    print("\n  Takashima (seated): lateral lower ribcage out 0.96 ± 0.85, up 2.19 ± 0.94 mm. 'lower w.' = lower ribcage")
    print("  transverse widening, mm. χ²(SE) judges the mean body against the standard error (SD/√15).")
}
