import Foundation

// Compartments as OEP draws them (the work plan (private), item 2, literature pass 12).
//
// The model's regions are flat bands: abdomen below z = costalMargin (18 cm), lower ribcage to the
// xiphoid (25 cm), upper ribcage above. OEP's boundary between the abdominal ribcage and the abdomen
// is the lower costal margin, which is not flat: from the xiphoid at the front midline it runs down
// and out along the costal arch to the tip of the 10th rib, then round the side and back at about
// the lowest ribs' level. The model's mechanics keep the flat margin (the ribs end at z = 18 all
// round); this file only changes where the breath's volume is counted.
//
// Method: outward surface flux, ∫ (displacement · normal) dA, over the trunk's side surface, split
// by a boundary z_b(ψ). The flat boundary through the same flux gives the comparison; the difference
// (arched − flat) is the definitional effect, added to the model's own (material-ring) shares.
// ASSUMED arch: z_b = xiphoid at ψ = 0, falling linearly to `lateralMargin` at ψ = `archEnd`, flat
// behind.

extension AnatomyModel {
    /// Height of the OEP lower-costal-margin boundary at ψ (degrees), cm. ASSUMED: the 10th rib's
    /// lateral tip at 13 cm (5 cm below the model's flat margin), reached at ψ = 70° (the anterior
    /// axillary line).
    public func oepMargin(psi: Double, lateralMargin: Double = 13, archEnd: Double = 70) -> Double {
        psi >= archEnd ? lateralMargin : xiphoid + (lateralMargin - xiphoid) * psi / archEnd
    }

    /// Surface-flux volumes (litres) of upper ribcage, lower ribcage, abdomen for a state, with the
    /// lower boundary given by `margin(ψ)` (flat: the model's `costalMargin`).
    public func fluxCompartments(_ s: AnatomyState, margin: (Double) -> Double) -> [Double] {
        var v = [0.0, 0.0, 0.0]
        let nz = 86, np = 36
        let dz = top / Double(nz)
        for side in Side.allCases {
            for zi in 0..<nz {
                let z = (Double(zi) + 0.5) * dz
                let (ap, half) = base(z)
                for pi in 0..<np {
                    let psi = (Double(pi) + 0.5) / Double(np) * 180, r = psi * .pi / 180
                    let dr = Double.pi / Double(np)
                    let nx0 = sin(r) / half, ny0 = cos(r) / (ap / 2), nn = (nx0 * nx0 + ny0 * ny0).squareRoot()
                    let tx = half * cos(r), ty = -ap / 2 * sin(r)
                    let ds = (tx * tx + ty * ty).squareRoot() * dr
                    let d = surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
                    let flux = (d.x * nx0 + d.y * ny0) / nn * ds * dz / 1000
                    let k = z >= xiphoid ? 0 : (z >= margin(psi) ? 1 : 2)
                    v[k] += flux
                }
            }
        }
        return v
    }
}
