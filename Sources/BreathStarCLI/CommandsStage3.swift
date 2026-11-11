import BreathStar
import Foundation

/// `stage3 [contact gain]`: the general rules (Settle.swift) across the sourced postures, one parameter set.
func runStage3(_ args: ArraySlice<String>) {
    let drive = Drive()
    var rules = GravityRules()
    let nums = args.compactMap(Double.init)
    if nums.count >= 2 { rules.contactStiffness = nums[0]; rules.abdominalWallGain = nums[1] }
    if args.contains("--seated-drive") { rules.quietTidal = nil }
    if args.contains("--regulate-ribs") { rules.regulated = .ribs }
    if let i = args.firstIndex(of: "--upper"), args.index(after: i) < args.endIndex, let v = Double(args[args.index(after: i)]) { rules.uprightUpperDrive = v }
    let law: GravityRules.WallLoad = args.contains("--front-pressure") ? .frontPressure
        : args.contains("--held-column") ? .heldColumn : .axialColumn
    rules.wallLoad = law
    if args.contains("--volumes") { rules.seatedVolumes = .mendesMenSeated }
    if args.contains("--upright-squared") { rules.uprightSquared = true }
    if args.contains("--free-lift") { rules.contactFreeLift = true }
    if args.contains("--fit") {
        let base = rules
        rules = fitStage3(drive: drive, wallLoad: law, base: base)
    }
    let s45 = 0.5.squareRoot()
    let configs: [BodyConfiguration] = [
        .seated,
        BodyConfiguration(name: "reclined 45°", gravity: (0, -s45, -s45), contacts: [ContactPatch(.back, on: "bed")]),
        .supine, .rightSideDown, .leftSideDown,
        BodyConfiguration(name: "prone", gravity: (0, 1, 0), contacts: [ContactPatch(.front)]),
    ] + (args.contains("--prone-variants") ? [
        BodyConfiguration(name: "prone, no floor", gravity: (0, 1, 0)),
        BodyConfiguration(name: "prone, chest", gravity: (0, 1, 0), contacts: [ContactPatch(.chest)]),
        BodyConfiguration(name: "prone, belly", gravity: (0, 1, 0), contacts: [ContactPatch(.belly)]),
        BodyConfiguration(name: "prone, ch+belly", gravity: (0, 1, 0), contacts: [ContactPatch(.chest), ContactPatch(.belly)]),
    ] : [])
    print("Stage 3: general rules, one parameter set. Contact stiffness \(f(rules.contactStiffness, 2)) cmH2O/cm,"
          + " wall gain \(f(rules.abdominalWallGain, 3)) /cmH2O (wall load: \(rules.wallLoad.rawValue)); gradients \(rules.abdominalGradient) abdomen, \(rules.pleuralGradient) pleural.\n")
    print("  " + pad("configuration", 16) + pad("ΔFRC L", 8) + pad("dome rise L/R mL", 18) + pad("dia force L/R", 15)
          + pad("wall C×", 8) + pad("wall p", 8) + pad("tidal", 7) + pad("drive d/r", 11) + pad("shares u/l/a", 18) + pad("floor lung", 11) + "chest wall L/R")
    for c in configs {
        let r = BodyGenerator.general(c, rules: rules, drive: drive)
        let m = SidedBreath.measure(r.body.simulate(drive: drive), period: drive.period)
        let dep = r.body.dependent.map { m.lung[$0.rawValue] / (m.lung[0] + m.lung[1]) }
        print("  " + pad(c.name, 16) + pad(f(r.frcChange, 2), 8)
              + pad("\(f(r.domeRise[0] * 1000, 0))/\(f(r.domeRise[1] * 1000, 0))", 18)
              + pad("\(f(r.diaphragmForceScale[0], 3))/\(f(r.diaphragmForceScale[1], 3))", 15)
              + pad(f(r.abdomenComplianceScale, 2), 8) + pad(f(r.settled.frontWallLoad, 1), 8) + pad(f(m.tidalVolume, 3), 7) + pad(f(r.driveScale, 2) + "/" + f(r.ribDriveScale, 2), 11)
              + pad("\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%", 18)
              + pad(dep.map { f($0 * 100) + "%" } ?? "–", 11)
              + "\(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))")
    }
    print("""

      Targets (sourced): ΔFRC sitting→supine −0.81 L, → side −0.46 L (Lumb & Nunn 1991); supine shares
      19.5/11.5/69.8% (Mendes men) or 19.1/6.4/74.5% (Takashima markers); 45° 31.0/14.3/55.4% (Mendes men),
      abdomen 47.9% (Sonpeayung); side-lying floor lung 51–62% (Amano, Grant), dependent chest wall smaller
      (Nozoe 2014); any horizontal posture ribcage 32–36% (Lumb & Nunn). Prone: predicted, nothing fitted.
      Tidal: held at the quiet-breathing volume (`GravityRules.quietTidal`); 'drive' is what that takes
      relative to seated (--seated-drive: hold the drive instead, tidal predicted).
      Stage-2 builds for comparison: supine 19.1/6.4/74.5%, side 13.4/5.8/80.9% floor lung 56.3%.
    """)
}

/// Fit the two shared parameters on supine and side-lying only (45° and prone are then predictions).
/// χ² terms: Mendes 2020 men supine shares against their standard errors (SD/√31); the floor-side
/// lung's share against the middle of 51–62% (half-range as SD); side-lying ribcage share against
/// Lumb & Nunn's 32–36% (half-range as SD).
/// `base`: every other rule as given (only contact stiffness and wall gain are scanned).
func fitStage3(drive: Drive, wallLoad: GravityRules.WallLoad, base: GravityRules = GravityRules()) -> GravityRules {
    let se = (31.0).squareRoot()
    var best = (chi: Double.infinity, rules: GravityRules())
    print("Fit (supine + right side down; 45° and prone held out):")
    print("  " + pad("contact", 9) + pad("gain", 7) + pad("χ²", 8) + "supine u/l/a, side floor lung, side ribcage")
    for c in [0.0, 2, 5, 10, 20, 50, 100, 200] {
        for gi in 0...10 {
            var rules = base
            rules.contactStiffness = c; rules.abdominalWallGain = Double(gi) * 0.02; rules.wallLoad = wallLoad
            let sup = SidedBreath.measure(BodyGenerator.general(.supine, rules: rules, drive: drive).body.simulate(drive: drive), period: drive.period)
            let side = SidedBreath.measure(BodyGenerator.general(.rightSideDown, rules: rules, drive: drive).body.simulate(drive: drive), period: drive.period)
            let floor = side.lung[1] / (side.lung[0] + side.lung[1])
            var chi = pow((sup.upperShare * 100 - 19.5) / (9.9 / se), 2) + pow((sup.lowerShare * 100 - 11.5) / (4.4 / se), 2)
                + pow((sup.abdomenShare * 100 - 69.8) / (13.4 / se), 2)
            chi += pow((floor * 100 - 56.5) / 5.5, 2) + pow(((side.upperShare + side.lowerShare) * 100 - 34) / 2, 2)
            // Nozoe 2014 (a direction, not a size): the floor side's chest wall moves less.
            let nozoe = side.chestWall[1] < side.chestWall[0]
            if nozoe && chi < best.chi { best = (chi, rules) }
            if gi % 2 == 0 {
                print("  " + pad(f(c, 0), 9) + pad(f(rules.abdominalWallGain, 2), 7) + pad(f(chi, 1) + (nozoe ? "" : "*"), 8)
                      + "\(f(sup.upperShare * 100))/\(f(sup.lowerShare * 100))/\(f(sup.abdomenShare * 100))%, \(f(floor * 100))%, \(f((side.upperShare + side.lowerShare) * 100))%")
            }
        }
    }
    print("  best: contact \(f(best.rules.contactStiffness, 0)) cmH2O/cm, gain \(f(best.rules.abdominalWallGain, 2)) /cmH2O, χ² \(f(best.chi, 1)) (5 terms; * = fails Nozoe's direction, excluded)\n")
    return best.rules
}

/// `stage3-frc`: where the end-expiratory volume change comes from.
func runStage3FRC(_ args: ArraySlice<String>) {
    let drive = Drive()
    let seated = BodyGenerator.seatedSymmetric(drive: drive)
    let sym = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(seated.reference),
                                  passive: seated.passive)
    func lungs(_ b: SidedBody, _ g: (x: Double, y: Double, z: Double), _ r: GravityRules) -> Double {
        let s = b.settle(gravity: g, rules: r); return s.lung[0] + s.lung[1]
    }
    let base = GravityRules()
    var noPleural = base; noPleural.pleuralGradient = 0
    var noAbdomen = base; noAbdomen.abdominalGradient = 0
    let up = (x: 0.0, y: 0.0, z: -1.0), back = (x: 0.0, y: -1.0, z: 0.0), side = (x: -1.0, y: 0.0, z: 0.0)
    let supineBody = SidedBody.from(seated: sym, anatomy: AnatomyModel.resting(gravity: back))
    let seatedSupineGeometry = sym  // seated geometry, for the geometry-free comparison
    print("End-expiratory lung volume change, sitting → supine (L), by part:")
    for (label, r) in [("both gradients", base), ("abdomen only", noPleural), ("pleural only", noAbdomen)] {
        let ref = lungs(sym, up, r)
        print("  " + pad(label, 18) + "seated → weightless " + f(lungs(sym, (0, 0, 0), r) - ref, 2)
              + "   weightless → supine load (seated geometry) " + f(lungs(seatedSupineGeometry, back, r) - lungs(sym, (0, 0, 0), r), 2)
              + "   total, supine geometry " + f(lungs(supineBody, back, r) - ref, 2)
              + "   side " + f(lungs(SidedBody.from(seated: sym, anatomy: AnatomyModel.resting(gravity: side)), side, r) - ref, 2))
    }
    // How stiff is the relaxed system? Volume per cmH2O of airway pressure, muscles relaxed.
    print("\n  relaxed respiratory-system compliance (seated): \(f(sym.passive.lungCompliance, 3)) L/cmH2O lung; total from the static solve below")
}
