import BreathStar
import Foundation

// CLI commands: Sided model: side-lying. Dispatched from main.swift.

/// `breathstar side-lying`
func runSideLying(_ args: ArraySlice<String>) {
    // A2 with both sides free (Sided.swift), then lying on the right side.
    let drive = Drive()
    func pct(_ x: Double) -> String { f(x * 100) + "%" }
    let seatedA2 = a2Bodies(drive: drive).reference
    print("1. Consistency: the sided model with a symmetric body must reproduce A2.")
    let sym = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(seatedA2.reference),
                                  passive: seatedA2.passive).matchedToTidal(0.56, drive: drive)
    for (label, a2, sb) in [("seated reference", seatedA2, sym),
                            ("seated, diaphragm only", seatedA2.silenced([.ribs]), sym.silenced([.ribs])),
                            ("seated, rib muscles only", seatedA2.silenced([.diaphragm]), sym.silenced([.diaphragm]))] {
        let m = SignedBreath.measure(a2.simulate(drive: drive), period: drive.period)
        let s2 = SidedBreath.measure(sb.simulate(drive: drive), period: drive.period)
        print("   " + pad(label, 28) + "A2 \(f(m.tidalVolume, 3)) L  \(pct(m.upperShare))/\(pct(m.lowerShare))/\(pct(m.abdomenShare))   "
              + "sided \(f(s2.tidalVolume, 3)) L  \(pct(s2.upperShare))/\(pct(s2.lowerShare))/\(pct(s2.abdomenShare))  "
              + "left/right lung \(f(s2.lung[0] * 1000, 0))/\(f(s2.lung[1] * 1000, 0)) mL")
    }

    // Supine: the sided body moved to the supine geometry the way A2's supine body is (operating
    // point 0.22 L, the supine fit's wall scales), against A2's supine body.
    let sup = a2Supine(.ribcageStiffness, drive: drive)
    let opSup = OperatingPoint(frcDrop: 0.22)
    let sidedSupine = SidedBody.from(seated: sym, anatomy: opSup.apply(to: AnatomyModel.supine()),
                                     abdomenComplianceScale: sup.abScale, ribcageStiffnessScale: sup.secondScale,
                                     diaphragmForceScale: [opSup.diaphragmForceScale, opSup.diaphragmForceScale])
    do {
        let m = SignedBreath.measure(sup.body.simulate(drive: drive), period: drive.period)
        let s2 = SidedBreath.measure(sidedSupine.simulate(drive: drive), period: drive.period)
        print("   " + pad("supine reference", 28) + "A2 \(f(m.tidalVolume, 3)) L  \(pct(m.upperShare))/\(pct(m.lowerShare))/\(pct(m.abdomenShare))   "
              + "sided \(f(s2.tidalVolume, 3)) L  \(pct(s2.upperShare))/\(pct(s2.lowerShare))/\(pct(s2.abdomenShare))  "
              + "left/right lung \(f(s2.lung[0] * 1000, 0))/\(f(s2.lung[1] * 1000, 0)) mL")
    }
    print("   (Static calibration is exact; differences are the flanks, which A2 tied to the front and the sided")
    print("   model frees with an effective restraint calibrated on the reference breath.)")

    // Lying on the right side. Lying wall effects taken from the supine fit (hypothesis A), ASSUMED
    // the same lying on the side; FRC drop 0.22 L as supine, ASSUMED; its split between the domes
    // and the bed's stiffness are scanned.
    print("\n2. Lying on the right side (Takashima 2017 right-lateral geometry). Lying wall effects from the supine")
    print("   fit (abdominal compliance ×\(f(sup.abScale, 2)), ribcage ×\(f(sup.secondScale, 2)); ASSUMED the same on the side);")
    print("   FRC 0.22 L below seated (ASSUMED as supine). Scanned: the dependent dome's share of the rise, the bed.")
    print("   Markers on the upper (left) side and the front, 15 components (Takashima Table 3, right lateral, incl. the")
    print("   front markers' side-to-side motion). No trunk lift (off by default since critique 3; see section 4).\n")
    print("   " + pad("dep. share", 12) + pad("bed", 6) + pad("chi²", 8) + pad("out SD", 8) + pad("lung R/L (dep/up)", 19)
          + pad("wall R/L", 14) + pad("shares u/l/a", 18) + "upper-side lat. rib out")
    var bestFit: (share: Double, bed: Double, chi: Double)? = nil
    for share in [0.5, 0.75, 1.0] {
        let opS = SidedOperatingPoint(frcDrop: 0.22, dependent: .right, dependentShare: share)
        let anat = opS.apply(to: AnatomyModel.rightSideDown())
        for bed in [0.0, 1, 3, 10, 30, 100] {
            let body = SidedBody.from(seated: sym, anatomy: anat, abdomenComplianceScale: sup.abScale,
                                      ribcageStiffnessScale: sup.secondScale,
                                      diaphragmForceScale: Side.allCases.map { opS.forceScale($0) },
                                      dependent: .right, bedGain: bed).matchedToTidal(0.51, drive: drive)
            let br = SidedBreath.measure(body.simulate(drive: drive), period: drive.period)
            let o = anat.observeSided(anat.sidedState(body.endInspiration(drive: drive)), restingOn: .right)
            let ms = TakashimaMarkers.rightSideDownAll
            let chi = ms.reduce(0.0) { $0 + pow(($1.value(o) - $1.mean) / $1.sd, 2) }
            let outside = ms.filter { abs($0.value(o) - $0.mean) > $0.sd }.count
            if bestFit == nil || chi < bestFit!.chi { bestFit = (share, bed, chi) }
            print("   " + pad(f(share, 2), 12) + pad(f(bed, 0), 6) + pad(f(chi, 1), 8) + pad("\(outside)/\(ms.count)", 8)
                  + pad("\(f(br.lung[1] * 1000, 0))/\(f(br.lung[0] * 1000, 0)) mL", 19)
                  + pad("\(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0))", 14)
                  + pad("\(pct(br.upperShare))/\(pct(br.lowerShare))/\(pct(br.abdomenShare))", 18)
                  + f(o.markers["left lateral lower ribcage"]!.x, 2) + " (1.70±0.58), lift " + f(o.markers["trunk lift"]!.x, 2))
        }
    }
    if let b = bestFit { print("\n   best: dependent share \(f(b.share, 2)), bed \(f(b.bed, 0)), chi² \(f(b.chi, 1))") }

    // The lying wall factors fitted to side-lying itself (instead of copied from supine): ribcage
    // stiffness and abdominal compliance, on a grid, against the 12 side-lying components.
    // The sourced split (dependent share 2.0); was 0.75 before literature pass 8.
    let op75 = SidedOperatingPoint.rightSideDown
    let anat75 = op75.apply(to: AnatomyModel.rightSideDown())
    func sideBody(_ rib: Double, _ ab: Double, _ bed: Double) -> SidedBody {
        SidedBody.from(seated: sym, anatomy: anat75, abdomenComplianceScale: ab, ribcageStiffnessScale: rib,
                       diaphragmForceScale: Side.allCases.map { op75.forceScale($0) }, dependent: .right, bedGain: bed)
            .matchedToTidal(0.51, drive: drive)
    }
    func sideObs(_ b: SidedBody) -> AnatomyObservables {
        anat75.observeSided(anat75.sidedState(b.endInspiration(drive: drive)), restingOn: .right)
    }
    func chi(_ o: AnatomyObservables) -> Double {
        TakashimaMarkers.rightSideDownAll.reduce(0.0) { $0 + pow(($1.value(o) - $1.mean) / $1.sd, 2) }
    }
    print("\n3. Lying wall factors fitted to side-lying (fitted force asymmetry, share \(f(op75.dependentShare, 2))), grid; chi² over")
    print("   15 components, no trunk lift, no shoulder hold:")
    var fitted: [(bed: Double, rib: Double, ab: Double, chi: Double)] = []
    for bed in [0.0, 1] {
        var best = (rib: 0.0, ab: 0.0, chi: Double.infinity)
        for rib in [1.0, 1.79, 2.5, 3, 3.5, 4.2, 5, 7, 10] {
            for ab in [0.7, 1.0, 1.34, 1.8, 2.5, 3.5, 5, 7] {
                let c = chi(sideObs(sideBody(rib, ab, bed)))
                if c < best.chi { best = (rib, ab, c) }
            }
        }
        fitted.append((bed, best.rib, best.ab, best.chi))
        print("   bed \(f(bed, 0)): ribcage ×\(f(best.rib, 2)), abdominal compliance ×\(f(best.ab, 2)), chi² \(f(best.chi, 1))"
              + "  (supine fit: ×\(f(sup.secondScale, 2)), ×\(f(sup.abScale, 2)))")
    }

    // Section 4: the fitted bodies without and with the trunk lift (the lift now also moves the front
    // markers, which a rigid lift must).
    print("\n4. Per component (mm; * outside SD). Fitted bodies (section 3), without and with the room-frame trunk")
    print("   lift. The front side-to-side rows (+ toward the left, away from the floor) test the lift: a rigid lift")
    print("   moves the front away from the floor; Takashima's front lower ribcage and belly move toward it.")
    print("   " + pad("marker", 28) + pad("motion", 9) + pad("published", 13) + pad("bed 0", 11) + pad("bed 1", 11) + "bed 1 + lift")
    let bodies = [sideBody(sup.secondScale, sup.abScale, 0)] + fitted.map { sideBody($0.rib, $0.ab, $0.bed) }
    let fitEnd = anat75.sidedState(bodies[2].endInspiration(drive: drive))
    let obs = [sideObs(bodies[1]), sideObs(bodies[2]), anat75.observeSided(fitEnd, restingOn: .right, lift: true)]
    for m in TakashimaMarkers.rightSideDownAll {
        var line = "   " + pad(m.marker, 28) + pad(m.component.rawValue, 9) + pad("\(f(m.mean, 2))±\(f(m.sd, 2))", 13)
        for o in obs { let v = m.value(o); line += pad(f(v, 2) + (abs(v - m.mean) <= m.sd ? "" : " *"), 11) }
        print(line)
    }
    let all = TakashimaMarkers.rightSideDownAll
    print("   " + pad("within SD", 50) + obs.map { o in pad("\(all.filter { abs($0.value(o) - $0.mean) <= $0.sd }.count)/\(all.count)", 11) }.joined())
    print("   " + pad("chi²", 50) + obs.map { pad(f(chi($0), 1), 11) }.joined())
    print("   Front side-to-side, in standard errors of the mean (SD/√15), bed 1 + lift: "
          + TakashimaMarkers.rightSideDownFrontSideways.map { m in f((m.value(obs[2]) - m.mean) / (m.sd / 15.0.squareRoot()), 1) }.joined(separator: ", "))
    print("   Without the lift the upper side's lower ribs move out \(f(obs[1].markers["left lateral lower ribcage"]!.x, 2)) mm (1.70 ± 0.58):")
    print("   no mechanism in the model explains Takashima's largest sideways motion; the lift was one candidate.")

    print("\n5. Per side, fitted bodies (Nozoe 2014: the dependent side's chest wall moves less; Kaneko 1966:")
    print("   the dependent lung ventilates more, by xenon; summary only, not yet read):")
    for (label, b) in zip(["fit bed 0", "fit bed 1"], bodies.dropFirst()) {
        let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        print("   " + pad(label, 11) + "lung dependent/upper \(f(br.lung[1] * 1000, 0))/\(f(br.lung[0] * 1000, 0)) mL "
              + "(\(pct(br.lung[1] / br.tidalVolume)) dependent);  chest wall dependent/upper \(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0)) mL;  "
              + "shares \(pct(br.upperShare))/\(pct(br.lowerShare))/\(pct(br.abdomenShare))")
    }
    for share in [0.5, 1.0] {
        let op = SidedOperatingPoint(frcDrop: 0.22, dependent: .right, dependentShare: share)
        let an = op.apply(to: AnatomyModel.rightSideDown())
        let b = SidedBody.from(seated: sym, anatomy: an, abdomenComplianceScale: fitted[1].ab, ribcageStiffnessScale: fitted[1].rib,
                               diaphragmForceScale: Side.allCases.map { op.forceScale($0) }, dependent: .right, bedGain: 1)
            .matchedToTidal(0.51, drive: drive)
        let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        print("   dependent dome share \(f(share, 2)) (bed 1): lung dependent \(pct(br.lung[1] / br.tidalVolume)), "
              + "chest wall dependent/upper \(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0)) mL")
    }

    // Sourced targets (research pass, notes "sources-asymmetry-standing"): the dependent lung's share
    // of a side-lying breath is 56–62% (Amano 2024 CT 62% right side down; Grant 2011 EIT 59%);
    // with the diaphragm relaxed it goes even (Chevrolet 1979: upper/lower per volume 0.99 vs 0.55).
    // FRC side-lying is ~450 mL below sitting where supine is ~806 below (Lumb & Nunn 1991): scaled
    // to this model's supine 0.22 L, 0.12 L. Scan the dome split, now allowed beyond 1 (the upper
    // dome sitting LOWER than seated: Amano's upper lung is +700 mL fuller than supine).
    print("\n6. The lung split is a FITTED hemidiaphragm force asymmetry (restated after critique 3): the dependent")
    print("   share scales each hemidiaphragm's force by its assumed lengthening; target: the floor-side lung's share,")
    print("   51–62% across sources (Amano 2024 CT 56–62%, Grant 2011 EIT 51–59%). Rib-muscles-only checks removed:")
    print("   lying on the side that breath is 7–35 mL, too small for its split to mean anything.")
    print("   " + pad("FRC drop", 10) + pad("dep. share", 12) + pad("force dep/up", 14) + pad("dep. lung", 11)
          + pad("wall dep/up mL", 16) + "chi² (15)")
    for frc in [0.22, 0.12] {
        for share in [0.5, 1.0, 1.5, 2.0, 3.0, 4.0] {
            let op = SidedOperatingPoint(frcDrop: frc, dependent: .right, dependentShare: share)
            let an = op.apply(to: AnatomyModel.rightSideDown())
            let b = SidedBody.from(seated: sym, anatomy: an, abdomenComplianceScale: fitted[1].ab, ribcageStiffnessScale: fitted[1].rib,
                                   diaphragmForceScale: Side.allCases.map { op.forceScale($0) }, dependent: .right, bedGain: 1)
                .matchedToTidal(0.51, drive: drive)
            let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
            let o = an.observeSided(an.sidedState(b.endInspiration(drive: drive)), restingOn: .right)
            print("   " + pad(f(frc, 2), 10) + pad(f(share, 1), 12)
                  + pad("×\(f(op.forceScale(.right), 3))/×\(f(op.forceScale(.left), 3))", 14)
                  + pad(pct(br.lung[1] / br.tidalVolume), 11)
                  + pad("\(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0))", 16) + f(chi(o), 1))
        }
    }
    do {
        let op = SidedOperatingPoint.rightSideDown, plain = AnatomyModel.rightSideDown(), raised = op.apply(to: plain)
        func depShare(_ an: AnatomyModel, _ force: [Double]) -> Double {
            let b = SidedBody.from(seated: sym, anatomy: an, abdomenComplianceScale: fitted[1].ab, ribcageStiffnessScale: fitted[1].rib,
                                   diaphragmForceScale: force, dependent: .right, bedGain: 1).matchedToTidal(0.51, drive: drive)
            let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
            return br.lung[1] / br.tidalVolume
        }
        let fs = Side.allCases.map { op.forceScale($0) }
        print("   Separated (share 2.0): neither \(pct(depShare(plain, [1, 1]))), dome heights and apposition only "
              + "\(pct(depShare(raised, [1, 1]))), force scaling only \(pct(depShare(plain, fs))), both \(pct(depShare(raised, fs))).")
    }

    // The spine's arc lying on the side (SideLyingArc, Leilnahari 2011): rest geometry only. Its
    // mechanical effect is unknown; one hypothesis, scanned: each side's rib stiffness scales with
    // its lateral wall's strain, k × strain (k > 0: a stretched side is stiffer; k < 0: freer).
    let arc = SideLyingArc.firmSurface, zApex = 21.5
    let w = AnatomyModel.rightSideDown().section(zApex, AnatomyState()).halfWidth[0]
    let eps = arc.lateralStrain(zApex, halfWidth: w, dependentSide: true)
    print("\n7. The spine's arc lying on the side (Leilnahari 2011, firm surface 8.9° at T11): sag \(f(arc.sag, 2)) cm,")
    print("   lateral wall strain at the apex ±\(f(eps * 100, 1))% (dependent side stretched, upper side shortened).")
    print("   Hypothesis scanned (no source): rib stiffness × (1 + k·strain) per side. Sourced split, bed 1.")
    print("   " + pad("k", 6) + pad("dep./up ribs", 14) + pad("dep. lung", 11) + pad("wall dep/up mL", 16) + pad("upper lat. rib out", 20) + "chi² (15)")
    let opS = SidedOperatingPoint.rightSideDown, anS = opS.apply(to: AnatomyModel.rightSideDown())
    let wall = SidedBody.rightSideDownWall
    let baseS = SidedBody.from(seated: sym, anatomy: anS, abdomenComplianceScale: wall.abdomenComplianceScale,
                               ribcageStiffnessScale: wall.ribcageStiffnessScale,
                               diaphragmForceScale: Side.allCases.map { opS.forceScale($0) }, dependent: .right, bedGain: wall.bedGain)
    let ribs = A2Coordinate.ribs
    for k in [-4.0, -2, 0, 2, 4] {
        let dep = max(0.1, 1 + k * eps), up = max(0.1, 1 - k * eps)
        let b = baseS.stiffened(SidedCoordinate.on(.right, ribs), by: dep).stiffened(SidedCoordinate.on(.left, ribs), by: up)
            .matchedToTidal(0.51, drive: drive)
        let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let o = anS.observeSided(anS.sidedState(b.endInspiration(drive: drive)), restingOn: .right)
        print("   " + pad(f(k, 0), 6) + pad("×\(f(dep, 2))/×\(f(up, 2))", 14) + pad(pct(br.lung[1] / br.tidalVolume), 11)
              + pad("\(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0))", 16)
              + pad(f(o.markers["left lateral lower ribcage"]!.x, 2) + " (1.70)", 20) + f(chi(o), 1))
    }

    // User's hypothesis: the floor-side lower ribs are deformed (flattened) away from their point of
    // optimal elasticity, so they're stiffer; the upper side moves more. DeformedSideStiffening:
    // derived strain 0.26 (Takashima's narrowing, ASSUMED all on the dependent side), stiffening size
    // ASSUMED. Scanned here at the sourced split, bed on.
    print("\n8. Deformed floor-side ribs (user's hypothesis): dependent lower ribs' stiffness × m, at strain")
    print("   \(f(DeformedSideStiffening.assumed.strain, 2)) (Takashima's narrowing, ASSUMED all on the floor side). m ASSUMED; default ×2.")
    print("   Targets: chest wall moves less on the floor side (Nozoe), the upper side's lower ribs move out 1.70 mm")
    print("   (Takashima), the dependent lung still takes 56–62% (Amano, Grant).")
    print("   " + pad("m", 6) + pad("dep. lung", 11) + pad("wall dep/up mL", 16) + pad("lower ribcage dep/up mL", 25)
          + pad("upper lat. rib out", 20) + pad("own (spine frame)", 19) + pad("lift", 7) + "chi² (15)")
    for m in [1.0, 1.5, 2, 3, 5] {
        let b = baseS.withDeformedSide(.multiplier(m)).matchedToTidal(0.51, drive: drive)
        let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let o = anS.observeSided(anS.sidedState(b.endInspiration(drive: drive)), restingOn: .right)
        print("   " + pad("×" + f(m, 1), 6) + pad(pct(br.lung[1] / br.tidalVolume), 11)
              + pad("\(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0))", 16)
              + pad("\(f(br.lower[1] * 1000, 0))/\(f(br.lower[0] * 1000, 0))", 25)
              + pad(f(o.markers["left lateral lower ribcage"]!.x, 2) + " (1.70)", 20)
              + pad(f(anS.observeSided(anS.sidedState(b.endInspiration(drive: drive))).markers["left lateral lower ribcage"]!.x, 2), 19)
              + pad(f(o.markers["trunk lift"]!.x, 2), 7) + f(chi(o), 1))
    }

    // The mediastinum: a compliance between the pleural spaces, set from Hubmayr & Margulies 1992
    // (pleural pressure transmission to the other side on inflating one lung: 0.5 baboons, 0.7 dogs).
    print("\n9. A compliant mediastinum (Hubmayr & Margulies 1992: transmission 0.5 ± 0.1 baboons, 0.7 ± 0.1 dogs).")
    var symRigid = sym, baseRigid = baseS
    symRigid.mediastinalCompliance = 0; baseRigid.mediastinalCompliance = 0
    print("   Default since 2026-11-09: transmission \(f(SidedBody.mediastinalTransmission, 1)) (every section above uses it).")
    print("   Transmission with a rigid mediastinum (chest wall alone): seated \(f(symRigid.pleuralTransmission(), 2)), "
          + "side-lying \(f(baseRigid.pleuralTransmission(), 2))")
    for t in [0.5, 0.7] {
        let seatedM = sym.withMediastinum(transmission: t)
        let sideM = baseS.withMediastinum(transmission: t)
        print("\n   transmission \(f(t, 1)): mediastinal compliance seated \(f(seatedM.mediastinalCompliance * 1000, 0)) mL/cmH2O, "
              + "side-lying \(f(sideM.mediastinalCompliance * 1000, 0)) mL/cmH2O")
        print("   " + pad("case (seated)", 34) + pad("rigid: lung L/R mL", 21) + pad("compliant: lung L/R", 21) + "wall L/R (compliant)")
        for (label, f0) in [("reference", { (b: SidedBody) in b }),
                            ("hand on left lower ribs ×5", { (b: SidedBody) in b.stiffened(SidedCoordinate.on(.left, A2Coordinate.lowerBand), by: 5) }),
                            ("left hemidiaphragm paralysed", { (b: SidedBody) in b.silenced([.diaphragm], side: .left) }),
                            ("left rib muscles silent", { (b: SidedBody) in b.silenced([.ribs], side: .left) })] {
            let r0 = SidedBreath.measure(f0(symRigid).simulate(drive: drive), period: drive.period)
            let r1 = SidedBreath.measure(f0(seatedM).simulate(drive: drive), period: drive.period)
            print("   " + pad(label, 34) + pad("\(f(r0.lung[0] * 1000, 0))/\(f(r0.lung[1] * 1000, 0))", 21)
                  + pad("\(f(r1.lung[0] * 1000, 0))/\(f(r1.lung[1] * 1000, 0))", 21)
                  + "\(f(r1.chestWall[0] * 1000, 0))/\(f(r1.chestWall[1] * 1000, 0))")
        }
        print("   " + pad("side-lying, floor-side ribs", 34) + pad("dep. lung", 11) + pad("wall dep/up", 13) + pad("upper rib out", 15)
              + pad("own", 7) + pad("lift", 7) + "chi² (15)")
        for m in [1.0, 2, 5] {
            let b = sideM.withDeformedSide(.multiplier(m)).matchedToTidal(0.51, drive: drive)
            let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
            let st = anS.sidedState(b.endInspiration(drive: drive))
            let o = anS.observeSided(st, restingOn: .right)
            print("   " + pad("  ×" + f(m, 0), 34) + pad(pct(br.lung[1] / br.tidalVolume), 11)
                  + pad("\(f(br.chestWall[1] * 1000, 0))/\(f(br.chestWall[0] * 1000, 0))", 13)
                  + pad(f(o.markers["left lateral lower ribcage"]!.x, 2), 15)
                  + pad(f(anS.observeSided(st).markers["left lateral lower ribcage"]!.x, 2), 7)
                  + pad(f(o.markers["trunk lift"]!.x, 2), 7) + f(chi(o), 1))
        }
    }

    // Which floor constraint carries the user's sense ("the floor-side ribs are constrained, more goes
    // to the upper side")? Constrain bigger-volume parts of the dependent side, ×m stiffer each, with
    // the default (compliant) mediastinum. Nozoe 2014 (abstract): the dependent side moves less
    // "because of the decrease in abdominal rib cage and abdomen volume changes".
    print("\n10. Floor constraints on the dependent side (×m stiffer), mediastinum 0.5. Per-side regions, mL,")
    print("    dependent/upper: upper ribcage, lower ribcage, abdomen. Nozoe: dependent lower ribcage and abdomen less.")
    print("    " + pad("constraint", 30) + pad("m", 5) + pad("dep. lung", 11) + pad("upper rc", 10) + pad("lower rc", 10)
          + pad("abdomen", 10) + pad("upper rib out", 15) + pad("own", 6) + "chi²")
    let R = Side.right
    let constraints: [(String, (SidedBody, Double) -> SidedBody)] = [
        ("none", { b, _ in b }),
        ("lower ribs (deformed)", { b, m in b.withDeformedSide(.multiplier(m)) }),
        ("belly wall (flank)", { b, m in b.stiffened([.flankR], by: m) }),
        ("lower ribs + belly wall", { b, m in b.withDeformedSide(.multiplier(m)).stiffened([.flankR], by: m) }),
        ("top ribs (shoulder)", { b, m in b.stiffened(SidedCoordinate.on(R, [.upperRotation, .upperDilation]), by: m) }),
        ("whole floor-side ribcage", { b, m in b.stiffened(SidedCoordinate.on(R, A2Coordinate.ribs), by: m) }),
        ("floor-side hemidiaphragm", { b, m in b.stiffened([.diaphragmR], by: m) }),
    ]
    for (label, apply) in constraints {
        for m in (label == "none" ? [1.0] : [2.0, 5]) {
            let b = apply(baseS, m).matchedToTidal(0.51, drive: drive)
            let br = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
            let st = anS.sidedState(b.endInspiration(drive: drive))
            let o = anS.observeSided(st, restingOn: .right)
            func pair(_ v: [Double]) -> String { "\(f(v[1] * 1000, 0))/\(f(v[0] * 1000, 0))" }
            print("    " + pad(label, 30) + pad(label == "none" ? "" : "×" + f(m, 0), 5) + pad(pct(br.lung[1] / br.tidalVolume), 11)
                  + pad(pair(br.upper), 10) + pad(pair(br.lower), 10) + pad(pair(br.abdomen), 10)
                  + pad(f(o.markers["left lateral lower ribcage"]!.x, 2), 15)
                  + pad(f(anS.observeSided(st).markers["left lateral lower ribcage"]!.x, 2), 6) + f(chi(o), 1))
        }
    }
}
