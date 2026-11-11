import BreathStar
import Foundation

// CLI commands: A1 anatomy: marker fits, drawings, back body, volume and shape checks. Dispatched from main.swift.

/// `breathstar anatomy`
func runAnatomy(_ args: ArraySlice<String>) {
    // A1 fitted directly to Takashima's 8 marker motions + tidal volume (surface volumes).
    let model = AnatomyModel()
    print("A1 anatomy fitted directly to Takashima 2017 (15 young men, sitting): 8 marker motions + tidal 0.56 L.")
    print("Weighted least squares (1/SD), surface (OEP-like) volumes; the diaphragm follows from the abdomen's closure.\n")
    let fits = [("without spine extension", model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56)),
                ("with spine extension", model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56, includeExtension: true))]
    print("   " + pad("marker", 28) + pad("motion", 9) + pad("published", 12) + pad(fits[0].0, 26) + fits[1].0)
    for k in 0..<TakashimaMarkers.sitting.count {
        let ob = TakashimaMarkers.sitting[k]
        var line = "   " + pad(ob.marker, 28) + pad(ob.component.rawValue, 9) + pad("\(f(ob.mean, 2))±\(f(ob.sd, 2))", 12)
        for (_, fit) in fits {
            let v = fit.rows[k].model
            line += pad(f(v, 2) + (abs(v - ob.mean) <= ob.sd ? "" : " *"), 26)
        }
        print(line)
    }
    print("   " + pad("χ² (\(TakashimaMarkers.sitting.count) components)", 49) + pad(f(fits[0].1.chiSquared, 2), 26) + f(fits[1].1.chiSquared, 2))
    for (label, fit) in fits {
        let st = fit.state, o = model.observe(st)
        let t = o.totalSurface
        func share(_ v: [Double]) -> String { f(v.reduce(0, +) / t * 100) + "%" }
        // How much of each band's region volume comes from dilation (derived, not fitted).
        func bandShare(upper: Bool) -> Double {
            var rot = AnatomyState(), dil = AnatomyState()
            if upper { rot.upperRib = st.upperRib; dil.upperDilation = st.upperDilation }
            else { rot.lowerRib = st.lowerRib; dil.lowerDilation = st.lowerDilation; dil.lowerDilationAP = st.lowerDilationAP }
            let vr = (upper ? model.observe(rot).upperRibcage : model.observe(rot).lowerRibcage).reduce(0, +)
            let vd = (upper ? model.observe(dil).upperRibcage : model.observe(dil).lowerRibcage).reduce(0, +)
            return vd / (vr + vd)
        }
        print("\n   \(label): tidal \(f(fit.tidalVolume, 3)) L; regional split upper \(share(o.upperRibcage)), lower \(share(o.lowerRibcage)), "
              + "abdomen \(share(o.abdomen)); diaphragm \(f(st.diaphragm[0], 2)) cm")
        print("     rib rotation upper \(f(st.upperRib[0] * 100, 1))% / lower bucket \(f(st.lowerRib[0] * 100, 1))%, "
              + "lower pump \(f((st.lowerPump ?? st.lowerRib[0]) * 100, 1))% of FRC→TLC (lower front tied to the sternum); "
              + "dilation's share of band volume (derived) upper \(f(bandShare(upper: true) * 100, 0))%, lower \(f(bandShare(upper: false) * 100, 0))%")
        print("     abdomen front \(f(st.abdomenFront * 10, 2)) mm, flank \(f(st.abdomenFlank[0] * 10, 2)) mm (ratio \(f(st.abdomenFlank[0] / st.abdomenFront, 2)))"
              + (st.spineExtension != 0 ? "; spine extension \(f(st.spineExtension * 180 / .pi, 2))°" : ""))
    }
}

/// `breathstar anatomy-svg`
func runAnatomySvg(_ args: ArraySlice<String>) {
    // Animated SVG of one seated breath. Options: --magnify N (default 6), --tidal L, --still,
    // --case ID (an A2 what-if: reference, diaphragm-only, ribs-only, belly-held, hand-lower-ribs,
    // upper-chest-held).
    var magnify = 6.0, tidal = 0.56, still = false, caseID: String? = nil, supine = false, extensionDegrees = 0.0
    var it = args.dropFirst().makeIterator()
    while let flag = it.next() {
        if flag == "--still" { still = true; continue }
        if flag == "--supine" { supine = true; continue }
        if flag == "--extension" { extensionDegrees = it.next().flatMap(Double.init) ?? 0; continue }
        if flag == "--case" { caseID = it.next(); continue }
        guard let v = it.next().flatMap(Double.init) else { fail("bad value for \(flag)") }
        switch flag {
        case "--magnify": magnify = v
        case "--tidal": tidal = v
        default: fail("unknown option \(flag)")
        }
    }
    var model = AnatomyModel()
    var peak = AnatomyState()
    var title: String, subtitle: String
    var simulated: (times: [Double], states: [AnatomyState], traces: [VolumeTrace])? = nil
    if caseID != nil || supine {
        // A2: play the solver's own breath (last full cycle), its own geometry and volumes.
        let id = caseID ?? "reference"
        let cases = supine ? a2Cases(a2Supine(.ribcageStiffness).body) : a2Bodies().cases
        guard let c = cases.first(where: { $0.id == id }) else {
            fail("unknown --case \(id); try " + cases.map(\.id).joined(separator: ", "))
        }
        let drive = Drive()
        let cycle = lastCycle(c.body, drive: drive)
        model = c.body.anatomy
        simulated = (cycle.times, cycle.states, cycle.traces)
        let m = cycle.breath
        title = "Breath Star — A2 \(supine ? "supine" : "seated"): \(c.label)"
        subtitle = "Simulated (A2), drawn from the solver's own states: tidal \(f(m.tidalVolume, 2)) L; signed shares upper "
            + "\(f(m.upperShare * 100, 0))%, lower \(f(m.lowerShare * 100, 0))%, abdomen \(f(m.abdomenShare * 100, 0))%. Back fixed."
    } else {
        let ref = Reference.mendes2020(.men).seated
        peak = model.state(upperRibcage: tidal * ref.upperRibcageShare! / 100,
                           lowerRibcage: tidal * ref.lowerRibcageShare! / 100,
                           abdomen: tidal * ref.abdomenShare / 100)
        peak.spineExtension = extensionDegrees * .pi / 180
        title = "Breath Star — A1 anatomy: one quiet seated breath (\(f(tidal, 2)) L, man)"
            + (extensionDegrees != 0 ? ", with \(f(extensionDegrees, 1))° thoracic extension (hypothesis)" : "")
        subtitle = "A1 PRESCRIBED, not simulated: Mendes 2020 regional volumes mapped onto rib, diaphragm and abdominal-wall coordinates."
    }
    var svg = AnatomySVG(model: model, peak: peak, drive: Drive(), magnify: magnify,
                         title: title, subtitle: subtitle, still: still)
    svg.simulated = simulated
    print(svg.render(), terminator: "")
}

/// `breathstar extension`
func runExtension(_ args: ArraySlice<String>) {
    // Back-body hypothesis: thoracic spine extension during inspiration (Gómez-Recio et al. 2024
    // report it, minor seated, no size given). What does a small extension do?
    let m = AnatomyModel()
    print("Thoracic spine extension (pivot at the spine, \(f(m.extensionPivot, 0)) cm above the iliac crests, assumed).")
    print("Per 0.5° of extension at true scale, seated geometry:\n")
    var st = AnatomyState()
    st.spineExtension = 0.5 * .pi / 180
    let slices = m.observe(st).totalSurface
    let mesh = m.meshVolume(st, pinTopLift: true) - m.meshVolume(AnatomyState())
    print("  volume: slices \(f(slices * 1000, 1)) mL (sections only translate; they can't see it),")
    print("          mesh \(f(mesh * 1000, 1)) mL (top cut pinned; the wedge that opens at the front of the pivot)")
    print("          = \(f(mesh / 0.56 * 100, 0))% of a 0.56 L quiet breath\n")
    let o = m.observe(st)
    for name in ["anterior upper ribcage", "anterior lower ribcage", "anterior abdomen", "posterior upper ribcage"] {
        let v = o.markers[name]!
        print("  " + pad(name, 26) + "forward \(pad(f(v.y, 2), 6)) mm   up \(pad(f(v.z, 2), 6)) mm")
    }
    print("\n  The upper back moves BACKWARD (negative forward) and the front rises: the back-body motion")
    print("  a fixed spine ruled out. Takashima's seated front markers move ~2 mm forward and ~2 mm up per")
    print("  breath; extension would add lift and subtract forward motion there, so its size is bounded by")
    print("  the front-marker fit; back-marker data would pin it down directly. Not yet in A2's mechanics:")
    print("  its volume exists only in the surface (mesh) definition, pending that decision.")
}

/// `breathstar back`
func runBack(_ args: ArraySlice<String>) {
    // Back-body motion predicted by the marker-fitted breaths, and De Groote et al. 1997's direction.
    print("Back-body motion over one quiet breath, mm (A1 fitted to Takashima's markers; surface volumes).")
    print("De Groote et al. 1997 (5 seated subjects, 36 markers all round): the ribcage moves up, forward and")
    print("slightly out; the back surface moves FORWARD (ventrally), not accounted for by spinal flexion.\n")
    let names = ["posterior upper ribcage", "posterior lower ribcage", "left posterolateral lower ribcage", "posterior abdomen"]
    for (label, model, data, tidal) in [("seated", AnatomyModel(), TakashimaMarkers.sitting, 0.56),
                                        ("supine", AnatomyModel.supine(), TakashimaMarkers.supine, 0.52)] {
        let st = model.fitToMarkers(data, tidal: tidal).state
        let o = model.observe(st)
        print("  \(label):")
        for n in names {
            let v = o.markers[n]!
            print("    " + pad(n, 34) + "forward \(pad(f(v.y, 2), 6)) out \(pad(f(v.x, 2), 6)) up \(f(v.z, 2))")
        }
        if label == "seated" {
            let back = o.markers["posterior lower ribcage"]!.y
            print("    De Groote direction (back surface moves forward): \(back > 0 ? "ok" : "MISS"), \(f(back, 2)) mm "
                  + "(from ribs rotating and opening about the spine; the spine itself is fixed)")
        } else {
            print("    (supine the back rests on the bed; Takashima: the back stays symmetric against the floor)")
        }
        let base = o.posteriorLungBase.reduce(0, +), dia = o.diaphragmVolume.reduce(0, +)
        print("    Diaphragm (tilt \(f(model.diaphragmTilt, 2))): back edge descends \(f(model.diaphragmDescent(st.diaphragm[0], at: 1) * 10, 1)) mm, "
              + "front edge \(f(model.diaphragmDescent(st.diaphragm[0], at: -1) * 10, 1)) mm; the back half of the lung bases takes "
              + "\(f(base, 3)) of \(f(dia, 3)) L (\(f(100 * model.diaphragmBackShare, 0))%)")
    }
    print("\n  The back ribs widen sideways and swing forward; the back surface follows them forward by a fraction")
    print("  of a millimetre: in this model, quiet 'breathing into the back' is the posterolateral lower ribs")
    print("  moving out, up and forward, not the back moving back.")
    print("  Inside, the back of the diaphragm descends more than the front (Krayer 1989; Kolář 2009 supine")
    print("  1.4× apex): the back of the lung bases fills more. The surface can't show it; the drawing does.")
}

/// `breathstar volume-check`
func runVolumeCheck(_ args: ArraySlice<String>) {
    // The volume definitions compared, for the A2 seated and supine reference breaths at TRUE scale.
    print("Volume definitions at end inspiration, true scale, same breath:")
    print("  linear   = A2's Jacobians · q (what the solver uses; built on the surface regions)")
    print("  surface  = ring-bounded surface regions per side (the definition since 2026-11-09; OEP-like)")
    print("  slices   = fixed-height sections (the old definition; ignores vertical motion)")
    print("  mesh     = one closed surface, whole rings (a different cap at the top)\n")
    for (name, body) in [("seated", a2Bodies().reference), ("supine", a2Supine(.ribcageStiffness).body)] {
        let q = body.endInspiration()
        let a = body.anatomy, st = a.a2State(q)
        func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
        let linear = dot(body.geometry.upperRegion) + dot(body.geometry.lowerRegion) + dot(body.geometry.abdomenRegion)
        let surface = a.observe(st).totalSurface
        let slices = (0..<2).reduce(0.0) { $0 + a.sliceVolume(st, from: 0, to: a.top, side: $1) - a.sliceVolume(AnatomyState(), from: 0, to: a.top, side: $1) }
        let mesh = a.meshVolume(st) - a.meshVolume(AnatomyState())
        print("  \(pad(name, 7)) linear \(f(linear * 1000, 1))  surface \(f(surface * 1000, 1))  slices \(f(slices * 1000, 1))  mesh \(f(mesh * 1000, 1)) mL")
        print("          slices miss \(f((surface - slices) / surface * 100, 1))% of the surface volume; surface vs whole-ring mesh "
              + "\(f((mesh - surface) / surface * 100, 1))% (how the top is capped)")
    }
}

/// `breathstar abdomen-shape`
func runAbdomenShape(_ args: ArraySlice<String>) {
    // Scan the abdominal wall's two shape exponents against all 12 Takashima components per posture
    // (the 8 fitted + the 4 previously unused), refitting at each.
    print("Abdominal wall shape scan: chi² over all 12 Takashima components per posture, refitted each time.")
    print("  " + pad("bulge exp", 11) + pad("carry exp", 11) + pad("seated chi²", 13) + pad("supine chi²", 13) + pad("total", 8) + "outside SD")
    var best: (Double, Double, Double) = (0, 0, .infinity)
    for m in [1.0, 2, 3, 3.5, 4, 6] {
        for k in [1.0, 4, 8, 12, 20] {
            var total = 0.0, outside = 0
            var parts: [Double] = []
            for (base, all, tidal) in [(AnatomyModel(), TakashimaMarkers.sitting, 0.56),
                                       (AnatomyModel.supine(), TakashimaMarkers.supine, 0.52)] {
                var a = base
                a.bulgeExponent = m; a.verticalCarryExponent = k
                let o = a.observe(a.fitToMarkers(all, tidal: tidal).state)
                let chi = all.reduce(0.0) { $0 + pow(($1.value(o) - $1.mean) / $1.sd, 2) }
                outside += all.filter { abs($0.value(o) - $0.mean) > $0.sd }.count
                parts.append(chi); total += chi
            }
            if total < best.2 { best = (m, k, total) }
            print("  " + pad(f(m, 1), 11) + pad(f(k, 1), 11) + pad(f(parts[0], 2), 13) + pad(f(parts[1], 2), 13) + pad(f(total, 2), 8) + "\(outside)/24")
        }
    }
    print("  best: bulge exponent \(f(best.0, 1)), carry exponent \(f(best.1, 1)), total chi² \(f(best.2, 2)) (24 components, 7 parameters per posture)")
}

/// `breathstar lateral-drop`
func runLateralDrop(_ args: ArraySlice<String>) {
    // How far a lower rib's lateral point hangs below its bucket-handle axis (lateralDropFraction,
    // assumed 0.5): what the markers and the checks say across its plausible range.
    print("Lateral drop fraction scan (seated): A1 refitted to Takashima's markers at each value, A2 recalibrated.")
    print("  chi² = Σ((model − mean)/SD)² over the 8 markers (+ tidal); dilation must stay ≥ 0 (it is expansion).")
    print("  " + pad("fraction", 10) + pad("chi²", 8) + pad("upper dil", 11) + pad("lower dil", 11) + pad("lower bucket", 14)
          + pad("Urmey benefit", 15) + "checks")
    var jordanoglou: [(l: Double, mal: Double, malRotation: Double, mclForward: Double, chi: Double)] = []
    for l in stride(from: 0.1, through: 1.61, by: 0.1) {
        var a = AnatomyModel()
        a.lateralDropFraction = l
        let fit = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56)
        let body = A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(fit.state)).matchedToTidal(0.56)
        let checks = seatedSourceChecks(a2Cases(body))
        let d = body.silenced([.ribs]), drive = Drive()
        let up0 = SignedBreath.measure(d.simulate(drive: drive), period: drive.period).upperShare
        let up1 = SignedBreath.measure(d.stiffened([.abdomen], by: 5).simulate(drive: drive), period: drive.period).upperShare
        // Jordanoglou 1969 (supine, tidal, ribs 7–9 at the mid-axillary line): out/up ≈ 0.70, forward/total ≈ 0.8.
        var sa = AnatomyModel.supine()
        sa.lateralDropFraction = l
        let sfit = sa.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52)
        func dir(_ m: AnatomyModel, _ st: AnatomyState, _ psi: Double) -> (out: Double, up: Double, fwd: Double) {
            var o = 0.0, u = 0.0, fw = 0.0
            for z in [19.0, 21.0, 23.0] {
                let d = m.surfaceDisplacement(z: z, psiDegrees: psi, side: .left, st)
                o += d.x; u += d.z; fw += d.y
            }
            return (o, u, fw)
        }
        let mal = dir(sa, sfit.state, 90), mcl = dir(sa, sfit.state, 35)
        var rot = sfit.state; rot.upperDilation = [0, 0]; rot.lowerDilation = [0, 0]; rot.lowerDilationAP = 0
        let malRot = dir(sa, rot, 90)
        jordanoglou.append((l, mal.out / mal.up, malRot.out / malRot.up,
                            mcl.fwd / (mcl.fwd * mcl.fwd + mcl.out * mcl.out + mcl.up * mcl.up).squareRoot(), sfit.chiSquared))
        print("  " + pad(f(l, 1), 10) + pad(f(fit.chiSquared, 2), 8) + pad(f(fit.state.upperDilation[0] * 1000, 2), 11)
              + pad(f(fit.state.lowerDilation[0] * 1000, 2), 11) + pad(f(fit.state.lowerRib[0] * 180 / .pi, 2) + "°", 14)
              + pad(f((up1 - up0) * 100, 2) + " pts", 15) + "\(checks.filter(\.ok).count)/7  "
              + checks.filter { !$0.ok }.map(\.name).joined(separator: "; "))
    }
    print("\nAgainst Jordanoglou 1969 (10 young adults, supine, tidal; every point on a rib moves parallel):")
    print("  lower ribs 7–9 at the mid-axillary line, out/up = 0.67, 0.63, 0.81 (θ 56 ± 6, 56.7 ± 6, 51 ± 6°); mean ≈ 0.70.")
    print("  Model: supine A1 fitted to Takashima's supine markers, lower ribcage z 19–23 cm.")
    print("  " + pad("fraction", 10) + pad("MAL out/up", 12) + pad("rotation only", 15) + pad("MCL fwd/|S|", 13) + "supine chi²")
    for j in jordanoglou {
        print("  " + pad(f(j.l, 1), 10) + pad(f(j.mal, 2), 12) + pad(f(j.malRotation, 2), 15) + pad(f(j.mclForward, 2), 13) + f(j.chi, 2))
    }
    print("  (Takashima supine lateral lower ribcage: out/up = 0.41/1.08 = 0.38, with SD 0.44 on 'out'.)")

    // Seated markers with the lateral lower ribcage's outward motion set to Jordanoglou's direction
    // (0.70 × Takashima's 'up' 2.19 = 1.53 mm, inside Takashima's 0.96 ± 0.85).
    let jMarkers = TakashimaMarkers.sitting.map { m -> MarkerObservation in
        m.marker == "left lateral lower ribcage" && m.component == .outward
            ? MarkerObservation(marker: m.marker, component: m.component, mean: 0.70 * 2.19, sd: m.sd) : m
    }
    print("\nSeated, with the lateral lower ribcage moving in Jordanoglou's direction (outward 1.53 mm, inside Takashima's SD):")
    print("  " + pad("fraction", 10) + pad("chi²", 8) + pad("Urmey benefit", 15) + "checks")
    for l in stride(from: 0.1, through: 1.21, by: 0.1) {
        var a = AnatomyModel()
        a.lateralDropFraction = l
        let fit = a.fitToMarkers(jMarkers, tidal: 0.56)
        let body = A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(fit.state)).matchedToTidal(0.56)
        let checks = seatedSourceChecks(a2Cases(body))
        let d = body.silenced([.ribs]), drive = Drive()
        let up0 = SignedBreath.measure(d.simulate(drive: drive), period: drive.period).upperShare
        let up1 = SignedBreath.measure(d.stiffened([.abdomen], by: 5).simulate(drive: drive), period: drive.period).upperShare
        print("  " + pad(f(l, 1), 10) + pad(f(fit.chiSquared, 2), 8) + pad(f((up1 - up0) * 100, 2) + " pts", 15)
              + "\(checks.filter(\.ok).count)/7  " + checks.filter { !$0.ok }.map(\.name).joined(separator: "; "))
    }
}

/// `breathstar jordanoglou`
func runJordanoglou(_ args: ArraySlice<String>) {
    // Independent healthy reference: Jordanoglou 1969 (Thorax 24:407), 10 adults (8 M) aged 20–33,
    // supine, tidal breathing, a mechanical plunger following points on each rib. Table I: unit
    // direction components of each rib's movement (all points on a rib move parallel), forward
    // (Sg/S), outward (St/S), up (Sv/S, toward the head).
    let table: [(rib: String, z: Double, fwd: Double, out: Double, up: Double)] = [
        ("4", 36, 0.77, 0.20, 0.60), ("5", 33, 0.83, 0.26, 0.47), ("6", 30, 0.85, 0.26, 0.45),
        ("7", 25, 0.76, 0.35, 0.52), ("8", 22, 0.83, 0.29, 0.46), ("9", 19, 0.79, 0.38, 0.47),
    ]
    let a = AnatomyModel.supine()
    let st = a.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52).state
    print("Rib movement direction, supine tidal breath: Jordanoglou 1969 (Table I) against this model")
    print("(A1 fitted to Takashima's supine markers). Unit vectors; points along each rib, as he measured")
    print("(parasternal ψ 15°, mid-clavicular 35°, anterior axillary 60°, mid-axillary 90°). Rib heights ASSUMED.\n")
    print("  " + pad("rib", 5) + pad("measured fwd/out/up", 22) + pad("model ψ 15", 18) + pad("ψ 35", 18) + pad("ψ 60", 18) + "ψ 90")
    var angles: [Double] = []
    for r in table {
        var cols: [String] = []
        for psi in [15.0, 35, 60, 90] {
            let d = a.surfaceDisplacement(z: r.z, psiDegrees: psi, side: .left, st)
            let n = (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
            let (fw, ou, upv) = (d.y / n, d.x / n, d.z / n)
            cols.append("\(f(fw, 2))/\(f(ou, 2))/\(f(upv, 2))")
            angles.append(acos(min(1, fw * r.fwd + ou * r.out + upv * r.up)) * 180 / .pi)
        }
        print("  " + pad(r.rib, 5) + pad("\(f(r.fwd, 2))/\(f(r.out, 2))/\(f(r.up, 2))", 22)
              + cols.map { pad($0, 18) }.joined())
    }
    let mean = angles.reduce(0, +) / Double(angles.count)
    print("\n  Angle between model and measured directions: mean \(f(mean, 0))°, max \(f(angles.max()!, 0))°.")
    print("  (Jordanoglou's own spread: θ ± 5–10°, φ ± 3–10°.) Lower ribs now move nearly parallel along their")
    print("  length (pump carries the rib's sag); upper ribs still turn from forward-and-up at the sternum to")
    print("  out-and-up at the side, and every rib moves more upward than he measured (Takashima's data do too).")
}
