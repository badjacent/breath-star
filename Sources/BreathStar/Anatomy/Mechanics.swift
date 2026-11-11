import Foundation

// A2: mechanics on A1's anatomical coordinates, by virtual work. Linearised about end
// expiration (quiet breaths are a few millimetres), symmetric left/right for now.
//
// Coordinates q (both sides together):
//   0 upper band rotation        1 upper band dilation
//   2 lower band pump            3 lower band bucket
//   4 lower band AP dilation     5 lower band transverse dilation
//   6 diaphragm descent (cm)     7 abdominal front bulge (cm)
//
// The lower band's pump and bucket are separate: ribs 7–10 join the sternum through the
// costal-cartilage arch, so their front can move with the sternum while their sides swing out.
// A sternal coupling spring (the arch) ties the lower front's forward motion to the sternum's
// (the upper band's front), making the stiffness a full matrix: K = diag(k) + kc · c cᵀ.
//
// A1's geometry gives, for each coordinate, how much it changes each cavity. The lower
// ribcage's wall is split by what lies behind it, from the lung's lower edge (classical lines:
// 6th rib midclavicular, 8th midaxillary, 10th posterior): above it the wall faces lung; below
// it the diaphragm lies against the ribs (the zone of apposition) and the wall feels abdominal
// pressure. The front of the lower ribcage is mostly apposed; a lateral band faces lung.
//   J_th[i]  thoracic cavity  = upper region + lower region's lung-facing wall + diaphragm volume
//   J_ab[i]  abdominal cavity = lower region's apposed wall + abdomen region − diaphragm volume
//
// Equilibrium of each coordinate (elastic + pressures + muscles; no wall inertia):
//   K_i q_i = Ppl · J_th[i] + Pab · J_ab[i] + F_i(t)
// Lung (airway open at 0):  Ppl = −V_th / CL − R · dV_th/dt,  V_th = J_th · q
// Abdomen (incompressible contents): J_ab · q = 0, with Pab its pressure (a multiplier).
//
// Units: litres, cmH2O, seconds; a generalised force is in L·cmH2O per unit of its coordinate.

public enum A2Coordinate: Int, CaseIterable, Sendable {
    case upperRotation, upperDilation, lowerPump, lowerBucket, lowerDilationAP, lowerDilationTransverse, diaphragm, abdomen

    public static let count = allCases.count
    public static let ribs: [A2Coordinate] = [.upperRotation, .upperDilation, .lowerPump, .lowerBucket,
                                              .lowerDilationAP, .lowerDilationTransverse]
    public static let lowerBand: [A2Coordinate] = [.lowerPump, .lowerBucket, .lowerDilationAP, .lowerDilationTransverse]

    public var isRib: Bool { Self.ribs.contains(self) }

    public var label: String {
        switch self {
        case .upperRotation: "upper rib band, rotation"
        case .upperDilation: "upper rib band, dilation"
        case .lowerPump: "lower rib band, pump"
        case .lowerBucket: "lower rib band, bucket"
        case .lowerDilationAP: "lower rib band, AP dilation"
        case .lowerDilationTransverse: "lower band, transverse dilation"
        case .diaphragm: "diaphragm descent"
        case .abdomen: "abdominal wall bulge"
        }
    }
}

/// Muscle groups that can be silenced (what-ifs, patients).
public enum A2Muscles: Sendable { case ribs, diaphragm }

/// Region volumes per unit of each coordinate (litres), from A1's geometry.
public struct A2Geometry: Sendable {
    public var upperRegion: [Double]
    /// Lower ribcage region, split by what lies behind its wall: lung (thoracic cavity) above the
    /// lung's lower edge, the diaphragm (abdominal cavity, via apposition) below it.
    public var lowerLungFacing: [Double]
    public var lowerApposed: [Double]
    public var abdomenRegion: [Double]
    public var diaphragmVolume: [Double]

    public var lowerRegion: [Double] { zip(lowerLungFacing, lowerApposed).map { $0 + $1 } }
    public var thorax: [Double] { (0..<A2Coordinate.count).map { upperRegion[$0] + lowerLungFacing[$0] + diaphragmVolume[$0] } }
    public var abdominalCavity: [Double] {
        (0..<A2Coordinate.count).map { lowerApposed[$0] + abdomenRegion[$0] - diaphragmVolume[$0] }
    }
    /// The chest-wall volume a coordinate moves (its own compliance's volume). For the ribs and the
    /// abdominal wall this is the TOTAL surface volume it moves, not one compartment's share: with
    /// ring-bounded (surface) compartments, the lower ribs' rotation mostly transfers volume across
    /// the costal-margin ring into the abdominal compartment, so its own-region share is near zero
    /// and a region-based stiffness came out floppy (2026-11-09). For the diaphragm: its descent.
    public var own: [Double] {
        let low = lowerRegion
        let total = (0..<A2Coordinate.count).map { upperRegion[$0] + low[$0] + abdomenRegion[$0] }
        return [total[0], total[1], total[2], total[3], total[4], total[5], diaphragmVolume[6], total[7]]
    }
}

extension AnatomyModel {
    /// The symmetric anatomical state for coordinates q.
    public func a2State(_ q: [Double]) -> AnatomyState {
        var s = AnatomyState()
        s.upperRib = [q[0], q[0]]
        s.upperDilation = [q[1], q[1]]
        s.lowerPump = q[2]
        s.lowerRib = [q[3], q[3]]
        s.lowerDilationAP = q[4]
        s.lowerDilation = [q[5], q[5]]
        s.diaphragm = [q[6], q[6]]
        s.abdomenFront = q[7]
        s.abdomenFlank = [q[7] * flankRatio, q[7] * flankRatio]
        return s
    }

    /// Coordinates of a symmetric A1 state.
    public func a2Coordinates(_ s: AnatomyState) -> [Double] {
        [s.upperRib[0], s.upperDilation[0], s.lowerPump ?? 0.5 * (s.lowerRib[0] + s.lowerRib[1]), s.lowerRib[0],
         s.lowerDilationAP, s.lowerDilation[0], s.diaphragm[0], s.abdomenFront]
    }

    /// Height (cm above the iliac crests) of the lung's lower edge at angle ψ around the trunk
    /// (0° front midline, 90° side, 180° spine). Above it the chest wall faces lung (pleural
    /// pressure); below it, down to the costal margin, the diaphragm lies against the ribs (the
    /// zone of apposition), so the wall feels abdominal pressure through it.
    /// Rib levels are classical surface anatomy (textbook): the lung's lower border crosses
    /// the 6th rib at the midclavicular line, the 8th at the midaxillary line and the 10th
    /// posteriorly. Consistent with Tanaka et al. 2026 (the lung is avoided at the 7th space and
    /// below in front of the anterior axillary line). The HEIGHTS those ribs sit at in this
    /// model's trunk are ASSUMED: front ~26 cm (just above the xiphoid, 25), midclavicular 25,
    /// midaxillary 20.5, posterior 23 (posterior ribs sit higher than their fronts).
    /// Replaces an earlier ±45° "front faces lung" rule, which rested on a misread source.
    public func lungEdgeHeight(psiDegrees psi: Double, side: Side = .left) -> Double {
        let points: [(Double, Double)] = [(0, 26), (35, 25), (90, 20.5), (160, 23), (180, 23.5)]
        // The operating point's rise, tilted like the diaphragm: u = −cos ψ (−1 front, +1 back).
        let net = appositionShift + appositionShiftBySide[side.rawValue] - appositionDescent
        let shift = tiltedApposition ? diaphragmDescent(net, at: -cos(psi * .pi / 180)) : net
        for (a, b) in zip(points, points.dropFirst()) where psi <= b.0 {
            let t = (psi - a.0) / (b.0 - a.0)
            return a.1 + max(0, min(1, t)) * (b.1 - a.1) + shift
        }
        return points.last!.1 + shift
    }

    /// Volume flux, litres, through the lower ribcage's wall (both sides), counting only the
    /// lung-facing part (above the lung edge) or only the apposed part (below it):
    /// ∫∫ u · n ds dz, with n ds = (b sinψ, w cosψ) dψ on the half-ellipse x = w sinψ,
    /// y = b(1 + cosψ). Both parts together equal the region's (first-order) volume change.
    func lowerFlux(_ s: AnatomyState, lungFacing: Bool, sides: [Side] = Side.allCases) -> Double {
        let nz = 28, np = 72
        var v = 0.0
        let dpsi = Double.pi / Double(np)
        for ip in 0..<np {
            let psiDeg = (Double(ip) + 0.5) / Double(np) * 180
            let psi = psiDeg * .pi / 180
            let bottom = ribBottom(psiDegrees: psiDeg)  // the ribs' lower edge (flat unless lateralRibMargin)
            let dz = (xiphoid - bottom) / Double(nz)
            for iz in 0..<nz {
                let z = bottom + (Double(iz) + 0.5) * dz
                let (ap, w) = base(z)
                let b = ap / 2
                for side in sides {
                    guard (z >= lungEdgeHeight(psiDegrees: psiDeg, side: side)) == lungFacing else { continue }
                    let u = surfaceDisplacement(z: z, psiDegrees: psiDeg, side: side, s)
                    v += (u.x * b * sin(psi) + u.y * w * cos(psi)) * dpsi * dz
                }
            }
        }
        return v / 1000
    }

    /// Jacobians at end expiration, by central differences of A1's geometry.
    public func a2Geometry() -> A2Geometry {
        let n = A2Coordinate.count
        let steps = [1e-3, 1e-4, 1e-3, 1e-3, 1e-4, 1e-4, 1e-2, 1e-2]
        var up = [Double](repeating: 0, count: n), front = up, back = up, ab = up, dia = up
        for i in 0..<n {
            var plus = [Double](repeating: 0, count: n), minus = plus
            plus[i] = steps[i]
            minus[i] = -steps[i]
            let sp = a2State(plus), sm = a2State(minus)
            let a = observe(sp), b = observe(sm)
            func d(_ f: (AnatomyObservables) -> [Double]) -> Double {
                (f(a).reduce(0, +) - f(b).reduce(0, +)) / (2 * steps[i])
            }
            up[i] = d { $0.upperRibcage }
            ab[i] = d { $0.abdomen }
            dia[i] = d { $0.diaphragmVolume }
            // Split the lower region's change by the wall it passes through, then scale both parts
            // so they sum exactly to the region's (section-integrated) change.
            let lower = d { $0.lowerRibcage }
            let f = (lowerFlux(sp, lungFacing: true) - lowerFlux(sm, lungFacing: true)) / (2 * steps[i])
            let r = (lowerFlux(sp, lungFacing: false) - lowerFlux(sm, lungFacing: false)) / (2 * steps[i])
            let total = f + r
            if abs(total) > 1e-12 {
                front[i] = lower * f / total
                back[i] = lower * r / total
            } else {
                front[i] = 0
                back[i] = lower
            }
        }
        return A2Geometry(upperRegion: up, lowerLungFacing: front, lowerApposed: back, abdomenRegion: ab,
                          diaphragmVolume: dia)
    }
}

/// Passive properties. Every value says where it comes from.
public struct A2Passive: Sendable {
    /// Lung compliance, L/cmH2O, and resistance, cmH2O·s/L (textbook, as in M0–M1).
    public var lungCompliance = 0.2
    public var resistance = 2.0
    /// Passive (relaxed, tone-free) ribcage compliance, L/cmH2O (textbook: chest wall ~0.2 split
    /// ribcage/abdomen; Estenne 1983 measured relaxed chest-wall compliance 0.248 ± 0.013 in 20
    /// healthy adults). Split between the bands in proportion to their regions' resting volumes;
    /// the upper band half rotation, half dilation; the lower band half rotation, a quarter each
    /// AP and transverse dilation. The splits are ASSUMED.
    public var ribcageCompliance = 0.11
    /// Tonic rib-muscle activity during healthy breathing, as extra ribcage stiffness:
    /// K = passive × (1 + tone). Druz & Sharp 1981 report tonic scalene and parasternal activity,
    /// more upright than supine, but no size. UNSOURCED; 0 by default, swept in the reports.
    public var ribcageTone = 0.0
    /// Passive abdominal wall compliance, L/cmH2O (textbook split of ~0.2 chest wall). ASSUMED.
    public var abdomenCompliance = 0.09
    /// Passive diaphragm compliance, L/cmH2O: the relaxed muscle sheet is slack. ASSUMED.
    public var diaphragmCompliance = 1.0
    /// Which volume a coordinate's passive stiffness is scaled by, K = volume² / compliance. With
    /// ring-bounded (surface) compartments the choice matters, because lifting the ribs hands
    /// volume across the costal-margin ring (the working log (private), "stiffness basis"). ASSUMED.
    public enum StiffnessBasis: String, Sendable, CaseIterable {
        /// The coordinate's own compartment (upper or lower ribcage; abdomen; diaphragm).
        case ownCompartment
        /// The ribcage compartments together (upper + lower) for rib coordinates.
        case ribcage
        /// All chest-wall compartments together.
        case chestWall
    }
    /// Default .ribcage: the textbook ribcage compliance is defined on the ribcage compartments'
    /// volume (relaxation studies), so a rib coordinate's stiffness scales with its effect on that
    /// volume. Chosen after comparing all three (own compartment: floppy; chest wall: no
    /// paradoxes; ribcage: 7/7 seated directions), so a selection effect is possible.
    public var stiffnessBasis: StiffnessBasis = .ribcage

    /// Extra stiffness on a coordinate (a hold, a hand), as a multiplier. 1 = none.
    public var stiffen = [Double](repeating: 1, count: A2Coordinate.count)

    /// Stiffness of the costal-cartilage arch tying the lower band's front to the sternum, as a
    /// multiple of the lower pump's own spring. ASSUMED 10 (a stiff arch); swept in the reports.
    public var sternalCoupling = 10.0

    /// Chronic respiratory-muscle weakness stiffens the relaxed chest wall: Estenne et al. 1983,
    /// compliance 0.162 ± 0.012 in 16 patients against 0.248 ± 0.013 in 20 controls (×1.53).
    public static let chronicWeaknessStiffening = 0.248 / 0.162

    public init() {}
}

/// One calibrated A2 body: stiffnesses, and the muscle forces that produce a reference breath.
public struct A2Body: Sendable {
    public var anatomy: AnatomyModel
    public var geometry: A2Geometry
    public var passive: A2Passive
    /// Diagonal stiffness per coordinate, L·cmH2O per unit².
    public var stiffness: [Double]
    /// Sternal coupling: c (cm per unit of each coordinate) is the sternum's forward motion minus
    /// the lower band's front's; the arch adds kc · c cᵀ to the stiffness.
    public var coupling: [Double] = []
    public var couplingStiffness: Double = 0

    /// The full stiffness matrix.
    public var stiffnessMatrix: [[Double]] {
        let n = A2Coordinate.count
        return (0..<n).map { i in (0..<n).map { j in
            (i == j ? stiffness[i] : 0) + (coupling.isEmpty ? 0 : couplingStiffness * coupling[i] * coupling[j])
        } }
    }
    /// Muscle forces at the reference breath's end inspiration (generalised, per coordinate).
    public var peakForce: [Double]
    /// The reference end-inspiratory state and its pressures.
    public var reference: [Double]
    public var referencePleural: Double
    public var referenceAbdominal: Double
    /// Per-coordinate activation ONSET delay, seconds (empty: every muscle group in phase). Each
    /// group starts later and rises faster; all release together at the end of inspiration (the
    /// brainstem's inspiratory off-switch is common). Shifting the whole waveform instead made the
    /// shares depend on tens of milliseconds, because the lung peaks during the release
    /// (the working log (private), "timing").
    public var delay: [Double] = []
    /// Diaphragm relaxation time after inspiration, s (nil: the drive's, shared by every group).
    /// Longer = post-inspiratory braking: the diaphragm keeps some activity into early expiration,
    /// slowing the lung's emptying (present in healthy subjects; size unsourced). Diaphragm-only
    /// braking beyond ~0.32 s puts the seated breath out of healthy synchrony; braking shared by all
    /// inspiratory muscles (the drive's relaxationTime) doesn't. Off by default.
    public var diaphragmRelaxation: Double? = nil
    /// Expiratory abdominal muscle pressure, cmH2O at peak (transversus abdominis and obliques
    /// drawing the wall in during expiration; Abe et al. 1996). 0 = relaxed. Size UNSOURCED; healthy
    /// synchrony bounds it to ~0.2 cmH2O seated (`breathstar expiration-bounds`). Off by default.
    public var expiratoryAbdominalPressure = 0.0
    /// External pressure pressing a region's wall in during expiration, cmH2O per coordinate (a
    /// therapist's expiratory assist, 呼吸介助: pressing from the start of expiration until just before
    /// inspiration, released for inspiration; Kouyama et al. 2016). Empty: none. Plateau waveform
    /// (Drive.expiratoryPlateau).
    public var externalExpiratoryPressure: [Double] = []

    /// Calibrate on a reference end-inspiratory state (A1's, matched to markers).
    /// The abdominal muscles are relaxed in quiet breathing (no force on the wall), which
    /// fixes the abdominal pressure; every other coordinate's muscle force is then whatever
    /// equilibrium requires. That required force is a RESULT, not an input.
    public static func calibrate(anatomy: AnatomyModel, reference q: [Double],
                                 passive: A2Passive = A2Passive()) -> A2Body {
        let g = anatomy.a2Geometry()
        let k = passiveStiffness(anatomy: anatomy, geometry: g, passive: passive)
        let (c, kc) = sternalCoupling(anatomy: anatomy, stiffness: k, factor: passive.sternalCoupling)
        let jth = g.thorax, jab = g.abdominalCavity
        let a = A2Coordinate.abdomen.rawValue
        // A1's closure counted the whole lower ribcage as abdominal; here only its apposed wall
        // is. Re-close the reference with the abdominal wall.
        var q = q
        q[a] = -(0..<A2Coordinate.count).filter { $0 != a }.reduce(0.0) { $0 + jab[$1] * q[$1] } / jab[a]
        let vth = zip(jth, q).reduce(0) { $0 + $1.0 * $1.1 }
        let ppl = -vth / passive.lungCompliance  // end inspiration: no flow
        var body = A2Body(anatomy: anatomy, geometry: g, passive: passive, stiffness: k, peakForce: [],
                          reference: q, referencePleural: ppl, referenceAbdominal: 0)
        body.coupling = c
        body.couplingStiffness = kc
        let kq = multiply(body.stiffnessMatrix, q)
        let pab = (kq[a] - ppl * jth[a]) / jab[a]
        var force = (0..<A2Coordinate.count).map { kq[$0] - ppl * jth[$0] - pab * jab[$0] }
        force[a] = 0
        body.peakForce = force
        body.referenceAbdominal = pab
        return body
    }

    /// The sternal-coupling vector and stiffness. c_i is how much coordinate i moves the
    /// sternum forward (the upper band's front, just above the band blend) minus the lower band's
    /// front (mid lower ribcage), cm per unit; kc = factor × the lower pump's spring / c_pump².
    static func sternalCoupling(anatomy: AnatomyModel, stiffness k: [Double], factor: Double) -> ([Double], Double) {
        let n = A2Coordinate.count
        let zSternum = anatomy.xiphoid + AnatomyModel.bandBlend + 0.5
        let zLower = 0.5 * (anatomy.costalMargin + anatomy.xiphoid)
        let c = (0..<n).map { i -> Double in
            var q = [Double](repeating: 0, count: n)
            q[i] = 1e-3
            let s = anatomy.a2State(q)
            let sternum = anatomy.surfaceDisplacement(z: zSternum, psiDegrees: 0, side: .left, s).y
            let lower = anatomy.surfaceDisplacement(z: zLower, psiDegrees: 0, side: .left, s).y
            return (sternum - lower) / 1e-3
        }
        let p = A2Coordinate.lowerPump.rawValue
        return (c, factor * k[p] / (c[p] * c[p]))
    }

    /// Diagonal passive stiffness from compliances: K = (own volume per unit)² / compliance.
    static func passiveStiffness(anatomy: AnatomyModel, geometry g: A2Geometry, passive: A2Passive) -> [Double] {
        let restUpper = anatomy.sliceVolume(AnatomyState(), from: anatomy.xiphoid, to: anatomy.top, side: 0)
        let restLower = anatomy.sliceVolume(AnatomyState(), from: anatomy.costalMargin, to: anatomy.xiphoid, side: 0)
        let upperC = passive.ribcageCompliance * restUpper / (restUpper + restLower)
        let lowerC = passive.ribcageCompliance - upperC
        let compliance = [upperC / 2, upperC / 2, lowerC / 4, lowerC / 4, lowerC / 4, lowerC / 4,
                          passive.diaphragmCompliance, passive.abdomenCompliance]
        let low = g.lowerRegion
        let basis: [Double] = (0..<A2Coordinate.count).map { i in
            let c = A2Coordinate(rawValue: i)!
            if c == .diaphragm { return g.diaphragmVolume[i] }
            if c == .abdomen { return passive.stiffnessBasis == .chestWall ? g.own[i] : g.abdomenRegion[i] }
            switch passive.stiffnessBasis {
            case .ownCompartment: return (c == .upperRotation || c == .upperDilation) ? g.upperRegion[i] : low[i]
            case .ribcage: return g.upperRegion[i] + low[i]
            case .chestWall: return g.own[i]
            }
        }
        return (0..<A2Coordinate.count).map { i in
            let tone = A2Coordinate(rawValue: i)!.isRib ? 1 + passive.ribcageTone : 1
            return basis[i] * basis[i] / compliance[i] * passive.stiffen[i] * tone
        }
    }

    /// The same body in another posture: that posture's geometry (so new Jacobians), the
    /// same muscle PRESSURES as `seated` (force-as-pressure × the new own-region volume), and
    /// two posture effects on the passive walls:
    ///   - ribcageStiffnessScale: the trunk's weight on a support pins the ribcage (M1's contact);
    ///   - abdomenComplianceScale: without gravity hanging the viscera on it, the abdominal
    ///     wall is softer (M0's axial-gravity stiffening, inverted).
    /// `reference`, `referencePleural` and `referenceAbdominal` keep the seated values.
    public static func inPosture(anatomy: AnatomyModel, from seated: A2Body,
                                 abdomenComplianceScale: Double, ribcageStiffnessScale: Double,
                                 ribMuscleScale: Double = 1, diaphragmForceScale: Double = 1,
                                 passiveDiaphragmCompliance: Double? = nil, ribcageTone: Double? = nil) -> A2Body {
        let g = anatomy.a2Geometry()
        var passive = seated.passive
        passive.abdomenCompliance *= abdomenComplianceScale
        if let c = passiveDiaphragmCompliance { passive.diaphragmCompliance = c }
        if let t = ribcageTone { passive.ribcageTone = t }
        var k = passiveStiffness(anatomy: anatomy, geometry: g, passive: passive)
        let (coupling, kc) = sternalCoupling(anatomy: anatomy, stiffness: k, factor: passive.sternalCoupling)
        for c in A2Coordinate.ribs { k[c.rawValue] *= ribcageStiffnessScale }
        let force = (0..<A2Coordinate.count).map { i -> Double in
            if i == A2Coordinate.abdomen.rawValue { return 0 }
            let c = A2Coordinate(rawValue: i)!
            let scale = c.isRib ? ribMuscleScale : c == .diaphragm ? diaphragmForceScale : 1
            return seated.forceAsPressure(i) * g.own[i] * scale
        }
        var body = A2Body(anatomy: anatomy, geometry: g, passive: passive, stiffness: k, peakForce: force,
                          reference: seated.reference, referencePleural: seated.referencePleural,
                          referenceAbdominal: seated.referenceAbdominal)
        body.coupling = coupling
        body.couplingStiffness = kc * ribcageStiffnessScale
        body.delay = seated.delay
        body.diaphragmRelaxation = seated.diaphragmRelaxation
        return body
    }

    /// Which second mechanism explains a posture's smaller rib motion.
    public enum PostureHypothesis: String, Sendable, CaseIterable {
        /// A: the support pins the ribcage (passive stiffening, as M1's contact). The default:
        /// an effective restraint, mechanism unspecified. Kept over B because B overshoots the
        /// healthy supine rib markers (the working log (private), "hypothesis B as default: no").
        case ribcageStiffness
        /// B: the rib muscles are driven less (Druz & Sharp 1981: less scalene,
        /// sternocleidomastoid and parasternal activity supine); the cage stays as compliant.
        case ribMuscleDrive
    }

    /// Fit the posture's abdominal compliance and its second mechanism (A or B) to a breath.
    public static func fitPosture(anatomy: AnatomyModel, from seated: A2Body, abdomenShare target: Double,
                                  tidal: Double, hypothesis: PostureHypothesis, diaphragmForceScale: Double = 1,
                                  passiveDiaphragmCompliance: Double? = nil, ribcageTone: Double? = nil,
                                  drive: Drive = Drive())
        -> (body: A2Body, abdomenComplianceScale: Double, secondScale: Double) {
        func make(_ ab: Double, _ x: Double) -> A2Body {
            switch hypothesis {
            case .ribcageStiffness:
                return inPosture(anatomy: anatomy, from: seated, abdomenComplianceScale: ab, ribcageStiffnessScale: x,
                                 diaphragmForceScale: diaphragmForceScale, passiveDiaphragmCompliance: passiveDiaphragmCompliance,
                                 ribcageTone: ribcageTone)
            case .ribMuscleDrive:
                return inPosture(anatomy: anatomy, from: seated, abdomenComplianceScale: ab, ribcageStiffnessScale: 1,
                                 ribMuscleScale: x, diaphragmForceScale: diaphragmForceScale,
                                 passiveDiaphragmCompliance: passiveDiaphragmCompliance, ribcageTone: ribcageTone)
            }
        }
        func breath(_ ab: Double, _ x: Double) -> SignedBreath {
            SignedBreath.measure(make(ab, x).simulate(drive: drive, cycles: 2, timeStep: 0.004), period: drive.period)
        }
        func bisect(_ lo0: Double, _ hi0: Double, _ below: (Double) -> Bool) -> Double {
            var lo = log(lo0), hi = log(hi0)
            for _ in 0..<36 {
                let mid = 0.5 * (lo + hi)
                if below(exp(mid)) { lo = mid } else { hi = mid }
            }
            return exp(0.5 * (lo + hi))
        }
        func shareFit(_ x: Double) -> Double { bisect(0.02, 50) { breath($0, x).abdomenShare < target } }
        // A: stiffer cage → less volume. B: more rib drive → more volume.
        let x: Double
        switch hypothesis {
        case .ribcageStiffness: x = bisect(0.05, 50) { breath(shareFit($0), $0).tidalVolume > tidal }
        case .ribMuscleDrive: x = bisect(0.01, 20) { breath(shareFit($0), $0).tidalVolume < tidal }
        }
        let ab = shareFit(x)
        return (make(ab, x), ab, x)
    }

    /// The pressure-equivalent of a coordinate's muscle force: the force divided by the volume
    /// that coordinate moves in its own region, cmH2O. For the diaphragm, its active Pdi.
    public func forceAsPressure(_ i: Int) -> Double { peakForce[i] / geometry.own[i] }

    /// A copy whose muscle forces are scaled so the simulated (dynamic) breath reaches the
    /// target tidal volume. The calibration is static (end inspiration, no flow); with airway
    /// resistance the lungs never quite reach it. The model is linear, so one scale suffices
    /// and leaves every share unchanged.
    public func matchedToTidal(_ target: Double, drive: Drive = Drive()) -> A2Body {
        let m = SignedBreath.measure(simulate(drive: drive), period: drive.period)
        var b = self
        b.peakForce = peakForce.map { $0 * target / m.tidalVolume }
        return b
    }

    /// A copy with modified passive properties (a hold, a hand) and/or muscle forces,
    /// keeping the same geometry.
    public func modified(stiffen: [Double]? = nil, forceScale: [Double]? = nil) -> A2Body {
        var b = self
        if let st = stiffen {
            b.stiffness = (0..<A2Coordinate.count).map { stiffness[$0] * st[$0] }
            b.passive.stiffen = st
        }
        if let fs = forceScale { b.peakForce = (0..<A2Coordinate.count).map { peakForce[$0] * fs[$0] } }
        return b
    }

    /// A healthy body with some muscle groups' phasic forces switched off (tone kept).
    public func silenced(_ groups: Set<A2Muscles>) -> A2Body {
        modified(forceScale: A2Coordinate.allCases.map { c in
            (groups.contains(.ribs) && c.isRib) || (groups.contains(.diaphragm) && c == .diaphragm) ? 0 : 1
        })
    }

    /// A healthy body with some coordinates stiffened (a hold, a hand).
    public func stiffened(_ coordinates: [A2Coordinate], by factor: Double) -> A2Body {
        modified(stiffen: A2Coordinate.allCases.map { coordinates.contains($0) ? factor : 1 })
    }

    /// A patient: the paralysed groups' forces off, the rib muscles' tone gone (paralysed rib
    /// muscles have none), and, if chronic, the relaxed ribcage and abdominal wall stiffened as
    /// Estenne et al. 1983 measured (×1.53).
    public func asPatient(paralysed groups: Set<A2Muscles>, chronic: Bool) -> A2Body {
        var b = silenced(groups)
        let chronicFactor = chronic ? A2Passive.chronicWeaknessStiffening : 1
        for c in A2Coordinate.allCases {
            if c.isRib, groups.contains(.ribs) { b.stiffness[c.rawValue] /= 1 + passive.ribcageTone }
            if c.isRib || c == .abdomen { b.stiffness[c.rawValue] *= chronicFactor }
        }
        if groups.contains(.ribs) { b.passive.ribcageTone = 0 }
        return b
    }
}

public struct A2Sample: Sendable {
    public var time: Double
    public var q: [Double]
    public var pleural: Double
    public var abdominal: Double
    public var upperRegion: Double, lowerRegion: Double, abdomenRegion: Double, lung: Double
}

extension A2Body {
    /// Simulate cycles of the drive: muscle forces follow the activation waveform.
    public func simulate(drive: Drive = Drive(), cycles: Int = 4, timeStep: Double = 0.002) -> [A2Sample] {
        let n = A2Coordinate.count, dt = timeStep
        let jth = geometry.thorax, jab = geometry.abdominalCavity
        let cl = passive.lungCompliance, r = passive.resistance
        // Unknowns: q[0..n-1], Ppl (n), Pab (n+1).
        var a = [[Double]](repeating: [Double](repeating: 0, count: n + 2), count: n + 2)
        let kfull = stiffnessMatrix
        for i in 0..<n {
            for j in 0..<n { a[i][j] = kfull[i][j] }
            a[i][n] = -jth[i]
            a[i][n + 1] = -jab[i]
            a[n][i] = (1 / cl + r / dt) * jth[i]
            a[n + 1][i] = jab[i]
        }
        a[n][n] = 1
        let inverse = invert(a)
        let steps = Int((Double(cycles) * drive.period / dt).rounded())
        var previousVth = 0.0
        var out: [A2Sample] = []
        out.reserveCapacity(steps + 1)
        for k in 0...steps {
            let t = Double(k) * dt
            var rhs = [Double](repeating: 0, count: n + 2)
            for i in 0..<n {
                let tau = i == A2Coordinate.diaphragm.rawValue ? diaphragmRelaxation : nil
                rhs[i] = peakForce[i] * drive.activation(at: t, onsetDelay: delay.isEmpty ? 0 : delay[i], relaxation: tau)
            }
            if !externalExpiratoryPressure.isEmpty {
                let e = drive.expiratoryPlateau(at: t)
                for i in 0..<n where externalExpiratoryPressure[i] != 0 {
                    rhs[i] -= externalExpiratoryPressure[i] * abs(geometry.own[i]) * e
                }
            }
            if expiratoryAbdominalPressure != 0 {
                // A pressure drawing the wall in: generalised force = −P × the volume the wall moves.
                let a = A2Coordinate.abdomen.rawValue
                rhs[a] -= expiratoryAbdominalPressure * geometry.own[a] * drive.expiratoryActivation(at: t)
            }
            rhs[n] = r / dt * previousVth
            let x = multiply(inverse, rhs)
            let q = Array(x[0..<n])
            func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
            previousVth = dot(jth)
            out.append(A2Sample(time: t, q: q, pleural: x[n], abdominal: x[n + 1],
                                upperRegion: dot(geometry.upperRegion), lowerRegion: dot(geometry.lowerRegion),
                                abdomenRegion: dot(geometry.abdomenRegion), lung: previousVth))
        }
        return out
    }
}

/// Signed contributions (critique point 2): each region's change between the same two
/// instants of the breath, end expiration and end inspiration (the lung's minimum and
/// maximum over the last cycle). A region moving inward while the lung fills is negative.
/// Shares sum to 1 exactly, because the regions' changes sum to the lung's.
public struct SignedBreath: Sendable {
    public var tidalVolume: Double
    public var upper: Double, lower: Double, abdomen: Double
    public var upperShare: Double { upper / tidalVolume }
    public var lowerShare: Double { lower / tidalVolume }
    public var abdomenShare: Double { abdomen / tidalVolume }

    public static func measure(_ samples: [A2Sample], period: Double) -> SignedBreath {
        let end = samples.last!.time
        let cycle = samples.filter { $0.time >= end - period }
        let lo = cycle.min { $0.lung < $1.lung }!, hi = cycle.max { $0.lung < $1.lung }!
        return SignedBreath(tidalVolume: hi.lung - lo.lung, upper: hi.upperRegion - lo.upperRegion,
                            lower: hi.lowerRegion - lo.lowerRegion, abdomen: hi.abdomenRegion - lo.abdomenRegion)
    }
}

extension A2Body {
    /// Coordinates at end inspiration (the lung's maximum) over the last simulated cycle.
    public func endInspiration(drive: Drive = Drive(), timeStep: Double = 0.002) -> [Double] {
        let sim = simulate(drive: drive, timeStep: timeStep)
        let last = sim.suffix(Int(drive.period / timeStep))
        return last.max { $0.lung < $1.lung }!.q
    }

    /// Diameter changes over the breath at a height, cm: front-to-back (AP) and side-to-side
    /// (transverse, both sides), from the anatomical shape at end inspiration.
    public func diameterChanges(atHeight z: Double, drive: Drive = Drive()) -> (ap: Double, transverse: Double) {
        let q = endInspiration(drive: drive)
        let end = anatomy.section(z, anatomy.a2State(q)), rest = anatomy.section(z, AnatomyState())
        return (end.ap - rest.ap, end.halfWidth.reduce(0, +) - rest.halfWidth.reduce(0, +))
    }
}

// MARK: - Gravity through the operating point

/// A posture's operating point: where end expiration sits, relative to seated. Lying down, the
/// abdominal contents push the diaphragm headward and resting lung volume (FRC) falls (Ibañez &
/// Raurich 1982: always, in 100 healthy adults; Sonpeayung 2019: ERV 1.12 → 0.90 L in healthy men,
/// i.e. ~0.22 L; textbook figures are larger). Effects on the breath taken from there:
///   - the diaphragm is longer, so it makes more force per activation: Smith & Bellemare 1987,
///     twitch Pdi 49 → 20 cmH2O from RV to TLC, ~15% per litre at FRC (scaled by a 4.53 L VC,
///     Sonpeayung's healthy FVC, assumed linear);
///   - the dome sits higher, so the zone of apposition is taller by the dome's rise.
public struct OperatingPoint: Sendable {
    /// Fall in end-expiratory lung volume relative to seated, litres.
    public var frcDrop: Double
    public static let lengthTensionPerLitre = (49.1 - 19.6) / 4.53 / (49.1 - (49.1 - 19.6) * 1.12 / 4.53)

    public init(frcDrop: Double) { self.frcDrop = frcDrop }

    public var diaphragmForceScale: Double { 1 + Self.lengthTensionPerLitre * frcDrop }

    /// The dome's rise, cm: the volume drop over both hemidiaphragms' effective area.
    public func domeRise(_ anatomy: AnatomyModel) -> Double {
        frcDrop * 1000 / (anatomy.domeArea(side: 0) + anatomy.domeArea(side: 1))
    }

    /// The anatomy with its zone of apposition raised by the dome's rise.
    public func apply(to anatomy: AnatomyModel) -> AnatomyModel {
        var a = anatomy
        a.appositionShift += domeRise(anatomy)
        return a
    }
}


// MARK: - Timing between muscle groups

/// When each muscle group starts, relative to the diaphragm, as a fraction of inspiratory time.
/// Source: single motor units in quiet seated breathing (5 subjects; AUPS Proceedings 33:35P,
/// recruitment after inspiratory flow onset, % of Ti): diaphragm 21.7, scalenes 21.0, parasternal
/// intercostals 31.6, dorsal external intercostals 3rd space 30.4, 5th space 41.7. Mapped onto A2's
/// effective drives (which are not single muscles):
///   upper band (scalenes and upper parasternals): +5% of Ti (mean of −0.7 and +9.9);
///   lower band (lower parasternals, lower external intercostals): +15% (between +9.9 and +20.0).
/// The mapping is ASSUMED; sweep it. With a common release (onsets only), this timing gives a
/// ribcage–abdomen phase angle of +2.6° seated, inside healthy synchrony (Priori 2013: none in
/// controls; −5° to +4° by motion capture), so it is the default (the working log (private), "timing").
public struct MuscleTiming: Sendable {
    public var upperBand: Double
    public var lowerBand: Double
    public var diaphragm: Double

    public init(upperBand: Double = 0.05, lowerBand: Double = 0.15, diaphragm: Double = 0) {
        self.upperBand = upperBand; self.lowerBand = lowerBand; self.diaphragm = diaphragm
    }
    public static let inPhase = MuscleTiming(upperBand: 0, lowerBand: 0)

    /// Delays (s) per A2 coordinate for a drive.
    public func delays(_ drive: Drive) -> [Double] {
        let ti = drive.dutyCycle * drive.period
        return A2Coordinate.allCases.map { c in
            switch c {
            case .upperRotation, .upperDilation: upperBand * ti
            case .lowerPump, .lowerBucket, .lowerDilationAP, .lowerDilationTransverse: lowerBand * ti
            case .diaphragm: diaphragm * ti
            case .abdomen: 0
            }
        }
    }
}

extension A2Body {
    public func timed(_ timing: MuscleTiming, drive: Drive = Drive()) -> A2Body {
        var b = self
        b.delay = timing.delays(drive)
        return b
    }
}

/// Timing of a simulated breath: each region's first-harmonic phase relative to the lung, degrees
/// (positive = later), the ribcage–abdomen phase angle as OEP and RIP studies report it, and the
/// time each region peaks.
public struct BreathTiming: Sendable {
    public var upperLag: Double, lowerLag: Double, abdomenLag: Double
    /// Ribcage (upper + lower) relative to abdomen, degrees; positive = ribcage later.
    public var ribcageAbdomen: Double
    public var peakTime: (lung: Double, upper: Double, lower: Double, abdomen: Double)

    public static func measure(_ samples: [A2Sample], period: Double) -> BreathTiming {
        let end = samples.last!.time
        let cycle = samples.filter { $0.time > end - period }
        func phase(_ f: (A2Sample) -> Double) -> Double {
            var c = 0.0, s = 0.0
            for x in cycle { let w = 2 * Double.pi * x.time / period; c += f(x) * cos(w); s += f(x) * sin(w) }
            return atan2(s, c)
        }
        func lag(_ a: Double, _ b: Double) -> Double {  // phase of a after b, degrees in (−180, 180]
            var d = (a - b) * 180 / .pi
            while d > 180 { d -= 360 }
            while d <= -180 { d += 360 }
            return d
        }
        let pl = phase(\.lung), pu = phase(\.upperRegion), pw = phase(\.lowerRegion), pa = phase(\.abdomenRegion)
        let pr = phase { $0.upperRegion + $0.lowerRegion }
        let t0 = cycle.first!.time
        func peak(_ f: (A2Sample) -> Double) -> Double { cycle.max { f($0) < f($1) }!.time - t0 }
        return BreathTiming(upperLag: lag(pu, pl), lowerLag: lag(pw, pl), abdomenLag: lag(pa, pl),
                            ribcageAbdomen: lag(pr, pa),
                            peakTime: (peak(\.lung), peak(\.upperRegion), peak(\.lowerRegion), peak(\.abdomenRegion)))
    }
}
