import Testing
@testable import BreathStar

/// A2 with both sides free (Sided.swift) and lying on the right side (the working log (private), "side-lying").
@Suite struct Sided {
    static let drive = Drive()
    static let seatedA2: A2Body = {
        let a = AnatomyModel()
        let s = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        return A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(s)).matchedToTidal(0.56)
    }()
    static let sym = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(seatedA2.reference),
                                         passive: seatedA2.passive).matchedToTidal(0.56)

    /// With a symmetric reference the sided body reproduces A2's seated breath (static calibration is
    /// exact; the dynamic breath agrees closely) and both lungs take the same.
    @Test func symmetricMatchesA2() {
        let a = SignedBreath.measure(Self.seatedA2.simulate(), period: Self.drive.period)
        let b = SidedBreath.measure(Self.sym.simulate(), period: Self.drive.period)
        #expect(abs(a.tidalVolume - b.tidalVolume) < 0.005)
        #expect(abs(a.upperShare - b.upperShare) < 0.01 && abs(a.abdomenShare - b.abdomenShare) < 0.01)
        #expect(abs(b.lung[0] - b.lung[1]) < 1e-6)
    }

    func rightSideDown(share: Double, bed: Double) -> (body: SidedBody, anatomy: AnatomyModel) {
        let op = SidedOperatingPoint(frcDrop: 0.22, dependent: .right, dependentShare: share)
        let an = op.apply(to: AnatomyModel.rightSideDown())
        let b = SidedBody.from(seated: Self.sym, anatomy: an, abdomenComplianceScale: 1.34, ribcageStiffnessScale: 2.5,
                               diaphragmForceScale: Side.allCases.map { op.forceScale($0) }, dependent: .right, bedGain: bed)
            .matchedToTidal(0.51)
        return (b, an)
    }

    /// Measured from the room (as OEP does), the trunk lifts off the floor by its dependent side's
    /// widening, so the upper side's lateral ribs move out much more than they do relative to the
    /// spine (Takashima 2017: 1.70 mm, the largest sideways motion in the study).
    /// The lift is a hypothesis (off by default since critique 3). Switched on, it nearly doubles the
    /// upper side's lateral motion, but it also moves the front markers away from the floor, where
    /// Takashima's front lower ribcage and belly move toward it (−0.29, −0.54 mm): it fails those.
    @Test func roomFrameLiftHypothesis() {
        let (b, an) = rightSideDown(share: 0.75, bed: 0)
        let st = an.sidedState(b.endInspiration())
        let body = an.observeSided(st), off = an.observeSided(st, restingOn: .right)
        let on = an.observeSided(st, restingOn: .right, lift: true)
        let key = "left lateral lower ribcage"
        #expect(!SidedBody.trunkLiftDefault)
        #expect(abs(off.markers[key]!.x - body.markers[key]!.x) < 1e-12)
        #expect(on.markers[key]!.x > 1.8 * body.markers[key]!.x)
        for m in TakashimaMarkers.rightSideDownFrontSideways where m.mean < 0 {
            #expect(m.value(on) > 0, "the lift moves \(m.marker) away from the floor; measured toward it")
        }
    }

    /// A dependent dome share above ½ ventilates the dependent lung more (Kaneko 1966's direction;
    /// in this model it comes only from the assumed split, and it is small).
    @Test func dependentLungTakesMoreWhenItsDomeRisesMore() {
        let even = SidedBreath.measure(rightSideDown(share: 0.5, bed: 1).body.simulate(), period: Self.drive.period)
        let dep = SidedBreath.measure(rightSideDown(share: 1.0, bed: 1).body.simulate(), period: Self.drive.period)
        #expect(abs(even.lung[1] - even.lung[0]) < 0.003)
        #expect(dep.lung[1] > dep.lung[0])
    }

    /// With the floor pressing on the dependent flank, the dependent chest wall moves less (Nozoe 2014's
    /// direction); without that spring (lift only) the two sides are nearly equal.
    @Test func bedMakesDependentWallMoveLess() {
        let free = SidedBreath.measure(rightSideDown(share: 0.75, bed: 0).body.simulate(), period: Self.drive.period)
        let bed = SidedBreath.measure(rightSideDown(share: 0.75, bed: 1).body.simulate(), period: Self.drive.period)
        #expect(bed.chestWall[1] < bed.chestWall[0] * 0.95)
        #expect(abs(free.chestWall[1] - free.chestWall[0]) < 0.02)
    }
}

/// One-sided what-ifs, seated (the working log (private), "one-sided").
@Suite struct SidedOneSided {
    let body = Sided.sym
    func breath(_ b: SidedBody) -> SidedBreath { SidedBreath.measure(b.simulate(), period: Drive().period) }

    /// A hand on the left lower ribs: the left chest wall moves less than the right.
    @Test func handOnLeftLowerRibs() {
        let b = breath(body.stiffened(SidedCoordinate.on(.left, A2Coordinate.lowerBand), by: 5))
        #expect(b.chestWall[0] < b.chestWall[1])
        #expect(b.lower[0] < b.lower[1])
    }

    /// One hemidiaphragm paralysed: on the fluoroscopic sniff test the paralysed dome rises on
    /// inspiration (paradoxical motion), and that side's lung takes less.
    @Test func leftHemidiaphragmParalysis() {
        let b = body.silenced([.diaphragm], side: .left)
        let q = b.endInspiration()
        #expect(q[SidedCoordinate.diaphragmL.rawValue] < 0)
        #expect(q[SidedCoordinate.diaphragmR.rawValue] > 0)
        let br = breath(b)
        #expect(br.lung[0] < br.lung[1])
    }
}

/// Side-lying against the sourced per-lung split (the working log (private), "side-lying from sources").
@Suite struct SidedFromSources {
    func body(_ op: SidedOperatingPoint) -> SidedBody {
        let an = op.apply(to: AnatomyModel.rightSideDown())
        let w = SidedBody.rightSideDownWall
        return SidedBody.from(seated: Sided.sym, anatomy: an, abdomenComplianceScale: w.abdomenComplianceScale,
                              ribcageStiffnessScale: w.ribcageStiffnessScale,
                              diaphragmForceScale: Side.allCases.map { op.forceScale($0) }, dependent: .right, bedGain: w.bedGain)
            .matchedToTidal(0.51)
    }
    func share(_ b: SidedBody) -> Double {
        let m = SidedBreath.measure(b.simulate(), period: Drive().period)
        return m.lung[1] / m.tidalVolume
    }

    /// The fitted force asymmetry lands in the sources' range: Amano 2024 (CT) 56–62%, Grant 2011
    /// (EIT) 51–59%, so 51–62%. A calibration, not a prediction.
    @Test func dependentLungShareInSourcedRange() {
        let s = share(body(.rightSideDown))
        #expect(s > 0.51 && s < 0.62)
    }

    // The Chevrolet 1979 checks (diaphragm relaxed → about even) were removed after critique 3: lying on
    // the side the model's rib-muscles-only breath is 7–35 mL, too small for its lung split to mean anything.
}

/// The spine's arc lying on the side (SideLyingArc; Leilnahari 2011, firm surface).
@Suite struct SideLyingArcTests {
    let arc = SideLyingArc.firmSurface

    /// 8.9° at T11 over C7–L5 (~49 cm) is a sag of ~1.9 cm, zero at both supports.
    @Test func sagFromLeilnahari() {
        #expect(abs(arc.sag - 1.90) < 0.01)
        #expect(abs(arc.offset(21.5) - arc.sag) < 1e-9)
        #expect(arc.offset(arc.zLower) == 0 && arc.offset(arc.zUpper) == 0)
        #expect(arc.tilt(10) > 0 && arc.tilt(35) < 0)
    }

    /// Convex toward the support: the dependent side stretches, the upper side shortens.
    @Test func dependentSideLengthens() {
        #expect(arc.lateralStrain(21.5, halfWidth: 14, dependentSide: true) > 0.1)
        #expect(arc.lateralStrain(21.5, halfWidth: 14, dependentSide: false) < -0.1)
    }

    /// For drawing, right side down: at rest the spine sits toward the right (−x); in the room frame
    /// during inspiration it moves back up by the lift.
    @Test func spineForDrawing() {
        let a = AnatomyModel.rightSideDown()
        let rest = a.sideLyingSpine(z: 21.5, AnatomyState(), restingOn: .right)
        #expect(abs(rest.x + arc.sag) < 1e-9)
        var s = AnatomyState()
        s.lowerDilation = [0.01, 0.01]
        #expect(a.sideLyingSpine(z: 21.5, s, restingOn: .right).x > rest.x)
    }
}

/// The user's deformed-floor-side hypothesis (DeformedSideStiffening; the working log (private)).
@Suite struct SidedDeformedSide {
    /// The derived strain is Takashima's narrowing over the half-width; `assumed` doubles stiffness.
    @Test func sizes() {
        #expect(abs(DeformedSideStiffening.assumed.strain - 0.26) < 0.005)
        #expect(abs(DeformedSideStiffening.assumed.factor - 2) < 1e-9)
    }

    /// Stiffer floor-side lower ribs move less. Without coupling between the pleural spaces the
    /// upper side's own motion doesn't pick it up; in the room frame the lift falls.
    @Test func floorSideMovesLessUpperSideUnchanged() {
        let op = SidedOperatingPoint.rightSideDown, an = op.apply(to: AnatomyModel.rightSideDown())
        let w = SidedBody.rightSideDownWall
        let base = SidedBody.from(seated: Sided.sym, anatomy: an, abdomenComplianceScale: w.abdomenComplianceScale,
                                  ribcageStiffnessScale: w.ribcageStiffnessScale,
                                  diaphragmForceScale: Side.allCases.map { op.forceScale($0) }, dependent: .right, bedGain: w.bedGain)
        let a = base.matchedToTidal(0.51), b = base.withDeformedSide().matchedToTidal(0.51)
        let sa = an.sidedState(a.endInspiration()), sb = an.sidedState(b.endInspiration())
        #expect(an.roomLift(z: 21.5, sb, restingOn: .right) < an.roomLift(z: 21.5, sa, restingOn: .right))
        let own = { (s: AnatomyState) in an.observeSided(s).markers["left lateral lower ribcage"]!.x }
        #expect(abs(own(sb) - own(sa)) < 0.05)
    }
}

/// The compliant mediastinum (Hubmayr & Margulies 1992; the working log (private), "mediastinum").
@Suite struct SidedMediastinum {
    /// The default body transmits half a one-sided pleural pressure change to the other side
    /// (baboons 0.5); a rigid mediastinum transmits less (chest wall only).
    @Test func transmissionMatchesSource() {
        #expect(abs(Sided.sym.pleuralTransmission() - 0.5) < 0.01)
        var rigid = Sided.sym
        rigid.mediastinalCompliance = 0
        #expect(rigid.pleuralTransmission() < 0.45)
    }

    /// One hemidiaphragm paralysed: with the mediastinum that side's lung is under-ventilated, not
    /// emptied (it lost volume with a rigid mediastinum).
    @Test func paralysedSideStillFills() {
        let br = SidedBreath.measure(Sided.sym.silenced([.diaphragm], side: .left).simulate(), period: Drive().period)
        #expect(br.lung[0] > 0 && br.lung[0] < 0.5 * br.lung[1])
    }
}
