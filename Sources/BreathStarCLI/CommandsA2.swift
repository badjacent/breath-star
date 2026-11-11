import BreathStar
import Foundation

// CLI commands: A2 mechanics: seated and supine, timing, expiration. Dispatched from main.swift.

/// `breathstar a2`
func runA2(_ args: ArraySlice<String>) {
    // A2: mechanics on the anatomical coordinates. Calibrate on A1's marker-matched breath,
    // report the muscle forces it requires, then perturb.
    let anatomy = AnatomyModel()
    let tidal = 0.56
    let refState = anatomy.fitToMarkers(TakashimaMarkers.sitting, tidal: tidal).state
    let refObs = anatomy.observe(refState)
    let implied = (upper: refObs.upperRibcage.reduce(0, +), lower: refObs.lowerRibcage.reduce(0, +), abdomen: refObs.abdomen.reduce(0, +))
    let it = implied.upper + implied.lower + implied.abdomen
    let qRef = anatomy.a2Coordinates(refState)
    let drive = Drive()
    let freeForces = CommandLine.arguments.contains("--free-forces")
    let groupFit = A2Body.fitMuscleGroups(anatomy: anatomy, markers: TakashimaMarkers.sitting, tidal: tidal,
                                          passive: A2MuscleGroup.defaultPassive, lowerBandStiffness: A2MuscleGroup.lowerBandStiffness)
    var staticBody = freeForces ? A2Body.calibrate(anatomy: anatomy, reference: qRef) : groupFit.body
    if !freeForces {
        // The groups' static state and its pressures (calibrate's reference fields are for free forces).
        let q = staticBody.reference, jth = staticBody.geometry.thorax, jab = staticBody.geometry.abdominalCavity
        let a = A2Coordinate.abdomen.rawValue
        let ppl = -zip(jth, q).reduce(0) { $0 + $1.0 * $1.1 } / staticBody.passive.lungCompliance
        let kq = multiplyRows(staticBody.stiffnessMatrix, q)
        staticBody.referencePleural = ppl
        staticBody.referenceAbdominal = (kq[a] - ppl * jth[a] - staticBody.peakForce[a]) / jab[a]
    }
    let body = staticBody.timed(MuscleTiming(), drive: drive).matchedToTidal(tidal, drive: drive)
    print("A2 mechanics on A1's coordinates (seated man; Takashima 2017's markers, 0.56 L). "
          + (freeForces ? "Free forces (--free-forces): one per coordinate, solved to reproduce A1's fitted state exactly."
                        : "Three fixed-sign muscle groups, fitted to the markers; lower band ×\(f(A2MuscleGroup.lowerBandStiffness, 1)) stiffer."))
    if !freeForces {
        print("   Group pressures (cmH2O, ≥ 0): " + zip(A2MuscleGroup.allCases, groupFit.pressures).map { "\($0.label) \(f($1, 2))" }.joined(separator: "; "))
        print("   Markers: χ² \(f(groupFit.chiSquared, 2)) over \(TakashimaMarkers.sitting.count) components (static), "
              + "\(groupFit.rows.filter { abs($0.model - $0.observation.mean) <= $0.observation.sd }.count) within SD")
    }
    print("")
    print("1. Pressures at the reference end inspiration (static):")
    print("   pleural \(f(staticBody.referencePleural, 2)) cmH2O (lung compliance \(f(staticBody.passive.lungCompliance, 2)) L/cmH2O, textbook)")
    print("   abdominal \(f(staticBody.referenceAbdominal, 2)) cmH2O (abdominal muscles assumed relaxed in quiet breathing)")
    print("   transdiaphragmatic \(f(staticBody.referenceAbdominal - staticBody.referencePleural, 2)) cmH2O\n")
    print("2. Muscle forces, as pressure over each coordinate's own region" + (freeForces ? " (solved, not assumed)." : " (from the groups)."))
    print("   Static solve; the simulation then scales all forces by \(f(body.peakForce[6] / staticBody.peakForce[6], 3)) to reach \(f(tidal, 2)) L through airway resistance:")
    for c in A2Coordinate.allCases where c != .abdomen {
        let p = staticBody.forceAsPressure(c.rawValue)
        let passiveNote: String
        switch c {
        case .lowerDilationAP, .lowerDilationTransverse, .upperDilation:
            let byPleural = staticBody.referencePleural * staticBody.geometry.thorax[c.rawValue] / staticBody.geometry.own[c.rawValue]
            let byAbdominal = staticBody.referenceAbdominal * staticBody.geometry.abdominalCavity[c.rawValue] / staticBody.geometry.own[c.rawValue]
            passiveNote = "  (cavity pressures supply \(f(byPleural + byAbdominal, 2)) of the \(f(staticBody.stiffness[c.rawValue] * staticBody.reference[c.rawValue] / staticBody.geometry.own[c.rawValue], 2)) needed)"
        case .diaphragm:
            passiveNote = "  (active Pdi)"
        default:
            passiveNote = ""
        }
        print("   " + pad(c.label, 28) + pad(f(p, 2) + " cmH2O", 14) + passiveNote)
    }
    print("")
    let base = body.simulate(drive: drive)
    let b0 = SignedBreath.measure(base, period: drive.period)
    print("3. Simulated breath (drive waveform, lung resistance included): tidal \(f(b0.tidalVolume, 3)) L vs reference \(f(tidal, 3)) L")
    print("   signed shares upper / lower / abdomen: \(f(b0.upperShare * 100))% / \(f(b0.lowerShare * 100))% / \(f(b0.abdomenShare * 100))%"
          + "  (reference \(f(implied.upper / it * 100))% / \(f(implied.lower / it * 100))% / \(f(implied.abdomen / it * 100))%)\n")

    print("4. What-ifs (PREDICTIONS, unsourced): same muscle forces unless stated; signed contributions.")
    print("   " + pad("case", 46) + pad("tidal L", 9) + pad("upper", 9) + pad("lower", 9) + pad("abdomen", 9) + "peak Pab")
    func row(_ label: String, _ b: A2Body) {
        let sim = b.simulate(drive: drive)
        let m = SignedBreath.measure(sim, period: drive.period)
        let pab = sim.suffix(Int(drive.period / 0.002)).map(\.abdominal).max()!
        print("   " + pad(label, 46) + pad(f(m.tidalVolume, 3), 9) + pad(f(m.upperShare * 100) + "%", 9)
              + pad(f(m.lowerShare * 100) + "%", 9) + pad(f(m.abdomenShare * 100) + "%", 9) + f(pab, 2))
    }
    for c in a2Bodies(drive: drive).cases { row(c.label, c.body) }

    print("\n5. Against sources (directions; literature pass 3, reference/LITERATURE.md). Diameters at mid upper")
    print("   ribcage (z = 34 cm) and mid lower ribcage (z = 21.5 cm), change over the breath in mm:")
    var sourceFailures = 0
    for c in seatedSourceChecks(a2Bodies(drive: drive).cases, drive: drive) {
        if !c.ok { sourceFailures += 1 }
        print("   \(c.ok ? "ok  " : "MISS") \(c.detail)")
    }
    print("   (All are directions in patients; the model is a healthy seated body with muscles switched off.")
    print("   De Troyer 1986's patients breathed with neck muscles, the model's 'rib muscles' are a generic ribcage force.)")
    print(sourceFailures == 0 ? "   All \(7) source directions reproduced." : "   \(sourceFailures) source direction(s) missed.")
}

/// `breathstar a2-supine`
func runA2Supine(_ args: ArraySlice<String>) {
    let drive = Drive()
    let seated = a2Bodies(drive: drive).reference
    print("A2 supine: the seated body (calibrated on Takashima sitting) moved to supine geometry (Takashima Table 2),")
    print("at the supine operating point (FRC 0.22 L lower: diaphragm ×\(f(OperatingPoint(frcDrop: 0.22).diaphragmForceScale, 3)) per activation,")
    print("apposition zone \(f(OperatingPoint(frcDrop: 0.22).domeRise(AnatomyModel.supine()), 2)) cm taller). Two hypotheses for why rib motion falls lying down, each with the abdominal wall's")
    print("compliance, FITTED to the same healthy supine breath (Takashima: markers' implied abdominal share; 0.52 L):")
    print("  A  the bed pins the ribcage (passive stiffening; M1's contact)")
    print("  B  the rib muscles are driven less (Druz & Sharp 1981: less scalene/SCM/parasternal activity supine)")
    print("Then each PREDICTS what nothing fitted: the markers' rib motion and the patient patterns lying down.\n")
    func sig(_ b: A2Body) -> SignedBreath { SignedBreath.measure(b.simulate(drive: drive), period: drive.period) }
    var results: [(A2Body.PostureHypothesis, A2Body, Double, Double)] = []
    for h in A2Body.PostureHypothesis.allCases {
        let r = a2Supine(h, drive: drive)
        results.append((h, r.body, r.abScale, r.secondScale))
    }
    let implied = a2Supine(.ribMuscleDrive, drive: drive).implied
    print("1. Fits. Targets: abdominal share \(f(implied.abdomen * 100))%, tidal 0.52 L.")
    for (h, b, ab, x) in results {
        let m = sig(b)
        print("   \(h == .ribcageStiffness ? "A" : "B"): abdominal compliance ×\(f(ab, 2)), "
              + (h == .ribcageStiffness ? "ribcage stiffness ×\(f(x, 2))" : "rib-muscle drive ×\(f(x, 2))")
              + ";  tidal \(f(m.tidalVolume, 3)) L, upper/lower/abdomen \(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%")
    }
    print("   Upper/lower implied by Takashima's markers: \(f(implied.upper * 100))/\(f(implied.lower * 100))%; "
          + "Mendes 2020 supine men 19.5±9.8/11.5±4.4%.\n")

    print("2. Supine marker motion, mm (Takashima Table 3, supine). Abdominal markers informed the fitted share;")
    print("   rib motion is untouched by any fit. * outside SD.")
    print("   " + pad("marker", 28) + pad("motion", 9) + pad("published", 12) + pad("A", 9) + "B")
    var within = [0, 0]
    let ends = results.map { r in r.1.anatomy.observe(r.1.anatomy.a2State(r.1.endInspiration(drive: drive))) }
    for m in TakashimaMarkers.supine {
        var line = "   " + pad(m.marker, 28) + pad(m.component.rawValue, 9) + pad("\(f(m.mean, 2))±\(f(m.sd, 2))", 12)
        for (k, o) in ends.enumerated() {
            let v = m.value(o)
            let ok = abs(v - m.mean) <= m.sd
            if ok { within[k] += 1 }
            line += pad(f(v, 2) + (ok ? "" : " *"), 9)
        }
        print(line)
    }
    print("   within SD: A \(within[0])/\(TakashimaMarkers.supine.count), B \(within[1])/\(TakashimaMarkers.supine.count)\n")

    print("3. Patient patterns lying down (literature pass 3), PREDICTED by each hypothesis. Shown as signed")
    print("   shares of the breath (patients regulate breath size) and absolute; both must agree to count.")
    for chronic in [false, true] {
    print("   Patients modelled as \(chronic ? "CHRONIC (relaxed chest wall ×1.53 stiffer, Estenne 1983)" : "without chronic stiffening") "
          + "(tone \(f(seated.passive.ribcageTone, 2)) removed):")
    let sd0 = seated.asPatient(paralysed: [.ribs], chronic: chronic), sr0 = seated.asPatient(paralysed: [.diaphragm], chronic: chronic)
    let sdS = sig(sd0), srS = sig(sr0), sdLow = sd0.diameterChanges(atHeight: 21.5)
    for (h, b, _, _) in results {
        let pd = b.asPatient(paralysed: [.ribs], chronic: chronic), pr = b.asPatient(paralysed: [.diaphragm], chronic: chronic)
        let pdS = sig(pd), prS = sig(pr), pdLow = pd.diameterChanges(atHeight: 21.5)
        print("   Hypothesis \(h == .ribcageStiffness ? "A (ribcage pinned)" : "B (rib muscles driven less)"):")
        var n = 0
        func check(_ ok: Bool, _ t: String) { if ok { n += 1 }; print("     \(ok ? "ok  " : "MISS") \(t)") }
        check(pdLow.ap < 0, "Estenne 1985 supine: lower ribcage AP decreases (diaphragm only). "
              + "Model \(f(pdLow.ap * 10, 2)) mm (seated \(f(sdLow.ap * 10, 2)))")
        check(pdLow.transverse > 0, "Estenne 1985 supine: transverse still increases. Model \(f(pdLow.transverse * 10, 2)) mm")
        check(pdS.upperShare + pdS.lowerShare < sdS.upperShare + sdS.lowerShare && pdS.upper + pdS.lower < sdS.upper + sdS.lower,
              "Mortola 1978: ribcage paradox worse supine. Ribcage share \(f((pdS.upperShare + pdS.lowerShare) * 100))% "
              + "(seated \(f((sdS.upperShare + sdS.lowerShare) * 100))%); \(f((pdS.upper + pdS.lower) * 1000, 0)) mL (seated \(f((sdS.upper + sdS.lower) * 1000, 0)))")
        check(prS.abdomenShare < srS.abdomenShare && prS.abdomen < srS.abdomen,
              "Higenbottam 1977: abdominal paradox clearest lying down. Abdomen share \(f(prS.abdomenShare * 100))% "
              + "(seated \(f(srS.abdomenShare * 100))%); \(f(prS.abdomen * 1000, 0)) mL (seated \(f(srS.abdomen * 1000, 0)))")
        print("     \(n)/4 reproduced")
    }
    }
}

/// `breathstar timing`
func runTiming(_ args: ArraySlice<String>) {
    // Timing between regions: muscle groups in phase vs staggered as measured (MuscleTiming).
    let drive = Drive()
    let ti = drive.dutyCycle * drive.period
    print("Timing of the seated breath (A2). Muscle onsets relative to the diaphragm, % of inspiratory time")
    print("(\(f(ti, 2)) s). Sourced default: upper band +5%, lower band +15% (single motor units, quiet seated breathing).")
    print("Healthy reference: compartments move essentially in sync (Priori 2013, OEP: no asynchrony in controls;")
    print("motion capture: phase angles −5° to +4°).\n")
    print("  " + pad("upper/lower delay", 19) + pad("tidal", 8) + pad("shares u/l/a", 19) + pad("lag vs lung: upper/lower/abd", 30)
          + pad("ribcage–abd", 13) + pad("peaks u/l/a (s)", 19) + "checks")
    let base = a2Bodies(drive: drive).reference.timed(.inPhase, drive: drive)
    for (u, l) in [(0.0, 0.0), (0.05, 0.0), (0.0, 0.15), (0.05, 0.10), (0.05, 0.15), (0.05, 0.20), (0.10, 0.25)] {
        let body = base.timed(MuscleTiming(upperBand: u, lowerBand: l), drive: drive).matchedToTidal(0.56, drive: drive)
        let sim = body.simulate(drive: drive)
        let m = SignedBreath.measure(sim, period: drive.period), tm = BreathTiming.measure(sim, period: drive.period)
        let checks = seatedSourceChecks(a2Cases(body), drive: drive)
        print("  " + pad("+\(f(u * 100, 0))% / +\(f(l * 100, 0))%", 19) + pad(f(m.tidalVolume, 3), 8)
              + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 19)
              + pad("\(f(tm.upperLag, 1))°/\(f(tm.lowerLag, 1))°/\(f(tm.abdomenLag, 1))°", 30)
              + pad(f(tm.ribcageAbdomen, 1) + "°", 13)
              + pad("\(f(tm.peakTime.upper, 2))/\(f(tm.peakTime.lower, 2))/\(f(tm.peakTime.abdomen, 2))", 19)
              + "\(checks.filter(\.ok).count)/7")
    }
    let sb = base.timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
    let st = BreathTiming.measure(sb.simulate(drive: drive), period: drive.period)
    let order = [("upper ribcage", st.upperLag), ("lower ribcage", st.lowerLag), ("abdomen", st.abdomenLag)].sorted { $0.1 < $1.1 }
    print("\n  Each group starts later and rises faster; all release together (the inspiratory off-switch).")
    print("  Recruitment timing (+5% / +15%, the default): ribcage–abdomen \(f(st.ribcageAbdomen, 1))° (healthy: about −5° to +4°);")
    print("  order of arrival: " + order.map { "\($0.0) \(f($0.1, 1))°" }.joined(separator: ", ") + ".")
    print("  With the fixed-sign groups the lower rib-cage group's pressure is \(f(sb.forceAsPressure(A2Coordinate.lowerPump.rawValue), 2)) cmH2O, so its")
    print("  delay changes little. An illustration of the machinery, not a finding (critique 3, section 5).")
}

/// `breathstar expiration`
func runExpiration(_ args: ArraySlice<String>) {
    // Diaphragm braking (longer relaxation) and expiratory abdominal activity, swept; healthy
    // synchrony bounds them. Marker motion is end expiration → end inspiration (as markers see it).
    let drive = Drive()
    let base = a2Bodies(drive: drive).reference
    print("Expiration: diaphragm relaxation time (braking) × expiratory abdominal pressure (seated A2, sourced timing).")
    print("Neither size is sourced. Healthy synchrony (ribcage–abdomen −5° to +4°) and Takashima's 12 components bound them.\n")
    print("  " + pad("τ dia", 7) + pad("P abd", 7) + pad("shares u/l/a", 19) + pad("rc–abd", 9) + pad("lags u/l/a", 22)
          + pad("below FRC", 11) + pad("markers", 9) + "checks")
    for tau in [0.25, 0.4, 0.6] {
        for pab in [0.0, 0.5, 1.0, 2.0] {
            var b = base
            b.diaphragmRelaxation = tau == 0.25 ? nil : tau
            b.expiratoryAbdominalPressure = pab
            b = b.matchedToTidal(0.56, drive: drive)
            let sim = b.simulate(drive: drive)
            let m = SignedBreath.measure(sim, period: drive.period), tm = BreathTiming.measure(sim, period: drive.period)
            let cyc = sim.filter { $0.time > sim.last!.time - drive.period }
            let lo = cyc.min { $0.lung < $1.lung }!, hi = cyc.max { $0.lung < $1.lung }!
            let a = b.anatomy
            var o = a.observe(a.a2State(hi.q))
            let o0 = a.observe(a.a2State(lo.q))
            for (k, v) in o.markers { let w = o0.markers[k]!; o.markers[k] = (v.x - w.x, v.y - w.y, v.z - w.z) }
            let within = TakashimaMarkers.sitting.filter { abs($0.value(o) - $0.mean) <= $0.sd }.count
            var cases = a2Cases(b)
            cases = cases.map { c in var cb = c.body; cb.diaphragmRelaxation = b.diaphragmRelaxation; cb.expiratoryAbdominalPressure = pab; return (c.id, c.label, cb) }
            let checks = seatedSourceChecks(cases, drive: drive).filter(\.ok).count
            print("  " + pad(f(tau, 2) + "d", 7) + pad(f(pab, 1), 7)
                  + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 19)
                  + pad(f(tm.ribcageAbdomen, 1) + "°", 9)
                  + pad("\(f(tm.upperLag, 1))/\(f(tm.lowerLag, 1))/\(f(tm.abdomenLag, 1))°", 22)
                  + pad(f(-lo.lung * 1000, 0) + " mL", 11) + pad("\(within)/12", 9) + "\(checks)/7")
        }
    }
}

/// `breathstar expiration-bounds`
func runExpirationBounds(_ args: ArraySlice<String>) {
    // How large each unsourced mechanism can be before the seated breath leaves healthy synchrony
    // (ribcage–abdomen −5° to +4°).
    let drive = Drive()
    let base = a2Bodies(drive: drive).reference
    func angle(_ b: A2Body) -> Double { BreathTiming.measure(b.simulate(drive: drive, cycles: 3), period: drive.period).ribcageAbdomen }
    func bisect(_ lo0: Double, _ hi0: Double, _ f: (Double) -> Double, _ target: Double) -> Double {
        var lo = lo0, hi = hi0
        let rising = f(hi0) > f(lo0)
        for _ in 0..<30 { let mid = 0.5 * (lo + hi); if (f(mid) < target) == rising { lo = mid } else { hi = mid } }
        return 0.5 * (lo + hi)
    }
    let pMax = bisect(0, 3, { p in var b = base; b.expiratoryAbdominalPressure = p; return angle(b) }, 4)
    let tauMax = bisect(0.25, 1.0, { t in var b = base; b.diaphragmRelaxation = t; return angle(b) }, -5)
    print("Healthy synchrony bounds (seated, sourced onset timing, shared release 0.25 s):")
    print("  expiratory abdominal pressure ≤ \(f(pMax, 2)) cmH2O at peak (alone)")
    print("  diaphragm-only relaxation ≤ \(f(tauMax, 2)) s (alone; braking shared by all inspiratory muscles is unbounded here)")
}

/// `breathstar expiration-all`
func runExpirationAll(_ args: ArraySlice<String>) {
    // Braking in every inspiratory muscle (one longer relaxation time), with expiratory abdominals.
    print("Braking in all inspiratory muscles (shared relaxation time) × expiratory abdominal pressure:")
    print("  " + pad("τ all", 7) + pad("P abd", 7) + pad("shares u/l/a", 19) + pad("rc–abd", 9) + pad("lags u/l/a", 22) + "below FRC")
    for tau in [0.25, 0.4, 0.6] {
        var drive = Drive()
        drive.relaxationTime = tau
        let base = a2Bodies(drive: drive).reference
        for pab in [0.0, 0.5, 1.0, 2.0] {
            var b = base
            b.expiratoryAbdominalPressure = pab
            b = b.matchedToTidal(0.56, drive: drive)
            let sim = b.simulate(drive: drive)
            let m = SignedBreath.measure(sim, period: drive.period), tm = BreathTiming.measure(sim, period: drive.period)
            let lo = sim.filter { $0.time > sim.last!.time - drive.period }.min { $0.lung < $1.lung }!
            print("  " + pad(f(tau, 2), 7) + pad(f(pab, 1), 7)
                  + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 19)
                  + pad(f(tm.ribcageAbdomen, 1) + "°", 9) + pad("\(f(tm.upperLag, 1))/\(f(tm.lowerLag, 1))/\(f(tm.abdomenLag, 1))°", 22)
                  + f(-lo.lung * 1000, 0) + " mL")
        }
    }
}

/// Matrix × vector (the library's helper is internal).
func multiplyRows(_ m: [[Double]], _ v: [Double]) -> [Double] { m.map { zip($0, v).reduce(0) { $0 + $1.0 * $1.1 } } }
