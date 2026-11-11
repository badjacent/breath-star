import BreathStar
import Foundation

// Shared CLI helpers (usage, option parsing, formatting, the A2 bodies and cases). Commands live
// in Commands*.swift; main.swift only dispatches.

let usage = """
breathstar — Breath Star v1: a mechanical model of breathing in the trunk (docs/DESIGN.md)

Configurations and lessons (start here)
  stage3 [--fit] [--volumes] [--upper U] [--prone-variants] [--free-lift] [--upright-squared]
                         the postures with data, one parameter set: seated, 45°, supine, sides, face down
  stage3-frc             where each posture's end-expiratory volume change comes from
  configure NAME|x,y,z   one configuration's body and provenance (seated, reclined, supine, right, left, prone)
  stage4                 the spine's shape: side-bend, slump, extension, rotation
  stage4-fit | stage4-lungs | stage4-extension
                         the bend law's gain; a side-bend per side; what moves the lower ribs in an arch
  legs                   lying on the back with the knees bent or one foot standing
  prone                  face down: where the breath goes, contact and anchoring variants
  patients               three clinical patterns (one muscle group silenced), sitting against lying
  lesson [--file PATH]   a lesson step by step with verdicts (the built-in example by default)
  lesson-slow [--file PATH]
                         slow-state hypotheses across their sizes: the closing step against the opening one
  measure-predictions [--lesson PATH]
                         what a self-measurement should find (reference/SELF_MEASUREMENT_PLAN.md)
  viewer [--out PATH] [--lesson PATH]
                         the self-contained HTML viewer (default out/viewer.html)

The seated body and its fit
  muscles                fixed-sign muscle groups against free per-coordinate forces
  volume-fit [--arch L] [--wide]
                         the muscle-group fit with and without OEP compartment volumes
  compartments           shares with the model's flat margin and with OEP's arched one
  uncertainty            the results across plausible alternative bodies
  holds | kouyama | basis-test | arch-scan
                         holding a region; an anchor test (Kouyama 2016); stiffness bases; the costal arch
  side-lying             side-lying checks on the sided body

The anatomical layers (A1, A2)
  anatomy | anatomy-svg | extension | back | volume-check | abdomen-shape | lateral-drop | jordanoglou
                         A1 geometry: the fitted breath, drawings, spine extension, back markers,
                         volume definitions, the belly's shape, the lower ribs' drop, a sourced check
  a2 | a2-supine | timing | expiration | expiration-bounds | expiration-all
                         A2 mechanics: the seated and supine bodies, muscle timing, expiration

The first, lumped model (M1)
  check                  per dataset: fit seated and supine, predict 45°; side-lying checks (exit 1 on failure)
  params [--sex men|women]
                         the calibrated parameters (Mendes 2020)
  render [--sex men|women] [--posture NAME|<tilt°>] [--roll DEG] [--cycles N] [--rate BPM] [--dt S]
                         a CSV time series to stdout (Tools/plot.py draws it)
"""

struct Options {
    var sex: Reference.Sex = .men
    var posture: Posture = .supine
    var roll: Double?
    var cycles = 4
    var rate = 16.0
    var dt = 0.002
    var diaphragmGain: Double?
}

func parse(_ args: ArraySlice<String>) -> Options {
    var o = Options()
    var it = args.makeIterator()
    while let flag = it.next() {
        guard let value = it.next() else { fail("missing value for \(flag)") }
        switch flag {
        case "--sex": o.sex = Reference.Sex(rawValue: value) ?? { fail("unknown sex \(value)") }()
        case "--posture": o.posture = Posture.named(value) ?? { fail("unknown posture \(value)") }()
        case "--roll": o.roll = Double(value) ?? { fail("bad --roll") }()
        case "--cycles": o.cycles = Int(value) ?? { fail("bad --cycles") }()
        case "--rate": o.rate = Double(value) ?? { fail("bad --rate") }()
        case "--dt": o.dt = Double(value) ?? { fail("bad --dt") }()
        case "--diaphragm-gain": o.diaphragmGain = Double(value) ?? { fail("bad --diaphragm-gain") }()
        default: fail("unknown option \(flag)")
        }
    }
    if let roll = o.roll {
        guard abs(roll) <= 90 else { fail("--roll must be within ±90") }
        o.posture = Posture(tiltFromVertical: o.posture.tiltFromVertical, roll: roll)
    }
    return o
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("breathstar: \(message)\n\n\(usage)\n".utf8))
    exit(2)
}

func f(_ x: Double, _ digits: Int = 1) -> String { String(format: "%.\(digits)f", x) }
func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: n, withPad: " ", startingAt: 0) }
func pm(_ mean: Double?, _ sd: Double?, _ digits: Int) -> String {
    guard let mean else { return "—" }
    return sd.map { "\(f(mean, digits))±\(f($0, digits))" } ?? f(mean, digits)
}

/// A2 bodies: the reference (calibrated on A1's breath fitted to Takashima's sitting markers) and its what-ifs.
/// `volumes`: also fit compartment volumes (the stage-3 default base; the viewer passes it so its
/// seated case matches the postures built from the rules).
func a2Bodies(drive: Drive = Drive(), volumes: VolumeShareTarget? = nil) -> (reference: A2Body, cases: [(id: String, label: String, body: A2Body)]) {
    let args = CommandLine.arguments
    // The default is the library's (BodyGenerator.seatedSymmetric: fixed-sign muscle groups fitted to
    // Takashima's seated markers). The flags below are diagnostics on the old paths.
    guard args.contains("--free-forces") || args.contains("--midbreath-apposition") || args.contains("--flat-apposition") else {
        let body = BodyGenerator.seatedSymmetric(drive: drive, volumes: volumes)
        return (body, a2Cases(body))
    }
    var anatomy = AnatomyModel()
    let tidal = 0.56
    let ref = anatomy.fitToMarkers(TakashimaMarkers.sitting, tidal: tidal).state
    // `--midbreath-apposition`: take the zone of apposition at half the reference breath's descent.
    if args.contains("--midbreath-apposition") { anatomy.appositionDescent = 0.5 * ref.diaphragm[0] }
    if args.contains("--flat-apposition") { anatomy.tiltedApposition = false }
    // `--free-forces` restores the old calibration (one free force per coordinate, exact fit).
    let staticBody = args.contains("--free-forces")
        ? A2Body.calibrate(anatomy: anatomy, reference: anatomy.a2Coordinates(ref))
        : A2Body.fitMuscleGroups(anatomy: anatomy, markers: TakashimaMarkers.sitting, tidal: tidal,
                                 passive: A2MuscleGroup.defaultPassive, lowerBandStiffness: A2MuscleGroup.lowerBandStiffness).body
    let body = staticBody.timed(MuscleTiming(), drive: drive).matchedToTidal(tidal, drive: drive)
    return (body, a2Cases(body))
}

/// The what-ifs of one A2 body (seated or supine).
func a2Cases(_ body: A2Body) -> [(id: String, label: String, body: A2Body)] {
    [
        ("reference", "reference breath", body),
        ("diaphragm-only", "diaphragm only (rib muscles silent)", body.silenced([.ribs])),
        ("ribs-only", "rib muscles only (diaphragm silent)", body.silenced([.diaphragm])),
        ("belly-held", "belly held (abdominal wall 5× stiffer)", body.stiffened([.abdomen], by: 5)),
        ("hand-lower-ribs", "hand on lower ribs (lower band 5× stiffer)", body.stiffened(A2Coordinate.lowerBand, by: 5)),
        ("upper-chest-held", "upper chest held (upper band 5× stiffer)", body.stiffened([.upperRotation, .upperDilation], by: 5)),
        ("in-phase", "all muscle groups in phase (no stagger)", body.timed(.inPhase)),
        ("lower-ribs-late", "lower ribs late (stagger ×3, beyond healthy)",
         body.timed(MuscleTiming(upperBand: 0.15, lowerBand: 0.45))),
        ("belly-in-on-exhale", "belly drawn in on exhale (beyond healthy)",
         { var b = body; b.expiratoryAbdominalPressure = 1; return b }()),
        ("diaphragm-braking", "diaphragm braking 0.6 s (beyond healthy)",
         { var b = body; b.diaphragmRelaxation = 0.6; return b }()),
    ]
}

/// Supine A2: the seated body moved to supine geometry, with its two posture effects fitted to
/// Takashima's healthy supine breath (the abdominal share of A1 fitted to its supine markers, and 0.52 L).
func a2Supine(_ hypothesis: A2Body.PostureHypothesis, drive: Drive = Drive(), seated: A2Body? = nil)
    -> (body: A2Body, abScale: Double, secondScale: Double, implied: (upper: Double, lower: Double, abdomen: Double)) {
    // The library's (BodyGenerator.supineSymmetric); `--flat-apposition` and `--midbreath-apposition` as diagnostics.
    BodyGenerator.supineSymmetric(from: seated ?? a2Bodies(drive: drive).reference, hypothesis: hypothesis, drive: drive,
                                  tiltedApposition: !CommandLine.arguments.contains("--flat-apposition"),
                                  midbreathApposition: CommandLine.arguments.contains("--midbreath-apposition"))
}
