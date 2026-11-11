import Testing
@testable import BreathStar

/// A2: mechanics on the anatomical coordinates.
@Suite struct Mechanics {
    let anatomy = AnatomyModel()
    let drive = Drive()

    func reference() -> [Double] {
        anatomy.a2Coordinates(anatomy.state(upperRibcage: 0.16, lowerRibcage: 0.09, abdomen: 0.31))
    }

    func body() -> A2Body { A2Body.calibrate(anatomy: anatomy, reference: reference()).matchedToTidal(0.56) }

    /// Calibration is exact: the static equilibrium with the solved forces is the reference.
    @Test func staticEquilibriumIsTheReference() {
        let b = A2Body.calibrate(anatomy: anatomy, reference: reference())
        let jth = b.geometry.thorax, jab = b.geometry.abdominalCavity
        let kq = multiply(b.stiffnessMatrix, b.reference)
        for i in 0..<A2Coordinate.count {
            let lhs = kq[i]
            let rhs = b.referencePleural * jth[i] + b.referenceAbdominal * jab[i] + b.peakForce[i]
            #expect(abs(lhs - rhs) < 1e-9)
        }
        #expect(abs(b.peakForce[A2Coordinate.abdomen.rawValue]) < 1e-12)  // relaxed belly
    }

    /// The abdomen's contents never change volume, at any instant.
    @Test func abdomenIsIncompressible() {
        let b = body(), jab = b.geometry.abdominalCavity
        for s in b.simulate(drive: drive, cycles: 2) {
            #expect(abs(zip(jab, s.q).reduce(0) { $0 + $1.0 * $1.1 }) < 1e-10)
        }
    }

    /// The simulated breath keeps the reference's regional split and reaches its volume.
    @Test func reproducesTheReferenceBreath() {
        // Calibration re-closes the reference's abdomen under anisotropic apposition (only the
        // lower ribcage's sides and back are abdominal), so compare with the calibrated reference.
        let b = body()
        let m = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
        func dot(_ v: [Double]) -> Double { zip(v, b.reference).reduce(0) { $0 + $1.0 * $1.1 } }
        let total = dot(b.geometry.thorax)
        #expect(abs(m.tidalVolume - 0.56) < 1e-3)
        #expect(abs(m.upperShare - dot(b.geometry.upperRegion) / total) < 0.01)
        #expect(abs(m.abdomenShare - dot(b.geometry.abdomenRegion) / total) < 0.01)
        #expect(abs(m.upperShare + m.lowerShare + m.abdomenShare - 1) < 1e-9)
    }

    /// With the rib muscles silent, the diaphragm alone draws the upper ribcage in while the
    /// lower ribcage still expands (pushed by abdominal pressure through apposition).
    @Test func diaphragmAloneGivesUpperRibcageParadox() {
        let b = body().silenced([.ribs])
        let m = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
        #expect(m.upper < 0)
        // The lower ribs still widen (Estenne measured diameters). Their ring-bounded region volume
        // can be slightly negative: lifting the costal-margin ring hands volume to the abdomen.
        #expect(b.diameterChanges(atHeight: 21.5).transverse > 0)
    }

    /// With the diaphragm silent, the rib muscles draw the abdomen in.
    @Test func ribsAloneGiveAbdominalParadox() {
        let b = body().silenced([.diaphragm])
        let m = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
        #expect(m.abdomen < 0)
    }

    /// Stiffening a region (a hold, a hand) reduces that region's share of the breath.
    @Test(arguments: ["abdomen", "lower", "upper"])
    func stiffeningARegionReducesItsShare(_ region: String) {
        let b = body()
        let coords: [A2Coordinate] = region == "abdomen" ? [.abdomen]
            : region == "lower" ? A2Coordinate.lowerBand : [.upperRotation, .upperDilation]
        func share(_ m: SignedBreath) -> Double {
            region == "abdomen" ? m.abdomenShare : region == "lower" ? m.lowerShare : m.upperShare
        }
        let base = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let held = SignedBreath.measure(b.stiffened(coords, by: 5).simulate(drive: drive), period: drive.period)
        #expect(share(held) < share(base))
    }
}

/// A2 against published patterns in patients (literature pass 3). Directions only: the model is a
/// healthy seated body with muscles switched off, not a patient.
@Suite struct MechanicsAgainstSources {
    let anatomy = AnatomyModel()
    let drive = Drive()

    func body() -> A2Body {
        let q = anatomy.a2Coordinates(anatomy.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state)
        return A2Body.calibrate(anatomy: anatomy, reference: q).matchedToTidal(0.56)
    }
    var diaphragmOnly: A2Body { body().asPatient(paralysed: [.ribs], chronic: false) }
    var ribsOnly: A2Body { body().asPatient(paralysed: [.diaphragm], chronic: false) }

    /// Estenne & De Troyer 1985: lower ribcage expands more than upper; upper AP paradox;
    /// lower ribcage expands more transversely than AP (partly geometric here: isotropic
    /// dilation of a section wider than deep).
    @Test func tetraplegiaPattern() {
        let b = diaphragmOnly
        let m = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
        #expect(m.lower > m.upper)
        let up = b.diameterChanges(atHeight: 34), low = b.diameterChanges(atHeight: 21.5)
        #expect(up.ap < 0)
        #expect(low.transverse > low.ap && low.transverse > 0)
    }

    /// Urmey et al. 1986: abdominal compression reduces ribcage distortion. Weak in the model
    /// (no apposition-area change, the mechanism Urmey proposed), but the right direction.
    @Test func abdominalCompressionReducesDistortion() {
        let free = SignedBreath.measure(diaphragmOnly.simulate(drive: drive), period: drive.period)
        let held = SignedBreath.measure(diaphragmOnly.stiffened([.abdomen], by: 5).simulate(drive: drive),
                                        period: drive.period)
        #expect(held.upperShare > free.upperShare)
    }

    /// De Troyer et al. 1986 (neck muscles only) and Higenbottam et al. 1977 (bilateral diaphragm palsy).
    @Test func noDiaphragmPattern() {
        let b = ribsOnly
        #expect(b.diameterChanges(atHeight: 34).ap > 0)
        #expect(b.diameterChanges(atHeight: 21.5).transverse < 0)
        #expect(SignedBreath.measure(b.simulate(drive: drive), period: drive.period).abdomen < 0)
    }
}

/// Supine A2 (the working log (private), "A2 supine"). Fitted to Takashima's healthy supine breath under
/// hypothesis A (the bed pins the ribcage). Patient patterns still missed are KNOWN ISSUES:
/// withKnownIssue fails loudly if one of them starts passing.
@Suite struct MechanicsSupine {
    let drive = Drive()

    func seated() -> A2Body {
        let anatomy = AnatomyModel()
        let q = anatomy.a2Coordinates(anatomy.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state)
        return A2Body.calibrate(anatomy: anatomy, reference: q).matchedToTidal(0.56)
    }

    func supine(_ h: A2Body.PostureHypothesis = .ribcageStiffness) -> (body: A2Body, abdomenShare: Double) {
        let anatomy0 = AnatomyModel.supine()
        let o = anatomy0.observe(anatomy0.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52).state)
        let share = o.abdomen.reduce(0, +) / o.totalSurface
        let op = OperatingPoint(frcDrop: 0.22)
        return (A2Body.fitPosture(anatomy: op.apply(to: anatomy0), from: seated(), abdomenShare: share, tidal: 0.52,
                                  hypothesis: h, diaphragmForceScale: op.diaphragmForceScale, drive: drive).body, share)
    }

    func signed(_ b: A2Body) -> SignedBreath { SignedBreath.measure(b.simulate(drive: drive), period: drive.period) }

    @Test func fitsTheHealthySupineBreath() {
        let (b, share) = supine()
        let m = signed(b)
        #expect(abs(m.tidalVolume - 0.52) < 0.01)
        #expect(abs(m.abdomenShare - share) < 0.01)
    }

    /// Lying down shifts the breath to the abdomen (Mendes, Takashima, Sonpeayung all agree).
    @Test func supineIsMoreAbdominalThanSeated() {
        #expect(signed(supine().body).abdomenShare > signed(seated()).abdomenShare)
    }

    /// Estenne & De Troyer 1985: supine, the lower ribcage still widens with the diaphragm alone.
    @Test func diaphragmAloneStillWidensLowerRibcageSupine() {
        let d = supine().body.asPatient(paralysed: [.ribs], chronic: false).diameterChanges(atHeight: 21.5)
        #expect(d.transverse > 0)
    }

    // Retired 2026-11-11: patientPatternsLyingDownKnownIssues and abdominalParadoxLyingDownKnownIssue
    // checked Estenne 1985, Mortola 1978 and Higenbottam 1977 on this earlier fitted supine body,
    // superseded by the posture rules. The patterns are tested on the current bodies in
    // PatientTests (Mortola and the paradoxes hold; Estenne holds with the costal arch ×5; the
    // sitting belly paradox is masked by upright expiratory abdominals).

    /// Hypothesis A (ribcage pinned) explains healthy supine markers better than B (less rib drive).
    @Test func pinnedRibcageFitsHealthyMarkersBetter() {
        let a = signed(supine(.ribcageStiffness).body), b = signed(supine(.ribMuscleDrive).body)
        // The supine markers imply an upper-ribcage share of about 12.8%. A is closer (narrowly,
        // since the sternal coupling; A 5/8 markers within SD, B 4/8).
        let sup = AnatomyModel.supine()
        let o = sup.observe(sup.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52).state)
        let implied = o.upperRibcage.reduce(0, +) / o.totalSurface
        #expect(abs(a.upperShare - implied) < abs(b.upperShare - implied))
    }
}

/// Anisotropic apposition and the tone split (the working log (private), "apposition and tone").
@Suite struct MechanicsApposition {
    let anatomy = AnatomyModel()

    /// The lower region's change splits exactly into front (pleural) and sides/back (abdominal).
    @Test func lowerRegionSplitsExactly() {
        let g = anatomy.a2Geometry()
        for i in 0..<A2Coordinate.count {
            #expect(abs(g.lowerLungFacing[i] + g.lowerApposed[i] - g.lowerRegion[i]) < 1e-12)
        }
    }

    /// The lung's lower edge is higher in front (6th rib) than at the side (8th): the front of the
    /// lower ribcage is almost all apposed, while a lateral band faces lung. So AP dilation moves
    /// volume almost entirely against the diaphragm; transverse dilation partly against lung.
    @Test func lowerFrontIsApposedSidesPartlyFaceLung() {
        let g = anatomy.a2Geometry()
        let ap = A2Coordinate.lowerDilationAP.rawValue, tr = A2Coordinate.lowerDilationTransverse.rawValue
        #expect(g.lowerLungFacing[ap] / g.lowerRegion[ap] < 0.1)
        #expect(g.lowerLungFacing[tr] / g.lowerRegion[tr] > 0.2)
    }

    /// The lung edge follows the classical lines: highest in front, lowest at the side.
    @Test func lungEdgeShape() {
        #expect(anatomy.lungEdgeHeight(psiDegrees: 0) > anatomy.lungEdgeHeight(psiDegrees: 90))
        #expect(anatomy.lungEdgeHeight(psiDegrees: 170) > anatomy.lungEdgeHeight(psiDegrees: 90))
    }

    /// The flux integral reproduces the section-integrated volume change (first order).
    @Test func fluxMatchesVolume() {
        var s = AnatomyState()
        s.lowerDilation = [0.001, 0.001]
        s.lowerDilationAP = 0.001
        let flux = anatomy.lowerFlux(s, lungFacing: true) + anatomy.lowerFlux(s, lungFacing: false)
        let volume = anatomy.observe(s).lowerRibcage.reduce(0, +)
        #expect(abs(flux - volume) / volume < 0.02)
    }

    /// Estenne 1983: chronic weakness stiffens the relaxed chest wall ×1.53; patients lose tone.
    @Test func patientStiffness() {
        var passive = A2Passive()
        passive.ribcageTone = 1
        let q = anatomy.a2Coordinates(anatomy.state(upperRibcage: 0.16, lowerRibcage: 0.09, abdomen: 0.31))
        let b = A2Body.calibrate(anatomy: anatomy, reference: q, passive: passive)
        let acute = b.asPatient(paralysed: [.ribs], chronic: false)
        let chronic = b.asPatient(paralysed: [.ribs], chronic: true)
        let r = A2Coordinate.upperRotation.rawValue, a = A2Coordinate.abdomen.rawValue
        #expect(abs(acute.stiffness[r] - b.stiffness[r] / 2) < 1e-9)
        #expect(abs(chronic.stiffness[r] - b.stiffness[r] / 2 * A2Passive.chronicWeaknessStiffening) < 1e-9)
        #expect(abs(chronic.stiffness[a] - b.stiffness[a] * A2Passive.chronicWeaknessStiffening) < 1e-9)
        #expect(acute.peakForce[r] == 0)
    }
}

/// Sternal coupling (the working log (private), "sternal coupling").
@Suite struct MechanicsSternalCoupling {
    let anatomy = AnatomyModel()

    /// The coupling only acts through the sternum and the lower front: the abdominal wall and the
    /// diaphragm don't load the arch.
    @Test func couplingTouchesOnlyTheRibs() {
        let q = anatomy.a2Coordinates(anatomy.state(upperRibcage: 0.16, lowerRibcage: 0.09, abdomen: 0.31))
        let b = A2Body.calibrate(anatomy: anatomy, reference: q)
        #expect(abs(b.coupling[A2Coordinate.abdomen.rawValue]) < 1e-9)
        #expect(abs(b.coupling[A2Coordinate.diaphragm.rawValue]) < 1e-9)
        #expect(b.coupling[A2Coordinate.lowerPump.rawValue] < 0)  // the lower pump moves the lower front, not the sternum
        #expect(b.coupling[A2Coordinate.upperRotation.rawValue] > 0)
    }

    /// The stiffness matrix is symmetric (it comes from an energy).
    @Test func stiffnessIsSymmetric() {
        let q = anatomy.a2Coordinates(anatomy.state(upperRibcage: 0.16, lowerRibcage: 0.09, abdomen: 0.31))
        let k = A2Body.calibrate(anatomy: anatomy, reference: q).stiffnessMatrix
        for i in 0..<A2Coordinate.count { for j in 0..<A2Coordinate.count { #expect(abs(k[i][j] - k[j][i]) < 1e-9) } }
    }
}

/// Gravity through the operating point (the working log (private), "gravity").
@Suite struct MechanicsOperatingPoint {
    /// Smith & Bellemare 1987 scaled by a 4.53 L VC: about 15% more force per litre lower.
    @Test func lengthTension() {
        #expect(OperatingPoint.lengthTensionPerLitre > 0.1 && OperatingPoint.lengthTensionPerLitre < 0.2)
        #expect(OperatingPoint(frcDrop: 0.22).diaphragmForceScale > 1)
    }

    /// A lower FRC raises the dome and the zone of apposition with it.
    @Test func appositionRises() {
        let a = AnatomyModel.supine()
        let op = OperatingPoint(frcDrop: 0.22)
        #expect(op.apply(to: a).lungEdgeHeight(psiDegrees: 90) > a.lungEdgeHeight(psiDegrees: 90))
    }
}


/// The tilt reaches the zone of apposition (the working log (private), "tilt to the back ribs").
@Suite struct MechanicsTiltedApposition {
    /// Lying down the dome rises more at the back, so the back zone of apposition grows more.
    @Test func backEdgeRisesMore() {
        var m = AnatomyModel.supine()
        let flat0 = m.lungEdgeHeight(psiDegrees: 180), front0 = m.lungEdgeHeight(psiDegrees: 0)
        m = OperatingPoint(frcDrop: 0.22).apply(to: m)
        let backRise = m.lungEdgeHeight(psiDegrees: 180) - flat0
        let frontRise = m.lungEdgeHeight(psiDegrees: 0) - front0
        #expect(backRise > frontRise && frontRise > 0)
        #expect(abs(backRise / frontRise - 1.43 / 0.57) < 0.01)
    }

    /// Mid-breath, the edge is lowered by the tilted descent: most at the back.
    @Test func midBreathLowersBackMost() {
        var m = AnatomyModel()
        let back0 = m.lungEdgeHeight(psiDegrees: 180), front0 = m.lungEdgeHeight(psiDegrees: 0)
        m.appositionDescent = 0.7
        #expect(back0 - m.lungEdgeHeight(psiDegrees: 180) > front0 - m.lungEdgeHeight(psiDegrees: 0))
    }
}

/// Visible uncertainty (the working log (private), "uncertainty sets"): across plausible bodies, which
/// conclusions hold. The ensemble is `breathstar uncertainty`; this pins the two ends of the
/// assumption that decides the least settled check.
@Suite struct MechanicsUncertainty {
    func body(lateralDropFraction l: Double) -> A2Body {
        var a = AnatomyModel()
        a.lateralDropFraction = l
        let s = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        return A2Body.calibrate(anatomy: a, reference: a2(a, s)).matchedToTidal(0.56)
    }
    func a2(_ a: AnatomyModel, _ s: AnatomyState) -> [Double] { a.a2Coordinates(s) }
    func signed(_ b: A2Body) -> SignedBreath { SignedBreath.measure(b.simulate(), period: Drive().period) }

    /// Settled across the ensemble: with the diaphragm alone the upper chest sinks, at both ends.
    @Test(arguments: [0.3, 0.7])
    func diaphragmOnlyUpperChestSinks(_ l: Double) {
        #expect(signed(body(lateralDropFraction: l).silenced([.ribs])).upperShare < 0)
    }

    /// Unsettled: Urmey's "belly compression reduces the distortion" depends on how far the
    /// lower ribs' lateral points lie below the bucket axis (ASSUMED 0.5). Less drop, more benefit.
    @Test func urmeyDependsOnLateralDrop() {
        func benefit(_ l: Double) -> Double {
            let d = body(lateralDropFraction: l).silenced([.ribs])
            return signed(d.stiffened([.abdomen], by: 5)).upperShare - signed(d).upperShare
        }
        #expect(benefit(0.3) > benefit(0.7))
    }
}

extension MechanicsUncertainty {
    /// With the rib muscles silent, the breath's shares don't depend on the reference rib motion
    /// (only geometry and stiffness): changing the lateral marker target leaves Urmey's benefit
    /// unchanged. So only anatomy, not marker data, can settle it (the working log (private), "lateral drop").
    @Test func urmeyIgnoresMarkerData() {
        let a = AnatomyModel()
        func benefit(_ markers: [MarkerObservation]) -> Double {
            let s = a.fitToMarkers(markers, tidal: 0.56).state
            let d = A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(s)).matchedToTidal(0.56).silenced([.ribs])
            return signed(d.stiffened([.abdomen], by: 5)).upperShare - signed(d).upperShare
        }
        let jordanoglou = TakashimaMarkers.sitting.map { m in
            m.marker == "left lateral lower ribcage" && m.component == .outward
                ? MarkerObservation(marker: m.marker, component: m.component, mean: 1.53, sd: m.sd) : m
        }
        #expect(abs(benefit(TakashimaMarkers.sitting) - benefit(jordanoglou)) < 1e-4)
    }
}

/// Timing between muscle groups (the working log (private), "timing").
@Suite struct MechanicsTiming {
    let drive = Drive()
    func body() -> A2Body {
        let a = AnatomyModel()
        let s = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        return A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(s)).matchedToTidal(0.56, drive: drive)
    }

    /// The recruitment timing (onsets only, common release) keeps the ribcage and abdomen within
    /// healthy synchrony (−5° to +4°), and the lower ribs arrive last.
    @Test func recruitmentTimingStaysSynchronous() {
        let t = BreathTiming.measure(body().timed(MuscleTiming(), drive: drive).simulate(drive: drive), period: drive.period)
        #expect(t.ribcageAbdomen > -5 && t.ribcageAbdomen < 4)
        #expect(t.lowerLag > t.upperLag && t.lowerLag > t.abdomenLag)
    }

    /// Onset delays don't change the shares (all groups release together; the lung peaks during the release).
    @Test func onsetDelaysLeaveSharesAlone() {
        let b = body()
        let a = SignedBreath.measure(b.timed(.inPhase, drive: drive).simulate(drive: drive), period: drive.period)
        let c = SignedBreath.measure(b.timed(MuscleTiming(upperBand: 0.15, lowerBand: 0.45), drive: drive).simulate(drive: drive), period: drive.period)
        #expect(abs(a.upperShare - c.upperShare) < 0.005 && abs(a.abdomenShare - c.abdomenShare) < 0.005)
    }

    /// A later onset makes a region lag more.
    @Test func laterOnsetMoreLag() {
        let b = body()
        let small = BreathTiming.measure(b.timed(MuscleTiming(), drive: drive).simulate(drive: drive), period: drive.period)
        let big = BreathTiming.measure(b.timed(MuscleTiming(upperBand: 0.15, lowerBand: 0.45), drive: drive).simulate(drive: drive), period: drive.period)
        #expect(big.lowerLag > small.lowerLag + 3)
    }
}

extension MechanicsTiming {
    func angle(_ b: A2Body, _ d: Drive) -> Double { BreathTiming.measure(b.simulate(drive: d), period: d.period).ribcageAbdomen }

    /// Expiratory abdominal activity delays the ribcage relative to the abdomen; at 0.5 cmH2O it
    /// already leaves healthy synchrony (bound ~0.2).
    @Test func expiratoryAbdominalsDelayRibcage() {
        var b = body().timed(MuscleTiming(), drive: drive)
        let base = angle(b, drive)
        b.expiratoryAbdominalPressure = 0.5
        #expect(angle(b, drive) > base + 2 && angle(b, drive) > 4)
    }

    /// Braking shared by all inspiratory muscles leaves synchrony alone; diaphragm-only braking
    /// makes the ribcage lead.
    @Test func sharedBrakingKeepsSynchrony() {
        var slow = Drive()
        slow.relaxationTime = 0.5
        let a = AnatomyModel()
        let s = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        let shared = A2Body.calibrate(anatomy: a, reference: a.a2Coordinates(s)).timed(MuscleTiming(), drive: slow).matchedToTidal(0.56, drive: slow)
        #expect(abs(angle(shared, slow) - 2.6) < 1)
        var dia = body().timed(MuscleTiming(), drive: drive)
        dia.diaphragmRelaxation = 0.5
        #expect(angle(dia, drive) < -5)
    }
}

/// Fixed-sign muscle groups (MuscleGroups.swift; critique 3, section 3).
@Suite struct MechanicsMuscleGroups {
    let fit = A2Body.fitMuscleGroups(anatomy: AnatomyModel(), markers: TakashimaMarkers.sitting, tidal: 0.56,
                                     passive: A2MuscleGroup.defaultPassive, lowerBandStiffness: A2MuscleGroup.lowerBandStiffness)

    /// Every group pushes outward or not at all: no inward-pulling inspiratory force on any coordinate.
    @Test func noInwardForces() {
        #expect(fit.pressures.allSatisfy { $0 >= 0 })
        #expect(fit.body.peakForce.allSatisfy { $0 >= 0 })
    }

    /// Three pressures (and the lower band ×2) still fit Takashima's 12 seated components within SD.
    @Test func fitsTheMarkers() {
        #expect(fit.rows.allSatisfy { abs($0.model - $0.observation.mean) <= $0.observation.sd })
        #expect(fit.chiSquared < 2)
        #expect(abs(fit.tidalVolume - 0.56) < 0.01)
    }

    /// The lower ribs need no drive of their own once they are stiffer: the diaphragm and the sternal
    /// coupling move them. Recorded so a change shows up.
    @Test func lowerGroupNearlySilent() {
        #expect(fit.pressures[A2MuscleGroup.lowerRibcage.rawValue] < 0.5)
    }

    /// The textbook stiffness (×1) fits worse: the lower ribs move too far without an inward pull.
    @Test func textbookLowerBandFitsWorse() {
        let soft = A2Body.fitMuscleGroups(anatomy: AnatomyModel(), markers: TakashimaMarkers.sitting, tidal: 0.56,
                                          passive: A2MuscleGroup.defaultPassive)
        #expect(soft.chiSquared > 2 * fit.chiSquared)
    }
}
