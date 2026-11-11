import Foundation

// Configuration in, body out (docs/LESSON_ADAPTATION.md §4, stage 2: no new physics).
//
// A position is described, not named: gravity's direction in the body's frame and a list of contact
// patches. One generator turns it into a body (the sided model, so later asymmetric positions need no
// special case). In this stage the generator recognises the three postures the model has data for
// (upright, lying on the back, lying on either side) and builds them exactly as before, with their
// per-posture fitted factors; anything else is refused until stage 3's general rules (a hydrostatic
// abdomen, stiffness by distance from neutral, contacts as patches) can derive it.
//
// Acceptance test (stage 2): the three postures, as configurations, reproduce their earlier numbers
// (`ConfigurationTests`, against `handFitted`). Since stage 3, `body` uses the general rules.

/// Where a support touches the trunk.
public struct ContactPatch: Sendable, Equatable {
    public enum Region: Sendable, Equatable {
        /// The back of the trunk (lying on the back).
        case back
        /// One flank (lying on that side).
        case flank(Side)
        /// The front of the chest and belly (lying face down).
        case front
        /// Only the front of the chest (face down, belly free: a towel under the chest).
        case chest
        /// Only the front of the belly.
        case belly
        /// The back below the ribcage (the lumbar spine on the floor: knees bent).
        case lowBack
        /// Face down, the front and its sides to ψ (degrees): the belly's front-sides on the floor too.
        case frontTo(Double)
    }
    public var region: Region
    /// What it rests on: "floor", "bed", "chair back".
    public var support: String

    public init(_ region: Region, on support: String = "floor") { self.region = region; self.support = support }

    public var label: String {
        switch region {
        case .back: "back on the \(support)"
        case .flank(let s): "\(s == .left ? "left" : "right") flank on the \(support)"
        case .front: "front on the \(support)"
        case .chest: "chest on the \(support)"
        case .belly: "belly on the \(support)"
        case .lowBack: "lower back on the \(support)"
        case .frontTo(let p): "front to \(Int(p))° on the \(support)"
        }
    }
}

/// A position: gravity in the body's frame (x toward the left, y forward, z toward the head; a unit
/// vector pointing the way gravity pulls) and the contacts.
public struct BodyConfiguration: Sendable {
    public var name: String
    public var gravity: (x: Double, y: Double, z: Double)
    public var contacts: [ContactPatch]
    /// The spine's shape (stage 4, Bending.swift); neutral by default.
    public var spine: SpineShape
    /// Tone on named regions (stage 5, Lesson.swift); none by default.
    public var tone: [RegionTone] = []
    /// Stiffness carried from earlier in a lesson, per sided coordinate (stage 6, SlowState); empty = none.
    public var carried: [Double] = []
    /// The legs (docs/LESSON_ADAPTATION.md §4.6); nil: as the data's subjects (legs long, presumably).
    public var legs: Legs? = nil

    public init(name: String, gravity: (x: Double, y: Double, z: Double), contacts: [ContactPatch] = [], spine: SpineShape = .neutral) {
        let n = (gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z).squareRoot()
        self.name = name
        self.gravity = n > 0 ? (gravity.x / n, gravity.y / n, gravity.z / n) : (0, 0, -1)
        self.contacts = contacts
        self.spine = spine
    }

    /// The same configuration with the spine shaped.
    public func with(_ spine: SpineShape, name: String? = nil) -> BodyConfiguration {
        var c = self; c.spine = spine; if let name { c.name = name }; return c
    }

    /// Lying on the back with the legs placed (`Legs.apply`).
    public func with(_ legs: Legs) -> BodyConfiguration { legs.apply(to: self) }

    /// Sitting upright (gravity toward the feet). Takashima's seated subjects; a backrest bears no load.
    public static let seated = BodyConfiguration(name: "seated", gravity: (0, 0, -1))
    /// Standing: sitting's gravity, with the hips straight. Derived, nothing fitted: the seated data's
    /// subjects sat with the hips at ~90°; `Legs`' rule (lumbar flexion 0.15° per degree of hip
    /// flexion, checked against supine MRI) then gives standing a lumbar curve 13.5° more extended
    /// than sitting (Claus et al. 2015: relaxed sitting flexes the lumbar spine ~24° from standing).
    /// The membrane rule then lengthens and stiffens the belly wall. Not included (unsized): the
    /// tonic oblique activity of standing (Druz & Sharp 1981). Checks: the ribcage share at least the
    /// seated one (Verschakelen 1995, Gómez-Recio 2024); end-expiratory volume about the same
    /// (Attali 2024).
    public static let standing: BodyConfiguration = {
        var c = BodyConfiguration(name: "standing", gravity: (0, 0, -1))
        c.spine.lumbarFlexion = -Legs.lumbarFlexionPerHipDegree * 90
        return c
    }()
    /// Lying on the back on the floor (gravity toward the back).
    public static let supine = BodyConfiguration(name: "supine", gravity: (0, -1, 0), contacts: [ContactPatch(.back)])
    /// Lying on the right side on the floor (gravity toward the right, −x).
    public static let rightSideDown = BodyConfiguration(name: "right side down", gravity: (-1, 0, 0),
                                                        contacts: [ContactPatch(.flank(.right))])
    public static let leftSideDown = BodyConfiguration(name: "left side down", gravity: (1, 0, 0),
                                                       contacts: [ContactPatch(.flank(.left))])
    /// Reclined at 45° on a backrest (Fowler's, Mendes's and Sonpeayung's 45°).
    public static let reclined45 = BodyConfiguration(name: "reclined 45°", gravity: (0, -0.5.squareRoot(), -0.5.squareRoot()),
                                                     contacts: [ContactPatch(.back, on: "backrest")])
    /// Lying face down on the floor.
    public static let prone = BodyConfiguration(name: "face down", gravity: (0, 1, 0), contacts: [ContactPatch(.front)])

    /// The postures the model has data for, recognised from gravity (within about 18° of the axis).
    public enum Posture: Equatable, Sendable { case upright, supine, side(Side) }
    public var posture: Posture? {
        let g = gravity, near = cos(18 * Double.pi / 180)
        if -g.z >= near { return .upright }
        if -g.y >= near { return .supine }
        if -g.x >= near { return .side(.right) }
        if g.x >= near { return .side(.left) }
        return nil
    }
}

public enum ConfigurationError: Error, CustomStringConvertible {
    case unsupported(String)
    public var description: String {
        switch self { case .unsupported(let s): "unsupported configuration: \(s)" }
    }
}

/// A generated body, with what it rests on.
public struct GeneratedBody: Sendable {
    public var configuration: BodyConfiguration
    public var body: SidedBody
    /// The breath size it is matched to (the posture's measured tidal volume), litres.
    public var tidalVolume: Double
    /// One line per ingredient: what it is and whether it is sourced, fitted or assumed.
    public var provenance: [String]
}

public enum BodyGenerator {
    /// The seated symmetric body: three fixed-sign muscle groups fitted to Takashima's seated markers,
    /// the fitted lower band and costal arch, recruitment timing, matched to 0.56 L.
    /// `volumes`: also fit OEP compartment shares (Mendes's men seated), the work plan (private), item 2.
    public static func seatedSymmetric(drive: Drive = Drive(), anatomy: AnatomyModel = AnatomyModel(),
                                       volumes: VolumeShareTarget? = nil) -> A2Body {
        A2Body.fitMuscleGroups(anatomy: anatomy, markers: TakashimaMarkers.sitting, tidal: 0.56,
                               passive: A2MuscleGroup.defaultPassive, lowerBandStiffness: A2MuscleGroup.lowerBandStiffness,
                               volumes: volumes).body
            .timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
    }

    /// The supine symmetric body from a seated one: supine geometry (Takashima), gravity's operating
    /// point (FRC 0.22 L below seated), and the two posture effects fitted to the healthy supine breath
    /// (abdominal share from Takashima's supine markers, 0.52 L).
    public static func supineSymmetric(from seated: A2Body, hypothesis: A2Body.PostureHypothesis = .ribcageStiffness,
                                       drive: Drive = Drive(), tiltedApposition: Bool = true, midbreathApposition: Bool = false)
        -> (body: A2Body, abScale: Double, secondScale: Double, implied: (upper: Double, lower: Double, abdomen: Double)) {
        var supine0 = AnatomyModel.supine()
        supine0.tiltedApposition = tiltedApposition
        let supineRef = supine0.fitToMarkers(TakashimaMarkers.supine, tidal: 0.52).state
        if midbreathApposition { supine0.appositionDescent = 0.5 * supineRef.diaphragm[0] }
        let o = supine0.observe(supineRef)
        let v = (upper: o.upperRibcage.reduce(0, +), lower: o.lowerRibcage.reduce(0, +), abdomen: o.abdomen.reduce(0, +))
        let t = v.upper + v.lower + v.abdomen
        let op = OperatingPoint(frcDrop: 0.22)
        let fit = A2Body.fitPosture(anatomy: op.apply(to: supine0), from: seated, abdomenShare: v.abdomen / t, tidal: 0.52,
                                    hypothesis: hypothesis, diaphragmForceScale: op.diaphragmForceScale, drive: drive)
        return (fit.body, fit.abdomenComplianceScale, fit.secondScale, (v.upper / t, v.lower / t, v.abdomen / t))
    }

    /// The default generator (since 2026-11-10): the general rules of stage 3 (Settle.swift), one
    /// parameter set for any gravity direction and contacts. The quiet tidal volume is held, so the
    /// drive a configuration needs is part of the output (provenance).
    public static func body(_ c: BodyConfiguration, drive: Drive = Drive(), rules: GravityRules = GravityRules()) -> GeneratedBody {
        let r = general(c, rules: rules, drive: drive)
        var lines = ["muscles: three fixed-sign groups fitted to Takashima's seated markers (FITTED); lower band ×"
                     + "\(A2MuscleGroup.lowerBandStiffness), costal arch ×\(A2MuscleGroup.costalArch) (FITTED)",
                     "geometry: Takashima 2017's seated, supine and side-lying sections blended by gravity (SOURCED sections, ASSUMED blend)",
                     "gravity: liquid abdomen \(rules.abdominalGradient) cmH2O/cm, pleural \(rules.pleuralGradient) (SOURCED); settle → dome rise left/right "
                     + "\(String(format: "%.0f/%.0f", r.domeRise[0] * 1000, r.domeRise[1] * 1000)) mL, diaphragm force ×"
                     + "\(String(format: "%.3f/%.3f", r.diaphragmForceScale[0], r.diaphragmForceScale[1])) (length–tension, Smith & Bellemare)",
                     "resting volume \(String(format: "%+.2f", r.frcChange)) L vs seated (saturating at the seated expiratory reserve, \(rules.expiratoryReserve.map { String(format: "%.2f", $0) } ?? "off") L)",
                     "abdominal wall compliance ×\(String(format: "%.2f", r.abdomenComplianceScale)) (axial column law, gain \(rules.abdominalWallGain): FITTED)"]
        lines.append(c.contacts.isEmpty ? "contacts: none" : "contacts: " + c.contacts.map(\.label).joined(separator: ", ")
                     + " (one tissue stiffness \(rules.contactStiffness) cmH2O/cm × load share, per region and side: FITTED)")
        lines.append(rules.quietTidal.map { String(format: "breath held at %.2f L (regulated); drive needed ×%.2f of seated (PREDICTED)", $0, r.driveScale) }
                     ?? String(format: "seated drive; tidal %.3f L (PREDICTED)", r.tidalAtSeatedDrive))
        return GeneratedBody(configuration: c, body: r.body, tidalVolume: rules.quietTidal ?? r.tidalAtSeatedDrive, provenance: lines)
    }

    /// Stage 2's generator, kept for comparison: the three postures with data, each built with its
    /// own fitted factors (the hand-fitted bodies). Throws for other gravity directions.
    public static func handFitted(_ c: BodyConfiguration, drive: Drive = Drive()) throws -> GeneratedBody {
        guard let posture = c.posture else {
            throw ConfigurationError.unsupported(
                "gravity (\(c.gravity.x), \(c.gravity.y), \(c.gravity.z)) is none of upright, supine or side-lying; "
                + "other directions need stage 3 (a hydrostatic abdomen)")
        }
        let seated = seatedSymmetric(drive: drive)
        let sym = SidedBody.calibrate(anatomy: AnatomyModel(), reference: SidedCoordinate.fromSymmetric(seated.reference),
                                      passive: seated.passive)
        var lines = ["muscles: three fixed-sign groups fitted to Takashima's seated markers (FITTED); lower band ×"
                     + "\(A2MuscleGroup.lowerBandStiffness), costal arch ×\(A2MuscleGroup.costalArch) (FITTED)"]
        switch posture {
        case .upright:
            if !c.contacts.isEmpty { lines.append("contacts: ignored upright (a backrest bears no load; Sonpeayung 2019)") }
            lines.append("posture: seated geometry and breath (Takashima 2017, SOURCED)")
            return GeneratedBody(configuration: c, body: sym.matchedToTidal(0.56, drive: drive), tidalVolume: 0.56, provenance: lines)
        case .supine:
            let sup = supineSymmetric(from: seated, drive: drive)
            let op = OperatingPoint(frcDrop: 0.22)
            // The supine ribcage restraint (hypothesis A) is attributed to the back resting on its support.
            let back = c.contacts.contains { $0.region == .back }
            let body = SidedBody.from(seated: sym, anatomy: op.apply(to: AnatomyModel.supine()),
                                      abdomenComplianceScale: sup.abScale, ribcageStiffnessScale: back ? sup.secondScale : 1,
                                      diaphragmForceScale: [op.diaphragmForceScale, op.diaphragmForceScale])
            lines += ["posture: supine geometry (Takashima 2017, SOURCED); FRC 0.22 L below seated (Sonpeayung 2019, SOURCED)",
                      "abdominal wall ×\(String(format: "%.2f", sup.abScale)) (FITTED to the supine share)",
                      back ? "back contact: ribcage restraint ×\(String(format: "%.2f", sup.secondScale)) (FITTED, hypothesis A)"
                           : "no back contact: no ribcage restraint (the fitted restraint is the support's)"]
            return GeneratedBody(configuration: c, body: body.matchedToTidal(0.52, drive: drive), tidalVolume: 0.52, provenance: lines)
        case .side(let down):
            let op = down == .right ? SidedOperatingPoint.rightSideDown
                                    : SidedOperatingPoint(frcDrop: 0.22, dependent: .left, dependentShare: SidedOperatingPoint.rightSideDown.dependentShare)
            let a = op.apply(to: AnatomyModel.rightSideDown())  // a symmetric section: serves either side
            let wall = SidedBody.rightSideDownWall
            let flank = c.contacts.contains { $0.region == .flank(down) }
            let body = SidedBody.from(seated: sym, anatomy: a, abdomenComplianceScale: wall.abdomenComplianceScale,
                                      ribcageStiffnessScale: wall.ribcageStiffnessScale,
                                      diaphragmForceScale: Side.allCases.map { op.forceScale($0) },
                                      dependent: down, bedGain: flank ? wall.bedGain : 0)
            lines += ["posture: side-lying geometry (Takashima 2017 right lateral, SOURCED; mirrored for the left)",
                      "hemidiaphragm force asymmetry fitted to the floor-side lung's share (Amano 2024, Grant 2011: FITTED)",
                      "wall factors fitted to Takashima's side-lying markers (FITTED)",
                      flank ? "flank contact on the \(down == .right ? "right" : "left"): bed spring (FITTED; Nozoe 2014's direction)"
                            : "no flank contact: no bed spring"]
            return GeneratedBody(configuration: c, body: body.matchedToTidal(0.51, drive: drive), tidalVolume: 0.51, provenance: lines)
        }
    }
}


/// Leg position, lying on the back (docs/LESSON_ADAPTATION.md §4.6): hip flexion per side and whether the
/// feet stand. Not simulated; it sets the trunk's inputs. Every size here is ASSUMED (no measurement
/// compares the positions; self-measurement contrast H):
///   - the pelvis rolls back: lumbar flexion = 0.15 × mean hip flexion, capped at 15° (feet standing,
///     hips ~60° → 9°). Checked 2026-11-11 (literature pass 13): supine MRI with the legs flexed
///     over a cushion has ~5.7° less lordosis than with them straight (100 patients; other studies
///     3–6°); the rule gives 4.5–6° at a cushion's 30–40° of hip flexion. Not contradicted; the slope
///     beyond a cushion is unsourced. Unequal hips also tilt the pelvis: lumbar side-bend toward the more flexed
///     side, 0.1 × the difference, capped at 6°;
///   - the lumbar curve reaches the floor (a contact under the lower back) once the lumbar flexion is
///     5° or more and the feet bear weight (with the feet off the floor the pelvis is held by the
///     hips, not pressed down);
///   - the low belly wall slackens: the bulge's peak moves from 0.5 toward 0.35 at 15°.
/// The membrane rule (Bending.swift) then softens the shortened front wall.
public struct Legs: Sendable, Equatable {
    /// Hip flexion, degrees (left, right): 0 = legs long, ~60 = feet standing, ~110 = knee to chest.
    public var hipFlexion: [Double]
    public var feetStanding: Bool
    public init(left: Double, right: Double, feetStanding: Bool = true) { hipFlexion = [left, right]; self.feetStanding = feetStanding }
    public static let long = Legs(left: 0, right: 0, feetStanding: false)
    public static let kneesBent = Legs(left: 60, right: 60)

    /// Lumbar flexion per degree of hip flexion (the pelvis rolling back), degrees. ASSUMED slope,
    /// checked at a cushion's hip angle against supine MRI (3–6°).
    public static let lumbarFlexionPerHipDegree = 0.15
    public var lumbarFlexion: Double { min(15, Self.lumbarFlexionPerHipDegree * 0.5 * (hipFlexion[0] + hipFlexion[1])) }
    /// + toward the left (the left side short) when the left hip is more flexed.
    public var lumbarSideBend: Double { max(-6, min(6, 0.1 * (hipFlexion[0] - hipFlexion[1]))) }
    public var bulgePeak: Double { 0.5 - 0.15 * lumbarFlexion / 15 }
    public var lowBackOnFloor: Bool { feetStanding && lumbarFlexion >= 5 }

    public func apply(to c: BodyConfiguration) -> BodyConfiguration {
        var out = c
        out.legs = self
        out.spine.lumbarFlexion += lumbarFlexion
        out.spine.lumbarSideBend += lumbarSideBend
        if lowBackOnFloor { out.contacts.append(ContactPatch(.lowBack, on: c.contacts.first?.support ?? "floor")) }
        return out
    }
}
