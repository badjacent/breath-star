import BreathStar
import Foundation

/// `stage4`: the spine's shape and Rule B (Bending.swift), seated.
func runStage4(_ args: ArraySlice<String>) {
    let drive = Drive()
    let rules = GravityRules()
    func run(_ c: BodyConfiguration, _ r: GravityRules = GravityRules()) -> (body: SidedBody, m: SidedBreath, drive: Double) {
        let g = BodyGenerator.general(c, rules: r, drive: drive)
        return (g.body, SidedBreath.measure(g.body.simulate(drive: drive), period: drive.period), g.driveScale)
    }
    func side(_ m: SidedBreath, _ k: Int) -> String {
        "\(f(m.upper[k] * 1000, 0))/\(f(m.lower[k] * 1000, 0))/\(f(m.abdomen[k] * 1000, 0))"
    }
    // Wall motion at end inspiration, mm (outward on that side): the lateral lower ribs (9th rib
    // level) and the axilla.
    func lateral(_ b: SidedBody, _ s: Side, z: ClosedRange<Double>) -> Double {
        let q = b.endInspiration(drive: drive)
        let lo = b.simulate(drive: drive).suffix(Int(drive.period / 0.002)).min { $0.totalLung < $1.totalLung }!.q
        let a = b.anatomy
        return a.sectorMotion(z: z, psi: 80...100, side: s, a.sidedState(zip(q, lo).map { $0 - $1 })).x
    }
    let base = BodyConfiguration.seated
    print("Stage 4: the spine's shape and Rule B, seated. Law: k × exp(−gain·ε + twist·|γ|), gain ribs \(f(rules.ribBendGain, 2)),"
          + " wall \(f(rules.wallBendGain, 2)), twist \(f(rules.twistGain, 2)). Quiet tidal held (0.56 L).\n")

    print("1. Strain each coordinate takes (lengthwise ε, + lengthened), side-bend 20° to the left:")
    let sb = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(BodyGenerator.seatedSymmetric(drive: drive).reference))
    let st = sb.coordinateStrains(SpineShape(sideBend: 20))
    for c in SidedCoordinate.allCases where !c.isDiaphragm {
        print("   " + pad(c.label, 48) + "ε " + f(st[c.rawValue].axial, 3) + "  → k ×" + f(exp(-rules.ribBendGain * st[c.rawValue].axial), 2))
    }

    print("\n2. Seated configurations (regions per side: upper/lower ribcage/abdomen, mL):")
    print("   " + pad("spine", 24) + pad("shares u/l/a", 18) + pad("drive", 7) + pad("lungs L/R", 11) + pad("left u/l/a", 14) + pad("right u/l/a", 14) + "chest wall L/R")
    let cases: [(String, SpineShape)] = [
        ("neutral", .neutral), ("side-bend left 20°", SpineShape(sideBend: 20)), ("side-bend right 20°", SpineShape(sideBend: -20)),
        ("slumped (flexion)", .slumped), ("extension 15°", SpineShape(flexion: -15)),
        ("rotation left 30°", SpineShape(rotation: 30)), ("rotation right 30°", SpineShape(rotation: -30)),
    ]
    var results: [String: (body: SidedBody, m: SidedBreath, drive: Double)] = [:]
    for (label, s) in cases {
        let r = run(base.with(s, name: label)); results[label] = r
        let m = r.m
        print("   " + pad(label, 24) + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 18)
              + pad(f(r.drive, 2), 7) + pad("\(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0))", 11)
              + pad(side(m, 0), 14) + pad(side(m, 1), 14) + "\(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))")
    }
    let l = results["side-bend left 20°"]!.m, r = results["side-bend right 20°"]!.m
    let rl = results["rotation left 30°"]!.m, rr = results["rotation right 30°"]!.m
    let mirror = max(abs(l.chestWall[0] - r.chestWall[1]), abs(l.chestWall[1] - r.chestWall[0]),
                     abs(rl.chestWall[0] - rr.chestWall[1]), abs(rl.lung[0] - rr.lung[1])) * 1000
    print("   mirror check: left vs right bends and rotations, largest difference \(f(mirror, 2)) mL")

    print("\n3. Against the sources (direction and size):")
    let up = results["neutral"]!, sl = results["slumped (flexion)"]!
    let rc = { (m: SidedBreath) in m.upperShare + m.lowerShare }
    print("   slumped / upright ribcage volume: \(f(rc(sl.m) / rc(up.m), 3)) (Hazaki & Okada: rib cage expansion 3.6/4.2 = 0.857)")
    let ext = results["extension 15°"]!, rot = results["rotation left 30°"]!
    print("   extension: lateral lower ribs (9th rib level) \(f(lateral(up.body, .left, z: 18...25), 2)) → \(f(lateral(ext.body, .left, z: 18...25), 2)) mm (study of 7: more)")
    print("   rotation left 30°: axilla lateral, left \(f(lateral(up.body, .left, z: 34...40), 2)) → \(f(lateral(rot.body, .left, z: 34...40), 2)),"
          + " right → \(f(lateral(rot.body, .right, z: 34...40), 2)) mm (study of 7: less)")

    print("\n4a. The bend and the diaphragm: side-bend left 20°, the fraction of the rim's drop that becomes dome rise")
    print("    (1: the abdominal contents stay put; 0: they move with the rim). Rim drop left/right: "
          + AnatomyModel().rimDrop(SpineShape(sideBend: 20)).map { f($0, 2) }.joined(separator: "/") + " cm.")
    print("   " + pad("coupling", 10) + pad("dia force L/R", 16) + pad("lungs L/R mL", 14) + pad("chest wall L/R", 16) + "hemidiaphragm L/R mL")
    for k in [0.0, 0.25, 0.5, 1] {
        var g = GravityRules(); g.bendDomeCoupling = k
        let r = BodyGenerator.general(base.with(SpineShape(sideBend: 20)), rules: g, drive: drive)
        let m = SidedBreath.measure(r.body.simulate(drive: drive), period: drive.period)
        let sim = r.body.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
        let dq = zip(hi, lo).map { $0 - $1 }
        let dia = (0..<2).map { k in zip(r.body.geometry.diaphragm[k], dq).reduce(0) { $0 + $1.0 * $1.1 } * 1000 }
        print("   " + pad(f(k, 2), 10) + pad("\(f(r.diaphragmForceScale[0], 3))/\(f(r.diaphragmForceScale[1], 3))", 16)
              + pad("\(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0))", 14)
              + pad("\(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))", 16) + "\(f(dia[0], 0))/\(f(dia[1], 0))")
    }

    print("\n4. The direction question: side-bend left 20°, the law's gain scaled (− flips it: crowded side eases):")
    print("   " + pad("gain ×", 8) + pad("lungs L/R mL", 14) + pad("chest wall L/R", 16) + "where the breath goes")
    for k in [-1.0, 0, 0.5, 1, 2] {
        var g = GravityRules(); g.ribBendGain *= k; g.wallBendGain *= k; g.twistGain *= abs(k)
        let m = run(base.with(SpineShape(sideBend: 20)), g).m
        let d = m.chestWall[0] - m.chestWall[1]
        print("   " + pad(f(k, 1), 8) + pad("\(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0))", 14)
              + pad("\(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))", 16)
              + (abs(d) < 0.002 ? "even" : d > 0 ? "toward the crowded (left) side" : "toward the open (right) side"))
    }
}

/// `stage4-fit`: the rib gain against Hazaki & Okada's slumped sitting (ribcage 0.857 of upright),
/// the wall gain held; what each gain does to a side-bend and a rotation.
func runStage4Fit(_ args: ArraySlice<String>) {
    let drive = Drive()
    func m(_ s: SpineShape, _ r: GravityRules) -> SidedBreath {
        SidedBreath.measure(BodyGenerator.general(BodyConfiguration.seated.with(s), rules: r, drive: drive).body.simulate(drive: drive), period: drive.period)
    }
    print("  " + pad("rib gain", 10) + pad("wall gain", 11) + pad("slump rc ratio", 16) + pad("bend L20 cw L/R", 18) + pad("bend L20 lungs", 16) + "rotation 30° rc share")
    for wall in [-2.67, 0.0, 2.67] {
        for rib in [0.0, 1.0, 2.67, 4.4, 8] {
            var r = GravityRules(); r.ribBendGain = rib; r.wallBendGain = wall; r.twistGain = rib
            let up = m(.neutral, r), sl = m(.slumped, r), sb = m(SpineShape(sideBend: 20), r), ro = m(SpineShape(rotation: 30), r)
            let rc = { (x: SidedBreath) in x.upperShare + x.lowerShare }
            print("  " + pad(f(rib, 2), 10) + pad(f(wall, 2), 11) + pad(f(rc(sl) / rc(up), 3), 16)
                  + pad("\(f(sb.chestWall[0] * 1000, 0))/\(f(sb.chestWall[1] * 1000, 0))", 18)
                  + pad("\(f(sb.lung[0] * 1000, 0))/\(f(sb.lung[1] * 1000, 0))", 16) + f(rc(ro) * 100) + "%")
        }
    }
}

/// `stage4-lungs`: where a side-bend's asymmetry goes, per side: upper ribcage, the lung-facing and
/// apposed lower ribcage, the hemidiaphragm, the flank and front abdomen, and the mediastinal shift.
func runStage4Lungs(_ args: ArraySlice<String>) {
    let drive = Drive()
    for (label, s) in [("neutral", SpineShape.neutral), ("side-bend left 20°", SpineShape(sideBend: 20))] {
        let b = BodyGenerator.general(BodyConfiguration.seated.with(s), drive: drive).body
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!, lo = sim.min { $0.totalLung < $1.totalLung }!
        let dq = zip(hi.q, lo.q).map { $0 - $1 }
        func dot(_ v: [Double]) -> Double { zip(v, dq).reduce(0) { $0 + $1.0 * $1.1 } * 1000 }
        let g = b.geometry
        print(label + ":")
        for k in 0..<2 {
            let thorax = dot(g.thorax(k)), lung = (hi.lung[k] - lo.lung[k]) * 1000
            print("  " + (k == 0 ? "left " : "right") + "  upper \(f(dot(g.upper[k]), 0))  lower lung-facing \(f(dot(g.lowerLungFacing[k]), 0))"
                  + "  apposed \(f(dot(g.lowerApposed[k]), 0))  hemidiaphragm \(f(dot(g.diaphragm[k]), 0))  abdomen \(f(dot(g.abdomen[k]), 0))"
                  + "  → thorax \(f(thorax, 0)), lung \(f(lung, 0)) (mediastinum \(f(lung - thorax, 0)))")
        }
    }
}

/// `stage4-extension`: what moves the lateral lower ribs (the 9th-rib level) at a matched breath.
func runStage4Extension(_ args: ArraySlice<String>) {
    let drive = Drive()
    func lateral(_ c: BodyConfiguration, _ r: GravityRules = GravityRules(), z: ClosedRange<Double>) -> Double {
        let b = BodyGenerator.general(c, rules: r, drive: drive).body
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
        return b.anatomy.sectorMotion(z: z, psi: 80...100, side: .left, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 })).x
    }
    var lumbar = SpineShape(); lumbar.lumbarFlexion = -15
    var thoracic = SpineShape(); thoracic.thoracicFlexion = -15
    var noDome = GravityRules(); noDome.bendDomeCoupling = 0
    var noWall = GravityRules(); noWall.wallBendGain = 0
    var noRib = GravityRules(); noRib.ribBendGain = 0
    let s = BodyConfiguration.seated
    var solved = GravityRules(); solved.bendDomeSolved = true
    let rows: [(String, BodyConfiguration, GravityRules)] = [
        ("neutral", s, GravityRules()),
        ("extension 15°, dome solved", s.with(SpineShape(flexion: -15)), solved),
        ("extension 15° (split)", s.with(SpineShape(flexion: -15)), GravityRules()),
        ("  without the dome effect", s.with(SpineShape(flexion: -15)), noDome),
        ("  without the wall law", s.with(SpineShape(flexion: -15)), noWall),
        ("  without the rib law", s.with(SpineShape(flexion: -15)), noRib),
        ("lumbar extension 15°", s.with(lumbar), GravityRules()),
        ("thoracic extension 15°", s.with(thoracic), GravityRules()),
        ("belly tone ×2", s.toned([RegionTone(.frontAbdomen, 2)]), GravityRules()),
        ("belly tone ×5", s.toned([RegionTone(.frontAbdomen, 5)]), GravityRules()),
    ]
    do {
        let b = BodyGenerator.general(s).body, r = GravityRules()
        for (label, sp) in [("extension 15° (split)", SpineShape(flexion: -15)), ("lumbar 15°", lumbar), ("thoracic 15°", thoracic)] {
            print("Strain per coordinate, \(label) (ε, + lengthened → k ×):")
            let st = b.coordinateStrains(sp)
            for c in SidedCoordinate.allCases where !c.isDiaphragm && c.side != .right {
                let e = st[c.rawValue], gain = c.isRib ? r.ribBendGain : r.wallBendGain
                print("   " + pad("\(c)", 26) + pad(f(e.axial, 4), 10) + "×" + f(exp(-gain * e.axial + r.twistGain * e.shear), 2))
            }
        }
    }
    print("Each dome's rise from the bend (mL, left/right; + longer fibres): assumed coupling vs solved")
    for (label, sp) in [("extension 15°", SpineShape(flexion: -15)), ("slumped", SpineShape.slumped), ("side-bend 20° left", SpineShape(sideBend: 20))] {
        let r0 = BodyGenerator.general(s.with(sp)).domeRise, r1 = BodyGenerator.general(s.with(sp), rules: solved).domeRise
        let seated = BodyGenerator.general(s).domeRise
        let bs = SidedBody.from(seated: BodyGenerator.general(s).body, anatomy: AnatomyModel()).bendSettle(sp)
        print("  " + pad(label, 22) + pad("\(f((r0[0] - seated[0]) * 1000, 0))/\(f((r0[1] - seated[1]) * 1000, 0))", 14)
              + pad("\(f((r1[0] - seated[0]) * 1000, 0))/\(f((r1[1] - seated[1]) * 1000, 0))", 14)
              + "cavity \(f(bs.cavity * 1000, 0)) mL, Pab \(f(bs.pab, 2)) cmH2O")
    }
    print("Extension 15° by where the arch happens (lumbar share) and the dome coupling: lowest ribs z 13–18, mm (neutral \(f(lateral(s, z: 13...18), 3)))")
    print("  " + pad("lumbar share", 14) + ["0", "0.5 (default)", "solved"].map { pad("dome \($0)", 20) }.joined())
    for share in [0.3, 0.5, 0.7, 0.9, 1.0] {
        var sp = SpineShape(); sp.lumbarFlexion = -15 * share; sp.thoracicFlexion = -15 * (1 - share)
        var r0 = GravityRules(); r0.bendDomeCoupling = 0
        let cells = [r0, GravityRules(), solved].map { pad(f(lateral(s.with(sp), $0, z: 13...18), 3), 20) }
        print("  " + pad(f(share, 1), 14) + cells.joined())
    }
    print("Lateral lower-rib motion (mm, outward, end-expiration → end-inspiration, quiet tidal held):")
    print("  " + pad("case", 30) + pad("z 18–25 (lower ribcage)", 26) + "z 13–18 (lowest ribs, the 9th–10th)")
    for (label, c, r) in rows {
        print("  " + pad(label, 30) + pad(f(lateral(c, r, z: 18...25), 3), 26) + f(lateral(c, r, z: 13...18), 3))
    }
}
