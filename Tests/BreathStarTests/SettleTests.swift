import Testing
@testable import BreathStar

/// Stage 3 (Settle.swift): the general rules, one parameter set. The passes are what the rules
/// predict without a per-posture number; the known issues are the stage's failures, kept visible
/// for the review the adaptation notes call for after stage 3.
@Suite struct Settle {
    static let drive = Drive()
    static func breath(_ r: RuleBody) -> SidedBreath { SidedBreath.measure(r.body.simulate(drive: drive), period: drive.period) }
    static let supine = BodyGenerator.general(.supine)
    static let right = BodyGenerator.general(.rightSideDown)
    static let left = BodyGenerator.general(.leftSideDown)

    /// Upright, nothing changes: the reference posture.
    @Test func seatedIsReference() {
        let r = BodyGenerator.general(.seated)
        #expect(abs(r.frcChange) < 1e-9 && abs(r.domeRise[0]) < 1e-9 && abs(r.abdomenComplianceScale - 1) < 1e-9)
    }

    /// Lying on a side, the hydrostatic abdomen alone lifts the floor-side hemidiaphragm, and the
    /// floor-side lung takes 51–62% of the breath (Amano 2024, Grant 2011). Predicted: no
    /// hemidiaphragm asymmetry was fitted (stage 2 fitted `dependentShare` for this).
    @Test func floorLungPredicted() {
        let m = Self.breath(Self.right)
        let floor = m.lung[1] / (m.lung[0] + m.lung[1])
        #expect(floor > 0.51 && floor < 0.62)
        #expect(Self.right.domeRise[1] > 0 && Self.right.domeRise[0] < 0)
    }

    @Test func sidesMirror() {
        #expect(abs(Self.right.domeRise[0] - Self.left.domeRise[1]) < 1e-3)  // 1 mL: quadrature noise
        let r = Self.breath(Self.right), l = Self.breath(Self.left)
        #expect(abs(r.lung[0] - l.lung[1]) < 0.002)
    }

    /// End-expiratory volume, sitting → side-lying: −0.46 L (Lumb & Nunn 1991). Predicted.
    @Test func sideLyingFRC() { #expect(abs(Self.right.frcChange + 0.46) < 0.1) }

    /// Any horizontal posture: ribcage 32–36% of the breath (Lumb & Nunn 1991).
    @Test func horizontalRibcageShare() {
        for r in [Self.supine, Self.right] {
            let m = Self.breath(r)
            #expect(m.upperShare + m.lowerShare > 0.30 && m.upperShare + m.lowerShare < 0.38)
        }
    }

    /// 45°, held out of the fit: within 2 SE of Mendes men's abdominal share (55.4%, SE 2.4), and
    /// 35–55% of the way from sitting to supine (the data: 44% Sonpeayung, 50% Mendes men). Under the
    /// first stage-3 wall law (pressure at the front wall) it was 64% and ~70% of the way.
    @Test func reclinedHeldOut() {
        let s45 = 0.5.squareRoot()
        let r45 = BodyGenerator.general(BodyConfiguration(name: "45°", gravity: (0, -s45, -s45), contacts: [ContactPatch(.back)]))
        let a45 = Self.breath(r45).abdomenShare, a0 = Self.breath(BodyGenerator.general(.seated)).abdomenShare
        let a90 = Self.breath(Self.supine).abdomenShare
        #expect(abs(a45 - 0.554) < 2 * 0.024)
        let along = (a45 - a0) / (a90 - a0)
        // Since the volume-fitted seated base (2026-11-10) the abdomen at 45° is 33% of the way
        // (data 44–50%): the shares match, the path's shape doesn't.
        withKnownIssue { #expect(along > 0.35 && along < 0.55) }
    }

    /// Lying on a side, the floor side's chest wall moves less (Nozoe 2014's direction).
    @Test func nozoeDirection() {
        let m = Self.breath(Self.right)
        #expect(m.chestWall[1] < m.chestWall[0])
    }

    /// Prone: ribcage 32–36% in any horizontal posture (Lumb & Nunn 1991). No longer a clean
    /// prediction: the per-region contact springs were found because prone failed (one spring on the
    /// whole front let the belly push into the floor while the chest pulled away; ribcage 45.5%).
    /// The rule is general (it changed side-lying and supine too, and the refit came out the same).
    /// Was 30.4%; since the volume-fitted seated base and the upper rib muscles' postural share 0.4
    /// (2026-11-10) 26.4%: a known issue (the band is for "any horizontal posture", not prone).
    @Test func proneRibcageShare() {
        let prone = BodyGenerator.general(BodyConfiguration(name: "prone", gravity: (0, 1, 0), contacts: [ContactPatch(.front)]))
        let m = Self.breath(prone)
        #expect(m.upperShare + m.lowerShare > 0.22)
        withKnownIssue { #expect(m.upperShare + m.lowerShare > 0.29 && m.upperShare + m.lowerShare < 0.39) }
        // LoMauro 2024 (OEP, 28 healthy, prone on a bed): abdomen 42.5% (Q1–Q3 38.7–46.5). The model
        // gives ~74%: the floor contact holds the chest back more than the belly (no floor: 65%).
        withKnownIssue { #expect(m.abdomenShare > 0.387 && m.abdomenShare < 0.465) }
    }

    /// Quiet breathing is regulated, so every configuration breathes the quiet tidal volume and the
    /// drive is the output. At the seated drive the rules would make the breath larger lying down
    /// (supine ~0.69 L; measured 0.52–0.58), which was the old known issue. The predicted drive:
    /// less lying on the back or side (a lengthened diaphragm), more face down (the floor holds the
    /// front). Literature pass 10: supine parasternal drive 0.90–0.95 of sitting (Wakode), one null
    /// study (n = 51), diaphragm unchanged when inverted; face down untested.
    /// Since 2026-11-10 (upper rib muscles' postural share 0.4, fitted): lying on the back the common
    /// drive is ×1.04 and the upper rib muscles' ×1.04 × 0.6 ≈ 0.62, so the diaphragm is about
    /// unchanged (as when inverted) and the upper rib muscles fall (parasternals 0.90–0.95, scalenes
    /// about halved). Before: one factor on everything, ×0.87.
    @Test func quietBreathHeldDrivePredicted() {
        let m = Self.breath(Self.supine)
        #expect(abs(m.tidalVolume - 0.56) < 0.005)
        #expect(Self.supine.driveScale > 0.95 && Self.supine.driveScale < 1.1)
        let upper = Self.supine.driveScale * (1 - GravityRules().uprightUpperDrive)
        #expect(upper < 0.8)
        let prone = BodyGenerator.general(BodyConfiguration(name: "prone", gravity: (0, 1, 0), contacts: [ContactPatch(.front)]))
        #expect(prone.driveScale > 1.1)
    }

    /// Sitting → supine end-expiratory volume: −0.81 L (Lumb & Nunn 1991; Attali 2024 −0.79). The
    /// linear settle gave −1.08 (a known issue until the relaxed system stiffened toward residual
    /// volume, `GravityRules.expiratoryReserve`). Seated → weightless alone gives −0.42; Elliott et al.
    /// 1994 (Spacelab SLS-1, n = 4; checked 2026-11-11): FRC ~15% (~0.5 L) below standing in
    /// microgravity, 32% below standing supine.
    @Test func supineFRC() { #expect(abs(Self.supine.frcChange + 0.81) < 0.1) }
}
