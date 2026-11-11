import Testing
@testable import BreathStar

/// A1: geometry and kinematics. These are properties of the construction, not of bodies,
/// except where a source is named.
@Suite struct Anatomy {
    let model = AnatomyModel()

    /// With the abdomen closed, the lungs take exactly what the surface shows.
    @Test func lungVolumeEqualsSurfaceVolume() {
        var s = AnatomyState()
        s.upperRib = [0.2, 0.1]
        s.lowerRib = [0.3, 0.25]
        s.diaphragm = [1.2, 0.8]
        let o = model.observe(model.closeAbdomen(s))
        #expect(abs(o.totalLung - o.totalSurface) < 1e-6)
    }

    /// The inverse map reproduces the regional volumes it was given.
    @Test func inverseMapRoundTrips() {
        let s = model.state(upperRibcage: 0.21, lowerRibcage: 0.12, abdomen: 0.23)
        let o = model.observe(s)
        #expect(abs(o.upperRibcage.reduce(0, +) - 0.21) < 1e-4)
        #expect(abs(o.lowerRibcage.reduce(0, +) - 0.12) < 1e-4)
        #expect(abs(o.abdomen.reduce(0, +) - 0.23) < 1e-4)
    }

    /// Pump-handle rotation moves the front of the chest forward and up; it doesn't widen it.
    @Test func pumpMovesFrontForwardAndUp() {
        var s = AnatomyState()
        s.upperRib = [0.5, 0.5]
        var m = model
        m.upperBucketDegrees = 0
        let front = m.surfaceDisplacement(z: 34, psiDegrees: 0, side: .left, s)
        #expect(front.y > 0 && front.z > 0)
        #expect(abs(front.x) < 1e-12)
    }

    /// Bucket-handle rotation moves the side of the chest out and up.
    @Test func bucketMovesSideOutAndUp() {
        var s = AnatomyState()
        s.lowerRib = [0.5, 0.5]
        var m = model
        m.lowerPumpDegrees = 0
        let side = m.surfaceDisplacement(z: 21, psiDegrees: 90, side: .left, s)
        #expect(side.x > 0 && side.z > 0)
    }

    /// The back sits on the spine and doesn't move (at ψ = 180°).
    @Test func backIsFixed() {
        var s = AnatomyState()
        s.upperRib = [0.5, 0.5]
        s.lowerRib = [0.5, 0.5]
        s = model.closeAbdomen(s)
        for z in [5.0, 21, 34] {
            let back = model.surfaceDisplacement(z: z, psiDegrees: 180, side: .left, s)
            #expect(abs(back.x) < 1e-9 && abs(back.y) < 1e-9 && abs(back.z) < 1e-9)
        }
    }

    /// A breath with no diaphragm and expanding lower ribs pulls the abdominal wall in:
    /// the abdomen's contents keep their volume (the paradox, kinematically).
    @Test func ribsAloneDrawTheAbdomenIn() {
        var s = AnatomyState()
        s.lowerRib = [0.3, 0.3]
        let closed = model.closeAbdomen(s)
        #expect(closed.abdomenFront < 0)
    }

    /// Wilson 1987: rib rotation over FRC→TLC is ~10°. A quiet breath should use a fraction of it.
    @Test func quietBreathUsesAFractionOfFullRibRotation() {
        let s = model.state(upperRibcage: 0.21, lowerRibcage: 0.12, abdomen: 0.23)
        for r in s.upperRib + s.lowerRib { #expect(r > 0 && r < 0.5) }
    }

    /// Boussuges 2009: quiet-breathing hemidiaphragm excursion, lower limit ~1.0 cm in men.
    /// A 0.56 L breath with Mendes's seated shares should not need far less or far more.
    @Test func diaphragmExcursionIsPlausible() {
        let s = model.state(upperRibcage: 0.209, lowerRibcage: 0.123, abdomen: 0.229)
        for d in s.diaphragm { #expect(d > 0.7 && d < 3.0) }
    }
}

/// A1 fitted directly to Takashima's markers + tidal volume (surface volumes; the working log (private),
/// "surface volumes").
@Suite struct AnatomyAgainstTakashima {
    let model = AnatomyModel()

    /// Dilation opens the band about the spine: forward and out, never up.
    @Test func dilationDoesNotLift() {
        var s = AnatomyState()
        s.upperDilation = [0.01, 0.01]
        for psi in [0.0, 45, 90] {
            let d = model.surfaceDisplacement(z: 34, psiDegrees: psi, side: .left, s)
            #expect(abs(d.z) < 1e-12)
            #expect(d.y >= 0 && d.x >= 0)
        }
    }

    /// Every sitting marker within its published SD, the tidal volume met, the diaphragm plausible.
    @Test func sittingFitWithinSD() {
        let fit = model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56)
        for (ob, v) in fit.rows { #expect(abs(v - ob.mean) <= ob.sd, "\(ob.marker) \(ob.component): \(v)") }
        #expect(abs(fit.tidalVolume - 0.56) < 0.005)
        #expect(fit.state.diaphragm[0] > 0.7 && fit.state.diaphragm[0] < 2.5)  // Boussuges 2009: ≥ ~1 cm
    }

    /// The flanks draw in slightly while the front bulges: a result, robust across volume definitions.
    @Test func flanksDrawIn() {
        let s = model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        #expect(s.abdomenFlank[0] < 0 && s.abdomenFront > 0)
    }

    /// The front markers don't support spine extension (it fits near zero).
    @Test func frontMarkersDontNeedExtension() {
        let fit = model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56, includeExtension: true)
        #expect(abs(fit.state.spineExtension) < 0.5 * .pi / 180)
    }

    /// The inverse map round-trips with the fitted shares (lower share above 1: rotation hands
    /// volume across the costal-margin ring).
    @Test func inverseMapRoundTripsWithSurfaceVolumes() {
        let s = model.state(upperRibcage: 0.13, lowerRibcage: 0.07, abdomen: 0.36)
        let o = model.observe(s)
        #expect(abs(o.upperRibcage.reduce(0, +) - 0.13) < 1e-3)
        #expect(abs(o.lowerRibcage.reduce(0, +) - 0.07) < 1e-3)
        #expect(abs(o.abdomen.reduce(0, +) - 0.36) < 1e-3)
    }
}

/// The surface is one continuous field: no jumps where regions hand off.
@Suite struct AnatomyContinuity {
    let model = AnatomyModel()

    func breath() -> AnatomyState {
        model.state(upperRibcage: 0.16, lowerRibcage: 0.09, abdomen: 0.31)
    }

    @Test(arguments: [0.0, 30, 60, 90, 120])
    func continuousAtCostalMargin(_ psi: Double) {
        let s = breath(), z = model.costalMargin
        let below = model.surfaceDisplacement(z: z - 1e-6, psiDegrees: psi, side: .left, s)
        let above = model.surfaceDisplacement(z: z + 1e-6, psiDegrees: psi, side: .left, s)
        #expect(abs(below.x - above.x) < 1e-5 && abs(below.y - above.y) < 1e-5 && abs(below.z - above.z) < 1e-5)
    }

    @Test(arguments: [0.0, 45, 90])
    func smoothAcrossXiphoid(_ psi: Double) {
        // Blended over a zone: neighbouring heights differ only a little.
        let s = breath()
        var previous = model.surfaceDisplacement(z: model.xiphoid - 3, psiDegrees: psi, side: .left, s)
        for z in stride(from: model.xiphoid - 2.9, through: model.xiphoid + 3, by: 0.1) {
            let d = model.surfaceDisplacement(z: z, psiDegrees: psi, side: .left, s)
            #expect(abs(d.y - previous.y) < 0.01 && abs(d.z - previous.z) < 0.01 && abs(d.x - previous.x) < 0.01)
            previous = d
        }
    }

    /// The abdominal wall is fixed at the pelvis.
    @Test func abdomenFixedAtPelvis() {
        let d = model.surfaceDisplacement(z: 0, psiDegrees: 0, side: .left, breath())
        #expect(abs(d.x) < 1e-12 && abs(d.y) < 1e-12 && abs(d.z) < 1e-12)
    }
}

/// Independent volume check (the working log (private), "volume check"): a closed triangulated surface.
@Suite struct AnatomyMeshVolume {
    let model = AnatomyModel()

    /// At rest, the mesh and the section integral agree.
    @Test func restVolumesAgree() {
        let slices = 2 * model.sliceVolume(AnatomyState(), from: 0, to: model.top, side: 0)
        #expect(abs(model.meshVolume(AnatomyState()) - slices) / slices < 0.002)
    }

    /// Purely horizontal motions (dilations, the abdominal bulge) give the same volume both ways.
    @Test func horizontalMotionAgrees() {
        var s = AnatomyState()
        s.upperDilation = [0.01, 0.01]
        s.lowerDilation = [0.01, 0.01]
        s.lowerDilationAP = 0.01
        s.abdomenFront = 0.5
        s.abdomenFlank = [0.05, 0.05]
        let slices = model.observe(s).totalSurface
        let mesh = model.meshVolume(s) - model.meshVolume(AnatomyState())
        #expect(abs(mesh - slices) / slices < 0.005)
    }

    /// Vertical motion (rib rotation lifts the wall) adds volume the fixed-height sections miss:
    /// a known limitation of the slice observables, recorded here so a fix shows up.
    @Test func ribRotationVolumeIsUndercountedBySlices() {
        var s = AnatomyState()
        s.upperRib = [0.1, 0.1]
        let slices = 2 * (model.sliceVolume(s, from: 0, to: model.top, side: 0) - model.sliceVolume(AnatomyState(), from: 0, to: model.top, side: 0))
        let pinned = model.meshVolume(s, pinTopLift: true) - model.meshVolume(AnatomyState())
        #expect(pinned > slices * 1.1)
    }
}

/// Spine extension: the back can move (the working log (private), "back-body").
@Suite struct AnatomySpineExtension {
    let model = AnatomyModel()

    /// Extension tilts the trunk rigidly: the upper back moves backward, the front rises, and
    /// fixed-height sections see no volume change (they only translate).
    @Test func upperBackMovesBackFrontRises() {
        var s = AnatomyState()
        s.spineExtension = 0.5 * .pi / 180
        let back = model.surfaceDisplacement(z: 35, psiDegrees: 180, side: .left, s)
        let front = model.surfaceDisplacement(z: 35, psiDegrees: 0, side: .left, s)
        #expect(back.y < 0)
        #expect(front.z > 0)
        // Fixed-height slices can't see it (sections only translate); the surface volumes can.
        let slices = 2 * (model.sliceVolume(s, from: 0, to: model.top, side: 0) - model.sliceVolume(AnatomyState(), from: 0, to: model.top, side: 0))
        #expect(abs(slices) < 1e-9)
        #expect(model.observe(s).totalSurface > 0.02)
    }

    /// The lumbar spine and pelvis stay put below the pivot zone.
    @Test func belowPivotIsFixed() {
        var s = AnatomyState()
        s.spineExtension = 0.01
        let d = model.surfaceDisplacement(z: 5, psiDegrees: 180, side: .left, s)
        #expect(abs(d.y) < 1e-12 && abs(d.z) < 1e-12)
    }

    /// The surface (mesh) volume sees the wedge that opens at the front of the pivot.
    @Test func extensionAddsSurfaceVolume() {
        var s = AnatomyState()
        s.spineExtension = 0.5 * .pi / 180
        let mesh = model.meshVolume(s, pinTopLift: true) - model.meshVolume(AnatomyState())
        #expect(mesh > 0.02)
    }
}

/// Back-body (the working log (private), "back-body"): what the marker-fitted breath does behind.
@Suite struct AnatomyBackBody {
    let model = AnatomyModel()

    /// Seated, the posterolateral lower ribs move out and up: the model's "breathing into the back".
    @Test func posterolateralLowerRibsWidenAndRise() {
        let st = model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        let v = model.observe(st).markers["left posterolateral lower ribcage"]!
        #expect(v.x > 0.3 && v.z > 0.3)
    }

    /// De Groote et al. 1997: the back surface moves forward, not backward. Since pump rotation
    /// carries the rib's sag (2026-11-09) the model's back surface moves forward ~0.14 mm (was
    /// 0.02): a fraction of what the posterolateral ribs do, but no longer negligible.
    @Test func backSurfaceMovesForwardSlightly() {
        let st = model.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        let o = model.observe(st)
        let lower = o.markers["posterior lower ribcage"]!
        #expect(lower.y > 0.05 && lower.y < 0.3)
        #expect(lower.y < 0.3 * o.markers["left posterolateral lower ribcage"]!.y)
    }

    /// Jordanoglou 1969: every point along a rib moves parallel. With pump carrying the rib's sag,
    /// a lower rib's side moves forward about as much (per unit motion) as its front.
    @Test func lowerRibMovesNearlyParallel() {
        let a = AnatomyModel.supine()
        let st = a.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52).state
        func unitForward(_ psi: Double) -> Double {
            let d = a.surfaceDisplacement(z: 22, psiDegrees: psi, side: .left, st)
            return d.y / (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
        }
        #expect(abs(unitForward(90) - unitForward(15)) < 0.1)
    }
}

/// The diaphragm descends more at the back (Krayer 1989; Kolář 2009; the working log (private),
/// "posterior diaphragm").
@Suite struct AnatomyDiaphragmTilt {
    /// The tilt moves volume backward without changing it: over an elliptical section
    /// (width ∝ √(1−u²)) the descent averages the piston descent, and the back half's share
    /// matches the closed form.
    @Test func tiltPreservesVolume() {
        let m = AnatomyModel.supine()
        var total = 0.0, back = 0.0, area = 0.0
        let n = 4000
        for i in 0..<n {
            let u = -1 + (Double(i) + 0.5) * 2 / Double(n)
            let w = (1 - u * u).squareRoot()
            let dv = m.diaphragmDescent(1.0, at: u) * w
            total += dv; area += w
            if u > 0 { back += dv }
        }
        #expect(abs(total / area - 1) < 1e-6)
        #expect(abs(back / total - m.diaphragmBackShare) < 1e-4)
    }

    /// Back > front in both postures; more so supine (Takazakura 2004). Supine back edge vs
    /// middle ≈ Kolář's 1.43.
    @Test func backMovesMoreSupineMost() {
        let seated = AnatomyModel(), supine = AnatomyModel.supine()
        #expect(seated.diaphragmTilt > 0 && supine.diaphragmTilt > seated.diaphragmTilt)
        #expect(abs(supine.diaphragmDescent(1, at: 1) - 1.43) < 0.01)
        #expect(supine.diaphragmBackShare > 0.55 && seated.diaphragmBackShare > 0.5)
    }

    /// The tilt changes no regional volume (A1's observables, hence A2's coordinates).
    @Test func tiltLeavesVolumesAlone() {
        var a = AnatomyModel(), b = AnatomyModel()
        a.diaphragmTilt = 0; b.diaphragmTilt = 0.43
        let s = a.fitToMarkers(TakashimaMarkers.sitting, tidal: 0.56).state
        #expect(abs(a.observe(s).totalLung - b.observe(s).totalLung) < 1e-12)
        #expect(abs(a.observe(s).totalSurface - b.observe(s).totalSurface) < 1e-12)
    }
}
