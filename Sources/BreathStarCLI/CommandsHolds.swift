import BreathStar
import Foundation

// Holds and pressing (critique 3, section 3; the work plan (private), step 4): report where the WALL moves, not
// compartment shares, at the same muscle drive and at matched breath size; and test the mechanics
// against a measured case of pressing on the chest (Kouyama et al. 2016).

/// Wall motion (mm, end expiration → end inspiration by lung volume) of six regions: outward normal
/// motion (front sectors forward, side sectors outward), the person's left side.
func wallRegions(_ b: A2Body, drive: Drive) -> [(name: String, mm: Double)] {
    let sim = b.simulate(drive: drive)
    let cyc = sim.filter { $0.time > sim.last!.time - drive.period }
    let lo = cyc.min { $0.lung < $1.lung }!, hi = cyc.max { $0.lung < $1.lung }!
    let a = b.anatomy
    let s1 = a.a2State(hi.q), s0 = a.a2State(lo.q)
    func sector(_ z: ClosedRange<Double>, _ psi: ClosedRange<Double>, _ front: Bool) -> Double {
        let m1 = a.sectorMotion(z: z, psi: psi, side: .left, s1), m0 = a.sectorMotion(z: z, psi: psi, side: .left, s0)
        return front ? m1.y - m0.y : m1.x - m0.x
    }
    return [
        ("upper front", sector(a.xiphoid...a.top, -40...40, true)),
        ("upper side", sector(a.xiphoid...a.top, 60...120, false)),
        ("lower front", sector(a.costalMargin...a.xiphoid, -40...40, true)),
        ("lower side", sector(a.costalMargin...a.xiphoid, 60...120, false)),
        ("belly front", sector(0...a.costalMargin, -40...40, true)),
        ("belly side", sector(0...a.costalMargin, 60...120, false)),
    ]
}

/// `breathstar holds`
func runHolds(_ args: ArraySlice<String>) {
    let drive = Drive()
    print("Holds: where the wall moves (mm per breath, outward; front regions forward, side regions outward).")
    print("Each hold at the SAME muscle drive as the reference (the breath gets smaller) and MATCHED to the")
    print("reference's breath size (the drive rises). Holds are 5× stiffer coordinates; their sizes are unsourced.\n")
    for (posture, ref) in [("seated", a2Bodies(drive: drive).reference), ("supine", a2Supine(.ribcageStiffness, drive: drive).body)] {
        let tidal = SignedBreath.measure(ref.simulate(drive: drive), period: drive.period).tidalVolume
        let holds: [(String, A2Body)] = [
            ("reference", ref),
            ("belly held", ref.stiffened([.abdomen], by: 5)),
            ("hand on lower ribs", ref.stiffened(A2Coordinate.lowerBand, by: 5)),
            ("upper chest held", ref.stiffened([.upperRotation, .upperDilation], by: 5)),
        ]
        let names = wallRegions(ref, drive: drive).map(\.name)
        print("  \(posture) (reference tidal \(f(tidal, 2)) L)")
        print("    " + pad("case", 32) + pad("tidal", 8) + names.map { pad($0, 13) }.joined())
        for (label, b) in holds {
            for (mode, body) in label == "reference" ? [("", b)] : [("same drive", b), ("matched", b.matchedToTidal(tidal, drive: drive))] {
                let t = SignedBreath.measure(body.simulate(drive: drive), period: drive.period).tidalVolume
                let w = wallRegions(body, drive: drive)
                print("    " + pad(label + (mode.isEmpty ? "" : ", " + mode), 32) + pad(f(t, 2), 8)
                      + w.map { pad(f($0.mm, 2), 13) }.joined())
            }
        }
        print("")
    }
    print("  Read the region under the hold (it moves less), then where the motion goes: at the same drive the")
    print("  breath shrinks; matched, the drive rises and the free regions take more. Shares are left out on purpose:")
    print("  ring-bounded compartments trade volume across the costal margin, so a held region's share can rise.")
}

/// `breathstar kouyama`: Kouyama et al. 2016 (Physical Therapy Japan 43:368–374; Nozoe and Takashima's lab).
/// 7 healthy men, supine, quiet breathing, OEP + oesophageal and gastric balloons. A physiotherapist presses
/// the upper ribcage (below the clavicles) or the lower ribcage (front, just below the nipples, to the sides)
/// from the start of expiration until just before inspiration, as hard as is comfortable. Table 2 (L, per
/// breath, mean ± SD) and Table 4 (end-expiratory gastric pressure, cmH2O).
func runKouyama(_ args: ArraySlice<String>) {
    let drive = Drive()
    let base = a2Supine(.ribcageStiffness, drive: drive).body
    struct Condition { var name: String; var coords: [A2Coordinate]; var pgaRise: Double; var data: [Double] }
    // data: ΔVcw, ΔVrcp (upper ribcage), ΔVrca (lower ribcage), ΔVab.
    let quietData = [0.50, 0.07, 0.09, 0.33]
    let conditions = [
        Condition(name: "upper-chest assist", coords: [.upperRotation, .upperDilation], pgaRise: 8.71 - 2.99, data: [1.58, 0.81, 0.43, 0.34]),
        Condition(name: "lower-ribcage assist", coords: A2Coordinate.lowerBand, pgaRise: 15.55 - 2.99, data: [1.40, -0.14, 0.90, 0.64]),
    ]
    func run(_ b: A2Body) -> (v: [Double], pabEndExp: Double) {
        let sim = b.simulate(drive: drive)
        let cyc = sim.filter { $0.time > sim.last!.time - drive.period }
        let lo = cyc.min { $0.lung < $1.lung }!, hi = cyc.max { $0.lung < $1.lung }!
        let up = hi.upperRegion - lo.upperRegion, low = hi.lowerRegion - lo.lowerRegion, ab = hi.abdomenRegion - lo.abdomenRegion
        return ([up + low + ab, up, low, ab], lo.abdominal)
    }
    let quiet = run(base)
    func fmtV(_ v: [Double]) -> String { v.map { pad(f($0, 2), 8) }.joined() }
    print("Kouyama et al. 2016: pressing the chest through expiration, supine (7 healthy men; OEP and gastric pressure).")
    print("Model: supine A2 (fixed-sign groups, hypothesis A), the same muscle drive in every condition. The press is an")
    print("external pressure on the pressed band's wall, held through expiration. Its size is FITTED to the measured rise")
    print("in end-expiratory gastric pressure; the four volume changes are then PREDICTED.\n")
    print("  " + pad("", 30) + pad("ΔVcw", 8) + pad("ΔVrcp", 8) + pad("ΔVrca", 8) + pad("ΔVab", 8) + "   end-exp Pab rise")
    print("  " + pad("quiet, measured", 30) + fmtV(quietData))
    print("  " + pad("quiet, model", 30) + fmtV(quiet.v))
    for c in conditions {
        func with(_ p: Double) -> A2Body {
            var b = base
            b.externalExpiratoryPressure = A2Coordinate.allCases.map { c.coords.contains($0) ? p : 0 }
            return b
        }
        var lo = 0.0, hi = 200.0
        for _ in 0..<40 { let mid = 0.5 * (lo + hi); if run(with(mid)).pabEndExp - quiet.pabEndExp < c.pgaRise { lo = mid } else { hi = mid } }
        let p = 0.5 * (lo + hi), r = run(with(p))
        print("  " + pad("\(c.name), measured", 30) + fmtV(c.data) + "   \(f(c.pgaRise, 1)) cmH2O")
        print("  " + pad("\(c.name), model", 30) + fmtV(r.v) + "   \(f(r.pabEndExp - quiet.pabEndExp, 1)) (press \(f(p, 1)) cmH2O, fitted)")
        let signs = zip(r.v, c.data).map { ($0 >= 0) == ($1 >= 0) }
        print("  " + pad("", 30) + "signs: " + zip(["cw", "rcp", "rca", "ab"], signs).map { "\($0) \($1 ? "ok" : "MISS")" }.joined(separator: ", "))
    }
    // Sensitivity (not a refit): what lets the upper ribcage expand under a lower-ribcage press?
    print("\n  Sensitivity, lower-ribcage assist (press refitted to the 12.6 cmH2O rise each time; body otherwise as above):")
    print("  " + pad("costal-arch coupling × / pressed", 40) + pad("ΔVcw", 8) + pad("ΔVrcp", 8) + pad("ΔVrca", 8) + pad("ΔVab", 8) + "press")
    let lateral: [A2Coordinate] = [.lowerBucket, .lowerDilationTransverse]
    for scale in [1.0, 0.3, 0.1, 0.0] {
        for (pressLabel, coords) in [("whole lower band", A2Coordinate.lowerBand), ("sides only", lateral)] {
            var b0 = base
            b0.couplingStiffness *= scale
            let q0 = run(b0)
            func with(_ p: Double) -> A2Body {
                var b = b0
                b.externalExpiratoryPressure = A2Coordinate.allCases.map { coords.contains($0) ? p : 0 }
                return b
            }
            var lo = 0.0, hi = 400.0
            for _ in 0..<40 { let mid = 0.5 * (lo + hi); if run(with(mid)).pabEndExp - q0.pabEndExp < 15.55 - 2.99 { lo = mid } else { hi = mid } }
            let p = 0.5 * (lo + hi), r = run(with(p))
            print("  " + pad("arch ×\(f(scale * 10, 1)) / \(pressLabel)", 40) + fmtV(r.v) + f(p, 0))
        }
    }
    print("  measured                                " + fmtV([1.40, -0.14, 0.90, 0.64]))

    print("\n  The test that matters: pressing the lower ribcage makes the upper ribcage EXPAND while breathing out")
    print("  (ΔVrcp −0.14 L, negative in all 7 subjects), through the rise in abdominal pressure (Kouyama's Fig. 4b).")
}


/// Kouyama 2016 as a reusable test on a supine body: each press sized to the measured end-expiratory
/// gastric pressure rise; predicted ΔV (cw, rcp, rca, ab) per condition, and χ² against Table 2 using the
/// standard error (SD/√7) over the 8 pressed values.
struct KouyamaResult { var quiet: [Double]; var upper: [Double]; var lower: [Double]; var chiSE: Double; var lowerRcpSignOK: Bool }
func kouyamaTest(_ base: A2Body, drive: Drive, lowerCoords: [A2Coordinate] = A2Coordinate.lowerBand) -> KouyamaResult {
    func run(_ b: A2Body) -> (v: [Double], pab: Double) {
        let sim = b.simulate(drive: drive)
        let cyc = sim.filter { $0.time > sim.last!.time - drive.period }
        let lo = cyc.min { $0.lung < $1.lung }!, hi = cyc.max { $0.lung < $1.lung }!
        let up = hi.upperRegion - lo.upperRegion, low = hi.lowerRegion - lo.lowerRegion, ab = hi.abdomenRegion - lo.abdomenRegion
        return ([up + low + ab, up, low, ab], lo.abdominal)
    }
    let quiet = run(base)
    func pressed(_ coords: [A2Coordinate], rise: Double) -> [Double] {
        func with(_ p: Double) -> A2Body {
            var b = base
            b.externalExpiratoryPressure = A2Coordinate.allCases.map { coords.contains($0) ? p : 0 }
            return b
        }
        var lo = 0.0, hi = 600.0
        for _ in 0..<36 { let mid = 0.5 * (lo + hi); if run(with(mid)).pab - quiet.pab < rise { lo = mid } else { hi = mid } }
        return run(with(0.5 * (lo + hi))).v
    }
    let up = pressed([.upperRotation, .upperDilation], rise: 8.71 - 2.99)
    let low = pressed(lowerCoords, rise: 15.55 - 2.99)
    let meanU = [1.58, 0.81, 0.43, 0.34], sdU = [0.28, 0.14, 0.11, 0.17]
    let meanL = [1.40, -0.14, 0.90, 0.64], sdL = [0.34, 0.09, 0.20, 0.26]
    let se = (7.0).squareRoot()
    var chi = 0.0
    for i in 0..<4 {
        chi += pow((up[i] - meanU[i]) / (sdU[i] / se), 2)
        chi += pow((low[i] - meanL[i]) / (sdL[i] / se), 2)
    }
    return KouyamaResult(quiet: quiet.v, upper: up, lower: low, chiSE: chi, lowerRcpSignOK: low[1] < 0)
}

/// `breathstar basis-test`: which passive-stiffness basis (and costal-arch coupling) do the data favour?
/// Per choice: the seated muscle groups refitted (the lower band's stiffness picked by the markers), the
/// supine body built from it (hypothesis A), then Kouyama's presses.
func runBasisTest(_ args: ArraySlice<String>) {
    let drive = Drive()
    let anatomy = AnatomyModel()
    print("Stiffness basis × costal-arch coupling, tested on Takashima's seated markers and Kouyama 2016's presses.")
    print("Per row: lower band stiffness chosen by the seated marker fit; supine from that body (hypothesis A);")
    print("Kouyama χ² against the standard error over 8 values (upper and lower press: ΔVcw, ΔVrcp, ΔVrca, ΔVab).\n")
    print("  " + pad("basis / arch", 24) + pad("lower ×", 9) + pad("seat χ²", 9) + pad("checks", 8) + pad("seated u/l/a", 17)
          + pad("supine u/l/a", 17) + pad("Kouyama χ²", 12) + pad("lower press rcp", 17) + "upper / lower press (cw rcp rca ab)")
    for basis in A2Passive.StiffnessBasis.allCases {
        for arch in [10.0, 1.0] {
            var passive = A2Passive()
            passive.stiffnessBasis = basis
            passive.sternalCoupling = arch
            let best = [0.5, 1, 1.5, 2, 3, 4, 6].map {
                A2Body.fitMuscleGroups(anatomy: anatomy, markers: TakashimaMarkers.sitting, tidal: 0.56, passive: passive, lowerBandStiffness: $0)
            }.min { $0.chiSquared < $1.chiSquared }!
            let seated = best.body.timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
            let sm = SignedBreath.measure(seated.simulate(drive: drive), period: drive.period)
            let checks = seatedSourceChecks(a2Cases(seated), drive: drive).filter(\.ok).count
            let supine = a2Supine(.ribcageStiffness, drive: drive, seated: seated).body
            let pm = SignedBreath.measure(supine.simulate(drive: drive), period: drive.period)
            let k = kouyamaTest(supine, drive: drive)
            func v(_ x: [Double]) -> String { x.map { f($0, 2) }.joined(separator: " ") }
            print("  " + pad("\(basis.rawValue) / ×\(f(arch, 0))", 24) + pad(f(best.lowerBandStiffness, 1), 9) + pad(f(best.chiSquared, 2), 9)
                  + pad("\(checks)/7", 8) + pad("\(f(sm.upperShare * 100, 0))/\(f(sm.lowerShare * 100, 0))/\(f(sm.abdomenShare * 100, 0))", 17)
                  + pad("\(f(pm.upperShare * 100, 0))/\(f(pm.lowerShare * 100, 0))/\(f(pm.abdomenShare * 100, 0))", 17)
                  + pad(f(k.chiSE, 0), 12) + pad("\(f(k.lower[1], 2)) \(k.lowerRcpSignOK ? "ok" : "MISS")", 17)
                  + v(k.upper) + " / " + v(k.lower))
        }
    }
    print("\n  Measured: upper press 1.58 0.81 0.43 0.34 / lower press 1.40 -0.14 0.90 0.64. Mendes 2020 seated men,")
    print("  abdomen 41%; supine 66–70%. Takashima's markers fit by every row is χ² over 12 components (SD).")
}


/// `breathstar arch-scan`: the costal-arch coupling (sternal coupling) under the default ribcage basis,
/// against every test at once: seated markers (lower band stiffness re-picked), seated patient directions,
/// supine markers and shares, Kouyama's presses.
func runArchScan(_ args: ArraySlice<String>) {
    let drive = Drive(), anatomy = AnatomyModel()
    print("Costal-arch coupling scan (ribcage basis; the lower band's stiffness re-picked by the seated markers each time).\n")
    print("  " + pad("arch ×", 8) + pad("lower ×", 9) + pad("seat χ²", 9) + pad("checks", 8) + pad("seated u/l/a", 15)
          + pad("supine in SD", 14) + pad("supine u/l/a", 15) + pad("Kouyama χ²", 12) + "lower press ΔVrcp")
    for arch in (CommandLine.arguments.contains("--fine") ? [3.0, 4, 5, 6, 8] : [0.5, 1, 2, 3, 5, 10, 20]) {
        var passive = A2Passive()
        passive.sternalCoupling = arch
        let best = [1.0, 1.5, 2, 2.5, 3, 4].map {
            A2Body.fitMuscleGroups(anatomy: anatomy, markers: TakashimaMarkers.sitting, tidal: 0.56, passive: passive, lowerBandStiffness: $0)
        }.min { $0.chiSquared < $1.chiSquared }!
        let seated = best.body.timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
        let sm = SignedBreath.measure(seated.simulate(drive: drive), period: drive.period)
        let checks = seatedSourceChecks(a2Cases(seated), drive: drive).filter(\.ok).count
        let supine = a2Supine(.ribcageStiffness, drive: drive, seated: seated).body
        let pm = SignedBreath.measure(supine.simulate(drive: drive), period: drive.period)
        let o = supine.anatomy.observe(supine.anatomy.a2State(supine.endInspiration(drive: drive)))
        let inSD = TakashimaMarkers.supine.filter { abs($0.value(o) - $0.mean) <= $0.sd }.count
        let k = kouyamaTest(supine, drive: drive)
        print("  " + pad(f(arch, 1), 8) + pad(f(best.lowerBandStiffness, 1), 9) + pad(f(best.chiSquared, 2), 9) + pad("\(checks)/7", 8)
              + pad("\(f(sm.upperShare * 100, 0))/\(f(sm.lowerShare * 100, 0))/\(f(sm.abdomenShare * 100, 0))", 15)
              + pad("\(inSD)/\(TakashimaMarkers.supine.count)", 14)
              + pad("\(f(pm.upperShare * 100, 0))/\(f(pm.lowerShare * 100, 0))/\(f(pm.abdomenShare * 100, 0))", 15)
              + pad(f(k.chiSE, 0), 12) + f(k.lower[1], 2))
    }
    print("\n  Measured lower-press ΔVrcp −0.14 L. Current default: arch ×10, lower ×2.")
}
