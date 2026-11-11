import Foundation

// Stage 3 of the lesson adaptation (docs/LESSON_ADAPTATION.md §4.3–4.4, §9): gravity as a rule, not a per-posture fit.
//
// Rule A, a hydrostatic abdomen: the abdominal contents are a liquid (1 cmH2O per cm of depth), and
// the lung's weight gives the pleural space a gradient of its own (~0.25 cmH2O/cm). Moving a wall
// where the liquid is deep lowers its potential energy, so gravity puts a generalised force on
// every coordinate: Q_j = ρg · ∂(depth moment of the contents)/∂q_j. The settle solve finds the
// resting state under that load (linear springs, the incompressible abdomen, both lungs, the
// mediastinum), and the breath layer takes from it each hemidiaphragm's resting length (its force,
// by length–tension, and its zone of apposition) and the end-expiratory volume.
//
// The diaphragm is four patches in the settle (left/right × front/back), but the breath has one
// coordinate per side, so each side's front and back loads are summed (its tilt fixes the split).
//
// Rule C, contacts as patches: a support resists the outward motion of the surface it touches,
// one-sided, with one tissue stiffness for every patch (cmH2O per cm of compression), scaled by the
// share of the body's weight pressing on it (the gravity component into the patch). ASSUMED linear
// in load.
//
// Rule B (stiffness by distance from neutral) is stage 4, except for one shared law on the
// abdominal wall, whose pre-strain IS set by Rule A: the wall holds the liquid's weight. Its
// stiffness × exp(gain · (p − p_seated)), with p the column of contents the front wall holds along
// the trunk's length (`WallLoad.axialColumn`, since the 45° fix; the first law, pressure at the
// front wall, put 45° ~70% of the way to supine against the data's 44–50%).

/// The shared parameters of the general rules: one set for every configuration.
public struct GravityRules: Sendable {
    /// Abdominal contents, cmH2O per cm of depth (a liquid of density ~1; SOURCED: Agostoni, Mead).
    public var abdominalGradient = 1.0
    /// Pleural pressure gradient, cmH2O per cm (West 1960s; ~0.2–0.5 across sources: SOURCED range).
    public var pleuralGradient = 0.25
    /// The support's tissue stiffness, cmH2O per cm of compression at full body weight. FITTED.
    public var contactStiffness = 50.0  // fitted: `breathstar stage3 --fit`
    /// Abdominal wall stiffening per cmH2O of extra hydrostatic load on it (Rule B on the wall). FITTED.
    public var abdominalWallGain = 0.04  // fitted: `breathstar stage3 --fit` (0.08 on the markers-only seated base, 0.12 before the upright upper drive)

    /// Quiet breathing is regulated: the breathing centre sets the drive to deliver the ventilation
    /// the body needs, and resting needs differ little between resting postures (Sonpeayung 2019:
    /// 0.54 L sitting, 0.52 supine, at similar rates). So every configuration breathes this tidal
    /// volume, and the drive it takes is the prediction. nil: keep the seated drive (tidal predicted).
    /// ASSUMED: one resting ventilation across postures (Mendes 2020 falls 30% to 45° and supine,
    /// but its reclined OEP used 52 front-only markers, the back treated as fixed).
    public var quietTidal: Double? = 0.56

    /// The relaxed system stiffens as end-expiratory volume nears residual volume (Rule B on the
    /// whole system): the linear settle's volume change ΔV becomes R·tanh(ΔV/R), with R the room
    /// below seated FRC (the seated expiratory reserve, 1.12 L in Sonpeayung 2019's controls:
    /// SOURCED) or above it (inspiratory capacity, ~3 L: ASSUMED). Slope 1 at the seated operating
    /// point, so small changes keep the measured compliance. The shape is ASSUMED. Every coordinate
    /// of the settle is scaled by the same factor (a secant stiffening of the whole system). nil: linear.
    public var expiratoryReserve: Double? = 1.12

    /// Which muscles the breathing centre turns up or down to hold the quiet tidal volume: all of
    /// them by one factor, or only the rib muscles (the diaphragm's drive held at seated; literature
    /// pass 10: posture changes parasternal and scalene activity, the crural diaphragm's less).
    public enum Regulated: String, Sendable { case all, ribs }
    public var regulated = Regulated.all
    public var inspiratoryCapacity = 3.0

    /// Rule B, the spine's shape (Bending.swift): k × exp(−gain·ε + twistGain·|γ|).
    /// Ribs (struts): crowding jams them, gain +2.67 = doubling at the side-lying floor side's derived
    /// strain (0.26), as `DeformedSideStiffening.assumed` (ASSUMED). Abdominal wall (a membrane): its
    /// resistance to bulging is its tension, so shortening slackens it and lengthening tightens it,
    /// gain −2.67 (same size, ASSUMED; the sign as the stage-3 wall law and docs/LESSON_ADAPTATION.md §4.6). Twist: the
    /// ribs' gain (ASSUMED). History: ribs 5.0 then 4.4 were fitted to slumped sitting's ribcage
    /// expansion as if it were a share at a matched breath; it isn't (the slumped breath was smaller:
    /// ribcage and diaphragm both moved less), so it is now a direction check only (working log, private: "belly wall").
    public var ribBendGain = log(2.0) / 0.26
    public var wallBendGain = -log(2.0) / 0.26
    public var twistGain = log(2.0) / 0.26
    /// The upper rib muscles (scalenes, upper parasternals) carry a postural share that falls as the
    /// trunk leaves upright: their drive × (1 − uprightUpperDrive · (1 − max(0, −g_z))), so lying
    /// and upside down both lose it. Sources (literature pass 10): parasternal sEMG supine 0.90–0.95
    /// of sitting (Wakode) → 0.08, the default (SOURCED, one muscle); scalene EMG about halved upside
    /// down (Flinders) → up to 0.5 for the scalenes; more of both upright (Druz & Sharp 1981). The
    /// scan (`breathstar stage3 --fit --upper u`): 0.25 fits supine and side best (χ² 15) but the
    /// refit then drops the wall law and 45° and prone slip; 0.5 overshoots. The quiet tidal volume
    /// is restored by the common drive. Since 2026-11-10 (the seated base fits Mendes's compartment
    /// volumes too, `seatedVolumes`): 0.4, FITTED (`stage3 --volumes --fit --upper u`: χ² 13.0 at
    /// 0.5, 11.5 at 0.4, 16.9 at 0.3, 58.7 at 0.6), between the parasternal (≈ 0.1) and scalene
    /// (≈ 0.5) evidence. Held out: 45° moves toward Mendes, prone's ribcage away from Lumb & Nunn.
    public var uprightUpperDrive = 0.4
    /// Scale the postural share by the squared upright component (as the geometry blend does) instead
    /// of the component itself. Only intermediate angles differ. `stage3 --upright-squared`.
    public var uprightSquared = false
    /// The abdominal flanks' own stiffness (the side bulge beyond what the front's bulge carries) ×
    /// this. The front and the sides are one sheet (obliques, transversus): a side bulge with the
    /// front held stretches it around the waist. 1: as calibrated. `breathstar prone` scans it.
    public var flankStiffness = 1.0
    /// Contacts resist only the uneven part of the surface's motion: the trunk may lift off the support
    /// as a whole (`withContacts`). false: springs on the motion relative to the spine (until 2026-11-11).
    public var contactFreeLift = false
    /// How firmly the trunk is held against lifting off its supports, 0 (free lift) to 1 (today's
    /// rule: springs relative to the spine). The fraction of weight the girdles carry (design note).
    public var contactAnchoring = 1.0

    /// The fraction of a bend's rim drop that becomes dome rise relative to the rim (Bending.swift):
    /// 1 = the abdominal contents stay put, 0 = they move with the rim. ASSUMED 0.5.
    public var bendDomeCoupling = 0.5
    /// Solve the bend's dome effect from the incompressible, fluid abdomen (`SidedBody.bendSettle`)
    /// instead of the assumed coupling.
    public var bendDomeSolved = false
    /// Build the seated base from Takashima's markers and Mendes's seated compartment volumes together
    /// (`VolumeShareTarget.mendesMenSeated`), not the markers alone. the work plan (private), item 2. Default since
    /// 2026-11-10: the markers stay 12/12 within SD (χ² 1.12 → 1.91) and the seated shares move from
    /// 32/12/56 to 40/15/45 (Mendes men 37/22/41). nil: markers only (the stage-2 builds).
    public var seatedVolumes: VolumeShareTarget? = .mendesMenSeated

    /// What sets the abdominal wall's pre-strain (Rule B on the wall).
    public enum WallLoad: String, Sendable { case frontPressure, heldColumn, axialColumn }
    public var wallLoad = WallLoad.axialColumn

    public init() {}
    public init(contactStiffness: Double, abdominalWallGain: Double) {
        self.contactStiffness = contactStiffness; self.abdominalWallGain = abdominalWallGain
    }
}

extension AnatomyModel {
    /// The resting geometry for a gravity direction: the three measured sections (seated, supine,
    /// side-lying; Takashima 2017) blended by gravity's squared components. ASSUMED: prone takes
    /// the supine section (front and back both flatten against the support), and in-between angles
    /// blend linearly in the squared components.
    public static func resting(gravity g: (x: Double, y: Double, z: Double)) -> AnatomyModel {
        let parts: [(AnatomyModel, Double)] = [(AnatomyModel(), g.z * g.z), (AnatomyModel.supine(), g.y * g.y),
                                               (AnatomyModel.rightSideDown(), g.x * g.x)]
        var m = AnatomyModel()
        m.profile = m.profile.indices.map { i in
            var ap = 0.0, w = 0.0
            for (a, t) in parts { ap += t * a.profile[i].ap; w += t * a.profile[i].width }
            return (m.profile[i].z, ap, w)
        }
        m.diaphragmTilt = parts.reduce(0) { $0 + $1.1 * $1.0.diaphragmTilt }
        return m
    }

    /// Rest position of a surface point (cm; x toward the left, y forward from the back, z up).
    func restPoint(z: Double, psi: Double, side: Side) -> (x: Double, y: Double, z: Double) {
        let (ap, w) = base(z), r = psi * .pi / 180
        return ((side == .left ? 1 : -1) * w * sin(r), ap / 2 * (1 + cos(r)), z)
    }
}

/// A contact patch's surface: heights, angles around each half-section, sides, and the outward
/// direction it resists (unit, body frame).
struct PatchSurface {
    var z: ClosedRange<Double>, psi: ClosedRange<Double>, sides: [Side], outward: (x: Double, y: Double, z: Double)
}

extension ContactPatch {
    func surface(_ a: AnatomyModel) -> PatchSurface {
        switch region {
        // Lying on the back: the ribcage's back and the sacrum bear weight; the lumbar curve is off
        // the floor (legs long). ASSUMED: the ribcage's back, ψ 140–180°, both sides.
        case .back: PatchSurface(z: a.costalMargin...a.top, psi: 140...180, sides: Side.allCases, outward: (0, -1, 0))
        // Lying on a side: the lateral wall from the iliac crest to the xiphoid (as the bed spring).
        case .flank(let s): PatchSurface(z: 1...a.xiphoid, psi: 60...120, sides: [s], outward: (s == .left ? 1 : -1, 0, 0))
        // Lying face down: the front of the chest and the belly, ψ 0–40°, both sides.
        case .front: PatchSurface(z: 1...a.top, psi: 0...40, sides: Side.allCases, outward: (0, 1, 0))
        case .chest: PatchSurface(z: a.xiphoid...a.top, psi: 0...40, sides: Side.allCases, outward: (0, 1, 0))
        case .belly: PatchSurface(z: 1...a.costalMargin, psi: 0...40, sides: Side.allCases, outward: (0, 1, 0))
        // Lying on the back with the knees bent: the pelvis rolls back and the lumbar curve comes down
        // onto the floor (docs/LESSON_ADAPTATION.md §4.6). ASSUMED: the back below the ribcage, ψ 140–180°.
        case .frontTo(let p): PatchSurface(z: 1...a.top, psi: 0...p, sides: Side.allCases, outward: (0, 1, 0))
        case .lowBack: PatchSurface(z: 1...a.costalMargin, psi: 140...180, sides: Side.allCases, outward: (0, -1, 0))
        }
    }
}

/// The resting state for a configuration, and what the breath layer takes from it.
public struct SettledState: Sendable {
    /// Coordinates at rest under gravity (relative to a weightless body), and the multipliers.
    public var q: [Double]
    /// End-expiratory lung volume change from weightless, litres, per side.
    public var lung: [Double]
    /// Each hemidiaphragm's displaced volume at rest, litres (+: descended).
    public var diaphragm: [Double]
    /// The abdominal wall's hydrostatic load, cmH2O (`GravityRules.WallLoad`).
    public var frontWallLoad: Double
}

extension SidedBody {
    /// Depth moments (L·cm) per unit of each coordinate: how far each coordinate moves the abdominal
    /// contents (index 0) and the thoracic contents (index 1) along x, y, z.
    func contentMoments() -> [[(x: Double, y: Double, z: Double)]] {
        let a = anatomy, n = SidedCoordinate.count, h = 1e-3
        let nz = 24, np = 18
        func flux(_ state: AnatomyState, z zs: ClosedRange<Double>) -> (x: Double, y: Double, z: Double) {
            var m = (x: 0.0, y: 0.0, z: 0.0)
            let dz = (zs.upperBound - zs.lowerBound) / Double(nz)
            for side in Side.allCases {
                for zi in 0..<nz {
                    let z = zs.lowerBound + (Double(zi) + 0.5) * dz
                    let (ap, w) = a.base(z)
                    for pi in 0..<np {
                        let psi = (Double(pi) + 0.5) / Double(np) * 180, r = psi * .pi / 180
                        // Outward normal of the half-ellipse in the section plane, and the arc length.
                        let nx0 = sin(r) / w, ny0 = cos(r) / (ap / 2), nn = (nx0 * nx0 + ny0 * ny0).squareRoot()
                        let tx = w * cos(r), ty = -ap / 2 * sin(r)
                        let ds = (tx * tx + ty * ty).squareRoot() * (.pi / Double(np))
                        let d = a.surfaceDisplacement(z: z, psiDegrees: psi, side: side, state)
                        let dn = (d.x * nx0 + d.y * ny0) / nn  // x outward on this side
                        let p = a.restPoint(z: z, psi: psi, side: side)
                        let dv = dn * ds * dz
                        m.x += p.x * dv; m.y += p.y * dv; m.z += p.z * dv
                    }
                }
            }
            return (m.x / 1000, m.y / 1000, m.z / 1000)
        }
        let dome = Side.allCases.map { side -> (x: Double, y: Double, z: Double) in
            let (ap, w) = a.base(0.5 * (a.costalMargin + a.xiphoid))
            return ((side == .left ? 1 : -1) * 4 * w / (3 * .pi), ap / 2 * (1 - a.diaphragmTilt / 4), 0.5 * (a.costalMargin + a.xiphoid))
        }
        let g = geometry
        return (0..<n).map { j in
            var e = [Double](repeating: 0, count: n); e[j] = h
            var em = e; em[j] = -h
            let sp = a.sidedState(e), sm = a.sidedState(em)
            func diff(_ zs: ClosedRange<Double>) -> (x: Double, y: Double, z: Double) {
                let p = flux(sp, z: zs), m = flux(sm, z: zs)
                return ((p.x - m.x) / (2 * h), (p.y - m.y) / (2 * h), (p.z - m.z) / (2 * h))
            }
            let wall = diff(0...a.costalMargin), lower = diff(a.costalMargin...a.xiphoid), upper = diff(a.xiphoid...a.top)
            var apposedShare = 0.0, lowerTotal = 0.0
            for k in 0..<2 { apposedShare += g.lowerApposed[k][j]; lowerTotal += g.lower(k)[j] }
            let f = abs(lowerTotal) > 1e-12 ? apposedShare / lowerTotal : 1
            var ab = (x: wall.x + f * lower.x, y: wall.y + f * lower.y, z: wall.z + f * lower.z)
            var th = (x: upper.x + (1 - f) * lower.x, y: upper.y + (1 - f) * lower.y, z: upper.z + (1 - f) * lower.z)
            for k in 0..<2 {
                let v = g.diaphragm[k][j], c = dome[k]
                ab.x -= v * c.x; ab.y -= v * c.y; ab.z -= v * c.z
                th.x += v * c.x; th.y += v * c.y; th.z += v * c.z
            }
            return [ab, th]
        }
    }

    /// The hydrostatic load on each coordinate (cmH2O·L per unit), gravity g in the body frame.
    public func hydrostaticLoad(gravity g: (x: Double, y: Double, z: Double), rules: GravityRules) -> [Double] {
        contentMoments().map { m in
            rules.abdominalGradient * (g.x * m[0].x + g.y * m[0].y + g.z * m[0].z)
                + rules.pleuralGradient * (g.x * m[1].x + g.y * m[1].y + g.z * m[1].z)
        }
    }

    /// The settle solve: the resting state under gravity (muscles relaxed), linear springs, the
    /// incompressible abdomen, both lungs, the mediastinum. The pleural gradient also acts across the
    /// mediastinum (the deeper lung's pleural pressure is higher).
    public func settle(gravity g: (x: Double, y: Double, z: Double), rules: GravityRules) -> SettledState {
        let n = SidedCoordinate.count
        var rhs = [Double](repeating: 0, count: n + 4)
        let load = hydrostaticLoad(gravity: g, rules: rules)
        for i in 0..<n { rhs[i] = load[i] }
        let (ap, w) = anatomy.base(0.5 * (anatomy.xiphoid + anatomy.top))
        let lungX = 4 * w / (3 * .pi)
        let depth = [g.x * lungX + g.y * ap / 2, -g.x * lungX + g.y * ap / 2]  // left, right
        rhs[n + 3] = mediastinalCompliance * rules.pleuralGradient * (depth[0] - depth[1])
        let x = multiply(invert(systemMatrix(flow: 0)), rhs)
        let q = Array(x[0..<n]), vm = x[n + 3]
        func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
        let lung = [dot(geometry.thorax(0)) + vm, dot(geometry.thorax(1)) - vm]
        // The abdominal pressure field is Pab + ρg·(g·x): Pab (the multiplier) is its value at the
        // origin. The wall's load, two measures (`GravityRules.WallLoad`):
        //   pressure at the middle of the front wall (the first stage-3 law), or
        //   the pressure the front wall holds back: the field's mean over the front wall (ψ 0–40°, pelvis
        //   to costal margin) above its least value there. Upright the wall spans the column of
        //   contents (≈ 9 cmH2O); lying on the back or front it lies at one depth (≈ 1).
        let pf = anatomy.restPoint(z: 0.5 * anatomy.costalMargin, psi: 0, side: .left)
        let frontLoad: Double
        switch rules.wallLoad {
        case .frontPressure:
            frontLoad = x[n + 2] + rules.abdominalGradient * (g.x * pf.x + g.y * pf.y + g.z * pf.z)
        case .heldColumn:
            var depths: [Double] = []
            for side in Side.allCases {
                for zi in 0..<12 {
                    for pi in 0..<5 {
                        let p = anatomy.restPoint(z: (Double(zi) + 0.5) / 12 * anatomy.costalMargin, psi: Double(pi) * 10, side: side)
                        depths.append(g.x * p.x + g.y * p.y + g.z * p.z)
                    }
                }
            }
            frontLoad = rules.abdominalGradient * (depths.reduce(0, +) / Double(depths.count) - depths.min()!)
        case .axialColumn:
            // Only the column along the trunk's length: the front wall is nearly flat head to foot
            // (large radius, so a pressure difference along it stretches it), and curved across the
            // section (hoop tension carries the sideways and front-to-back differences). ASSUMED.
            frontLoad = rules.abdominalGradient * abs(g.z) * 0.5 * anatomy.costalMargin
        }
        return SettledState(q: q, lung: lung, diaphragm: (0..<2).map { dot(geometry.diaphragm[$0]) }, frontWallLoad: frontLoad)
    }

    /// Contacts as couplings: each patch resists the mean outward motion of its surface, with the
    /// support's stiffness × the share of weight pressing into it × the patch area.
    public func withContacts(_ contacts: [ContactPatch], gravity g: (x: Double, y: Double, z: Double),
                             rules: GravityRules) -> SidedBody {
        var b = self
        let a = anatomy
        // Springs grouped by the support's normal, for the free lift below.
        var groups: [String: [(c: [Double], k: Double)]] = [:]
        for patch in contacts {
            let s = patch.surface(a)
            let into = g.x * s.outward.x + g.y * s.outward.y + g.z * s.outward.z  // weight pressing into the support
            guard into > 0.05 else { continue }  // the support bears no load: no contact
            // Each region (abdomen, lower ribcage, upper ribcage) and side the patch covers is its own
            // spring: one spring on a patch's mean motion would let one part push into the support
            // while another pulls away (found on prone, 2026-11-10).
            let cuts = [0.0, a.costalMargin, a.xiphoid, a.top]
            for k in 0..<3 {
                let lo = max(s.z.lowerBound, cuts[k]), hi = min(s.z.upperBound, cuts[k + 1])
                guard hi - lo > 0.5 else { continue }
                for side in s.sides {
                    let c = SidedBody.vector(a) { st in
                        let m = a.sectorMotion(z: lo...hi, psi: s.psi, side: side, st)
                        // sectorMotion's x is outward on that side; convert to the body frame.
                        let bx = (side == .left ? 1 : -1) * m.x
                        return (bx * s.outward.x + m.y * s.outward.y + m.z * s.outward.z) / 10  // mm → cm
                    }
                    // Sub-patch area, cm²: height × arc length over the sector.
                    let (ap, w) = a.base(0.5 * (lo + hi))
                    let arcPerRad = (0.5 * (w * w + ap * ap / 4)).squareRoot()
                    let area = (hi - lo) * arcPerRad * (s.psi.upperBound - s.psi.lowerBound) * .pi / 180
                    let spring = (c: c, k: rules.contactStiffness * into * area / 1000)
                    b.couplings.append(spring)
                    groups["\(s.outward.x),\(s.outward.y),\(s.outward.z)", default: []].append(spring)
                }
            }
        }
        // The free lift (`GravityRules.contactFreeLift`): a support holds the surface relative to the
        // room, not the spine, and the trunk can rise off it as a whole (its weight stays on the
        // support, so a uniform lift needs no extra force). Minimising the springs' energy over a lift
        // L along the normal leaves only the uneven part: Σ k_r (c_r·q − c̄·q)², i.e. the springs as
        // they are plus one coupling (c̄, −Σk) with c̄ = Σ k_r c_r / Σ k_r. (Positive semidefinite.)
        // Partly anchored (docs/STATUS.md, "Weight bearing beyond the trunk"): the lift is resisted by an anchor
        // spring k_a = K·a/(1 − a), leaving the coupling (c̄, −K(1 − a)). a = 1: today's rule.
        let anchoring = rules.contactFreeLift ? 0 : rules.contactAnchoring
        if anchoring < 1 {
            for (_, springs) in groups {
                let total = springs.reduce(0) { $0 + $1.k }
                guard total > 0 else { continue }
                var mean = [Double](repeating: 0, count: springs[0].c.count)
                for sp in springs { for i in mean.indices { mean[i] += sp.k * sp.c[i] / total } }
                b.couplings.append((mean, -total * (1 - max(0, anchoring))))
            }
        }
        return b
    }
}

/// A body built by the general rules, with what the settle solve found.
public struct RuleBody: Sendable {
    public var configuration: BodyConfiguration
    public var body: SidedBody
    public var settled: SettledState
    /// End-expiratory lung volume relative to seated, litres (+: larger).
    public var frcChange: Double
    /// Each hemidiaphragm's rise relative to seated, litres of displaced volume (left, right).
    public var domeRise: [Double]
    public var diaphragmForceScale: [Double]
    public var abdomenComplianceScale: Double
    /// The drive this configuration needs relative to seated, for the same breath (1 if not matched);
    /// with `regulated = .ribs` the diaphragm's (1) and the rib muscles' separately.
    public var driveScale: Double
    public var ribDriveScale: Double
    /// The tidal volume the seated drive would give here, litres.
    public var tidalAtSeatedDrive: Double
}

extension BodyGenerator {
    /// Stage 3: one parameter set (`GravityRules`) for every configuration; no per-posture factor.
    /// The seated muscle pressures carry over unchanged (the drive is the configuration's input), so
    /// tidal volume is predicted, not matched.
    public static func general(_ c: BodyConfiguration, rules: GravityRules = GravityRules(), drive: Drive = Drive()) -> RuleBody {
        let seated = seatedSymmetric(drive: drive, volumes: rules.seatedVolumes)
        let sym = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(seated.reference),
                                      passive: seated.passive).matchedToTidal(0.56, drive: drive)
        let up = (x: 0.0, y: 0.0, z: -1.0)
        let ref = sym.settle(gravity: up, rules: rules)
        var a0 = AnatomyModel.resting(gravity: c.gravity)
        if let legs = c.legs { a0.bulgePeak = legs.bulgePeak }
        let plain = SidedBody.from(seated: sym, anatomy: a0)
        let s = plain.settle(gravity: c.gravity, rules: rules)
        let linearChange = (s.lung[0] + s.lung[1]) - (ref.lung[0] + ref.lung[1])
        var squash = 1.0
        if let erv = rules.expiratoryReserve, abs(linearChange) > 1e-9 {
            let room = linearChange < 0 ? erv : rules.inspiratoryCapacity
            squash = room * tanh(abs(linearChange) / room) / abs(linearChange)
        }
        let bendRim = a0.rimDrop(c.spine)
        let bendRise: [Double]
        if c.spine.isNeutral { bendRise = [0, 0] }
        else if rules.bendDomeSolved { bendRise = plain.bent(c.spine, rules: rules).bendSettle(c.spine).rise }
        else { bendRise = (0..<2).map { rules.bendDomeCoupling * bendRim[$0] * a0.domeArea(side: $0) / 1000 } }
        let rise = (0..<2).map { -(s.diaphragm[$0] - ref.diaphragm[$0]) * squash + bendRise[$0] }
        let forceScale = rise.map { 1 + OperatingPoint.lengthTensionPerLitre * 2 * $0 }
        var a = a0
        for k in 0..<2 { a.appositionShiftBySide[k] += rise[k] * 1000 / a0.domeArea(side: k) }
        let wall = exp(-rules.abdominalWallGain * (s.frontWallLoad - ref.frontWallLoad))
        let dependent: Side? = abs(c.gravity.x) > 0.3 ? (c.gravity.x < 0 ? .right : .left) : nil
        var body = SidedBody.from(seated: sym, anatomy: a, abdomenComplianceScale: wall, diaphragmForceScale: forceScale,
                                  dependent: dependent)
            .bent(c.spine, rules: rules)
            .toned(c.tone)
            .carrying(c.carried)
            .withContacts(c.contacts, gravity: c.gravity, rules: rules)
        if rules.flankStiffness != 1 {
            for co in [SidedCoordinate.flankL, .flankR] { body.stiffness[co.rawValue] *= rules.flankStiffness }
        }
        if rules.uprightUpperDrive != 0 {
            let up = max(0, -c.gravity.z)
            let k = 1 - rules.uprightUpperDrive * (1 - (rules.uprightSquared ? up * up : up))
            for co in SidedCoordinate.allCases where co.symmetric == .upperRotation || co.symmetric == .upperDilation {
                body.peakForce[co.rawValue] *= k
            }
        }
        let free = SidedBreath.measure(body.simulate(drive: drive), period: drive.period).tidalVolume
        var driveScale = 1.0, ribDriveScale = 1.0
        if let target = rules.quietTidal {
            driveScale = target / free
            switch rules.regulated {
            case .all:
                body.peakForce = body.peakForce.map { $0 * driveScale }
                ribDriveScale = driveScale
            case .ribs:
                // Linear breath: the tidal volume is the diaphragm's part plus the ribs' part.
                let dia = SidedBreath.measure(body.silenced([.ribs]).simulate(drive: drive), period: drive.period).tidalVolume
                let ribs = free - dia
                let s = (target - dia) / ribs
                if s > 0 {
                    ribDriveScale = s; driveScale = 1
                    body.peakForce = SidedCoordinate.allCases.map { c in c.isRib ? body.peakForce[c.rawValue] * s : body.peakForce[c.rawValue] }
                } else {  // the diaphragm alone overshoots: scale everything
                    body.peakForce = body.peakForce.map { $0 * driveScale }
                    ribDriveScale = driveScale
                }
            }
        }
        return RuleBody(configuration: c, body: body, settled: s,
                        frcChange: linearChange * squash,
                        domeRise: rise, diaphragmForceScale: forceScale, abdomenComplianceScale: wall,
                        driveScale: driveScale, ribDriveScale: ribDriveScale, tidalAtSeatedDrive: free)
    }
}
