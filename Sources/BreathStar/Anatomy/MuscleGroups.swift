import Foundation

// Fixed-sign muscle groups (critique 3, section 3; the work plan (private), step 3).
//
// `A2Body.calibrate` gives every coordinate its own free force and solves whatever reproduces the
// reference exactly. That fits by construction and hides stiffness errors in invented forces: the
// lower band's solved forces pull the ribs IN during inspiration. Here a few muscle groups replace
// them. Each acts like a pressure on the wall it moves (F_i = P_g · |own_i| for its coordinates),
// with P_g ≥ 0, so nothing pulls the ribs inward during inspiration. The few pressures are fitted to
// the markers and the tidal volume; the reference is no longer matched exactly, and the misfit is
// information (about the stiffnesses, chiefly).
//
// Groups (ASSUMED mapping onto A2's coordinates):
//   diaphragm      the diaphragm's descent (its insertional pull on the lower ribs is not separated;
//                  the appositional pull is already in the mechanics through the abdominal pressure);
//   upper ribcage  scalenes and upper parasternals: the upper band's rotation and dilation;
//   lower ribcage  lower parasternals and lower external intercostals: the lower band's pump, bucket
//                  and dilations.
// The abdominal muscles stay relaxed (as in `calibrate`).

public enum A2MuscleGroup: Int, CaseIterable, Sendable {
    case diaphragm, upperRibcage, lowerRibcage

    public var coordinates: [A2Coordinate] {
        switch self {
        case .diaphragm: [.diaphragm]
        case .upperRibcage: [.upperRotation, .upperDilation]
        case .lowerRibcage: A2Coordinate.lowerBand
        }
    }

    public var label: String {
        switch self {
        case .diaphragm: "diaphragm"
        case .upperRibcage: "upper rib-cage group (scalenes, upper parasternals)"
        case .lowerRibcage: "lower rib-cage group (lower intercostals)"
        }
    }
}

/// A compartment-volume target for the group fit: each compartment's share of the breath (upper
/// ribcage, lower ribcage, abdomen) with its between-subject SD, as OEP reports them. Entered as
/// volumes (share × tidal), so the fit stays linear in the pressures.
public struct VolumeShareTarget: Sendable {
    public var label: String
    public var shares: [Double], sds: [Double]
    public init(_ label: String, shares: [Double], sds: [Double]) { self.label = label; self.shares = shares; self.sds = sds }
    /// Mendes 2020, men seated (OEP, n = 31): 37.4 (8.4) / 21.9 (5.8) / 40.8 (10.5) %.
    public static let mendesMenSeated = VolumeShareTarget("Mendes 2020 men seated", shares: [0.374, 0.219, 0.408], sds: [0.084, 0.058, 0.105])
}

/// The result of fitting the groups' pressures.
public struct MuscleGroupFit: Sendable {
    public var body: A2Body
    /// Each group's peak pressure, cmH2O (before tidal matching), ≥ 0.
    public var pressures: [Double]
    /// Per marker component: model value at the static end inspiration, and the observation.
    public var rows: [(observation: MarkerObservation, model: Double)]
    /// Static end-inspiratory lung volume, litres.
    public var tidalVolume: Double
    /// Σ ((model − mean)/SD)² over the markers.
    public var chiSquared: Double
    public var lowerBandStiffness: Double
}

extension A2Body {
    /// The static (no-flow) end-inspiratory state for generalised forces f: K q = Ppl·J_th + Pab·J_ab + f,
    /// with Ppl = −V_th / CL and the abdomen's contents incompressible (J_ab · q = 0).
    public func staticResponse(_ f: [Double]) -> [Double] {
        let n = A2Coordinate.count
        let jth = geometry.thorax, jab = geometry.abdominalCavity, cl = passive.lungCompliance
        let k = stiffnessMatrix
        var a = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n + 1)
        for i in 0..<n {
            for j in 0..<n { a[i][j] = k[i][j] + jth[i] * jth[j] / cl }
            a[i][n] = -jab[i]
            a[n][i] = jab[i]
        }
        let x = multiply(invert(a), f + [0])
        return Array(x[0..<n])
    }

    /// A group's force pattern per unit pressure: |own volume| on each of its coordinates.
    public func groupPattern(_ g: A2MuscleGroup) -> [Double] {
        let own = geometry.own
        var f = [Double](repeating: 0, count: A2Coordinate.count)
        for c in g.coordinates { f[c.rawValue] = abs(own[c.rawValue]) }
        return f
    }

    /// Fit non-negative group pressures to marker data and a tidal volume (static end inspiration),
    /// optionally with the lower band's passive stiffness scaled. Solved exactly over the 2³ sign
    /// patterns (non-negative least squares by enumeration).
    public static func fitMuscleGroups(anatomy a: AnatomyModel, markers: [MarkerObservation], tidal: Double,
                                       passive: A2Passive = A2Passive(), lowerBandStiffness: Double = 1,
                                       tidalSD: Double = 0.005, volumes: VolumeShareTarget? = nil) -> MuscleGroupFit {
        // Stiffness and coupling as `calibrate` builds them; the reference state is irrelevant here. The
        // lower band's scale goes into `passive.stiffen`, so postures built from this body (inPosture)
        // inherit it.
        var passive = passive
        for c in A2Coordinate.lowerBand { passive.stiffen[c.rawValue] *= lowerBandStiffness }
        var body = calibrate(anatomy: a, reference: [Double](repeating: 0, count: A2Coordinate.count), passive: passive)
        let groups = A2MuscleGroup.allCases
        let responses = groups.map { body.staticResponse(body.groupPattern($0)) }

        // Marker values are (to first order) linear in q: a Jacobian by central differences.
        let n = A2Coordinate.count
        let steps = [1e-3, 1e-4, 1e-3, 1e-3, 1e-4, 1e-4, 1e-2, 1e-2]
        let mj: [[Double]] = (0..<n).map { j in
            var p = [Double](repeating: 0, count: n), m = p
            p[j] = steps[j]; m[j] = -steps[j]
            let op = a.observe(a.a2State(p)), om = a.observe(a.a2State(m))
            return markers.map { ($0.value(op) - $0.value(om)) / (2 * steps[j]) }
        }
        func markerValues(_ q: [Double]) -> [Double] {
            markers.indices.map { k in (0..<n).reduce(0.0) { $0 + mj[$1][k] * q[$1] } }
        }
        let jth = body.geometry.thorax
        func lung(_ q: [Double]) -> Double { zip(jth, q).reduce(0) { $0 + $1.0 * $1.1 } }

        // Weighted design matrix: rows = markers (÷ SD) + tidal (÷ tidalSD); columns = groups.
        let colMarkers = responses.map(markerValues), colLung = responses.map(lung)
        var rowsA: [[Double]] = markers.indices.map { k in groups.indices.map { colMarkers[$0][k] / markers[k].sd } }
            + [groups.indices.map { colLung[$0] / tidalSD }]
        var b: [Double] = markers.map { $0.mean / $0.sd } + [tidal / tidalSD]
        if let v = volumes {
            let g = body.geometry
            let regions = [g.upperRegion, g.lowerRegion, g.abdomenRegion]
            for (k, region) in regions.enumerated() {
                rowsA.append(responses.map { r in zip(region, r).reduce(0.0) { $0 + $1.0 * $1.1 } / (v.sds[k] * tidal) })
                b.append(v.shares[k] / v.sds[k])
            }
        }

        var best: (p: [Double], cost: Double)? = nil
        for mask in 1..<(1 << groups.count) {
            let active = groups.indices.filter { mask & (1 << $0) != 0 }
            let ata = active.map { i in active.map { j in rowsA.reduce(0.0) { $0 + $1[i] * $1[j] } } }
            let atb = active.map { i in zip(rowsA, b).reduce(0.0) { $0 + $1.0[i] * $1.1 } }
            let sol = multiply(invert(ata), atb)
            guard sol.allSatisfy({ $0 >= 0 }) else { continue }
            var p = [Double](repeating: 0, count: groups.count)
            for (i, g) in active.enumerated() { p[g] = sol[i] }
            let cost = zip(rowsA, b).reduce(0.0) { acc, rb in
                let r = zip(rb.0, p).reduce(0.0) { $0 + $1.0 * $1.1 } - rb.1
                return acc + r * r
            }
            if best == nil || cost < best!.cost { best = (p, cost) }
        }
        let p = best?.p ?? [Double](repeating: 0, count: groups.count)
        var force = [Double](repeating: 0, count: n)
        for (gi, g) in groups.enumerated() { for (i, v) in body.groupPattern(g).enumerated() { force[i] += p[gi] * v } }
        body.peakForce = force
        let q = body.staticResponse(force)
        body.reference = q
        let values = markerValues(q)
        let rows = zip(markers, values).map { ($0, $1) }
        let chi = rows.reduce(0.0) { $0 + pow(($1.1 - $1.0.mean) / $1.0.sd, 2) }
        return MuscleGroupFit(body: body, pressures: p, rows: rows, tidalVolume: lung(q), chiSquared: chi,
                              lowerBandStiffness: lowerBandStiffness)
    }
}

extension A2MuscleGroup {
    /// The lower band's passive stiffness relative to the textbook split, and the costal-arch coupling
    /// (sternal coupling, × the lower pump's own spring), chosen 2026-11-10 against three datasets at
    /// once (`breathstar arch-scan`): Takashima's seated markers pick the lower band ×2.5 at every arch
    /// strength; the seated patient directions hold 7/7 for an arch of ×5 or weaker and 5/7 at ×10 or
    /// stiffer; Kouyama 2016's presses improve steadily as the arch weakens (χ² 1230 at ×10, 1007 at ×3,
    /// 707 at ×1), while the marker fit worsens slightly (1.04 → 1.12 → 1.34). ×3 balances them. FITTED,
    /// not sourced. (Until then: lower ×2, arch ×10 assumed.)
    public static let lowerBandStiffness = 2.5
    public static let costalArch = 3.0

    /// The default passive properties for a muscle-group body: A2Passive with the fitted costal arch.
    public static var defaultPassive: A2Passive {
        var p = A2Passive()
        p.sternalCoupling = costalArch
        return p
    }
}
