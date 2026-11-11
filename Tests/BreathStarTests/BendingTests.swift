import Testing
@testable import BreathStar

/// Stage 4 (Bending.swift): the spine's shape and Rule B. The adaptation notes' check: seated
/// side-bend and rotation give stable, symmetric-when-mirrored results; the direction question is
/// stated with the evidence found (literature pass 11).
@Suite struct Bending {
    static let drive = Drive()
    static func breath(_ s: SpineShape, _ r: GravityRules = GravityRules()) -> (body: SidedBody, m: SidedBreath) {
        let b = BodyGenerator.general(BodyConfiguration.seated.with(s), rules: r, drive: drive).body
        return (b, SidedBreath.measure(b.simulate(drive: drive), period: drive.period))
    }

    @Test func neutralUnchanged() {
        let a = BodyGenerator.general(.seated).body, b = BodyGenerator.general(BodyConfiguration.seated.with(.neutral)).body
        #expect(a.stiffness == b.stiffness)
    }

    @Test func mirrorSymmetric() {
        for s in [SpineShape(sideBend: 20), SpineShape(rotation: 30), SpineShape(flexion: 10, sideBend: 15, rotation: -20)] {
            let a = Self.breath(s).m, b = Self.breath(s.mirrored).m
            #expect(abs(a.chestWall[0] - b.chestWall[1]) < 5e-4 && abs(a.chestWall[1] - b.chestWall[0]) < 5e-4)
            #expect(abs(a.lung[0] - b.lung[1]) < 5e-4)
        }
    }

    /// Stable at a large bend: every stiffness positive and finite, the quiet breath reached.
    @Test func stableLargeBend() {
        let (b, m) = Self.breath(SpineShape(flexion: 40, sideBend: 40, rotation: 45))
        #expect(b.stiffness.allSatisfy { $0 > 0 && $0.isFinite })
        #expect(abs(m.tidalVolume - 0.56) < 0.005)
    }

    /// Slumped sitting: the ribcage moves less (Hazaki & Okada: 3.6 vs 4.2 cm; their breath was also
    /// smaller, so this is a direction check at a matched breath, not a size).
    @Test func slumpedRibcage() {
        let up = Self.breath(.neutral).m, sl = Self.breath(.slumped).m
        #expect(sl.upperShare + sl.lowerShare < 0.95 * (up.upperShare + up.lowerShare))
    }

    /// The abdominal wall is a membrane: shortened, it slackens (more belly); lengthened, it tightens.
    @Test func wallIsMembrane() {
        var knees = SpineShape(); knees.lumbarFlexion = 15
        var arch = SpineShape(); arch.lumbarFlexion = -15
        let n = Self.breath(.neutral).m.abdomenShare
        #expect(Self.breath(knees).m.abdomenShare > n && Self.breath(arch).m.abdomenShare < n)
    }

    /// The direction question: with the default sign the wall moves more on the open side of a
    /// side-bend, and flipping the sign sends it to the crowded side.
    @Test func sideBendDirection() {
        let m = Self.breath(SpineShape(sideBend: 20)).m
        #expect(m.chestWall[1] > m.chestWall[0] + 0.02)  // left crowded, right open
        var flipped = GravityRules(); flipped.ribBendGain *= -1; flipped.wallBendGain *= -1
        let f = Self.breath(SpineShape(sideBend: 20), flipped).m
        #expect(f.chestWall[0] > f.chestWall[1])
    }

    /// The bend and the diaphragm: the crowded side's rim drops, its dome rises relative to it, and
    /// that lung takes more (coupling 0.5, assumed); with the contents moving with the rim
    /// (coupling 0) the lungs stay even, the wall's asymmetry made up by the hemidiaphragms.
    @Test func sideBendLungs() {
        let m = Self.breath(SpineShape(sideBend: 20)).m
        #expect(m.lung[0] > m.lung[1] + 0.005)
        var none = GravityRules(); none.bendDomeCoupling = 0
        let n = Self.breath(SpineShape(sideBend: 20), none).m
        #expect(abs(n.lung[0] - n.lung[1]) < 0.003)
        let rim = AnatomyModel().rimDrop(SpineShape(sideBend: 20))
        #expect(rim[0] > 0.5 && abs(rim[0] + rim[1]) < 1e-9)
    }

    /// Rotation: less sideways motion at the axilla (sitting-posture study, n = 7).
    @Test func rotationAxilla() {
        func axilla(_ b: SidedBody) -> Double {
            let sim = b.simulate(drive: Self.drive).suffix(Int(Self.drive.period / 0.002))
            let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
            return b.anatomy.sectorMotion(z: 34...40, psi: 80...100, side: .left, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 })).x
        }
        #expect(axilla(Self.breath(SpineShape(rotation: 30)).body) < axilla(Self.breath(.neutral).body))
    }

    /// Extension: the same study found more sideways motion at the 9th rib with thoracolumbar
    /// extension. In the model the answer turns on where the arch is (2026-11-10, `stage4-extension`):
    /// an arch of the lower back lengthens and tightens the belly wall, the belly's pressure pushes
    /// the lowest ribs out through the zone of apposition (more); an arch of the mid-back lifts both
    /// domes' rims (less; the ribs themselves ease slightly, 2026-11-11 strains). The default split (lumbar 0.5) lands
    /// just on the "less" side at the lowest ribs (0.736 vs 0.771), so that stays a known issue; the
    /// two arches are pre-registered as contrasts C and C2 in the self-measurement plan.
    @Test func extensionDependsOnWhereTheArchIs() {
        func lateral(_ b: SidedBody, _ z: ClosedRange<Double>) -> Double {
            let sim = b.simulate(drive: Self.drive).suffix(Int(Self.drive.period / 0.002))
            let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
            return b.anatomy.sectorMotion(z: z, psi: 80...100, side: .left, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 })).x
        }
        var lumbar = SpineShape(); lumbar.lumbarFlexion = -15
        var thoracic = SpineShape(); thoracic.thoracicFlexion = -15
        let n = Self.breath(.neutral).body, lb = Self.breath(lumbar).body, tb = Self.breath(thoracic).body
        // Robust on both seated bases: the lower-back arch beats the mid-back arch at both levels,
        // the lower-back arch moves the lower ribcage more, the mid-back arch moves both less.
        #expect(lateral(lb, 13...18) > lateral(tb, 13...18))
        #expect(lateral(lb, 18...25) > lateral(n, 18...25))
        #expect(lateral(tb, 13...18) < lateral(n, 13...18))
        // Since the seated base fits OEP volumes (2026-11-10) the split arch moves both bands less
        // (0.92 → 0.88, 0.82 → 0.68): the study's direction is missed at the 9th rib on either side.
        let ext = Self.breath(SpineShape(flexion: -15)).body
        withKnownIssue { #expect(lateral(ext, 18...25) > lateral(n, 18...25)) }
        withKnownIssue { #expect(lateral(ext, 13...18) > lateral(n, 13...18)) }
    }

    /// The dome effect solved from the fluid, incompressible abdomen (`bendSettle`): a side-bend needs
    /// no dome to move (the contents flow across), a forward bend shortens the cavity and pushes both
    /// domes up, an arch the reverse, and the solve gives more than the assumed 0.5 of the rim's
    /// motion to the domes.
    @Test func bendSettleFromTheFluidAbdomen() {
        let b = Self.breath(.neutral).body
        let side = b.bendSettle(SpineShape(sideBend: 20))
        #expect(abs(side.rise[0]) < 1e-6 && abs(side.rise[1]) < 1e-6 && abs(side.cavity) < 1e-6)
        let fwd = b.bendSettle(.slumped), arch = b.bendSettle(SpineShape(flexion: -15))
        #expect(fwd.rise[0] > 0 && fwd.pab > 0)
        #expect(arch.rise[0] < 0 && arch.pab < 0)
        #expect(abs(fwd.rise[0] - fwd.rise[1]) < 1e-4)
    }
}
