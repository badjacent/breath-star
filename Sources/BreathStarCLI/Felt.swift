import BreathStar
import Foundation

// What can be felt (2026-11-27, at the user's request: "what is actually felt is the push against
// elasticity, not the volume"). The body has no sense of volume; it senses stretch (spindles, skin),
// tension (tendon organs), effort (the drive itself) and touch (pressure on the floor). The model
// already holds the pieces, so each becomes a field on the trunk surface for the viewer:
//
//   stretch — the wall's area strain: the breath's, plus (optionally) the posture's resting strain:
//             the weight's settle (q at rest under gravity, from weightless) and the spine's bend
//             (stage 4's lengthwise strain; lying on the side, the rest arc, Leilnahari 2011, which
//             the mechanics don't use yet).
//   push    — the tissue's elastic force, K_tissue·q: the passive springs, the costal arch and
//             sternum, the bend's stiffening (Rule B), the deformed floor side. Not the tone (that
//             is muscle: effort) and not the floor (touch).
//   effort  — the muscles: the phasic drive (peak force × activation, the diaphragm's pull on the
//             ribs, any expiratory abdominal push) plus what held regions resist, K_tone·q. The
//             model's holds are stiffnesses, so a hold costs effort only when the breath pushes on it.
//   floor   — each contact spring's pressure, cmH2O: k·(c·q) per area; with the resting load, the
//             trunk's weight spread over the contacts by how squarely each bears it (ASSUMED: 35 kg,
//             half of 70).
//
// A generalised force f_c becomes a surface pressure by virtual work: the least pressure field that
// does f_c's work through coordinate c's normal motion b_c, p = f_c·b_c / Σ b_c²·a (cmH2O). The
// diaphragm's forces go to the domes as f / (volume it moves). The model's springs are linear: real
// tissue stiffens as it stretches, which this can't show.

/// The trunk's weight on its supports, cmH2O·cm² (≈ gram-force): half of 70 kg. ASSUMED.
let trunkWeight = 35_000.0

/// How a configuration's stiffness splits: the tissue's own, the floor's, and (by difference) tone.
struct FeltSplit {
    var tissue: [[Double]]
    var contact: [[Double]]
    var springs: [ContactSpring]
    /// Coordinates at rest under gravity (from weightless), for the resting load.
    var restQ: [Double]
    /// The posture's resting lengthwise strain per surface vertex beyond the settle (bend, arc).
    var restStrain: [Double]?

    /// The same split with some stiffness counted as tissue (a deformed side is tissue, not tone).
    func addingTissue(_ from: SidedBody, _ to: SidedBody) -> FeltSplit {
        var s = self
        let a = from.stiffnessMatrix, b = to.stiffnessMatrix
        for i in a.indices { for j in a.indices { s.tissue[i][j] += b[i][j] - a[i][j] } }
        return s
    }
}

func feltSplit(_ c: BodyConfiguration, drive: Drive) -> FeltSplit {
    let rules = GravityRules()
    var cn = c; cn.tone = []; cn.carried = []
    let noTone = BodyGenerator.general(cn, drive: drive)
    var cb = cn; cb.contacts = []
    let bare = BodyGenerator.general(cb, drive: drive).body
    let kt = bare.stiffnessMatrix, kn = noTone.body.stiffnessMatrix
    let contact = kn.indices.map { i in kn.indices.map { j in kn[i][j] - kt[i][j] } }
    let springs = bare.contactSprings(c.contacts, gravity: c.gravity, rules: rules)
    // Resting lengthwise strain beyond the settle, per vertex (the surface grid's order).
    let a = bare.anatomy, g = surfaceGrid(a)
    var extra: [Double]? = nil
    if !c.spine.isNeutral {
        extra = (0..<g.count).map { round4(a.wallStrain(z: g.z[$0], psi: g.psi[$0], side: g.side[$0], spine: c.spine).axial) }
    } else if let dep = noTone.body.dependent {
        let arc = SideLyingArc.firmSurface
        extra = (0..<g.count).map { v in
            let p = a.restPoint(z: g.z[v], psi: g.psi[v], side: g.side[v])
            // Bending about the spine (x = 0): + toward the support (convex), − away.
            let toward = dep == .right ? -1.0 : 1.0
            return round4(arc.curvature(g.z[v]) * toward * p.x)
        }
    }
    return FeltSplit(tissue: kt, contact: contact, springs: springs, restQ: noTone.settled.q, restStrain: extra)
}

func matVec(_ m: [[Double]], _ v: [Double]) -> [Double] { m.map { row in zip(row, v).reduce(0) { $0 + $1.0 * $1.1 } } }

/// The felt quantities for one case's picked frames (keys added to the viewer case).
func feltCase(body: SidedBody, split s: FeltSplit, samples: [SidedSample], drive: Drive) -> [String: Any] {
    let n = SidedCoordinate.count
    let k = body.stiffnessMatrix
    let tone = (0..<n).map { i in (0..<n).map { j in k[i][j] - s.tissue[i][j] - s.contact[i][j] } }
    let a = SidedCoordinate.abdomen.rawValue
    func driveForce(_ t: Double) -> [Double] {
        let act = drive.activation(at: t)
        var f = body.peakForce.map { $0 * act }
        for (side, gv) in body.insertion.enumerated() {
            let p = body.diaphragmPressure(side: side) * act
            for i in 0..<n { f[i] += p * gv[i] }
        }
        if body.expiratoryAbdominalPressure != 0 {
            f[a] -= body.expiratoryAbdominalPressure * body.geometry.own[a] * drive.expiratoryActivation(at: t)
        }
        return f
    }
    let elastic = samples.map { matVec(s.tissue, $0.q).map(round4) }
    let effort = samples.map { smp -> [Double] in
        let held = matVec(tone, smp.q)
        return zip(driveForce(smp.time), held).map { round4($0 + $1) }
    }
    let floor = samples.map { smp in s.springs.map { round4($0.pressure(smp.q)) } }
    let bearing = s.springs.reduce(0) { $0 + $1.into * $1.area }
    var out: [String: Any] = [
        "elastic": elastic, "effort": effort, "floor": floor,
        "restElastic": matVec(s.tissue, s.restQ).map(round4), "restQ": s.restQ.map(round4),
        "patches": s.springs.map { sp -> [String: Any] in
            ["z": [sp.z.lowerBound, sp.z.upperBound], "psi": [sp.psi.lowerBound, sp.psi.upperBound],
             "side": sp.side == .left ? 1 : -1, "rest": round4(bearing > 0 ? trunkWeight * sp.into / bearing : 0)]
        },
    ]
    if let r = s.restStrain { out["restStrain"] = r }
    return out
}

/// Area strain of the wall per unit of each coordinate, per vertex: the change in a small surface
/// element's area over its rest area, from the exact surface (central differences).
func strainBasis(_ a: AnatomyModel, _ g: SurfaceGrid, map: CoordinateMap) -> [[Double]] {
    let hz = 0.5, hp = 5.0
    func point(_ z: Double, _ psi: Double, _ side: Side, _ s: AnatomyState) -> (Double, Double, Double) {
        let r = a.restPoint(z: z, psi: psi, side: side)
        let d = a.surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
        // In the side's own frame (x outward on that side); the displacement in cm.
        return (abs(r.x) + d.x, r.y + d.y, r.z + d.z)
    }
    func area(_ v: Int, _ s: AnatomyState) -> Double {
        let z = g.z[v], p = g.psi[v], sd = g.side[v]
        let a1 = point(z + hz, p, sd, s), a0 = point(z - hz, p, sd, s)
        let b1 = point(z, p + hp, sd, s), b0 = point(z, p - hp, sd, s)
        let u = (a1.0 - a0.0, a1.1 - a0.1, a1.2 - a0.2), w = (b1.0 - b0.0, b1.1 - b0.1, b1.2 - b0.2)
        let cx = u.1 * w.2 - u.2 * w.1, cy = u.2 * w.0 - u.0 * w.2, cz = u.0 * w.1 - u.1 * w.0
        return (cx * cx + cy * cy + cz * cz).squareRoot()
    }
    let rest = (0..<g.count).map { area($0, AnatomyState()) }
    return (0..<map.count).map { i in
        var p = [Double](repeating: 0, count: map.count), m = p
        p[i] = map.steps[i]; m[i] = -map.steps[i]
        let sp = map.state(p), sm = map.state(m)
        return (0..<g.count).map { v in (area(v, sp) - area(v, sm)) / (2 * map.steps[i]) / max(1e-9, rest[v]) }
    }
}
