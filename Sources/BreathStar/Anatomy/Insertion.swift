import Foundation

// The diaphragm's insertional pull on the ribs.
//
// The costal fibres insert on the costal margin and pull it toward the dome. In the zone of
// apposition they run headward along the inside of the ribcage, so at the sides they lift the ribs;
// at the front the fibres from the xiphoid and the costal cartilages slope headward and backward to
// the central tendon, so there they pull the lower front up and in. Until 2026-11-11 the model let
// the diaphragm act on the ribs only through the abdominal pressure (the appositional route).
//
// Virtual work: a hemidiaphragm with muscle pressure P has a fibre tension per unit length of
// margin τ = P·R/2 (Laplace, dome radius R). Moving the insertion by d does work τ·(d·u) per unit
// length, u the fibre direction at the insertion. So the generalized force on coordinate i is
// P · (R/2) · ∮ (∂d/∂q_i · u) dl over that side's margin.
// ASSUMED: R = 10 cm; the fibres at the front slope back from the vertical by `frontSlope` (45°)
// at the midline, tapering to vertical by ψ = 60°; the margin at the ribs' lower edge.

extension SidedBody {
    /// The muscle pressure a hemidiaphragm develops, cmH2O (its peak force over its own volume).
    public func diaphragmPressure(side k: Int) -> Double {
        let c = k == 0 ? SidedCoordinate.diaphragmL : .diaphragmR
        let own = abs(geometry.own[c.rawValue])
        return own > 0 ? peakForce[c.rawValue] / own : 0
    }

    /// The insertional force vectors (left, right) per cmH2O, scaled by `strength` (1 = Laplace
    /// with R = 10 cm).
    public func insertionVectors(strength: Double = 1, frontSlope: Double = 45, radius: Double = 10) -> [[Double]] {
        let a = anatomy, n = SidedCoordinate.count, h = 1e-3, np = 36
        let base = SidedCoordinate.allCases.map { c -> AnatomyState in
            var e = [Double](repeating: 0, count: n); e[c.rawValue] = h; return a.sidedState(e)
        }
        return Side.allCases.map { side in
            var g = [Double](repeating: 0, count: n)
            for pi in 0..<np {
                let psi = (Double(pi) + 0.5) / Double(np) * 180, r = psi * .pi / 180
                let z = a.ribBottom(psiDegrees: psi)
                let (ap, w) = a.base(z)
                // Fibre direction: headward, sloping back (−y) at the front.
                let slope = frontSlope * max(0, 1 - psi / 60) * .pi / 180
                let u = (x: 0.0, y: -sin(slope), z: cos(slope))
                let tx = w * cos(r), ty = -ap / 2 * sin(r)
                let dl = (tx * tx + ty * ty).squareRoot() * .pi / Double(np)
                for c in SidedCoordinate.allCases where !c.isDiaphragm {
                    let d = a.surfaceDisplacement(z: z, psiDegrees: psi, side: side, base[c.rawValue])
                    // surfaceDisplacement's x is outward on its side; u has no sideways part.
                    g[c.rawValue] += (d.y * u.y + d.z * u.z) / h * dl
                }
            }
            return g.map { $0 * strength * radius / 2 / 1000 }  // cmH2O·cm³ → cmH2O·L
        }
    }

    /// The same body with the insertional pull.
    public func withInsertion(strength: Double = 1, frontSlope: Double = 45) -> SidedBody {
        var b = self; b.insertion = insertionVectors(strength: strength, frontSlope: frontSlope); return b
    }
}
