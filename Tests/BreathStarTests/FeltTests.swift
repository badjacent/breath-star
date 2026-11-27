import Foundation
import Testing
@testable import BreathStar

/// What can be felt (2026-11-27): the contact springs are readable patch by patch, and the surface's
/// displacement is in cm (its volume integral is each coordinate's volume), which the contact and
/// tone springs read as mm.
@Suite struct Felt {
    /// `withContacts` adds exactly the springs `contactSprings` lists (the refactor kept them).
    @Test func contactSpringsAreTheCouplings() {
        let rules = GravityRules(), c = BodyConfiguration.rightSideDown
        let r = BodyGenerator.general(c)
        var bare = c; bare.contacts = []
        let b = BodyGenerator.general(bare).body
        let springs = b.contactSprings(c.contacts, gravity: c.gravity, rules: rules)
        #expect(springs.count == r.body.couplings.count - b.couplings.count)
        let added = r.body.couplings.suffix(springs.count)
        for (s, cpl) in zip(springs, added) {
            #expect(abs(s.k - cpl.k) < 1e-12 && zip(s.c, cpl.c).allSatisfy { abs($0 - $1) < 1e-12 })
        }
    }

    /// The surface displacement is in cm: the wall's outward motion integrated over the abdomen's
    /// front (its bulge) gives the abdomen coordinate's volume in litres only if read as cm.
    @Test func surfaceDisplacementIsInCentimetres() {
        let a = AnatomyModel()
        var q = [Double](repeating: 0, count: SidedCoordinate.count)
        q[SidedCoordinate.abdomen.rawValue] = 1
        let s = a.sidedState(q)
        // Volume swept by the wall below the costal margin, cm³, with the motion read as cm.
        var v = 0.0
        let nz = 40, np = 36
        for side in Side.allCases {
            for zi in 0..<nz {
                let z = (Double(zi) + 0.5) / Double(nz) * a.costalMargin, dz = a.costalMargin / Double(nz)
                let (ap, w) = a.base(z)
                for pi in 0..<np {
                    let psi = (Double(pi) + 0.5) / Double(np) * 180, r = psi * .pi / 180
                    let nx0 = sin(r) / w, ny0 = cos(r) / (ap / 2), nn = (nx0 * nx0 + ny0 * ny0).squareRoot()
                    let tx = w * cos(r), ty = -ap / 2 * sin(r)
                    let ds = (tx * tx + ty * ty).squareRoot() * (.pi / Double(np))
                    let d = a.surfaceDisplacement(z: z, psiDegrees: psi, side: side, s)
                    v += (d.x * nx0 + d.y * ny0) / nn * ds * dz
                }
            }
        }
        let own = a.sidedGeometry().own[SidedCoordinate.abdomen.rawValue]
        #expect(abs(v / 1000 / own - 1) < 0.1)
    }
}
