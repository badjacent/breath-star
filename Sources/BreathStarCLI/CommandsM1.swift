import BreathStar
import Foundation

// CLI commands: M1 lumped model. Dispatched from main.swift.

/// `breathstar check`
func runCheck(_ args: ArraySlice<String>) {
    var failures = 0
    print("Each dataset is fitted on seated (shares, tidal volume) and supine (abdomen share, tidal volume).")
    print("Everything else is predicted. Gated: outside the published SD fails; sources without SDs are reported only.\n")
    print(pad("dataset", 19) + pad("posture", 10) + pad("upper rc % pub/model", 22) + pad("lower rc % pub/model", 22)
          + pad("abdomen % pub/model", 22) + pad("tidal L pub/model", 20) + "verdict")
    for data in Reference.datasets {
        let fit = Calibration.fit(data)
        var model: [String: Double] = [:]
        for (name, posture) in Reference.mendesPostures {
            let ref = data.point(name)
            let d = fit.distribution(posture)
            model[name] = d.abdomenShare * 100
            // Predicted and gated where SDs exist: everything at 45°, the ribcage split at supine.
            var gated: [(Double, Double?, Double?)] = []
            if name == "incline45" {
                gated = [(d.abdomenShare * 100, ref.abdomenShare, ref.abdomenSD),
                         (d.tidalVolume, ref.tidalVolume, ref.tidalSD)]
            }
            if name != "seated" {
                gated += [(d.upperRibcageShare * 100, ref.upperRibcageShare, ref.upperRibcageSD),
                          (d.lowerRibcageShare * 100, ref.lowerRibcageShare, ref.lowerRibcageSD)]
            }
            let checkable = gated.compactMap { m, mean, sd in mean.flatMap { mean in sd.map { (m, mean, $0) } } }
            var verdict = name == "seated" ? "fit" : name == "supine" ? "fit abdomen+tidal; split" : "PREDICT"
            if !checkable.isEmpty {
                let ok = checkable.allSatisfy { abs($0.0 - $0.1) <= $0.2 }
                if !ok { failures += 1 }
                verdict += ok ? " within SD" : " OUTSIDE SD"
            } else if name != "seated" {
                verdict += " (no SD)"
            }
            print(pad(data.id, 19) + pad(name, 10)
                  + pad("\(pm(ref.upperRibcageShare, ref.upperRibcageSD, 1)) / \(f(d.upperRibcageShare * 100))", 22)
                  + pad("\(pm(ref.lowerRibcageShare, ref.lowerRibcageSD, 1)) / \(f(d.lowerRibcageShare * 100))", 22)
                  + pad("\(pm(ref.abdomenShare, ref.abdomenSD, 1)) / \(f(d.abdomenShare * 100))", 22)
                  + pad("\(pm(ref.tidalVolume, ref.tidalSD, 2)) / \(f(d.tidalVolume, 2))", 20)
                  + verdict)
        }
        let fraction = (model["incline45"]! - model["seated"]!) / (model["supine"]! - model["seated"]!)
        print("  → 45° sits \(f(data.fractionAt45, 2)) of the way from seated to supine in the data, \(f(fraction, 2)) in the model\n")
    }

    print("Side-lying (right side down), Mendes men calibration. Sources: Nozoe 2014 (abstract), Takashima 2017 (table).")
    let fit = Calibration.fit(.men)
    let supine = fit.distribution(.supine)
    let side = fit.distribution(.rightSideLying)
    let down = Side.right.rawValue, up = Side.left.rawValue
    func checkLine(_ label: String, _ ok: Bool, _ detail: String) {
        if !ok { failures += 1 }
        print("  \(ok ? "ok  " : "FAIL") \(label): \(detail)")
    }
    checkLine("supine is left/right symmetric (Nozoe)",
              abs(supine.surfaceExcursion[0] - supine.surfaceExcursion[1]) < 1e-9,
              "surface L \(f(supine.surfaceExcursion[0], 3)) / R \(f(supine.surfaceExcursion[1], 3)) L")
    checkLine("down side's surface moves less (Nozoe)",
              side.surfaceExcursion[down] < side.surfaceExcursion[up],
              "down \(f(side.surfaceExcursion[down], 3)) vs up \(f(side.surfaceExcursion[up], 3)) L")
    checkLine("up side's lower ribcage moves more than supine (Takashima)",
              side.lowerRibcageExcursionBySide[up] > supine.lowerRibcageExcursionBySide[up],
              "\(f(side.lowerRibcageExcursionBySide[up] * 1000, 0)) vs \(f(supine.lowerRibcageExcursionBySide[up] * 1000, 0)) mL")
    print("  info tidal volume, supine \(f(supine.tidalVolume, 2)) L, side-lying \(f(side.tidalVolume, 2)) L "
          + "(Takashima: 0.52 and 0.51, no posture effect)")

    print("\n  Which lung takes more air side-lying? (Kaneko 1966 says the down lung; not yet verified, so not gated.)")
    print("  It depends on how much more force the down hemidiaphragm makes, which no source here gives:")
    for gain in [0.0, 0.25, 0.5, 1.0] {
        var body = fit.body
        body.dependentDiaphragmGain = gain
        let d = Metrics.distribution(body: body, drive: fit.drive, posture: .rightSideLying)
        let share = d.lungExcursion[down] / (d.lungExcursion[down] + d.lungExcursion[up]) * 100
        print("    down-diaphragm gain \(f(gain, 2)): down lung \(f(share))% of ventilation, "
              + "down surface \(f(d.surfaceExcursion[down] / (d.surfaceExcursion[down] + d.surfaceExcursion[up]) * 100))% of surface motion")
    }

    print(failures == 0 ? "\nPASS: gated predictions within SD, sourced side-lying directions right."
                        : "\nFAIL: \(failures) check(s) failed.")
    exit(failures == 0 ? 0 : 1)
}

/// `breathstar params`
func runParams(_ args: ArraySlice<String>) {
    let o = parse(args.dropFirst())
    let r = Calibration.fit(o.sex)
    let b = r.body
    print("dataset: mendes2020-\(o.sex.rawValue)")
    print("lungCompliance             \(f(b.lungCompliance, 3)) L/cmH2O    (textbook; split equally per lung)")
    print("resistance                 \(f(b.resistance, 2)) cmH2O·s/L  (textbook)")
    print("ribcageCompliance (free)   \(f(b.ribcageCompliance, 3)) L/cmH2O    (textbook)")
    print("appositionFraction         \(f(b.appositionFraction, 2))              (fixed, lower ribcage)")
    print("upperRibcageFraction       \(f(b.upperRibcageFraction, 3))             (fit: seated upper-ribcage share)")
    print("diaphragmPeak              \(f(r.drive.diaphragmPeak, 2)) cmH2O      (fit: seated tidal volume)")
    print("ribcageMusclePeak          \(f(r.drive.ribcageMusclePeak, 2)) cmH2O      (fit: seated tidal volume, ratio fixed)")
    print("abdomenComplianceLying     \(f(b.abdomenComplianceLying, 4)) L/cmH2O   (fit: supine abdomen share + tidal volume)")
    print("contactStiffening          \(f(b.contactStiffening, 3))             (fit: supine abdomen share + tidal volume)")
    print("uprightAbdominalStiffening \(f(b.uprightAbdominalStiffening, 3))             (fit: seated abdomen share)")
    print("dependentDiaphragmGain     \(f(b.dependentDiaphragmGain, 2))              (not fitted; no source)")
}

/// `breathstar render`
func runRender(_ args: ArraySlice<String>) {
    let o = parse(args.dropFirst())
    let fit = Calibration.fit(o.sex)
    var drive = fit.drive
    drive.rate = o.rate
    var body = fit.body
    if let g = o.diaphragmGain { body.dependentDiaphragmGain = g }
    let samples = Simulation(body: body, drive: drive, posture: o.posture, timeStep: o.dt).run(cycles: o.cycles)
    let flow = [0] + flows(samples)
    print("t,activation,pdi,prc,ppl,pab,vl,vrc,vab,flow,"
          + "vl_l,vl_r,ppl_l,ppl_r,vrcp_l,vrcp_r,vrca_l,vrca_r,vab_l,vab_r,vdi_l,vdi_r")
    for (s, q) in zip(samples, flow) {
        let values: [Double] = [
            s.time, s.activation, s.diaphragmPressure, s.ribcageMusclePressure,
            s.pleuralPressure, s.abdominalPressure, s.lungVolume, s.ribcageVolume, s.abdomenVolume, q,
            s.left.lungVolume, s.right.lungVolume, s.left.pleuralPressure, s.right.pleuralPressure,
            s.left.upperRibcageVolume, s.right.upperRibcageVolume,
            s.left.lowerRibcageVolume, s.right.lowerRibcageVolume,
            s.left.abdomenVolume, s.right.abdomenVolume, s.left.diaphragmDescent, s.right.diaphragmDescent,
        ]
        print(values.map { String(format: "%.5f", $0) }.joined(separator: ","))
    }
}
