import Foundation

// Stage 4 of the lesson adaptation (docs/LESSON_ADAPTATION.md §4.2–4.3, §9): the spine's shape as part of the
// configuration, and Rule B, stiffness by distance from neutral.
//
// The trunk bends about its spine. A spine angle over a segment is a curvature (angle / length), and
// a wall point at distance d from the spine, on the side toward which the trunk bends, is shortened
// by κ·d (lengthened on the far side). Twisting shears the wall by θ·r / L. Each breathing coordinate
// takes the strain of the wall it moves (its surface motion weights the average), and its stiffness
// follows one law:
//
//     k = k0 · exp(−gain · ε + twistGain · |γ|)
//
// ε < 0 (crowded) stiffens, ε > 0 (lengthened) eases; any twist stiffens. The sign of `gain` is the
// direction question of Rule B: positive (the default) sends the breath away from a crowded side;
// negative sends it toward the crowded side. Evidence (literature pass 11): slumped sitting expands
// the ribcage less (Hazaki & Okada: 4.2 → 3.6 cm), extension moves the 9th rib's side more and
// rotation the axilla's side less (sitting-posture study, n = 7), and in scoliosis the concave
// (crowded) lung is the one most often found to ventilate less. Nothing measures an acute side-bend.
//
// The diaphragm: a bend lowers the rim of the hemidiaphragm on the crowded side toward the pelvis
// (and lifts it on the open side). If the abdominal contents stay where they are, that dome is
// pushed up relative to its rim: longer fibres, more force (length–tension, as the settle's dome
// rise) and a higher zone of apposition. If the contents move with the rim, nothing changes.
// `GravityRules.bendDomeCoupling` is the fraction that stays (ASSUMED 0.5; `breathstar stage4`
// scans 0–1). Solving it from Rule A's fluid, incompressible abdomen instead (`bendSettle`,
// `GravityRules.bendDomeSolved`, off) gives ~0.78 for a forward bend or an arch and 0 for a
// side-bend (the contents flow across). The side-bend's lung split (crowded lung more) therefore
// needs the contents to hold their place side to side, as organs hung on ligaments (liver right,
// stomach and spleen left) would and a fluid would not: kept assumed.
//
// Geometry: the sections keep their shapes, perpendicular to the curved centreline; only the
// stiffness and the drawing (the viewer's arc) change. ASSUMED: the crowded side's ribs come closer
// together without its section narrowing.

/// The spine's shape: angles in degrees over the lumbar (pelvis to the thoracolumbar pivot) and
/// thoracic (pivot to the top of the ribcage) segments.
public struct SpineShape: Sendable, Equatable {
    /// Bending forward (+) or back (−).
    public var lumbarFlexion = 0.0, thoracicFlexion = 0.0
    /// Bending sideways, + toward the left (the left side crowded).
    public var lumbarSideBend = 0.0, thoracicSideBend = 0.0
    /// Turning, + the shoulders toward the left.
    public var lumbarRotation = 0.0, thoracicRotation = 0.0

    public init() {}
    public static let neutral = SpineShape()

    /// The lumbar segment's share of a whole-trunk motion, by range of motion: summed per-level
    /// ranges (White & Panjabi's representative values): flexion–extension lumbar ~72° vs thoracic
    /// ~70° (checked 2026-11-11 against a reproduction of their thoracic table, T1–T12 ≈ 76°, and
    /// L1–L2 = 12°: share ≈ 0.49); lateral bending ~29° vs ~66° (secondary reproductions: ~6° per
    /// side per segment, L5–S1 3°: share ≈ 0.27–0.3) and axial rotation ~10° vs ~70° (lumbar 1–2° per
    /// segment, upper thoracic 8–9°: share ≈ 0.1), all checked 2026-11-11 (LITERATURE pass 15). (Until 2026-11-10 the split was by segment length, 18 : 28 cm, which put too little of a
    /// bend or an arch in the lower back and too much of a twist there.)
    public static let lumbarShare = (flexion: 0.5, sideBend: 0.3, rotation: 0.12)

    public init(flexion: Double = 0, sideBend: Double = 0, rotation: Double = 0) {
        let k = Self.lumbarShare
        lumbarFlexion = flexion * k.flexion; thoracicFlexion = flexion * (1 - k.flexion)
        lumbarSideBend = sideBend * k.sideBend; thoracicSideBend = sideBend * (1 - k.sideBend)
        lumbarRotation = rotation * k.rotation; thoracicRotation = rotation * (1 - k.rotation)
    }

    /// Slumped sitting. ASSUMED typical angles: lumbar +20°, thoracic +15° of flexion over upright.
    public static let slumped: SpineShape = {
        var s = SpineShape(); s.lumbarFlexion = 20; s.thoracicFlexion = 15; return s
    }()

    public var mirrored: SpineShape {
        var s = self
        s.lumbarSideBend = -lumbarSideBend; s.thoracicSideBend = -thoracicSideBend
        s.lumbarRotation = -lumbarRotation; s.thoracicRotation = -thoracicRotation
        return s
    }

    public var isNeutral: Bool { self == .neutral }
}

extension AnatomyModel {
    /// Depth of the bending axis (the vertebral bodies) in from the skin of the back, cm. ASSUMED 6
    /// (lumbar and lower thoracic bodies' centres lie ~5–7 cm in front of the back's surface).
    public static let bendAxisDepth = 6.0

    /// Segment bounds (cm): lumbar from 3 cm below the iliac crests to the pivot, thoracic from the
    /// pivot to the top of the ribcage.
    func segment(_ z: Double) -> (lumbar: Bool, length: Double) {
        z < extensionPivot ? (true, extensionPivot + 3) : (false, top - extensionPivot)
    }

    /// The wall's strain at a surface point (lengthwise ε, + lengthened; twist shear γ) for a spine shape.
    public func wallStrain(z: Double, psi: Double, side: Side, spine: SpineShape) -> (axial: Double, shear: Double) {
        let p = restPoint(z: z, psi: psi, side: side)
        let (lumbar, length) = segment(z)
        let rad = Double.pi / 180
        let flex = (lumbar ? spine.lumbarFlexion : spine.thoracicFlexion) * rad / length
        let bend = (lumbar ? spine.lumbarSideBend : spine.thoracicSideBend) * rad / length
        let twist = (lumbar ? spine.lumbarRotation : spine.thoracicRotation) * rad / length
        // The trunk bends about the vertebral bodies: the midline, `bendAxisDepth` in from the back
        // (y = 0 is the back surface). Bending forward shortens points in front of the axis
        // (y > 0); bending to the left shortens points on the left (x > 0).
        let axial = -flex * (p.y - AnatomyModel.bendAxisDepth) - bend * p.x
        let r = (p.x * p.x + (p.y - base(z).ap / 2) * (p.y - base(z).ap / 2)).squareRoot()
        return (axial, abs(twist) * r)
    }
}

extension SidedBody {
    /// Each coordinate's wall strain: the average over the surface it moves, weighted by how much
    /// it moves each point (|normal motion| × area). Diaphragm coordinates get none (no wall).
    public func coordinateStrains(_ spine: SpineShape) -> [(axial: Double, shear: Double)] {
        let a = anatomy, n = SidedCoordinate.count, h = 1e-3
        let nz = 24, np = 12
        return (0..<n).map { j -> (axial: Double, shear: Double) in
            if SidedCoordinate(rawValue: j)!.isDiaphragm { return (0, 0) }
            var e = [Double](repeating: 0, count: n); e[j] = h
            let st = a.sidedState(e)
            var w = 0.0, ax = 0.0, sh = 0.0
            for side in Side.allCases {
                for zi in 0..<nz {
                    let z = (Double(zi) + 0.5) / Double(nz) * a.top
                    let (ap, half) = a.base(z)
                    for pi in 0..<np {
                        let psi = (Double(pi) + 0.5) / Double(np) * 180, r = psi * .pi / 180
                        let nx0 = sin(r) / half, ny0 = cos(r) / (ap / 2), nn = (nx0 * nx0 + ny0 * ny0).squareRoot()
                        let tx = half * cos(r), ty = -ap / 2 * sin(r)
                        let ds = (tx * tx + ty * ty).squareRoot()
                        let d = a.surfaceDisplacement(z: z, psiDegrees: psi, side: side, st)
                        let weight = abs((d.x * nx0 + d.y * ny0) / nn) * ds
                        let s = a.wallStrain(z: z, psi: psi, side: side, spine: spine)
                        w += weight; ax += weight * s.axial; sh += weight * s.shear
                    }
                }
            }
            return w > 0 ? (ax / w, sh / w) : (0, 0)
        }
    }

    /// Rule B: each rib and abdominal-wall coordinate's stiffness by its strain.
    public func bent(_ spine: SpineShape, rules: GravityRules) -> SidedBody {
        guard !spine.isNeutral else { return self }
        var b = self
        let strains = coordinateStrains(spine)
        for c in SidedCoordinate.allCases where !c.isDiaphragm {
            let s = strains[c.rawValue]
            let gain = c.isRib ? rules.ribBendGain : rules.wallBendGain
            b.stiffness[c.rawValue] *= exp(-gain * s.axial + rules.twistGain * s.shear)
        }
        return b
    }
}

extension AnatomyModel {
    /// How far each hemidiaphragm's rim (the costal margin above the middle of that dome) drops
    /// toward the pelvis because of the spine's shape, cm (left, right): the wall's lengthwise strain
    /// at the dome's centre (x = ±4w/3π, the middle depth), summed from the pelvis to the costal margin.
    public func rimDrop(_ spine: SpineShape) -> [Double] {
        let (ap, w) = base(0.5 * (costalMargin + xiphoid))
        let xbar = 4 * w / (3 * .pi), rad = Double.pi / 180, dz = 0.25
        return Side.allCases.map { side in
            let x = side == .left ? xbar : -xbar
            var drop = 0.0, z = dz / 2
            while z < costalMargin {
                let (lumbar, length) = segment(z)
                let flex = (lumbar ? spine.lumbarFlexion : spine.thoracicFlexion) * rad / length
                let bend = (lumbar ? spine.lumbarSideBend : spine.thoracicSideBend) * rad / length
                drop += (flex * (ap / 2 - AnatomyModel.bendAxisDepth) + bend * x) * dz   // shortening (−ε) summed
                z += dz
            }
            return drop
        }
    }
}

extension SidedBody {
    /// The bend's effect on the domes, solved instead of assumed (`GravityRules.bendDomeSolved`).
    /// A bend changes the abdominal cavity's height under each hemidiaphragm by −rimDrop (each
    /// side's half-section). The contents are incompressible and, under Rule A, fluid: they keep
    /// their volume, so the coordinates must take up the cavity's change, and the settle solve
    /// (stiffnesses as bent, muscles relaxed) divides it between the domes, the belly wall and the
    /// ribs by their compliances. The side-to-side part needs nobody to move: the fluid flows from
    /// the crowded side to the open one. Returns each dome's rise relative to its rim, litres
    /// (left, right; + toward the chest, longer fibres), the cavity's change, and the change in
    /// abdominal pressure (cmH2O).
    public func bendSettle(_ spine: SpineShape) -> (rise: [Double], cavity: Double, pab: Double) {
        let n = SidedCoordinate.count, a = anatomy
        let drop = a.rimDrop(spine)
        let (ap, w) = a.base(0.5 * (a.costalMargin + a.xiphoid))
        let cavity = -(drop[0] + drop[1]) * a.halfArea(ap, w) / 1000
        var rhs = [Double](repeating: 0, count: n + 4)
        rhs[n + 2] = -cavity
        let x = multiply(invert(systemMatrix(flow: 0)), rhs)
        let q = Array(x[0..<n])
        func dot(_ v: [Double]) -> Double { zip(v, q).reduce(0) { $0 + $1.0 * $1.1 } }
        return ((0..<2).map { -dot(geometry.diaphragm[$0]) }, cavity, x[n + 2])
    }
}
