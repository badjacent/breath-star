import BreathStar
import Foundation

// Visible uncertainty (critique 2, §1): one representative body plus equally plausible
// alternatives. Each alternative redraws every ASSUMED number within a stated range and the
// published marker means within their standard error, refits A1 to those markers, recalibrates
// A2, and re-runs every check. A conclusion that changes across them is not settled.

/// Reproducible pseudo-random numbers (SplitMix64).
struct SplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func uniform(_ r: ClosedRange<Double>) -> Double {
        r.lowerBound + Double(next() >> 11) / Double(1 << 53) * (r.upperBound - r.lowerBound)
    }
    mutating func logUniform(_ r: ClosedRange<Double>) -> Double { exp(uniform(log(r.lowerBound)...log(r.upperBound))) }
    mutating func normal() -> Double {
        let u1 = max(uniform(0...1), 1e-12), u2 = uniform(0...1)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// What is varied, and over what range. Ranges are judgement: roughly "as wrong as the
/// assumption could plausibly be" (sourced numbers get narrower ranges).
let uncertaintyRanges: [(name: String, range: String)] = [
    ("rib drops (upper, lower)", "8–12, 10–14 cm (assumed 10, 12)"),
    ("lateral drop fraction", "0.3–1.0 (assumed 0.5; textbook estimate 0.3–1.0)"),
    ("diaphragm piston area fraction", "0.5–0.7 (assumed 0.6)"),
    ("costal margin, xiphoid heights", "17–19, 24–26 cm (assumed 18, 25)"),
    ("upper-ribcage width", "28–32 cm (assumed 30)"),
    ("Wilson rib angles", "each ×0.85–1.15 (sourced, 2 men, FRC→TLC)"),
    ("lung-edge (apposition) height", "±1 cm (rib levels textbook, heights assumed)"),
    ("diaphragm tilt, seated", "0.1–0.3 (assumed 0.2)"),
    ("ribcage, abdomen compliance", "0.08–0.14, 0.07–0.12 L/cmH2O (textbook splits)"),
    ("sternal coupling", "1–30, log-uniform (assumed 10; Kouyama 2016 hints weaker)"),
    ("stiffness basis", "ribcage / chest wall, equally (own compartment ruled out: basis-test)"),
    ("Takashima marker means", "± standard error (SD/√15), normal"),
]

struct Alternative {
    var anatomy: AnatomyModel
    var passive: A2Passive
    var markers: [MarkerObservation]
    /// The drawn values, normalised to 0…1 over their ranges (markers: standard normal), by name.
    var drawn: [(name: String, value: Double)] = []
}

func alternatives(count: Int, seed: UInt64) -> [Alternative] {
    var rng = SplitMix(state: seed)
    return (0..<count).map { _ in
        var a = AnatomyModel()
        a.upperRibDrop = rng.uniform(8...12)
        a.lowerRibDrop = rng.uniform(10...14)
        a.lateralDropFraction = rng.uniform(0.3...1.0)
        a.domeAreaFraction = rng.uniform(0.5...0.7)
        a.costalMargin = rng.uniform(17...19)
        a.xiphoid = rng.uniform(24...26)
        a.profile[3].width = rng.uniform(28...32)
        a.upperPumpDegrees *= rng.uniform(0.85...1.15)
        a.upperBucketDegrees *= rng.uniform(0.85...1.15)
        a.lowerPumpDegrees *= rng.uniform(0.85...1.15)
        a.lowerBucketDegrees *= rng.uniform(0.85...1.15)
        a.appositionShift = rng.uniform(-1...1)
        a.diaphragmTilt = rng.uniform(0.1...0.3)
        var p = A2Passive()
        p.ribcageCompliance = rng.uniform(0.08...0.14)
        p.abdomenCompliance = rng.uniform(0.07...0.12)
        p.sternalCoupling = rng.logUniform(1...30)
        // The stiffness basis, a structural choice (critique 3, sections 3 and 6). "Own compartment" is ruled
        // out by data (`basis-test`: Takashima's seated markers χ² 14–16, a negative supine abdominal share,
        // absurd Kouyama predictions); ribcage and chest wall both survive, drawn equally.
        let bases: [A2Passive.StiffnessBasis] = [.ribcage, .chestWall]
        let basisIndex = min(1, Int(rng.uniform(0...2)))
        p.stiffnessBasis = bases[basisIndex]
        let z = TakashimaMarkers.sitting.map { _ in rng.normal() }
        let markers = zip(TakashimaMarkers.sitting, z).map { m, zi in
            MarkerObservation(marker: m.marker, component: m.component,
                              mean: m.mean + m.sd / 15.0.squareRoot() * zi, sd: m.sd)
        }
        let d = AnatomyModel()
        var drawn: [(name: String, value: Double)] = []
        drawn.append(("upper rib drop", (a.upperRibDrop - 8) / 4))
        drawn.append(("lower rib drop", (a.lowerRibDrop - 10) / 4))
        drawn.append(("lateral drop fraction", (a.lateralDropFraction - 0.3) / 0.7))
        drawn.append(("piston area fraction", (a.domeAreaFraction - 0.5) / 0.2))
        drawn.append(("costal margin height", (a.costalMargin - 17) / 2))
        drawn.append(("xiphoid height", (a.xiphoid - 24) / 2))
        drawn.append(("upper-ribcage width", (a.profile[3].width - 28) / 4))
        drawn.append(("upper pump angle", (a.upperPumpDegrees / d.upperPumpDegrees - 0.85) / 0.3))
        drawn.append(("upper bucket angle", (a.upperBucketDegrees / d.upperBucketDegrees - 0.85) / 0.3))
        drawn.append(("lower pump angle", (a.lowerPumpDegrees / d.lowerPumpDegrees - 0.85) / 0.3))
        drawn.append(("lower bucket angle", (a.lowerBucketDegrees / d.lowerBucketDegrees - 0.85) / 0.3))
        drawn.append(("lung-edge height", (a.appositionShift + 1) / 2))
        drawn.append(("diaphragm tilt", (a.diaphragmTilt - 0.1) / 0.2))
        drawn.append(("ribcage compliance", (p.ribcageCompliance - 0.08) / 0.06))
        drawn.append(("abdomen compliance", (p.abdomenCompliance - 0.07) / 0.05))
        drawn.append(("sternal coupling", log(p.sternalCoupling) / log(30)))
        drawn.append(("stiffness basis (ribcage → chest wall)", Double(basisIndex)))
        for (m, zi) in zip(TakashimaMarkers.sitting, z) {
            drawn.append(("marker: \(m.marker) \(m.component.rawValue)", 0.5 + zi / 4))  // ±2 SE spans 0…1
        }
        return Alternative(anatomy: a, passive: p, markers: markers, drawn: drawn)
    }
}

/// The seated source checks (literature pass 3), as (short name, ok, detail).
func seatedSourceChecks(_ cases: [(id: String, label: String, body: A2Body)], drive: Drive = Drive())
    -> [(name: String, ok: Bool, detail: String)] {
    func body(_ id: String) -> A2Body { cases.first { $0.id == id }!.body }
    func dia(_ id: String, _ z: Double) -> (ap: Double, transverse: Double) { body(id).diameterChanges(atHeight: z, drive: drive) }
    func signed(_ b: A2Body) -> SignedBreath { SignedBreath.measure(b.simulate(drive: drive), period: drive.period) }
    let dOnly = signed(body("diaphragm-only"))
    let dUp = dia("diaphragm-only", 34), dLow = dia("diaphragm-only", 21.5)
    let comp = signed(body("diaphragm-only").stiffened([.abdomen], by: 5))
    let rUp = dia("ribs-only", 34), rLow = dia("ribs-only", 21.5)
    let rOnly = signed(body("ribs-only"))
    return [
        ("Estenne: lower > upper (diaphragm only)", dOnly.lower > dOnly.upper,
         "Estenne & De Troyer 1985 (20 tetraplegics, seated): lower ribcage expands more than upper. "
         + "Model, diaphragm only: lower \(f(dOnly.lower * 1000, 0)) mL, upper \(f(dOnly.upper * 1000, 0)) mL"),
        ("Estenne: upper AP paradox", dUp.ap < 0,
         "Estenne & De Troyer 1985: upper ribcage AP moves paradoxically inward (11/20; 7/8 with silent scalenes). "
         + "Model: upper AP \(f(dUp.ap * 10, 2)) mm"),
        ("Estenne: lower transverse > AP", dLow.transverse > dLow.ap,
         "Estenne & De Troyer 1985: lower ribcage expands more transversely than AP. "
         + "Model: transverse \(f(dLow.transverse * 10, 2)) mm, AP \(f(dLow.ap * 10, 2)) mm"),
        ("Mortola: lower ok, upper paradox", dLow.transverse > 0 && dUp.ap < 0,
         "Mortola & Sant'Ambrogio 1978 (seated): lower ribcage paradox gone, upper still present. "
         + "Model: lower transverse \(f(dLow.transverse * 10, 2)) mm, upper AP \(f(dUp.ap * 10, 2)) mm"),
        ("Urmey: belly compression helps", comp.upperShare > dOnly.upperShare,
         "Urmey et al. 1986 (quadriplegics): abdominal compression reduces ribcage distortion. "
         + "Model, diaphragm only + belly 5× stiffer: upper share \(f(dOnly.upperShare * 100))% → \(f(comp.upperShare * 100))%"),
        ("De Troyer: neck muscles only", rUp.ap > 0 && rLow.transverse < 0,
         "De Troyer et al. 1986 (high tetraplegics, neck muscles only): upper ribcage AP expands, lower ribcage "
         + "lateral walls move in. Model, rib muscles only: upper AP \(f(rUp.ap * 10, 2)) mm, lower transverse \(f(rLow.transverse * 10, 2)) mm"),
        ("Higenbottam: belly in (no diaphragm)", rOnly.abdomen < 0,
         "Higenbottam et al. 1977 (bilateral diaphragm palsy): front abdominal wall moves inward on inspiration. "
         + "Model, rib muscles only: abdomen \(f(rOnly.abdomen * 1000, 0)) mL"),
    ]
}

/// Everything one alternative body says.
struct Outcome {
    var alternative: Alternative
    var fit: MarkerFit
    var body: A2Body
    var withinSD: Int
    var shares: SignedBreath
    var diaphragmOnly: SignedBreath
    var markers: [String: (x: Double, y: Double, z: Double)]
    var checks: [(name: String, ok: Bool, detail: String)]
    var endInspiration: AnatomyState
}

func evaluate(_ alt: Alternative, drive: Drive = Drive()) -> Outcome? {
    let tidal = 0.56
    let fit = alt.anatomy.fitToMarkers(alt.markers, tidal: tidal)
    // Judged against the PUBLISHED markers, not the redrawn ones.
    let o = alt.anatomy.observe(fit.state)
    let within = TakashimaMarkers.sitting.filter { abs($0.value(o) - $0.mean) <= $0.sd }.count
    // A2 as the default seated body is built (fixed-sign muscle groups fitted to this variant's markers),
    // or free forces with --free-forces.
    let staticBody = CommandLine.arguments.contains("--free-forces")
        ? A2Body.calibrate(anatomy: alt.anatomy, reference: alt.anatomy.a2Coordinates(fit.state), passive: alt.passive)
        : A2Body.fitMuscleGroups(anatomy: alt.anatomy, markers: alt.markers, tidal: tidal, passive: alt.passive,
                                 lowerBandStiffness: A2MuscleGroup.lowerBandStiffness).body
    let body = staticBody.timed(MuscleTiming(), drive: drive).matchedToTidal(tidal, drive: drive)
    let shares = SignedBreath.measure(body.simulate(drive: drive), period: drive.period)
    guard shares.tidalVolume.isFinite, abs(shares.tidalVolume - tidal) < 0.05 else { return nil }
    let cases = a2Cases(body)
    let dOnly = SignedBreath.measure(cases.first { $0.id == "diaphragm-only" }!.body.simulate(drive: drive), period: drive.period)
    let end = alt.anatomy.a2State(body.endInspiration(drive: drive))
    return Outcome(alternative: alt, fit: fit, body: body, withinSD: within, shares: shares, diaphragmOnly: dOnly,
                   markers: alt.anatomy.observe(end).markers, checks: seatedSourceChecks(cases, drive: drive),
                   endInspiration: end)
}

func percentile(_ xs: [Double], _ p: Double) -> Double {
    let s = xs.sorted()
    guard !s.isEmpty else { return .nan }
    let i = p * Double(s.count - 1)
    let lo = Int(i.rounded(.down)), hi = min(lo + 1, s.count - 1)
    return s[lo] + (i - Double(lo)) * (s[hi] - s[lo])
}

func uncertaintyReport(count: Int, seed: UInt64) -> [Outcome] {
    print("Visible uncertainty: \(count) variants of the seated model (seed \(seed)) beside the reference.")
    print("Each redraws the assumed numbers and the published marker means, refits A1 to the markers,")
    print("recalibrates A2 and re-runs every check. Varied:")
    for r in uncertaintyRanges { print("  " + pad(r.name, 34) + r.range) }
    // Not varied here (structural choices, reported separately): the stiffness basis, the
    // two-band/eight-coordinate structure, the fixed spine, tidal volume 0.56 L.
    print("  Not varied: the muscle-group mapping, the lower band's ×2 stiffness, the 8-coordinate structure,")
    print("  the fixed spine, the tidal volume.\n")

    guard let ref = evaluate(Alternative(anatomy: AnatomyModel(), passive: A2MuscleGroup.defaultPassive, markers: TakashimaMarkers.sitting)) else {
        fail("reference body failed")
    }
    let alts = alternatives(count: count, seed: seed)
    let outs = alts.compactMap { evaluate($0) }
    let n = outs.count
    if n < count { print("  (\(count - n) alternatives failed to match the tidal volume and are dropped.)\n") }

    func verdict(_ k: Int) -> String {
        let fr = Double(k) / Double(n)
        // "robust": holds across ≥ 90% of these variants. Robustness to the varied assumptions, not a probability,
        // and not robustness to the structural choices left out (critique 3, section 6).
        return fr >= 0.9 ? "robust" : fr >= 0.6 ? "leaning" : fr > 0.4 ? "UNSETTLED" : fr > 0.1 ? "leaning against" : "robust against"
    }
    /// For a conclusion that isn't settled: the drawn number whose mean differs most between the
    /// bodies where it holds and where it fails (in units of its range), with the direction.
    func driver(_ ok: (Outcome) -> Bool) -> String {
        let holds = outs.filter(ok), fails = outs.filter { !ok($0) }
        guard !holds.isEmpty, !fails.isEmpty else { return "" }
        let names = outs[0].alternative.drawn.map(\.name)
        let diffs = names.indices.map { i -> (String, Double) in
            let a = holds.map { $0.alternative.drawn[i].value }.reduce(0, +) / Double(holds.count)
            let b = fails.map { $0.alternative.drawn[i].value }.reduce(0, +) / Double(fails.count)
            return (names[i], a - b)
        }.sorted { abs($0.1) > abs($1.1) }
        return diffs.prefix(2).map { "\($0.0) \($0.1 > 0 ? "high" : "low") (\(f(abs($0.1), 2)))" }.joined(separator: "; ")
    }
    var drivers: [(String, String)] = []
    func yes(_ label: String, _ refOK: Bool, _ ok: (Outcome) -> Bool) {
        let k = outs.filter(ok).count
        print("  " + pad(label, 52) + pad("\(k)/\(n)", 8) + pad(verdict(k), 17) + "reference: \(refOK ? "yes" : "no")")
        if verdict(k) != "robust" && verdict(k) != "robust against" { drivers.append((label, driver(ok))) }
    }
    func range(_ label: String, _ unit: String, _ scale: Double = 1, _ digits: Int = 1, _ v: (Outcome) -> Double) {
        let xs = outs.map(v).map { $0 * scale }
        print("  " + pad(label, 52) + pad("\(f(percentile(xs, 0.05), digits)) to \(f(percentile(xs, 0.95), digits)) \(unit)", 26)
              + "reference: \(f(v(ref) * scale, digits))")
    }

    print("Conclusions (fraction of variants where it holds; robust ≥ 90%: robust to the varied assumptions only;")
    print("the muscle-group mapping and the lower band's ×2 stiffness are not varied; the stiffness basis now is):")
    print("  A1 / the healthy breath")
    let nm = TakashimaMarkers.sitting.count
    // A weak test: each variant's marker means are redrawn by one standard error and refitted, then judged
    // against a full SD. The χ² against the standard error (the yardstick for a model of the mean body) is stricter.
    yes("all \(nm) Takashima components within SD (weak test)", ref.withinSD == nm) { $0.withinSD == nm }
    let se = (15.0).squareRoot()
    func chiSE(_ o: Outcome) -> Double {
        let obs = o.alternative.anatomy.observe(o.fit.state)
        return TakashimaMarkers.sitting.reduce(0.0) { $0 + pow(($1.value(obs) - $1.mean) / ($1.sd / se), 2) }
    }
    range("χ² against the standard error (\(nm) components)", "", 1, 1) { chiSE($0) }
    yes("flanks draw in while the front bulges", ref.fit.state.abdomenFlank[0] < 0) { $0.fit.state.abdomenFlank[0] < 0 && $0.fit.state.abdomenFront > 0 }
    range("diaphragm descent (piston mean)", "cm", 1, 2) { $0.fit.state.diaphragm[0] }
    range("upper dilation (fitted)", "×10⁻³", 1000, 1) { $0.fit.state.upperDilation[0] }
    range("lower dilation (fitted)", "×10⁻³", 1000, 1) { $0.fit.state.lowerDilation[0] }
    yes("dilation larger than zero in both bands", ref.fit.state.upperDilation[0] > 0 && ref.fit.state.lowerDilation[0] > 0) {
        $0.fit.state.upperDilation[0] > 0 && $0.fit.state.lowerDilation[0] > 0
    }
    print("  A2 / the simulated breath (signed shares)")
    range("upper ribcage share", "%", 100, 1) { $0.shares.upperShare }
    range("lower ribcage share", "%", 100, 1) { $0.shares.lowerShare }
    range("abdomen share", "%", 100, 1) { $0.shares.abdomenShare }
    yes("abdomen takes most of the breath", ref.shares.abdomenShare > 0.5) { $0.shares.abdomenShare > 0.5 }
    yes("diaphragm only: the upper chest sinks", ref.diaphragmOnly.upperShare < 0) { $0.diaphragmOnly.upperShare < 0 }
    print("  Back body")
    let pl = "left posterolateral lower ribcage", pb = "posterior lower ribcage"
    yes("posterolateral lower ribs move out and up", ref.markers[pl]!.x > 0 && ref.markers[pl]!.z > 0) {
        $0.markers[pl]!.x > 0 && $0.markers[pl]!.z > 0
    }
    range("  …outward", "mm", 1, 2) { $0.markers[pl]!.x }
    yes("back surface moves forward (De Groote 1997)", ref.markers[pb]!.y > 0) { $0.markers[pb]!.y > 0 }
    range("  …forward", "mm", 1, 3) { $0.markers[pb]!.y }
    print("  Holds (wall motion, not shares; hand on lower ribs = lower band 5× stiffer)")
    func holdEffect(_ o: Outcome) -> (sideRatio: Double, bellyMatchedGain: Double) {
        let d = Drive()
        let ref = wallRegions(o.body, drive: d)
        let held = o.body.stiffened(A2Coordinate.lowerBand, by: 5)
        let same = wallRegions(held, drive: d)
        let tidal = SignedBreath.measure(o.body.simulate(drive: d), period: d.period).tidalVolume
        let matched = wallRegions(held.matchedToTidal(tidal, drive: d), drive: d)
        let side = ref.first { $0.name == "lower side" }!.mm, belly = ref.first { $0.name == "belly front" }!.mm
        // Differences in mm (ratios blow up where the unheld motion is near zero).
        return (same.first { $0.name == "lower side" }!.mm - side, matched.first { $0.name == "belly front" }!.mm - belly)
    }
    let refHold = holdEffect(ref)
    let holdsAll = outs.map(holdEffect)
    print("  " + pad("hand: lower side wall moves less (same drive)", 52)
          + pad("\(holdsAll.filter { $0.sideRatio < 0 }.count)/\(n)", 8) + pad(verdict(holdsAll.filter { $0.sideRatio < 0 }.count), 17)
          + "reference: \(f(refHold.sideRatio, 2)) mm")
    let diffs = holdsAll.map(\.sideRatio)
    print("  " + pad("  …change in its motion", 52) + pad("\(f(percentile(diffs, 0.05), 2)) to \(f(percentile(diffs, 0.95), 2)) mm", 26))
    print("  " + pad("hand, matched size: belly front moves more", 52)
          + pad("\(holdsAll.filter { $0.bellyMatchedGain > 0 }.count)/\(n)", 8) + pad(verdict(holdsAll.filter { $0.bellyMatchedGain > 0 }.count), 17)
          + "reference: +\(f(refHold.bellyMatchedGain, 2)) mm")
    print("  Patient directions (seated)")
    for (i, c) in ref.checks.enumerated() { yes(c.name, c.ok) { $0.checks[i].ok } }
    let all7 = outs.filter { $0.checks.allSatisfy(\.ok) }.count
    print("  " + pad("all 7 together", 52) + pad("\(all7)/\(n)", 8) + verdict(all7))
    drivers.append(("all 7 together", driver { $0.checks.allSatisfy(\.ok) }))
    if !CommandLine.arguments.contains("--free-forces") {
        // Fixed-sign groups: each pressure is ≥ 0 by construction; report how often a group is active and its range.
        print("  Muscle groups (pressures ≥ 0 by construction, cmH2O, after matching to 0.56 L)")
        for (g, c) in [(A2MuscleGroup.diaphragm, A2Coordinate.diaphragm), (.upperRibcage, .upperRotation), (.lowerRibcage, .lowerPump)] {
            let ps = outs.map { $0.body.forceAsPressure(c.rawValue) }
            let active = ps.filter { $0 > 1e-6 }.count
            print("  " + pad("  " + g.label, 52) + pad("active \(active)/\(n)", 14)
                  + "\(f(percentile(ps, 0.05), 2)) to \(f(percentile(ps, 0.95), 2))   reference: \(f(ref.body.forceAsPressure(c.rawValue), 2))")
        }
    } else {
    print("  Effective drives (signs of the forces calibration needs; not muscle identities)")
    for c in A2Coordinate.allCases {
        let pos = outs.filter { $0.body.peakForce[c.rawValue] > 1e-12 }.count
        let zero = outs.filter { abs($0.body.peakForce[c.rawValue]) <= 1e-12 }.count
        let r = ref.body.peakForce[c.rawValue]
        if zero == n {
            // Set to zero by the calibration (the abdominal muscles are relaxed by assumption): not a finding.
            print("  " + pad("  " + c.label, 52) + pad("0 \(n)/\(n)", 8) + "zero by construction (relaxed by assumption)")
            continue
        }
        print("  " + pad("  " + c.label, 52) + pad("+ \(pos)/\(n)", 8) + pad(verdict(max(pos, n - pos)) == "robust" ? "robust" : "UNSETTLED", 17)
              + "reference: \(r > 1e-12 ? "+" : r < -1e-12 ? "−" : "0")")
    }
    }
    if !drivers.isEmpty {
        print("\nWhat decides the unsettled ones (the drawn numbers that differ most between bodies where it")
        print("holds and where it fails; difference of means in units of the range; \"high\" = holds when high):")
        for (label, d) in drivers { print("  " + pad(label, 44) + d) }
    }
    return [ref] + outs
}

/// The last full cycle of an A2 simulation, about 48 frames: times from 0, the solver's own
/// states and volumes, and the signed breath.
func lastCycle(_ body: A2Body, drive: Drive, timeStep dt: Double = 0.002)
    -> (times: [Double], states: [AnatomyState], traces: [VolumeTrace], breath: SignedBreath) {
    let sim = body.simulate(drive: drive, timeStep: dt)
    let perCycle = Int((drive.period / dt).rounded())
    let last = Array(sim.suffix(perCycle))
    let step = max(1, last.count / 48)
    let picked = stride(from: 0, to: last.count, by: step).map { last[$0] }
    let t0 = picked[0].time
    return (picked.map { $0.time - t0 }, picked.map { body.anatomy.a2State($0.q) },
            picked.map { VolumeTrace(lung: $0.lung, upper: $0.upperRegion, lower: $0.lowerRegion, abdomen: $0.abdomenRegion) },
            SignedBreath.measure(sim, period: drive.period))
}
