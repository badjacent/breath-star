import Foundation

// A1: low-resolution anatomical geometry and kinematics. No mechanics: the
// coordinates are prescribed (or found by inverse-mapping regional volumes),
// and every observable is computed from the shape they produce.
//
// Body-fixed frame, centimetres: z up from the pelvis (top of the iliac crests),
// y forward from the spine (the back of each section sits on the spine, y = 0),
// x sideways (+ left). Camera views are a rendering matter, not part of this.
//
// The trunk is a stack of cross-sections. Each side's half is a half-ellipse
// with its own half-width w_s and the section's shared depth AP:
//     area_s = π · w_s · AP / 4
// Regions follow the OEP compartments by landmark:
//     abdomen        z ∈ [0, costalMargin)
//     lower ribcage  z ∈ [costalMargin, xiphoid)
//     upper ribcage  z ∈ [xiphoid, top]

/// One prescribed or derived anatomical state. Per-side arrays are indexed by Side.rawValue.
public struct AnatomyState: Sendable, Equatable {
    /// Rib-band rotation as a fraction of its FRC→TLC rotation (Wilson 1987), per side.
    public var upperRib: [Double] = [0, 0]
    public var lowerRib: [Double] = [0, 0]
    /// Lower band's pump-handle rotation, as a fraction of its FRC→TLC pump angle, when it is
    /// separate from the bucket (A2): ribs 7–10 join the sternum through the costal-cartilage
    /// arch, so their front can move with the sternum while their sides swing out. nil: the pump
    /// follows the band's rotation (mean of lowerRib), as in A1.
    public var lowerPump: Double? = nil
    /// Rib-band dilation: the band's arcs open about the spine with no rotation (rib radius
    /// growing, costal cartilage straightening), as a fraction of the section's size, per side.
    /// Wilson 1987 reports a small radius increase from FRC to TLC. Moves the wall forward and
    /// out, never up.
    public var upperDilation: [Double] = [0, 0]
    /// Lower band: transverse dilation per side, and front-to-back dilation (shared, as the
    /// sternum and costal cartilages are). Kept separate because the lower ribcage's front and
    /// sides face different cavities (pleural vs. abdominal, through the zone of apposition) and
    /// can move differently (Estenne & De Troyer 1985). A1's inverse map keeps them equal.
    public var lowerDilation: [Double] = [0, 0]
    public var lowerDilationAP: Double = 0
    /// Thoracic spine extension, radians: the trunk above the thoracolumbar junction tilts back
    /// about the spine, moving the upper back backward and lifting the front. Gómez-Recio et al.
    /// 2024 (OEP shape analysis) report minor thoracic extension during inspiration seated, more
    /// standing. No published size for quiet breathing was found: a hypothesis, swept.
    public var spineExtension: Double = 0
    /// Hemidiaphragm descent, cm, per side.
    public var diaphragm: [Double] = [0, 0]
    /// Abdominal wall outward displacement at the bulge's peak, cm: front (shared) and flank (per side).
    public var abdomenFront: Double = 0
    public var abdomenFlank: [Double] = [0, 0]

    public init() {}
}

/// Every number the geometry uses, with where it comes from.
public struct AnatomyModel: Sendable {
    // Landmarks, cm above the iliac crests. ASSUMED (rough adult male, 175 cm); to source.
    public var costalMargin = 18.0
    public var xiphoid = 25.0
    public var top = 43.0
    /// The ribs' lower edge at the side (the 10th rib's tip and the ribs behind it), cm; nil: flat at
    /// `costalMargin` all round (the model until 2026-11-11). Anatomically the costal margin runs from
    /// the front down and out along the costal arch to the 10th rib's tip, below the front's level.
    /// When set, the ribs reach `ribBottom(ψ)`: `costalMargin` in front (ψ ≤ 30°), falling linearly to
    /// this value at ψ = 70° (the anterior axillary line) and staying there behind. ASSUMED shape.
    public var lateralRibMargin: Double? = nil

    /// Height of the ribs' lower edge at ψ (degrees), cm.
    public func ribBottom(psiDegrees psi: Double) -> Double {
        guard let l = lateralRibMargin else { return costalMargin }
        if psi <= 30 { return costalMargin }
        if psi >= 70 { return l }
        return costalMargin + (l - costalMargin) * (psi - 30) / 40
    }

    /// End-expiratory sitting profile: (z, AP depth, full width), cm, interpolated linearly.
    /// Sourced (Takashima 2017 Table 2, sitting, 15 men): abdomen AP 27.15 / width 31.20 at
    /// mid-abdomen; lower ribcage AP 22.37 / width 32.35; upper ribcage AP 20.10.
    /// ASSUMED: upper-ribcage width 30.0, and the pelvis and top tapers.
    public var profile: [(z: Double, ap: Double, width: Double)] = [
        (0, 25.0, 32.0),
        (9, 27.15, 31.20),
        (21.5, 22.37, 32.35),
        (34, 20.10, 30.0),
        (43, 15.0, 25.0),
    ]

    /// Rib rotation over FRC→TLC, degrees (Wilson 1987, abstract): rib 3 for the upper band,
    /// rib 7 for the lower band.
    public var upperPumpDegrees = 11.0, upperBucketDegrees = 13.0
    public var lowerPumpDegrees = 7.0, lowerBucketDegrees = 10.0

    /// How far a rib's front end lies below its rotation axis, cm. Pump rotation moves a
    /// front point forward in proportion to this drop and up in proportion to its depth.
    /// ASSUMED anatomical slope (rib heads sit roughly four vertebrae above their front ends);
    /// to source. Matching Takashima's marker directions with rotation alone would need 25–33 cm,
    /// which is impossible: non-lifting expansion (dilation) supplies the forward component
    /// (the working log (private), A1).
    public var upperRibDrop = 10.0, lowerRibDrop = 12.0
    /// How far a rib's lateral-most point lies below the bucket axis, as a fraction of the
    /// front drop. ASSUMED.
    public var lateralDropFraction = 0.5

    /// Hemidiaphragm effective piston area as a fraction of its half of the lower-ribcage
    /// section. ASSUMED ("widening piston", Gauthier 1994, is not yet represented).
    public var domeAreaFraction = 0.6
    /// Front-to-back tilt of the diaphragm's descent: at AP position u (−1 front edge, 0 middle,
    /// +1 back edge) a hemidiaphragm descends `d·(1 + tilt·u)`. Area-weighted, u averages 0 over
    /// the section, so the volume displaced is unchanged: the tilt only moves WHERE it is taken.
    /// Direction sourced: dorsal > ventral regardless of posture (Krayer 1989, CT, 5 of 6
    /// subjects; Gierada 1995, MRI, a front-to-back gradient), larger supine (Takazakura 2004,
    /// posterior−anterior difference larger supine in 5 of 6 planes). Supine size from Kolář 2009
    /// (16 adults, supine tidal MRI): posterior costophrenic angle 39 mm vs apex 27.3 mm, ratio 1.43
    /// → 0.43 with the apex taken as the middle. Seated 0.2 is ASSUMED (smaller, per Takazakura;
    /// no seated number found).
    public var diaphragmTilt = 0.2
    /// How the abdominal wall's forward bulge falls off around the trunk, ((1 + cos ψ)/2)^exponent,
    /// and how the costal margin's lift fades down the wall, carry^exponent. Both were 1 (assumed)
    /// until 2026-11-09. Scanned against all 12 Takashima components per posture: 3.5 and 8 (broad
    /// minimum, bulge 3–4, carry 6–12). The bulge is concentrated in front; the flank barely follows
    /// the ribs' lift. RESULTS of a fit (the working log (private), "abdominal wall shape").
    public var bulgeExponent = 3.5
    /// Where the belly wall's own bulge peaks, as a fraction of the height from the pelvis to the
    /// costal margin. 0.5: midway (the default). Knees bent (`Legs`) lower it: the slackened low wall
    /// moves more (docs/LESSON_ADAPTATION.md §4.6). ASSUMED.
    public var bulgePeak = 0.5
    public var verticalCarryExponent = 8.0
    /// The abdominal flank's own bulge per side relative to the front's, on top of the motion
    /// it carries from the costal margin. Negative: the flanks draw in slightly while the front
    /// bulges. A RESULT of `fitToMarkers` on Takashima sitting (surface volumes, arch-constrained,
    /// 2026-11-09): −0.06; with all 12 Takashima components and the fitted wall shape: −0.03.
    /// Not robust in size: −0.13 (slice volumes), −0.15 (surface, no arch). Used where the flank is
    /// tied to the front (the inverse map, A2's abdominal coordinate).
    public var flankRatio = -0.03
    /// Share of each rib band's (surface) region volume that comes from dilation rather than
    /// rotation, used by the inverse map. A RESULT of `fitToMarkers` on Takashima sitting
    /// (arch-constrained, 2026-11-09): upper 0.56; lower 1.24, above 1 because the lower band's
    /// rotation lifts the costal-margin ring and hands volume to the abdominal compartment (its
    /// own region change is negative), as OEP's ring-bounded compartments would show.
    public var upperDilationShare = 0.56, lowerDilationShare = 1.24

    /// Height of the extension pivot (thoracolumbar junction, at the spine), cm, and the half-width
    /// of the zone over which the tilt fades in. ASSUMED.
    public var extensionPivot = 15.0
    public var extensionBlend = 3.0
    /// How far the lung's lower edge (the top of the zone of apposition) is raised, cm: the
    /// dome's rise at a posture's operating point (OperatingPoint). 0 seated.
    public var appositionShift = 0.0
    /// Extra rise of the lung's lower edge on each side (left, right), cm: side-lying, the
    /// dependent hemidiaphragm is pushed further headward than the upper one (SidedOperatingPoint).
    public var appositionShiftBySide = [0.0, 0.0]
    /// Whether that rise follows the diaphragm's front-to-back tilt (more at the back). Froese &
    /// Bryan 1974: lying on the back, the abdominal contents push the dependent (dorsal) part of
    /// the diaphragm furthest headward. The same tilt as the descent is ASSUMED for the rise.
    public var tiltedApposition = true
    /// Mean diaphragm descent, cm, at which the lung edge is taken (0: end expiration). A2 is
    /// linear about one state; taking the apposition boundary at mid-breath (half the reference
    /// descent, tilted) is an EXPLORATORY way to let the zone's shortening during the breath count.
    public var appositionDescent = 0.0

    public init() {}

    /// Lying on the back. End-expiratory diameters from Takashima 2017 Table 2, supine
    /// (15 men): upper ribcage AP 16.88; lower ribcage AP 19.26, width 32.51; abdomen AP 18.11,
    /// width 31.06 cm. ASSUMED, as seated: upper-ribcage width 30.0, the pelvis and top tapers
    /// (scaled by the supine/seated depth ratio), and the landmarks. Rib and wall kinematics
    /// (slopes, dilation shares, flank ratio) are kept from the seated fits.
    public static func supine() -> AnatomyModel {
        var m = AnatomyModel()
        m.profile = [
            (0, 25.0 * 18.11 / 27.15, 32.0),
            (9, 18.11, 31.06),
            (21.5, 19.26, 32.51),
            (34, 16.88, 30.0),
            (43, 15.0 * 16.88 / 20.10, 25.0),
        ]
        m.diaphragmTilt = 0.43
        return m
    }

    /// Descent at AP position u (−1 front edge, +1 back edge) for a hemidiaphragm whose mean
    /// (piston) descent is d. See `diaphragmTilt`.
    public func diaphragmDescent(_ d: Double, at u: Double) -> Double { d * (1 + diaphragmTilt * u) }

    /// Share of the diaphragm's displaced volume taken by the back half of the dome:
    /// (1 + tilt·4/3π)/2, from the mean |u| of a half-ellipse (4/3π).
    public var diaphragmBackShare: Double { (1 + diaphragmTilt * 4 / (3 * .pi)) / 2 }

    static let dz = 0.25

    // MARK: profile

    func base(_ z: Double) -> (ap: Double, halfWidth: Double) {
        let p = profile
        if z <= p.first!.z { return (p.first!.ap, p.first!.width / 2) }
        for (a, b) in zip(p, p.dropFirst()) where z <= b.z {
            let t = (z - a.z) / (b.z - a.z)
            return (a.ap + t * (b.ap - a.ap), 0.5 * (a.width + t * (b.width - a.width)))
        }
        return (p.last!.ap, p.last!.width / 2)
    }

    /// The abdominal wall's displacement profile: zero at the pelvis and costal margin.
    func bulge(_ z: Double, height: Double? = nil) -> Double {
        let h = height ?? costalMargin
        guard z >= 0, z < h else { return 0 }
        let u = z / h
        guard bulgePeak != 0.5 else { return sin(.pi * u) }
        // Warp so the peak sits at `bulgePeak` (a fraction of the pelvis-to-margin height).
        return sin(.pi * pow(u, log(0.5) / log(bulgePeak)))
    }

    func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    func pump(_ s: AnatomyState, upper: Bool) -> Double {
        let mean = upper ? 0.5 * (s.upperRib[0] + s.upperRib[1]) : (s.lowerPump ?? 0.5 * (s.lowerRib[0] + s.lowerRib[1]))
        return mean * radians(upper ? upperPumpDegrees : lowerPumpDegrees)
    }

    func bucket(_ s: AnatomyState, upper: Bool, side: Int) -> Double {
        (upper ? s.upperRib[side] : s.lowerRib[side]) * radians(upper ? upperBucketDegrees : lowerBucketDegrees)
    }

    // MARK: sections

    /// The section at height z: depth (shared, set by the sternum and front wall) and the
    /// half-width of each side. Derived from the surface-motion field, so the volumes and the
    /// drawn surface can't disagree: depth moves with the front midline point (ψ = 0), each
    /// half-width with that side's lateral-most point (ψ = 90°).
    public func section(_ z: Double, _ s: AnatomyState) -> (ap: Double, halfWidth: [Double]) {
        let (ap0, w0) = base(z)
        // Depth is front minus back: the back can move now (spine extension translates a section
        // rigidly, which leaves its area unchanged).
        let front = surfaceDisplacement(z: z, psiDegrees: 0, side: .left, s)
        let back = surfaceDisplacement(z: z, psiDegrees: 180, side: .left, s)
        return (ap0 + front.y - back.y, Side.allCases.map { w0 + surfaceDisplacement(z: z, psiDegrees: 90, side: $0, s).x })
    }

    /// Width of the zone over which the upper and lower rib bands blend, either side of the
    /// xiphoid, cm. The ribs are continuous structures; the bands are a coarse division of
    /// them, so their motions shouldn't switch abruptly at a landmark. ASSUMED.
    static let bandBlend = 2.0

    /// Weight of the upper band at height z (0 below the blend zone, 1 above, smooth between).
    func upperWeight(_ z: Double) -> Double {
        let t = (z - (xiphoid - Self.bandBlend)) / (2 * Self.bandBlend)
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        return t * t * (3 - 2 * t)
    }

    /// How much of the costal margin's motion the abdominal wall carries at height z: the wall
    /// hangs between the pelvis (fixed, 0) and the costal margin (moving with the lower ribs, 1).
    func marginCarry(_ z: Double, height: Double? = nil) -> Double {
        guard z > 0 else { return 0 }
        return sin(.pi / 2 * min(1, z / (height ?? costalMargin)))
    }

    func halfArea(_ ap: Double, _ w: Double) -> Double { .pi * w * ap / 4 }

    /// Volume of one side's region, litres.
    /// Volume of one side's region by fixed-height sections, litres. A diagnostic since the switch to
    /// surface volumes: it ignores vertical motion of the wall.
    public func sliceVolume(_ s: AnatomyState, from z0: Double, to z1: Double, side: Int) -> Double {
        var v = 0.0
        var z = z0 + Self.dz / 2
        while z < z1 {
            let sec = section(z, s)
            v += halfArea(sec.ap, sec.halfWidth[side]) * Self.dz
            z += Self.dz
        }
        return v / 1000
    }

    /// The hemidiaphragm's effective piston area, cm², from the end-expiratory lower ribcage.
    public func domeArea(side: Int) -> Double {
        let (ap, w) = base(0.5 * (costalMargin + xiphoid))
        return domeAreaFraction * halfArea(ap, w)
    }
}

/// Everything computed from one state, as changes from end expiration.
public struct AnatomyObservables: Sendable {
    /// OEP-style regional volume changes, litres, per side.
    public var upperRibcage: [Double]
    public var lowerRibcage: [Double]
    public var abdomen: [Double]
    /// Volume the hemidiaphragm displaces, litres, per side.
    public var diaphragmVolume: [Double]
    /// Each lung's volume change: upper-ribcage expansion plus diaphragm descent on that side.
    public var lung: [Double]
    /// Of each side's diaphragm volume, what the back half of the lung base takes (litres).
    public var posteriorLungBase: [Double]
    /// Named surface markers: displacement (x sideways + left, y forward, z up), mm.
    public var markers: [String: (x: Double, y: Double, z: Double)]

    public var totalLung: Double { lung.reduce(0, +) }
    public var totalSurface: Double { (upperRibcage + lowerRibcage + abdomen).reduce(0, +) }
}

extension AnatomyModel {
    public func observe(_ s: AnatomyState) -> AnatomyObservables {
        let rest = AnatomyState()
        // Regional volumes on the moving surface (OEP-like): each region is bounded by the material
        // rings that sit at its landmarks at rest, followed as they move. Vertical motion counts.
        // (Before 2026-11-09 these were fixed-height slices, which missed ~13% of a seated breath;
        // `sliceVolume` keeps that definition for comparison.)
        func change(_ z0: Double, _ z1: Double) -> [Double] {
            Side.allCases.map { surfaceVolume(s, from: z0, to: z1, side: $0) - restSurfaceVolume(from: z0, to: z1, side: $0) }
        }
        _ = rest
        let upper = change(xiphoid, top)
        let lower = change(costalMargin, xiphoid)
        let abdomen = change(0, costalMargin)
        let dia = (0..<2).map { domeArea(side: $0) * s.diaphragm[$0] / 1000 }
        let lung = (0..<2).map { upper[$0] + dia[$0] }

        // Markers, averaged over the surface sector they stand for, as Takashima's marker
        // groups are: anterior = ±40° about the front midline, lateral = 60–120° on the
        // left side; over the region's height.
        let sectors: [(String, ClosedRange<Double>, ClosedRange<Double>, Side)] = [
            ("anterior upper ribcage", xiphoid...top, -40...40, .left),
            ("anterior lower ribcage", costalMargin...xiphoid, -40...40, .left),
            ("left lateral lower ribcage", costalMargin...xiphoid, 60...120, .left),
            ("anterior abdomen", 0...costalMargin, -40...40, .left),
            ("left lateral abdomen", 0...costalMargin, 60...120, .left),
            ("posterior upper ribcage", xiphoid...top, 140...180, .left),
            // Back-body markers (2026-11-09): the back surface near the spine, the posterolateral
            // lower ribs (the "back ribs" one feels widen), and the low back.
            ("posterior lower ribcage", costalMargin...xiphoid, 160...180, .left),
            ("left posterolateral lower ribcage", costalMargin...xiphoid, 115...160, .left),
            ("posterior abdomen", 0...costalMargin, 160...180, .left),
        ]
        var m: [String: (x: Double, y: Double, z: Double)] = [:]
        for (name, zs, psis, side) in sectors {
            var sum = (x: 0.0, y: 0.0, z: 0.0), n = 0.0
            for zi in 0..<12 {
                let t = (Double(zi) + 0.5) / 12
                for pi in 0..<9 {
                    let psi = psis.lowerBound + (Double(pi) + 0.5) / 9 * (psis.upperBound - psis.lowerBound)
                    // A bound at the costal margin follows the ribs' lower edge (flat unless
                    // `lateralRibMargin` is set): a marker group labelled "abdomen" stays on the belly.
                    let lo = zs.lowerBound == costalMargin ? ribBottom(psiDegrees: abs(psi)) : zs.lowerBound
                    let hi = zs.upperBound == costalMargin ? ribBottom(psiDegrees: abs(psi)) : zs.upperBound
                    let z = lo + t * (hi - lo)
                    let d = surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
                    sum.x += d.x; sum.y += d.y; sum.z += d.z; n += 1
                }
            }
            m[name] = (10 * sum.x / n, 10 * sum.y / n, 10 * sum.z / n)  // cm → mm
        }

        return AnatomyObservables(upperRibcage: upper, lowerRibcage: lower, abdomen: abdomen,
                                  diaphragmVolume: dia, lung: lung,
                                  posteriorLungBase: dia.map { $0 * diaphragmBackShare }, markers: m)
    }

    /// Displacement (cm; x outward on that side, y forward, z up) of the surface point at
    /// height z and angle ψ around its half-section (0° front midline, 90° side, 180° spine).
    ///
    /// Ribs rotate about axes near the spine (Wilson 1987). A rib point's distance below its
    /// pump axis grows linearly from the spine to the front (drop · y/AP), so pump rotation φ
    /// moves it forward by drop·(y/AP)·φ and up by y·φ. Its distance below the bucket axis
    /// grows with distance from the midline, so bucket rotation β moves it out by
    /// lateralDrop·(x/w)·β and up by x·β. The abdominal wall moves along its bulge profile.
    public func surfaceDisplacement(z: Double, psiDegrees: Double, side: Side,
                                    _ s: AnatomyState) -> (x: Double, y: Double, z: Double) {
        let local = localDisplacement(z: z, psiDegrees: psiDegrees, side: side, s)
        guard s.spineExtension != 0 else { return local }
        // Spine extension: a small rigid tilt backward about a transverse axis at the spine at the
        // pivot height, faded in across the pivot zone. A point a distance y in front of the spine
        // moves up by y·χ; a point a height h above the pivot moves back by h·χ.
        let (ap, _) = base(z)
        let e = extensionOffset(y: ap / 2 * (1 + cos(psiDegrees * .pi / 180)), z: z, s)
        return (local.x, local.y + e.dy, local.z + e.dz)
    }

    /// The spine-extension displacement of any point a distance y in front of the spine at height
    /// z (rest position), cm. Public so drawings (ribs, spine) move with the same field.
    public func extensionOffset(y: Double, z: Double, _ s: AnatomyState) -> (dy: Double, dz: Double) {
        let t = (z - (extensionPivot - extensionBlend)) / (2 * extensionBlend)
        let w = t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t)
        let chi = s.spineExtension * w
        return (-(z - extensionPivot) * chi, y * chi)
    }

    /// Displacement from the ribs, the dilations and the abdominal wall, before spine extension.
    func localDisplacement(z: Double, psiDegrees: Double, side: Side,
                           _ s: AnatomyState) -> (x: Double, y: Double, z: Double) {
        let psi = psiDegrees * .pi / 180
        let rb = ribBottom(psiDegrees: psiDegrees)
        if z >= rb {
            let u = upperWeight(z)
            let a = u > 0 ? ribDisplacement(z: z, psi: psi, side: side, upper: true, s) : (x: 0.0, y: 0.0, z: 0.0)
            let b = u < 1 ? ribDisplacement(z: z, psi: psi, side: side, upper: false, s) : (x: 0.0, y: 0.0, z: 0.0)
            return (u * a.x + (1 - u) * b.x, u * a.y + (1 - u) * b.y, u * a.z + (1 - u) * b.z)
        }
        // Abdominal wall: carried by the costal margin above (fading to the fixed pelvis), plus
        // its own bulge, which is zero at both attachments. Continuous with the ribs at the margin.
        let margin = ribDisplacement(z: rb, psi: psi, side: side, upper: false, s)
        let c = marginCarry(z, height: rb), b = bulge(z, height: rb)
        return (margin.x * c + s.abdomenFlank[side.rawValue] * b * abs(sin(psi)),
                margin.y * c + s.abdomenFront * b * pow((1 + cos(psi)) / 2, bulgeExponent),
                margin.z * pow(c, verticalCarryExponent))
    }

    /// One rib band's displacement of the surface point at (z, ψ), cm.
    func ribDisplacement(z: Double, psi: Double, side: Side, upper: Bool,
                         _ s: AnatomyState) -> (x: Double, y: Double, z: Double) {
        let (ap, w) = base(z)
        let y = ap / 2 * (1 + cos(psi))
        let x = w * abs(sin(psi))
        let drop = upper ? upperRibDrop : lowerRibDrop
        let phi = sin(pump(s, upper: upper))
        let beta = sin(bucket(s, upper: upper, side: side.rawValue))
        let dil = upper ? s.upperDilation : s.lowerDilation
        let eps = dil[side.rawValue], epsAP = upper ? 0.5 * (dil[0] + dil[1]) : s.lowerDilationAP
        // A point's depth below the rib head: the head-to-front chord's depth at its AP position,
        // drop·y/ap, plus its sag below the chord, lateralDrop·drop·x/w. Pump rotation (about a
        // transverse axis at the head) moves it forward by that whole depth; bucket rotation (about
        // the chord) moves it out by the sag. Until 2026-11-09 pump used the chord depth alone,
        // which moved the side forward half as much as the front; Jordanoglou 1969 finds every
        // point along a rib moving parallel (the working log (private), "rib sag in pump").
        let sag = lateralDropFraction * drop * (x / w)
        return (sag * beta + x * eps,
                (drop * (y / ap) + sag) * phi + y * epsAP,
                y * phi + x * beta)
    }

    /// Sets the abdominal wall so that the abdomen's contents keep their volume:
    /// what the diaphragms push down goes into the lower ribcage's enclosure and the wall.
    /// The front/flank split follows flankRatio.
    public func closeAbdomen(_ s: AnatomyState) -> AnatomyState {
        var s = s
        let dia = (0..<2).reduce(0.0) { $0 + domeArea(side: $1) * s.diaphragm[$1] / 1000 }
        func excess(_ front: Double) -> Double {
            var t = s
            t.abdomenFront = front
            t.abdomenFlank = [front * flankRatio, front * flankRatio]
            let o = observe(t)
            return o.abdomen.reduce(0, +) + o.lowerRibcage.reduce(0, +) - dia
        }
        // The excess is (very nearly) linear in the front displacement at breathing scale:
        // a secant step, then two refinements.
        var x0 = 0.0, x1 = 0.5
        var f0 = excess(x0), f1 = excess(x1)
        for _ in 0..<3 {
            guard abs(f1 - f0) > 1e-15 else { break }
            let x2 = x1 - f1 * (x1 - x0) / (f1 - f0)
            x0 = x1; f0 = f1
            x1 = x2; f1 = excess(x2)
            if abs(f1) < 1e-9 { break }
        }
        s.abdomenFront = x1
        s.abdomenFlank = [s.abdomenFront * flankRatio, s.abdomenFront * flankRatio]
        return s
    }

    /// Inverse map: the symmetric state whose regional volume changes equal the targets
    /// (litres, both sides together). Ribs come from the ribcage volumes; the diaphragm
    /// descent from what the abdomen's enclosure must take (lower ribcage plus abdomen).
    public func state(upperRibcage: Double, lowerRibcage: Double, abdomen: Double) -> AnatomyState {
        // Volumes are (very nearly) linear in each coordinate at breathing scale: secant steps.
        func solve(_ target: Double, _ volume: (Double) -> Double) -> Double {
            var x0 = 0.0, x1 = 0.1
            var f0 = volume(x0) - target, f1 = volume(x1) - target
            for _ in 0..<4 {
                guard abs(f1 - f0) > 1e-15 else { break }
                let x2 = x1 - f1 * (x1 - x0) / (f1 - f0)
                x0 = x1; f0 = f1
                x1 = x2; f1 = volume(x2) - target
                if abs(f1) < 1e-10 { break }
            }
            return x1
        }
        // Each band moves along a fixed mix of rotation and dilation: the mix that, for the band
        // alone, gives `share` of its volume from dilation. The two bands are then scaled
        // jointly, because they blend across the xiphoid and the lower band carries the
        // abdominal wall: each band's motion reaches into neighbouring regions' volumes.
        func make(_ upper: Bool, _ r: Double, _ e: Double) -> AnatomyState {
            var t = AnatomyState()
            if upper { t.upperRib = [r, r]; t.upperDilation = [e, e] } else {
                t.lowerRib = [r, r]; t.lowerDilation = [e, e]; t.lowerDilationAP = e
            }
            return t
        }
        func ownVolume(_ upper: Bool, _ t: AnatomyState) -> Double {
            let o = observe(t)
            return (upper ? o.upperRibcage : o.lowerRibcage).reduce(0, +)
        }
        func direction(_ upper: Bool, _ target: Double, _ share: Double) -> (rotation: Double, dilation: Double) {
            let r0 = solve(target * (1 - share)) { ownVolume(upper, make(upper, $0, 0)) }
            let e0 = solve(target * share) { ownVolume(upper, make(upper, 0, $0)) }
            return (r0, e0)
        }
        let du = direction(true, upperRibcage, upperDilationShare)
        let dl = direction(false, lowerRibcage, lowerDilationShare)
        func combined(_ ku: Double, _ kl: Double) -> AnatomyState {
            var t = AnatomyState()
            t.upperRib = [ku * du.rotation, ku * du.rotation]
            t.upperDilation = [ku * du.dilation, ku * du.dilation]
            t.lowerRib = [kl * dl.rotation, kl * dl.rotation]
            t.lowerDilation = [kl * dl.dilation, kl * dl.dilation]
            t.lowerDilationAP = kl * dl.dilation
            return t
        }
        var ku = 1.0, kl = 1.0
        for _ in 0..<5 {
            ku = solve(upperRibcage) { k in self.observe(combined(k, kl)).upperRibcage.reduce(0, +) }
            kl = solve(lowerRibcage) { k in self.observe(combined(ku, k)).lowerRibcage.reduce(0, +) }
        }
        var s = combined(ku, kl)
        let perSide = (lowerRibcage + abdomen) * 1000 / 2
        s.diaphragm = (0..<2).map { perSide / domeArea(side: $0) }
        return closeAbdomen(s)
    }
}

extension AnatomyModel {
    /// Independent volume check: the volume enclosed by a closed triangulated surface built from
    /// the displaced surface points (including their vertical motion), with caps at the bottom
    /// (iliac crests) and the top (where the trunk is cut). Litres. Unlike the section integral,
    /// nothing here assumes sections stay at fixed heights; it's how OEP computes volume from
    /// markers. The top cap moves with the ribs, as OEP's would.
    public func meshVolume(_ s: AnatomyState, rings: Int = 120, around: Int = 72, pinTopLift: Bool = false) -> Double {
        // One ring per height: left side front→back, then right side back→front.
        // pinTopLift: the top ring keeps its height (only its horizontal motion), to separate the
        // volume swept by lifting the cut at the top of the trunk from the rest.
        func ring(_ z: Double) -> [(Double, Double, Double)] {
            let pin = pinTopLift && z >= top - 1e-9
            let (ap, w) = base(z)
            var pts: [(Double, Double, Double)] = []
            for k in 0...around {
                let psi = Double(k) / Double(around) * 180
                let r = psi * .pi / 180
                let d = surfaceDisplacement(z: z, psiDegrees: psi, side: .left, s)
                pts.append((w * sin(r) + d.x, ap / 2 * (1 + cos(r)) + d.y, z + (pin ? 0 : d.z)))
            }
            for k in stride(from: around - 1, through: 1, by: -1) {
                let psi = Double(k) / Double(around) * 180
                let r = psi * .pi / 180
                let d = surfaceDisplacement(z: z, psiDegrees: psi, side: .right, s)
                pts.append((-(w * sin(r) + d.x), ap / 2 * (1 + cos(r)) + d.y, z + (pin ? 0 : d.z)))
            }
            return pts
        }
        func tri(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ c: (Double, Double, Double)) -> Double {
            (a.0 * (b.1 * c.2 - b.2 * c.1) - a.1 * (b.0 * c.2 - b.2 * c.0) + a.2 * (b.0 * c.1 - b.1 * c.0)) / 6
        }
        let zs = (0...rings).map { Double($0) / Double(rings) * top }
        let all = zs.map(ring)
        var v = 0.0
        for i in 0..<rings {
            let a = all[i], b = all[i + 1], n = a.count
            for j in 0..<n {
                let j2 = (j + 1) % n
                // Rings run clockwise seen from above; this winding gives outward normals,
                // consistent with the caps (a first version had them inward, which halved the
                // rest volume).
                v += tri(a[j], b[j2], a[j2]) + tri(a[j], b[j], b[j2])
            }
        }
        func cap(_ r: [(Double, Double, Double)], flip: Bool) -> Double {
            let n = Double(r.count)
            let c = (r.reduce(0) { $0 + $1.0 } / n, r.reduce(0) { $0 + $1.1 } / n, r.reduce(0) { $0 + $1.2 } / n)
            var t = 0.0
            for j in 0..<r.count {
                let j2 = (j + 1) % r.count
                t += flip ? tri(c, r[j2], r[j]) : tri(c, r[j], r[j2])
            }
            return t
        }
        v += cap(all[0], flip: false) + cap(all[rings], flip: true)
        return abs(v) / 1000
    }
}

extension AnatomyModel {
    /// One side's region volume on the moving surface, litres: the surface between the material
    /// rings that sit at heights z0 and z1 at rest, closed by the midplane and by caps across the two
    /// rings. Neighbouring regions share caps (they cancel), and the two sides share the midplane,
    /// so regions and sides add up exactly to the closed trunk's volume.
    public func surfaceVolume(_ s: AnatomyState, from z0: Double, to z1: Double, side: Side,
                              ringsPerCm: Double = 1.5, around: Int = 24) -> Double {
        let n = max(2, Int(((z1 - z0) * ringsPerCm).rounded()))
        // A bound at the costal margin follows the ribs' lower edge (`ribBottom`; flat unless
        // `lateralRibMargin` is set), so the rings between are interpolated per ψ.
        func bound(_ z: Double, _ psi: Double) -> Double { z == costalMargin ? ribBottom(psiDegrees: psi) : z }
        // Half ring, clockwise seen from above: front → side → back, closed along the midplane.
        func ring(_ t: Double) -> [(Double, Double, Double)] {
            var pts: [(Double, Double, Double)] = []
            for k in 0...around {
                let psi = Double(k) / Double(around) * 180
                let lo = bound(z0, psi), hi = bound(z1, psi)
                let z = lo + t * (hi - lo)
                let (ap, w) = base(z)
                let r = psi * .pi / 180
                let d = surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
                pts.append((w * sin(r) + d.x, ap / 2 * (1 + cos(r)) + d.y, z + d.z))
            }
            if side == .right {
                // Mirror to negative x, and reverse to stay clockwise.
                return pts.map { (-$0.0, $0.1, $0.2) }.reversed()
            }
            return pts
        }
        func tri(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ c: (Double, Double, Double)) -> Double {
            (a.0 * (b.1 * c.2 - b.2 * c.1) - a.1 * (b.0 * c.2 - b.2 * c.0) + a.2 * (b.0 * c.1 - b.1 * c.0)) / 6
        }
        let rings = (0...n).map { ring(Double($0) / Double(n)) }
        var v = 0.0
        for i in 0..<n {
            let a = rings[i], b = rings[i + 1], m = a.count
            for j in 0..<m {
                let j2 = (j + 1) % m
                v += tri(a[j], b[j2], a[j2]) + tri(a[j], b[j], b[j2])
            }
        }
        func cap(_ r: [(Double, Double, Double)], top: Bool) -> Double {
            let c = (r.reduce(0) { $0 + $1.0 } / Double(r.count), r.reduce(0) { $0 + $1.1 } / Double(r.count),
                     r.reduce(0) { $0 + $1.2 } / Double(r.count))
            var t = 0.0
            for j in 0..<r.count {
                let j2 = (j + 1) % r.count
                t += top ? tri(c, r[j2], r[j]) : tri(c, r[j], r[j2])
            }
            return t
        }
        v += cap(rings[0], top: false) + cap(rings[n], top: true)
        return v / 1000
    }
}

/// Rest volumes depend only on the resting geometry (profile and landmarks), so they are cached.
private final class RestVolumeCache: @unchecked Sendable {
    let lock = NSLock()
    var values: [String: Double] = [:]
    static let shared = RestVolumeCache()
}

extension AnatomyModel {
    func restSurfaceVolume(from z0: Double, to z1: Double, side: Side) -> Double {
        let key = profile.map { "\($0.z),\($0.ap),\($0.width)" }.joined(separator: ";")
            + "|\(z0)|\(z1)|\(side.rawValue)|\(lateralRibMargin.map { "\($0)" } ?? "flat")"
        let cache = RestVolumeCache.shared
        if let v = cache.lock.withLock({ cache.values[key] }) { return v }
        let v = surfaceVolume(AnatomyState(), from: z0, to: z1, side: side)
        cache.lock.withLock { cache.values[key] = v }
        return v
    }
}


// MARK: - Fitting the anatomy directly to marker data (since the switch to surface volumes)

/// One published marker motion: the sector, the component, its mean and SD (mm).
public struct MarkerObservation: Sendable {
    public enum Component: String, Sendable { case forward, up, outward }
    public var marker: String
    public var component: Component
    public var mean: Double
    public var sd: Double

    public init(marker: String, component: Component, mean: Double, sd: Double) {
        self.marker = marker; self.component = component; self.mean = mean; self.sd = sd
    }

    public func value(_ o: AnatomyObservables) -> Double {
        let v = o.markers[marker]!
        switch component {
        case .forward: return v.y
        case .up: return v.z
        case .outward: return v.x
        }
    }
}

public enum TakashimaMarkers {
    /// Takashima et al. 2017, Table 3 (15 healthy men), the sector groups this model averages over.
    public static let sitting: [MarkerObservation] = [
        .init(marker: "anterior upper ribcage", component: .forward, mean: 1.91, sd: 1.37),
        .init(marker: "anterior upper ribcage", component: .up, mean: 1.94, sd: 1.07),
        .init(marker: "anterior lower ribcage", component: .forward, mean: 2.81, sd: 1.14),
        .init(marker: "anterior lower ribcage", component: .up, mean: 2.58, sd: 1.26),
        .init(marker: "left lateral lower ribcage", component: .outward, mean: 0.96, sd: 0.85),
        .init(marker: "left lateral lower ribcage", component: .up, mean: 2.19, sd: 0.94),
        .init(marker: "anterior abdomen", component: .forward, mean: 4.79, sd: 2.60),
        .init(marker: "left lateral abdomen", component: .outward, mean: 0.55, sd: 0.61),
        // Added 2026-11-09 (unused before): forward motion at the sides, the abdomen's up-down.
        .init(marker: "left lateral lower ribcage", component: .forward, mean: 2.11, sd: 1.09),
        .init(marker: "anterior abdomen", component: .up, mean: 0.93, sd: 0.93),
        .init(marker: "left lateral abdomen", component: .up, mean: 0.58, sd: 0.37),
        .init(marker: "left lateral abdomen", component: .forward, mean: 1.59, sd: 0.73),
    ]
    public static let supine: [MarkerObservation] = [
        .init(marker: "anterior upper ribcage", component: .forward, mean: 0.69, sd: 0.73),
        .init(marker: "anterior upper ribcage", component: .up, mean: 1.14, sd: 0.68),
        .init(marker: "anterior lower ribcage", component: .forward, mean: 1.50, sd: 0.73),
        .init(marker: "anterior lower ribcage", component: .up, mean: 1.69, sd: 0.61),
        .init(marker: "left lateral lower ribcage", component: .outward, mean: 0.41, sd: 0.44),
        .init(marker: "left lateral lower ribcage", component: .up, mean: 1.08, sd: 0.45),
        .init(marker: "anterior abdomen", component: .forward, mean: 5.55, sd: 1.83),
        .init(marker: "left lateral abdomen", component: .outward, mean: 0.77, sd: 0.40),
        // Added 2026-11-09 (unused before).
        .init(marker: "left lateral lower ribcage", component: .forward, mean: 1.48, sd: 0.52),
        .init(marker: "anterior abdomen", component: .up, mean: 0.73, sd: 0.60),
        .init(marker: "left lateral abdomen", component: .up, mean: 0.23, sd: 0.20),
        .init(marker: "left lateral abdomen", component: .forward, mean: 1.45, sd: 0.42),
    ]

    /// Right side down (Takashima 2017, Table 3, "right lateral"; 15 men, on the floor). The
    /// markers are on the upper (left) side and the front. "Forward" is toward the front of the
    /// body (horizontal when lying on the side), "up" toward the head.
    public static let rightSideDown: [MarkerObservation] = [
        .init(marker: "anterior upper ribcage", component: .forward, mean: 0.64, sd: 0.81),
        .init(marker: "anterior upper ribcage", component: .up, mean: 0.68, sd: 0.34),
        .init(marker: "anterior lower ribcage", component: .forward, mean: 0.94, sd: 0.53),
        .init(marker: "anterior lower ribcage", component: .up, mean: 1.03, sd: 0.37),
        .init(marker: "left lateral lower ribcage", component: .outward, mean: 1.70, sd: 0.58),
        .init(marker: "left lateral lower ribcage", component: .up, mean: 0.95, sd: 0.40),
        .init(marker: "left lateral lower ribcage", component: .forward, mean: 1.65, sd: 0.88),
        .init(marker: "anterior abdomen", component: .forward, mean: 5.23, sd: 1.66),
        .init(marker: "anterior abdomen", component: .up, mean: 0.54, sd: 0.73),
        .init(marker: "left lateral abdomen", component: .outward, mean: 1.17, sd: 0.50),
        .init(marker: "left lateral abdomen", component: .up, mean: -0.11, sd: 0.33),
        .init(marker: "left lateral abdomen", component: .forward, mean: 1.25, sd: 0.63),
    ]
}

public struct MarkerFit: Sendable {
    public var state: AnatomyState
    public var parameterNames: [String]
    public var parameters: [Double]
    /// Per observation: model value and published mean ± SD.
    public var rows: [(observation: MarkerObservation, model: Double)]
    public var tidalVolume: Double
    /// Σ ((model − mean) / SD)² over the markers.
    public var chiSquared: Double
}

extension AnatomyModel {
    /// Fit a symmetric breath to published marker motions and a tidal volume, by weighted linear
    /// least squares (the kinematics are very nearly linear at breathing scale). Free: each band's
    /// rotation and (isotropic) dilation, the abdominal front and flank, and optionally thoracic
    /// spine extension. The diaphragm follows from the abdomen's closure (its contents keep their
    /// volume), so it is not free. The tidal volume (total surface volume) is weighted heavily.
    /// With `arch` on (the default), the lower band's pump is its own parameter and the fit is
    /// constrained so that the lower front moves forward with the sternum (the costal-cartilage
    /// arch, as A2's sternal coupling assumes); otherwise the reference breath would load that
    /// coupling with large forces (the working log (private), "surface volumes").
    public func fitToMarkers(_ data: [MarkerObservation], tidal: Double, includeExtension: Bool = false,
                             tidalSD: Double = 0.005, arch: Bool = true, archSD: Double = 0.002) -> MarkerFit {
        var names = ["upper rotation", "upper dilation", "lower bucket rotation", "lower dilation", "abdomen front",
                     "abdomen flank", "lower pump rotation"]
        if includeExtension { names.append("spine extension") }
        let n = names.count
        func state(_ p: [Double]) -> AnatomyState {
            var s = AnatomyState()
            s.upperRib = [p[0], p[0]]
            s.upperDilation = [p[1], p[1]]
            s.lowerRib = [p[2], p[2]]
            s.lowerDilation = [p[3], p[3]]
            s.lowerDilationAP = p[3]
            s.abdomenFront = p[4]
            s.abdomenFlank = [p[5], p[5]]
            s.lowerPump = arch ? p[6] : p[2]
            if includeExtension { s.spineExtension = p[7] }
            // Diaphragm from closure: its volume is what the lower ribcage and abdomen take.
            let o = observe(s)
            let take = o.lowerRibcage.reduce(0, +) + o.abdomen.reduce(0, +)
            s.diaphragm = [take * 1000 / 2 / domeArea(side: 0), take * 1000 / 2 / domeArea(side: 1)]
            return s
        }
        let zSternum = xiphoid + AnatomyModel.bandBlend + 0.5, zLowerFront = 0.5 * (costalMargin + xiphoid)
        func residuals(_ p: [Double]) -> [Double] {
            let st = state(p)
            let o = observe(st)
            var r = data.map { ($0.value(o) - $0.mean) / $0.sd } + [(o.totalLung - tidal) / tidalSD]
            if arch {
                let mismatch = surfaceDisplacement(z: zSternum, psiDegrees: 0, side: .left, st).y
                    - surfaceDisplacement(z: zLowerFront, psiDegrees: 0, side: .left, st).y
                r.append(mismatch / archSD)
            } else {
                r.append(p[6])  // unused parameter pinned at 0
            }
            return r
        }
        // Linear: r(p) = r0 + J p. Columns by finite differences at p = 0.
        let zero = [Double](repeating: 0, count: n)
        let r0 = residuals(zero)
        let steps = [0.1, 0.01, 0.1, 0.01, 0.5, 0.1, 0.1, 0.005]
        let cols = (0..<n).map { i -> [Double] in
            var p = zero
            p[i] = steps[i]
            return zip(residuals(p), r0).map { ($0 - $1) / steps[i] }
        }
        // Normal equations: (JᵀJ) p = −Jᵀ r0.
        let jtj = (0..<n).map { i in (0..<n).map { j in zip(cols[i], cols[j]).reduce(0) { $0 + $1.0 * $1.1 } } }
        let jtr = (0..<n).map { i in -zip(cols[i], r0).reduce(0) { $0 + $1.0 * $1.1 } }
        var p = multiply(invert(jtj), jtr)
        // One refinement for the small nonlinearity.
        let r1 = residuals(p)
        let corr = multiply(invert(jtj), (0..<n).map { i in -zip(cols[i], r1).reduce(0) { $0 + $1.0 * $1.1 } })
        p = zip(p, corr).map { $0 + $1 }
        let s = state(p)
        let o = observe(s)
        let rows = data.map { ($0, $0.value(o)) }
        let chi = rows.reduce(0.0) { $0 + pow(($1.1 - $1.0.mean) / $1.0.sd, 2) }
        return MarkerFit(state: s, parameterNames: names, parameters: p, rows: rows, tidalVolume: o.totalLung, chiSquared: chi)
    }
}
