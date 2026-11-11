import Foundation

// A2 with the two sides free (for side-lying). Same virtual-work mechanics as A2 (Mechanics.swift),
// with each side's ribs, hemidiaphragm and flank as separate coordinates, two lungs (each its own
// pleural pressure, compliance CL/2, resistance 2R in parallel), and one incompressible abdomen.
// Shared: the lower band's front swing (tied to the sternum), its front-to-back widening, and the
// abdominal wall's front bulge. The symmetric A2 is untouched; with a symmetric reference this
// model must reproduce it (`breathstar side-lying` prints the comparison).
//
// Couplings, K = diag(k) + Σ kc · c cᵀ:
//   - the costal arch: sternum forward minus lower front forward (as A2);
//   - the sternum is one bone: its left and right halves move together, forward and up. ASSUMED
//     rigid (100 × the upper rotation's own spring);
//   - the bed (side-lying): outward motion of the dependent side's lateral wall, ribcage and
//     abdomen. Its stiffness is scanned against Takashima's side-lying markers.

public enum SidedCoordinate: Int, CaseIterable, Sendable {
    case upperRotationL, upperRotationR, upperDilationL, upperDilationR, lowerPump, lowerBucketL, lowerBucketR,
         lowerDilationAP, lowerDilationTL, lowerDilationTR, diaphragmL, diaphragmR, abdomen, flankL, flankR

    public static let count = allCases.count

    /// The symmetric A2 coordinate it splits or keeps (nil: the flanks, which A2 tied to the front).
    public var symmetric: A2Coordinate? {
        switch self {
        case .upperRotationL, .upperRotationR: .upperRotation
        case .upperDilationL, .upperDilationR: .upperDilation
        case .lowerPump: .lowerPump
        case .lowerBucketL, .lowerBucketR: .lowerBucket
        case .lowerDilationAP: .lowerDilationAP
        case .lowerDilationTL, .lowerDilationTR: .lowerDilationTransverse
        case .diaphragmL, .diaphragmR: .diaphragm
        case .abdomen: .abdomen
        case .flankL, .flankR: nil
        }
    }

    public var side: Side? {
        switch self {
        case .upperRotationL, .upperDilationL, .lowerBucketL, .lowerDilationTL, .diaphragmL, .flankL: .left
        case .upperRotationR, .upperDilationR, .lowerBucketR, .lowerDilationTR, .diaphragmR, .flankR: .right
        default: nil
        }
    }

    public var isRib: Bool { symmetric?.isRib ?? false }
    public var isDiaphragm: Bool { symmetric == .diaphragm }

    public var label: String {
        let base = symmetric?.label ?? "abdominal flank (beyond the front's)"
        guard let s = side else { return base }
        return base + (s == .left ? " (left)" : " (right)")
    }

    /// The sided coordinates on one side that split the given symmetric ones (shared ones excluded:
    /// they can't be held on one side only).
    public static func on(_ side: Side, _ symmetric: [A2Coordinate]) -> [SidedCoordinate] {
        allCases.filter { $0.side == side && $0.symmetric.map(symmetric.contains) == true }
    }

    /// Symmetric coordinates → sided (each side gets the symmetric value; flanks 0).
    public static func fromSymmetric(_ q: [Double]) -> [Double] {
        allCases.map { c in c.symmetric.map { q[$0.rawValue] } ?? 0 }
    }
}

extension AnatomyModel {
    /// The anatomical state for sided coordinates q.
    public func sidedState(_ q: [Double]) -> AnatomyState {
        var s = AnatomyState()
        s.upperRib = [q[0], q[1]]
        s.upperDilation = [q[2], q[3]]
        s.lowerPump = q[4]
        s.lowerRib = [q[5], q[6]]
        s.lowerDilationAP = q[7]
        s.lowerDilation = [q[8], q[9]]
        s.diaphragm = [q[10], q[11]]
        s.abdomenFront = q[12]
        s.abdomenFlank = [q[12] * flankRatio + q[13], q[12] * flankRatio + q[14]]
        return s
    }

    /// Lying on the right side (on the floor). End-expiratory diameters from Takashima 2017
    /// Table 2, "right lateral" (15 men): upper ribcage AP 20.60; lower ribcage AP 23.78, width
    /// 28.28; abdomen AP 22.54, width 27.15 cm (the trunk narrows side to side). ASSUMED as for
    /// supine: upper-ribcage width (seated 30.0 × the lower ribcage's width ratio), the pelvis and
    /// top tapers, the landmarks; a symmetric section (the flattening is on the dependent side
    /// only in reality).
    public static func rightSideDown() -> AnatomyModel {
        var m = AnatomyModel()
        let widthRatio = 28.28 / 32.35
        m.profile = [
            (0, 25.0 * 22.54 / 27.15, 32.0 * 27.15 / 31.20),
            (9, 22.54, 27.15),
            (21.5, 23.78, 28.28),
            (34, 20.60, 30.0 * widthRatio),
            (43, 15.0 * 20.60 / 20.10, 25.0 * widthRatio),
        ]
        return m
    }

    /// Mean motion (mm) of the surface over a sector on one side: (x outward on that side, y
    /// forward, z up), as `observe` averages Takashima's marker groups.
    public func sectorMotion(z zs: ClosedRange<Double>, psi psis: ClosedRange<Double>, side: Side,
                             _ s: AnatomyState) -> (x: Double, y: Double, z: Double) {
        var sum = (x: 0.0, y: 0.0, z: 0.0), n = 0.0
        for zi in 0..<12 {
            let z = zs.lowerBound + (Double(zi) + 0.5) / 12 * (zs.upperBound - zs.lowerBound)
            for pi in 0..<9 {
                let psi = psis.lowerBound + (Double(pi) + 0.5) / 9 * (psis.upperBound - psis.lowerBound)
                let d = surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
                sum.x += d.x; sum.y += d.y; sum.z += d.z; n += 1
            }
        }
        return (10 * sum.x / n, 10 * sum.y / n, 10 * sum.z / n)
    }

    /// Observables for an asymmetric state: `observe`, with the front (midline) markers averaged
    /// over both sides, and the dependent (right) side's lateral markers added. With a side resting
    /// on a support, motion is measured from the room (as OEP does): the trunk is lifted off the
    /// support by its dependent lateral ribcage's outward motion (the ribcage rests on the floor;
    /// lifting the trunk's weight is a constant load, not a spring), so every point moves away
    /// from the support by that much too.
    /// `lift`: apply the room-frame trunk lift (one candidate explanation of the upper side's
    /// 1.70 mm; off by default since critique 3, 2026-11-10, because a rigid lift also moves the front
    /// markers away from the floor, which Takashima's front medio-lateral components contradict).
    /// The would-be lift is reported as marker "trunk lift" either way.
    public func observeSided(_ s: AnatomyState, restingOn support: Side? = nil,
                             lift applyLift: Bool = SidedBody.trunkLiftDefault) -> AnatomyObservables {
        var o = observe(s)
        for (name, zs) in [("anterior upper ribcage", xiphoid...top), ("anterior lower ribcage", costalMargin...xiphoid),
                           ("anterior abdomen", 0...costalMargin)] {
            let l = sectorMotion(z: zs, psi: -40...40, side: .left, s), r = sectorMotion(z: zs, psi: -40...40, side: .right, s)
            o.markers[name] = (0.5 * (l.x - r.x), 0.5 * (l.y + r.y), 0.5 * (l.z + r.z))
        }
        o.markers["right lateral lower ribcage"] = sectorMotion(z: costalMargin...xiphoid, psi: 60...120, side: .right, s)
        o.markers["right lateral abdomen"] = sectorMotion(z: 0...costalMargin, psi: 60...120, side: .right, s)
        if let side = support {
            let lift = sectorMotion(z: costalMargin...xiphoid, psi: 60...120, side: side, s).x
            func meanLift(_ zs: ClosedRange<Double>) -> Double {
                (0..<24).reduce(0.0) { acc, i in
                    let z = zs.lowerBound + (Double(i) + 0.5) / 24 * (zs.upperBound - zs.lowerBound)
                    return acc + roomLift(z: z, s, restingOn: side) / 24
                }
            }
            let ranges: [String: ClosedRange<Double>] = [
                "lateral lower ribcage": costalMargin...xiphoid, "lateral abdomen": 0...costalMargin,
                "posterolateral lower ribcage": costalMargin...xiphoid,
                "anterior upper ribcage": xiphoid...top, "anterior lower ribcage": costalMargin...xiphoid,
                "anterior abdomen": 0...costalMargin,
            ]
            // A rigid lift moves every marker away from the support: lateral markers outward on the
            // other side and inward on the support side; front markers sideways (their x is toward
            // the body's left, so + when resting on the right). Until critique 3 the front markers
            // were left out here, which hid the lift's failure against Takashima's front components.
            if applyLift {
                for (k, v) in o.markers {
                    guard let zs = ranges.first(where: { k.hasSuffix($0.key) })?.value else { continue }
                    let sign: Double
                    if k.hasPrefix("anterior") { sign = side == .right ? 1 : -1 }
                    else { sign = k.hasPrefix(side == .right ? "right" : "left") ? -1.0 : 1.0 }
                    o.markers[k] = (v.x + sign * meanLift(zs), v.y, v.z)
                }
            }
            o.markers["trunk lift"] = (lift, 0, 0)
        }
        return o
    }
}

extension AnatomyModel {
    /// How far the trunk is lifted away from the support at height z during the breath, cm (room
    /// frame): the dependent lower ribcage's outward motion, fading linearly to 0 at the iliac
    /// crests (the pelvis rests on the support and doesn't lift). Contact: on the floor the dependent
    /// lower ribcage and abdomen bear weight. Takashima 2017 (thesis, Kobe, read): subjects on the
    /// floor, upper arm propped on a cushion on the greater trochanter; the weight-bearing side's
    /// abdominal rib cage and abdomen are narrowed side to side, and the asymmetry is attributed to
    /// "local pressure on the chest wall due to the floor surface". Leilnahari 2011's "only shoulder
    /// and pelvis receive good support" (firm mattress) is about support quality, not absence of contact.
    public func roomLift(z: Double, _ s: AnatomyState, restingOn side: Side) -> Double {
        let zRib = 0.5 * (costalMargin + xiphoid)
        let lift = sectorMotion(z: costalMargin...xiphoid, psi: 60...120, side: side, s).x / 10  // mm → cm
        return lift * min(1, max(0, z / zRib)) * 10  // back to mm, as the markers
    }
}

/// The trunk's sideways arc lying on the side (rest geometry). Supported at the shoulder and the
/// pelvis, the waist sags toward the support: the spine bends sideways, convex toward the floor;
/// the dependent side lengthens (its ribs fan apart) and the upper side shortens (its ribs close).
/// Size: Leilnahari et al. 2011 (25 men, optical tracking of 12 spinous processes C7–L5, lateral
/// sleep posture): frontal-plane bend at T11 8.9° on a firm mattress (12.7° soft, 4.1° custom);
/// "only shoulder and pelvis receive good support". Read as two straight segments C7–T11–L5 over
/// ~49 cm: sag ≈ 24.5 · sin(8.9°/2) ≈ 1.9 cm. On the floor (Takashima's subjects) it is probably
/// larger: ASSUMED the firm-mattress value. Shape ASSUMED: a half sine from L5 (z = −3) to C7
/// (z = 46), its apex at z ≈ 21.5 (≈ T11 in this trunk). Not yet used by the mechanics.
public struct SideLyingArc: Sendable {
    /// Sag toward the support at the apex, cm.
    public var sag: Double
    public var zLower = -3.0, zUpper = 46.0
    public init(sag: Double) { self.sag = sag }
    public static let firmSurface = SideLyingArc(sag: 24.5 * sin(8.9 / 2 * .pi / 180))

    var span: Double { zUpper - zLower }
    /// Sag toward the support at height z, cm (0 at L5 and C7).
    public func offset(_ z: Double) -> Double {
        guard z > zLower, z < zUpper else { return 0 }
        return sag * sin(.pi * (z - zLower) / span)
    }
    /// The spine's tilt from the long axis at height z, radians (+: moving toward the support as z rises).
    public func tilt(_ z: Double) -> Double {
        guard z > zLower, z < zUpper else { return 0 }
        return atan(sag * .pi / span * cos(.pi * (z - zLower) / span))
    }
    /// Curvature at z, 1/cm (positive: convex toward the support).
    public func curvature(_ z: Double) -> Double {
        guard z > zLower, z < zUpper else { return 0 }
        return sag * pow(.pi / span, 2) * sin(.pi * (z - zLower) / span)
    }
    /// Lengthwise strain of the lateral wall at z, half-width w away from the spine: + on the
    /// dependent (convex) side, − on the upper side (bending about the spine).
    public func lateralStrain(_ z: Double, halfWidth w: Double, dependentSide: Bool) -> Double {
        (dependentSide ? 1 : -1) * curvature(z) * w
    }
}

extension AnatomyModel {
    /// For drawing: the spine's sideways position at height z, cm, in the body's x (+ left), and its
    /// tilt, lying on `support`: the rest arc (toward the support) plus, in the room frame, the
    /// breath's lift away from it (`roomLift`) for a state. Rest only: pass AnatomyState().
    public func sideLyingSpine(z: Double, _ s: AnatomyState, restingOn support: Side,
                               arc: SideLyingArc = .firmSurface, roomFrame: Bool = true) -> (x: Double, tilt: Double) {
        let toward = support == .right ? -1.0 : 1.0  // +x is the body's left
        let lift = roomFrame ? roomLift(z: z, s, restingOn: support) / 10 : 0
        return (toward * (arc.offset(z) - lift), toward * arc.tilt(z))
    }
}

/// Lying on the side, the dependent lower ribcage is flattened against the floor (Takashima 2017:
/// the lower ribcage's side-to-side width falls from 32.51 cm supine to 28.28 cm side-lying, the
/// weight-bearing side "narrowed"). If that narrowing is all on the dependent side, its half-width
/// is compressed by 4.23 cm of ~16.3, a strain of 0.26. Ribs, cartilage and intercostal tissue
/// stiffen as they are deformed away from rest (the relaxed chest wall's pressure–volume curve
/// flattens away from its resting volume), so the dependent lower ribs' bucket swing and sideways
/// widening are stiffer: stiffness × exp(gain · strain). The strain is DERIVED (all narrowing
/// ASSUMED on the dependent side); the gain is ASSUMED (no source sizes rib stiffening with
/// deformation); `assumed` doubles the stiffness. The upper side stays at rest stiffness.
public struct DeformedSideStiffening: Sendable {
    public var strain: Double
    public var gain: Double
    public init(strain: Double = (32.51 - 28.28) / (32.51 / 2), gain: Double) { self.strain = strain; self.gain = gain }
    /// Stiffness multiplier on the dependent lower ribs.
    public var factor: Double { exp(gain * strain) }
    /// Doubles the dependent lower ribs' stiffness at the derived strain.
    public static let assumed = DeformedSideStiffening(gain: log(2) / ((32.51 - 28.28) / (32.51 / 2)))
    /// The stiffening for a given multiplier at the derived strain (for scans).
    public static func multiplier(_ m: Double) -> DeformedSideStiffening {
        DeformedSideStiffening(gain: log(m) / ((32.51 - 28.28) / (32.51 / 2)))
    }
}

extension TakashimaMarkers {
    /// Right side down, the front markers' side-to-side motion (Takashima 2017 Table 3; + toward the
    /// subject's left, i.e. away from the floor). Added after critique 3 (2026-11-10): free,
    /// never-fitted data that discriminate between explanations of the upper side's 1.70 mm.
    public static let rightSideDownFrontSideways: [MarkerObservation] = [
        .init(marker: "anterior upper ribcage", component: .outward, mean: 0.29, sd: 0.29),
        .init(marker: "anterior lower ribcage", component: .outward, mean: -0.29, sd: 0.39),
        .init(marker: "anterior abdomen", component: .outward, mean: -0.54, sd: 0.68),
    ]
    /// All 15 side-lying components: the 12 fitted plus the 3 front side-to-side ones.
    public static let rightSideDownAll = rightSideDown + rightSideDownFrontSideways
}

/// Region volumes per unit of each sided coordinate, litres, per side: [side][coordinate].
public struct SidedGeometry: Sendable {
    public var upper: [[Double]], lowerLungFacing: [[Double]], lowerApposed: [[Double]], abdomen: [[Double]], diaphragm: [[Double]]

    public func thorax(_ side: Int) -> [Double] {
        (0..<SidedCoordinate.count).map { upper[side][$0] + lowerLungFacing[side][$0] + diaphragm[side][$0] }
    }
    public var abdominalCavity: [Double] {
        (0..<SidedCoordinate.count).map { (i: Int) -> Double in
            var v = 0.0
            for k in 0..<2 { v += lowerApposed[k][i] + abdomen[k][i] - diaphragm[k][i] }
            return v
        }
    }
    public func lower(_ side: Int) -> [Double] { zip(lowerLungFacing[side], lowerApposed[side]).map { $0 + $1 } }
    /// The chest-wall volume a coordinate moves (both sides), or its descent's volume (diaphragm).
    public var own: [Double] {
        SidedCoordinate.allCases.map { c in
            let i = c.rawValue
            if c.isDiaphragm { return diaphragm[0][i] + diaphragm[1][i] }
            var v = 0.0
            for k in 0..<2 { v += upper[k][i] + lower(k)[i] + abdomen[k][i] }
            return v
        }
    }
}

extension AnatomyModel {
    public func sidedGeometry() -> SidedGeometry {
        let n = SidedCoordinate.count
        let symSteps = [1e-3, 1e-4, 1e-3, 1e-3, 1e-4, 1e-4, 1e-2, 1e-2]
        let steps = SidedCoordinate.allCases.map { $0.symmetric.map { symSteps[$0.rawValue] } ?? 1e-2 }
        let zero = [[Double]](repeating: [Double](repeating: 0, count: n), count: 2)
        var up = zero, facing = zero, apposed = zero, ab = zero, dia = zero
        for i in 0..<n {
            var plus = [Double](repeating: 0, count: n), minus = plus
            plus[i] = steps[i]; minus[i] = -steps[i]
            let sp = sidedState(plus), sm = sidedState(minus)
            let a = observe(sp), b = observe(sm)
            for side in Side.allCases {
                let k = side.rawValue, h = 2 * steps[i]
                up[k][i] = (a.upperRibcage[k] - b.upperRibcage[k]) / h
                ab[k][i] = (a.abdomen[k] - b.abdomen[k]) / h
                dia[k][i] = (a.diaphragmVolume[k] - b.diaphragmVolume[k]) / h
                let lower = (a.lowerRibcage[k] - b.lowerRibcage[k]) / h
                let f = (lowerFlux(sp, lungFacing: true, sides: [side]) - lowerFlux(sm, lungFacing: true, sides: [side])) / h
                let r = (lowerFlux(sp, lungFacing: false, sides: [side]) - lowerFlux(sm, lungFacing: false, sides: [side])) / h
                if abs(f + r) > 1e-12 {
                    facing[k][i] = lower * f / (f + r); apposed[k][i] = lower * r / (f + r)
                } else {
                    facing[k][i] = 0; apposed[k][i] = lower
                }
            }
        }
        return SidedGeometry(upper: up, lowerLungFacing: facing, lowerApposed: apposed, abdomen: ab, diaphragm: dia)
    }
}

/// The posture's gravity, side by side: end-expiratory lung volume falls by `frcDrop` (litres,
/// relative to seated), and a fraction `dependentShare` of the dome's rise is on the dependent
/// side. Each hemidiaphragm's force scales with its own lengthening (Smith & Bellemare 1987, per
/// litre, as OperatingPoint); its zone of apposition rises by its own dome rise.
public struct SidedOperatingPoint: Sendable {
    public var frcDrop: Double
    public var dependent: Side
    public var dependentShare: Double

    public init(frcDrop: Double, dependent: Side, dependentShare: Double) {
        self.frcDrop = frcDrop; self.dependent = dependent; self.dependentShare = dependentShare
    }

    func share(_ side: Side) -> Double { side == dependent ? dependentShare : 1 - dependentShare }

    /// Lying on the right side: a FITTED hemidiaphragm force asymmetry (restated after critique 3,
    /// 2026-11-10). The dependent share 2.0 scales the floor-side hemidiaphragm's force ×1.137 and the
    /// upper one's ×0.931 (length–tension on its assumed dome rise); that force scaling is the whole
    /// effect: the dome heights and the zones of apposition change the lung split by nothing
    /// (`breathstar side-lying` section 6). One free number set to one target: the floor-side lung's
    /// share of the breath, 51–62% across sources (Amano 2024 CT 56–62%, Grant 2011 EIT 51–59%; the
    /// model gives 56%). Not a mechanism derived from sources. FRC 0.22 L below seated (as supine;
    /// Amano puts side-lying ~0.6 L above supine, mostly in the upper lung, which this model doesn't
    /// represent).
    public static let rightSideDown = SidedOperatingPoint(frcDrop: 0.22, dependent: .right, dependentShare: 2.0)

    /// Each side's dome rise, cm: its share of the volume drop over its own piston area.
    public func domeRise(_ anatomy: AnatomyModel, _ side: Side) -> Double {
        frcDrop * share(side) * 1000 / anatomy.domeArea(side: side.rawValue)
    }

    /// Each hemidiaphragm's force scale: as if its side's share were spread over both.
    public func forceScale(_ side: Side) -> Double { 1 + OperatingPoint.lengthTensionPerLitre * 2 * frcDrop * share(side) }

    public func apply(to anatomy: AnatomyModel) -> AnatomyModel {
        var a = anatomy
        for side in Side.allCases { a.appositionShiftBySide[side.rawValue] += domeRise(anatomy, side) }
        return a
    }
}

public struct SidedSample: Sendable {
    public var time: Double
    public var q: [Double]
    /// Per side (left, right): lung volume change and the chest-wall regions on that side.
    public var lung: [Double], upper: [Double], lower: [Double], abdomen: [Double]
    public var totalLung: Double { lung[0] + lung[1] }
}

/// One sided body: stiffnesses, couplings, and muscle forces.
public struct SidedBody: Sendable {
    public var anatomy: AnatomyModel
    public var geometry: SidedGeometry
    public var passive: A2Passive
    public var stiffness: [Double]
    public var couplings: [(c: [Double], k: Double)] = []
    public var peakForce: [Double]
    /// The side resting on the support, if any.
    public var dependent: Side?
    /// Mediastinal compliance, L/cmH2O: the midline structures between the pleural spaces give, so
    /// a pressure difference between them shifts volume from one lung to the other,
    /// V_m = C_m · (Ppl_left − Ppl_right) (positive: into the right hemithorax). 0 = rigid (until
    /// 2026-11-09). Set from Hubmayr & Margulies 1992 via `withMediastinum(transmission:)`.
    public var mediastinalCompliance = 0.0

    public var stiffnessMatrix: [[Double]] {
        let n = SidedCoordinate.count
        var m = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            m[i][i] = stiffness[i]
            for (c, k) in couplings { for j in 0..<n { m[i][j] += k * c[i] * c[j] } }
        }
        return m
    }

    /// Diagonal passive stiffness, K = (volume moved)² / compliance, as A2 (basis: ribcage).
    /// A per-side coordinate has half its symmetric compliance and moves half the volume, so equal
    /// motion of both sides stores the symmetric energy.
    static func passiveStiffness(anatomy: AnatomyModel, geometry g: SidedGeometry, passive: A2Passive) -> [Double] {
        let restUpper = anatomy.sliceVolume(AnatomyState(), from: anatomy.xiphoid, to: anatomy.top, side: 0)
        let restLower = anatomy.sliceVolume(AnatomyState(), from: anatomy.costalMargin, to: anatomy.xiphoid, side: 0)
        let upperC = passive.ribcageCompliance * restUpper / (restUpper + restLower), lowerC = passive.ribcageCompliance - upperC
        let symC = [upperC / 2, upperC / 2, lowerC / 4, lowerC / 4, lowerC / 4, lowerC / 4,
                    passive.diaphragmCompliance, passive.abdomenCompliance]
        return SidedCoordinate.allCases.map { c in
            let i = c.rawValue
            let compliance = (c.symmetric.map { symC[$0.rawValue] } ?? passive.abdomenCompliance) / (c.side == nil ? 1 : 2)
            let basis: Double
            if c.isDiaphragm {
                basis = g.diaphragm[0][i] + g.diaphragm[1][i]
            } else if c == .abdomen || c.symmetric == nil {
                basis = g.abdomen[0][i] + g.abdomen[1][i]
            } else {
                var v = 0.0
                for k in 0..<2 { v += g.upper[k][i] + g.lower(k)[i] }
                basis = v
            }
            let tone = c.isRib ? 1 + passive.ribcageTone : 1
            let stiffen = c.symmetric.map { passive.stiffen[$0.rawValue] } ?? 1
            return basis * basis / compliance * tone * stiffen
        }
    }

    /// Displacement-difference vector (cm per unit of each coordinate) of a linear function of the
    /// state, by central differences.
    static func vector(_ anatomy: AnatomyModel, _ f: (AnatomyState) -> Double) -> [Double] {
        let n = SidedCoordinate.count
        return (0..<n).map { i in
            var p = [Double](repeating: 0, count: n), m = p
            p[i] = 1e-3; m[i] = -1e-3
            return (f(anatomy.sidedState(p)) - f(anatomy.sidedState(m))) / 2e-3
        }
    }

    /// The couplings: the costal arch, the rigid sternum, and (if a side is dependent) the bed.
    static func couplings(anatomy a: AnatomyModel, stiffness k: [Double], archFactor: Double,
                          dependent: Side?, bedGain: Double) -> [(c: [Double], k: Double)] {
        let zSternum = a.xiphoid + AnatomyModel.bandBlend + 0.5, zLower = 0.5 * (a.costalMargin + a.xiphoid)
        func fwd(_ z: Double, _ side: Side) -> (AnatomyState) -> Double { { a.surfaceDisplacement(z: z, psiDegrees: 0, side: side, $0).y } }
        func up(_ z: Double, _ side: Side) -> (AnatomyState) -> Double { { a.surfaceDisplacement(z: z, psiDegrees: 0, side: side, $0).z } }
        let arch = vector(a) { s in
            0.5 * (fwd(zSternum, .left)(s) + fwd(zSternum, .right)(s)) - 0.5 * (fwd(zLower, .left)(s) + fwd(zLower, .right)(s))
        }
        let p = SidedCoordinate.lowerPump.rawValue, r = SidedCoordinate.upperRotationL.rawValue
        var out: [(c: [Double], k: Double)] = [(arch, archFactor * k[p] / (arch[p] * arch[p]))]
        for f in [fwd, up] {
            let c = vector(a) { s in f(zSternum, .left)(s) - f(zSternum, .right)(s) }
            if abs(c[r]) > 1e-12 { out.append((c, 100 * k[r] / (c[r] * c[r]))) }
        }
        if let side = dependent, bedGain > 0 {
            // The bed under the dependent flank: mean outward motion of its lateral wall (ψ 60–120°)
            // from the iliac crest to the lower ribcage, scaled to that side's lower bucket spring.
            let c = vector(a) { s in a.sectorMotion(z: 1...a.xiphoid, psi: 60...120, side: side, s).x / 10 }
            let b = (side == .left ? SidedCoordinate.lowerBucketL : .lowerBucketR).rawValue
            out.append((c, bedGain * k[b] / (c[b] * c[b])))
        }
        return out
    }

    /// Calibrate on a reference end-inspiratory state, as A2.calibrate: the abdominal muscles are
    /// relaxed (no force on the front bulge), which fixes the abdominal pressure; every other
    /// coordinate's force is what equilibrium requires (the flanks' is an effective restraint of
    /// the lateral abdominal wall: A2 tied the flank to the front instead). With a symmetric
    /// reference this reproduces A2's static breath exactly.
    /// The default pleural pressure transmission across the mediastinum: Hubmayr & Margulies 1992,
    /// baboons 0.5 ± 0.1 (the primate value; dogs 0.7). nil in `calibrate`/`from` = rigid.
    public static let mediastinalTransmission = 0.5

    public static func calibrate(anatomy: AnatomyModel, reference q0: [Double], passive: A2Passive = A2Passive(),
                                 mediastinalTransmission: Double? = SidedBody.mediastinalTransmission) -> SidedBody {
        let g = anatomy.sidedGeometry()
        let k = passiveStiffness(anatomy: anatomy, geometry: g, passive: passive)
        let cs = couplings(anatomy: anatomy, stiffness: k, archFactor: passive.sternalCoupling, dependent: nil, bedGain: 0)
        let n = SidedCoordinate.count, a = SidedCoordinate.abdomen.rawValue
        let jth = [g.thorax(0), g.thorax(1)], jab = g.abdominalCavity
        var q = q0
        var rest = 0.0
        for j in 0..<n where j != a { rest += jab[j] * q[j] }
        q[a] = -rest / jab[a]
        func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
        let ppl = (0..<2).map { -dot(jth[$0]) / (passive.lungCompliance / 2) }
        var body = SidedBody(anatomy: anatomy, geometry: g, passive: passive, stiffness: k, peakForce: [], dependent: nil)
        body.couplings = cs
        let kq = multiply(body.stiffnessMatrix, q)
        let pab = (kq[a] - ppl[0] * jth[0][a] - ppl[1] * jth[1][a]) / jab[a]
        var force = (0..<n).map { kq[$0] - ppl[0] * jth[0][$0] - ppl[1] * jth[1][$0] - pab * jab[$0] }
        force[a] = 0
        body.peakForce = force
        // The reference is symmetric (equal pleural pressures), so the mediastinum doesn't change it.
        return mediastinalTransmission.map { body.withMediastinum(transmission: $0) } ?? body
    }

    /// The pressure-equivalent of a coordinate's force (force over the volume it moves).
    public func forceAsPressure(_ i: Int) -> Double { peakForce[i] / geometry.own[i] }

    /// Lying on the right side: the lying wall factors fitted to Takashima 2017's side-lying
    /// components (grid, `breathstar side-lying` section 3) at `SidedOperatingPoint.rightSideDown`,
    /// bed spring on, no trunk lift, no shoulder hold. FITTED, not sourced. (Values and fit quality are
    /// printed by section 3; see the working log (private).) Refit 2026-11-10 on the default seated body
    /// (fixed-sign muscle groups, costal arch ×3, lower band ×2.5) over 15 components: bed on ×3.0 /
    /// ×1.8, χ² 15.7, 10/15 within SD. Without the bed ×3.5 / ×1.34 fits Takashima better (χ² 12.4,
    /// 11/15) but moves the floor-side chest wall more than the upper side, against Nozoe 2014; the
    /// bed is kept for Nozoe. Refit whenever the seated body changes.
    public static let rightSideDownWall = (ribcageStiffnessScale: 3.0, abdomenComplianceScale: 1.8, bedGain: 1.0)

    /// Lying on the side, the shoulder holds the dependent top ribs (the user's account; `side-lying`
    /// section 10): their rotation and widening are this many times stiffer. A GUESS (2026-11-09,
    /// user: "just make a guess for now"): ×2, the milder of the two scanned values. No source sizes
    /// it (literature pass 8, "searched, not found"); replace with a measurement (a pressure mat on
    /// the floor). OFF by default since critique 3 (2026-11-10): it worsens the fit (χ² and SD count)
    /// and was never refitted with the wall grid. Pass `shoulderHold: SidedBody.shoulderHoldGuess`
    /// to `from` to use it.
    public static let shoulderHoldGuess = 2.0

    /// Whether the room-frame trunk lift is applied by default (`observeSided(lift:)`). false since
    /// critique 3 (2026-11-10): the lift is one candidate explanation of the upper side's 1.70 mm,
    /// and it fails Takashima's front medio-lateral components (`breathstar side-lying` section 4).
    public static let trunkLiftDefault = false

    /// The seated sided body in another posture: the posture's geometry, the seated muscle
    /// PRESSURES (force-as-pressure × the volume each coordinate now moves), the lying wall effects
    /// (as A2.inPosture, hypothesis A), each hemidiaphragm's own force scale, and the bed.
    public static func from(seated: SidedBody, anatomy: AnatomyModel, abdomenComplianceScale: Double = 1,
                            ribcageStiffnessScale: Double = 1, diaphragmForceScale: [Double] = [1, 1],
                            dependent: Side? = nil, bedGain: Double = 0,
                            mediastinalTransmission: Double? = SidedBody.mediastinalTransmission,
                            shoulderHold: Double = 1) -> SidedBody {
        let g = anatomy.sidedGeometry()
        var passive = seated.passive
        passive.abdomenCompliance *= abdomenComplianceScale
        var k = passiveStiffness(anatomy: anatomy, geometry: g, passive: passive)
        var cs = couplings(anatomy: anatomy, stiffness: k, archFactor: passive.sternalCoupling, dependent: dependent, bedGain: bedGain)
        for c in SidedCoordinate.allCases where c.isRib { k[c.rawValue] *= ribcageStiffnessScale }
        cs[0].k *= ribcageStiffnessScale
        if let side = dependent {
            for c in SidedCoordinate.on(side, [.upperRotation, .upperDilation]) { k[c.rawValue] *= shoulderHold }
        }
        let own = g.own
        let force = SidedCoordinate.allCases.map { c -> Double in
            if c == .abdomen { return 0 }
            let scale = c.isDiaphragm ? diaphragmForceScale[c.side!.rawValue] : 1
            return seated.forceAsPressure(c.rawValue) * own[c.rawValue] * scale
        }
        var body = SidedBody(anatomy: anatomy, geometry: g, passive: passive, stiffness: k, peakForce: force, dependent: dependent)
        body.couplings = cs
        return mediastinalTransmission.map { body.withMediastinum(transmission: $0) } ?? body
    }

    /// A copy whose forces are scaled to a target (dynamic) tidal volume; shares unchanged.
    public func matchedToTidal(_ target: Double, drive: Drive = Drive()) -> SidedBody {
        let m = SidedBreath.measure(simulate(drive: drive), period: drive.period)
        var b = self
        b.peakForce = peakForce.map { $0 * target / m.tidalVolume }
        return b
    }

    /// Some muscle groups' phasic forces switched off.
    public func silenced(_ groups: Set<A2Muscles>) -> SidedBody {
        var b = self
        b.peakForce = SidedCoordinate.allCases.map { c in
            (groups.contains(.ribs) && c.isRib) || (groups.contains(.diaphragm) && c.isDiaphragm) ? 0 : peakForce[c.rawValue]
        }
        return b
    }

    /// One side's muscles switched off (a one-sided paralysis): that side's rib muscles and/or
    /// hemidiaphragm. The shared coordinates (the lower front's swing and AP widening) keep half
    /// their force, as their drive comes from both sides.
    public func silenced(_ groups: Set<A2Muscles>, side: Side) -> SidedBody {
        var b = self
        b.peakForce = SidedCoordinate.allCases.map { c in
            let hit = (groups.contains(.ribs) && c.isRib) || (groups.contains(.diaphragm) && c.isDiaphragm)
            guard hit else { return peakForce[c.rawValue] }
            if let cs = c.side { return cs == side ? 0 : peakForce[c.rawValue] }
            return 0.5 * peakForce[c.rawValue]
        }
        return b
    }

    /// Some coordinates stiffened (a hand, a hold), as A2.stiffened. Use `SidedCoordinate.on` to
    /// pick one side.
    public func stiffened(_ coordinates: [SidedCoordinate], by factor: Double) -> SidedBody {
        var b = self
        for c in coordinates { b.stiffness[c.rawValue] *= factor }
        return b
    }

    /// The dependent side's lower ribs stiffened because they are deformed (user's hypothesis,
    /// 2026-11-09: the ribs on the floor are flattened away from their point of optimal elasticity,
    /// so they move less and the upper side moves more). See `DeformedSideStiffening`.
    public func withDeformedSide(_ d: DeformedSideStiffening = .assumed) -> SidedBody {
        guard let side = dependent else { return self }
        return stiffened(SidedCoordinate.on(side, [.lowerBucket, .lowerDilationTransverse]), by: d.factor)
    }

    /// The system matrix: unknowns q, Ppl (left), Ppl (right), Pab, V_m. Each lung: compliance CL/2,
    /// resistance 2R (`flow` = R/dt; 0 for static). Left lung = J_th,L·q + V_m, right = J_th,R·q − V_m.
    func systemMatrix(flow rdt: Double) -> [[Double]] {
        let n = SidedCoordinate.count
        let jth = [geometry.thorax(0), geometry.thorax(1)], jab = geometry.abdominalCavity
        let cl = passive.lungCompliance / 2
        var a = [[Double]](repeating: [Double](repeating: 0, count: n + 4), count: n + 4)
        let kf = stiffnessMatrix
        for i in 0..<n {
            for j in 0..<n { a[i][j] = kf[i][j] }
            a[i][n] = -jth[0][i]; a[i][n + 1] = -jth[1][i]; a[i][n + 2] = -jab[i]
            a[n][i] = (1 / cl + rdt) * jth[0][i]
            a[n + 1][i] = (1 / cl + rdt) * jth[1][i]
            a[n + 2][i] = jab[i]
        }
        a[n][n] = 1; a[n + 1][n + 1] = 1
        a[n][n + 3] = 1 / cl + rdt; a[n + 1][n + 3] = -(1 / cl + rdt)
        // Mediastinum: V_m − C_m (Ppl_L − Ppl_R) = 0 (rigid: V_m = 0).
        a[n + 3][n + 3] = 1; a[n + 3][n] = -mediastinalCompliance; a[n + 3][n + 1] = mediastinalCompliance
        return a
    }

    /// Simulate (see `systemMatrix`).
    public func simulate(drive: Drive = Drive(), cycles: Int = 4, timeStep dt: Double = 0.002) -> [SidedSample] {
        let n = SidedCoordinate.count
        let jth = [geometry.thorax(0), geometry.thorax(1)]
        let r = passive.resistance * 2
        let inverse = invert(systemMatrix(flow: r / dt))
        let steps = Int((Double(cycles) * drive.period / dt).rounded())
        var previous = [0.0, 0.0]
        var out: [SidedSample] = []
        out.reserveCapacity(steps + 1)
        for step in 0...steps {
            let t = Double(step) * dt
            let act = drive.activation(at: t)
            var rhs = [Double](repeating: 0, count: n + 4)
            for i in 0..<n { rhs[i] = peakForce[i] * act }
            rhs[n] = r / dt * previous[0]; rhs[n + 1] = r / dt * previous[1]
            let x = multiply(inverse, rhs)
            let q = Array(x[0..<n]), vm = x[n + 3]
            func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
            previous = [dot(jth[0]) + vm, dot(jth[1]) - vm]
            out.append(SidedSample(time: t, q: q, lung: previous,
                                   upper: (0..<2).map { dot(geometry.upper[$0]) }, lower: (0..<2).map { dot(geometry.lower($0)) },
                                   abdomen: (0..<2).map { dot(geometry.abdomen[$0]) }))
        }
        return out
    }

    /// Static pleural pressure transmission across the midline: inflate one lung by 1 cmH2O of airway
    /// pressure (muscles relaxed) and return ΔPpl(other side) / ΔPpl(that side). This is what
    /// Hubmayr & Margulies 1992 measured (rib capsules, recumbent): 0.7 ± 0.1 in dogs, 0.5 ± 0.1 in
    /// baboons. With a rigid mediastinum it comes only through the chest wall's own coupling.
    public func pleuralTransmission(inflating side: Side = .left) -> Double {
        let n = SidedCoordinate.count
        var rhs = [Double](repeating: 0, count: n + 4)
        rhs[n + side.rawValue] = 1
        let x = multiply(invert(systemMatrix(flow: 0)), rhs)
        let own = x[n + side.rawValue], other = x[n + 1 - side.rawValue]
        return other / own
    }

    /// The same body with the mediastinal compliance that gives this transmission (bisection).
    public func withMediastinum(transmission target: Double) -> SidedBody {
        var b = self
        var lo = 0.0, hi = 10.0
        b.mediastinalCompliance = 0
        if b.pleuralTransmission() >= target { return b }
        for _ in 0..<60 {
            b.mediastinalCompliance = 0.5 * (lo + hi)
            if b.pleuralTransmission() < target { lo = b.mediastinalCompliance } else { hi = b.mediastinalCompliance }
        }
        return b
    }

    /// Coordinates at end inspiration (the lungs' total maximum) over the last cycle.
    public func endInspiration(drive: Drive = Drive(), timeStep: Double = 0.002) -> [Double] {
        let sim = simulate(drive: drive, timeStep: timeStep)
        return sim.suffix(Int(drive.period / timeStep)).max { $0.totalLung < $1.totalLung }!.q
    }
}

/// Signed contributions between end expiration and end inspiration (total lung min and max), by
/// region and by side, and each lung's share of the breath.
public struct SidedBreath: Sendable {
    public var tidalVolume: Double
    public var lung: [Double], upper: [Double], lower: [Double], abdomen: [Double]
    public var chestWall: [Double] { (0..<2).map { upper[$0] + lower[$0] + abdomen[$0] } }
    public var upperShare: Double { (upper[0] + upper[1]) / tidalVolume }
    public var lowerShare: Double { (lower[0] + lower[1]) / tidalVolume }
    public var abdomenShare: Double { (abdomen[0] + abdomen[1]) / tidalVolume }

    public static func measure(_ samples: [SidedSample], period: Double) -> SidedBreath {
        let end = samples.last!.time
        let cycle = samples.filter { $0.time >= end - period }
        let lo = cycle.min { $0.totalLung < $1.totalLung }!, hi = cycle.max { $0.totalLung < $1.totalLung }!
        func d(_ f: (SidedSample) -> [Double]) -> [Double] { (0..<2).map { f(hi)[$0] - f(lo)[$0] } }
        return SidedBreath(tidalVolume: hi.totalLung - lo.totalLung, lung: d(\.lung), upper: d(\.upper),
                           lower: d(\.lower), abdomen: d(\.abdomen))
    }
}
