import Foundation
import Testing
@testable import BreathStar

@Suite struct Engine {
    @Test func compartmentsSumToLungVolume() {
        let sim = Simulation(body: BodyParameters(), posture: .seated)
        for s in sim.run(cycles: 2) {
            #expect(abs(s.ribcageVolume + s.abdomenVolume - s.lungVolume) < 1e-12)
        }
    }

    /// Per side, the thorax closes on its own lung; the abdomen's contents don't compress.
    @Test func perSideClosures() {
        let fit = Calibration.fit(.men)
        var body = fit.body
        body.dependentDiaphragmGain = 0.5
        for s in Simulation(body: body, drive: fit.drive, posture: .rightSideLying).run(cycles: 2) {
            for side in [s.left, s.right] {
                #expect(abs(side.upperRibcageVolume + side.lowerRibcageVolume + side.diaphragmDescent - side.lungVolume) < 1e-12)
            }
            #expect(abs(s.left.abdomenVolume + s.right.abdomenVolume - s.left.diaphragmDescent - s.right.diaphragmDescent) < 1e-12)
        }
    }

    @Test func deterministic() {
        let sim = Simulation(body: BodyParameters(), posture: .incline45)
        #expect(sim.run(cycles: 3) == sim.run(cycles: 3))
    }

    @Test func quietBreathingIsPlausible() {
        let d = Calibration.fit(.men).distribution(.supine)
        // Quiet tidal volume for an adult: a few hundred millilitres.
        #expect(d.tidalVolume > 0.25 && d.tidalVolume < 1.0)
    }

    /// Calibration uses short, coarse runs (2 cycles at 4 ms); they must agree with long, fine ones.
    @Test func calibrationRunsConverge() {
        let fit = Calibration.fit(.women)
        for posture in [Posture.seated, .supine, .rightSideLying] {
            let coarse = Calibration.measure(fit.body, fit.drive, posture)
            let fine = Metrics.distribution(
                Simulation(body: fit.body, drive: fit.drive, posture: posture, timeStep: 0.0005).run(cycles: 6),
                period: fit.drive.period)
            #expect(abs(coarse.abdomenShare - fine.abdomenShare) < 0.005)
            #expect(abs(coarse.tidalVolume - fine.tidalVolume) / fine.tidalVolume < 0.01)
        }
    }

    /// Mechanics, not data: with the ribcage muscles silent the diaphragm
    /// alone sucks the upper ribcage in, the classic paradox when only the
    /// diaphragm works. The model should show a ribcage that moves against
    /// the abdomen.
    @Test func diaphragmAloneGivesRibcageParadox() {
        let fit = Calibration.fit(.men)
        var drive = fit.drive
        drive.ribcageMusclePeak = 0
        var body = fit.body
        body.appositionFraction = 0
        let samples = Simulation(body: body, drive: drive, posture: .supine).run(cycles: 4)
        let peakInspiration = samples.suffix(Int(drive.period / 0.002)).max { $0.lungVolume < $1.lungVolume }!
        #expect(peakInspiration.ribcageVolume < 0)
        #expect(peakInspiration.abdomenVolume > peakInspiration.lungVolume)
    }
}

@Suite struct AgainstData {
    @Test(arguments: Reference.datasets.map(\.id))
    func calibratedPosturesMatch(_ id: String) {
        let data = Reference.datasets.first { $0.id == id }!
        let fit = Calibration.fit(data)
        for name in ["seated", "supine"] {
            let ref = data.point(name)
            let d = fit.distribution(Posture.named(name)!)
            #expect(abs(d.abdomenShare * 100 - ref.abdomenShare) < 0.2)
            #expect(abs(d.tidalVolume - ref.tidalVolume) < 0.01)
        }
    }

    /// 45° is not fitted (a development check: it has guided the angle law). Gated where the source gives SDs.
    @Test(arguments: Reference.Sex.allCases)
    func predicts45DegreesWithinSD(_ sex: Reference.Sex) {
        let ref = Reference.mendes2020(sex).incline45
        let d = Calibration.fit(sex).distribution(.incline45)
        let share = d.abdomenShare * 100
        #expect(abs(share - ref.abdomenShare) <= ref.abdomenSD!, "share \(share)% vs \(ref.abdomenShare) ± \(ref.abdomenSD!)")
        #expect(abs(d.tidalVolume - ref.tidalVolume) <= ref.tidalSD!,
                "tidal \(d.tidalVolume) L vs \(ref.tidalVolume) ± \(ref.tidalSD!)")
    }

    /// The upper/lower ribcage split is fitted only seated; supine and 45° predict it.
    @Test(arguments: Reference.Sex.allCases)
    func predictsRibcageSplitWithinSD(_ sex: Reference.Sex) {
        let data = Reference.mendes2020(sex)
        let fit = Calibration.fit(sex)
        for (name, posture) in [("incline45", Posture.incline45), ("supine", .supine)] {
            let ref = data.point(name)
            let d = fit.distribution(posture)
            #expect(abs(d.upperRibcageShare * 100 - ref.upperRibcageShare!) <= ref.upperRibcageSD!, "\(name) upper")
            #expect(abs(d.lowerRibcageShare * 100 - ref.lowerRibcageShare!) <= ref.lowerRibcageSD!, "\(name) lower")
        }
    }

    @Test(arguments: Reference.datasets.map(\.id))
    func abdomenShareRisesAsTrunkTilts(_ id: String) {
        let fit = Calibration.fit(Reference.datasets.first { $0.id == id }!)
        let shares = stride(from: 0.0, through: 90, by: 15).map {
            fit.distribution(Posture(tiltFromVertical: $0)).abdomenShare
        }
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 < $1 })
    }

    /// What both sources agree on: people breathe more seated than reclined or flat.
    /// Whether 45° is above supine they disagree on (Mendes: yes; Sonpeayung: 45° is
    /// lowest), so that ordering is not tested. M1 women sit on Sonpeayung's side by
    /// 4 mL (the working log (private), M1).
    @Test(arguments: Reference.datasets.map(\.id))
    func seatedBreathesMoreThanReclined(_ id: String) {
        let fit = Calibration.fit(Reference.datasets.first { $0.id == id }!)
        let seated = fit.distribution(.seated).tidalVolume
        #expect(seated > fit.distribution(.incline45).tidalVolume)
        #expect(seated > fit.distribution(.supine).tidalVolume)
    }

    /// Sonpeayung 2019: a back support with the trunk upright barely changes
    /// anything. In the model, upright puts no load on a support, so contact
    /// stiffening cannot matter at 0°.
    @Test func backSupportUprightChangesNothing() {
        var body = Calibration.fit(.men).body
        let drive = Calibration.fit(.men).drive
        let with = Metrics.distribution(body: body, drive: drive, posture: .seated)
        body.contactStiffening = 0
        let without = Metrics.distribution(body: body, drive: drive, posture: .seated)
        #expect(abs(with.abdomenShare - without.abdomenShare) < 1e-9)
        #expect(abs(with.tidalVolume - without.tidalVolume) < 1e-9)
    }

    /// Reference.swift must stay a faithful copy of reference/compartments.json.
    @Test func referenceMatchesJSON() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("reference/compartments.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let groups = (json["mendes2020"] as! [String: Any])["groups"] as! [String: Any]
        for sex in Reference.Sex.allCases {
            let g = groups[sex.rawValue] as! [String: Any]
            for (name, _) in Reference.mendesPostures {
                let row = g[name] as! [String: Any]
                let ref = Reference.mendes2020(sex, name)!
                func pair(_ key: String) -> [Double] { row[key] as! [Double] }
                #expect(pair("rcp") == [ref.upperRibcage.mean, ref.upperRibcage.sd])
                #expect(pair("rca") == [ref.lowerRibcage.mean, ref.lowerRibcage.sd])
                #expect(pair("ab") == [ref.abdomen.mean, ref.abdomen.sd])
                #expect(pair("vcw_l") == [ref.tidalVolume.mean, ref.tidalVolume.sd])
            }
        }
        let son = (json["sonpeayung2019"] as! [String: Any])["control_men"] as! [String: Any]
        for (key, point) in [("sit_no_support", Reference.sonpeayung2019.seated),
                             ("fowler45", Reference.sonpeayung2019.incline45),
                             ("supine", Reference.sonpeayung2019.supine)] {
            let row = son[key] as! [String: Any]
            #expect(row["ab_pct"] as! Double == point.abdomenShare)
            #expect(abs((row["rc_l"] as! Double) + (row["ab_l"] as! Double) - point.tidalVolume) < 1e-12)
        }
    }
}

/// Side-lying: three sourced directions (gated) and the mechanics behind the lung split.
@Suite struct SideLying {
    let fit = Calibration.fit(.men)
    let down = Side.right.rawValue, up = Side.left.rawValue

    @Test func supineIsSymmetric() {  // Nozoe 2014
        let d = fit.distribution(.supine)
        #expect(abs(d.surfaceExcursion[0] - d.surfaceExcursion[1]) < 1e-9)
        #expect(abs(d.lungExcursion[0] - d.lungExcursion[1]) < 1e-9)
    }

    @Test func downSideSurfaceMovesLess() {  // Nozoe 2014 (abstract)
        let d = fit.distribution(.rightSideLying)
        #expect(d.surfaceExcursion[down] < d.surfaceExcursion[up])
    }

    /// Indirect: Takashima 2017 (Table 3) measured sideways marker displacement in mm;
    /// this compares regional volume. Direction only.
    @Test func upSideLowerRibcageMovesMoreThanSupine() {
        let side = fit.distribution(.rightSideLying)
        let supine = fit.distribution(.supine)
        #expect(side.lowerRibcageExcursionBySide[up] > supine.lowerRibcageExcursionBySide[up])
    }

    @Test func leftMirrorsRight() {
        let r = fit.distribution(.rightSideLying)
        let l = fit.distribution(.leftSideLying)
        #expect(abs(r.surfaceExcursion[0] - l.surfaceExcursion[1]) < 1e-9)
        #expect(abs(r.surfaceExcursion[1] - l.surfaceExcursion[0]) < 1e-9)
    }

    /// Mechanics: with equal hemidiaphragms the two pleural pressures are equal,
    /// so the lungs ventilate equally however unevenly the walls move. This is an
    /// invariant of the equations (a constraint of the lumped form), not physiology.
    @Test func lungSplitDependsOnlyOnDiaphragms() {
        let even = fit.distribution(.rightSideLying)
        #expect(abs(even.lungExcursion[down] - even.lungExcursion[up]) < 1e-9)
        var body = fit.body
        body.dependentDiaphragmGain = 0.25
        let stronger = Metrics.distribution(body: body, drive: fit.drive, posture: .rightSideLying)
        #expect(stronger.lungExcursion[down] > stronger.lungExcursion[up])
        #expect(stronger.surfaceExcursion[down] < stronger.surfaceExcursion[up])
    }
}

