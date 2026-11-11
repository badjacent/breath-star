import Foundation

// A lesson as a data file (JSON), so lesson encodings can live outside this repository: a lesson
// drawn from a recording belongs with whoever may use that recording, not with the model. The
// model ships one example written for it (`Lessons.example`); `breathstar lesson --file PATH`
// and `breathstar viewer --lesson PATH` run any other.
//
// Format (every field but `id`, `label` and `posture` optional):
//
// {
//   "name": "…", "source": "…",
//   "before": "scan", "after": "final-rest",          // the steps a before/after compares
//   "steps": [{
//     "id": "…", "label": "…", "source": "…",
//     "posture": "seated" | "standing" | "supine" | "rightSideDown" | "leftSideDown" | "reclined45" | "prone",
//     "legs": {"left": 0, "right": 60, "feetStanding": true},          // hip flexion, degrees
//     "spine": {"flexion": 25, "sideBend": 0, "rotation": 0,           // split lumbar/thoracic
//               "lumbarFlexion": 0, "thoracicFlexion": 12, …},         // added to the legs' shape
//     "tone": [{"region": "frontAbdomen", "side": "left", "factor": 0.7}],
//              // regions: frontAbdomen, flanks, lowerRibs, upperRibs; held 5, light 1.5, softened 0.7
//     "provenance": {"position": "stated", "shape": "implied", "tone": "inferred"},
//     "relation": "…",
//     "claim": {"kind": "sideMore", "side": "left", "text": "…"}
//            | {"kind": "ribcageShare", "lowerThan": "id", "higherThan": "id", "text": "…"}
//            | {"kind": "bellyShare", "higherThan": "id", "text": "…"}
//            | {"kind": "notRepresented", "text": "…"},
//     "note": "…", "minutes": 3
//   }]
// }

/// A lesson: its steps, and which two steps a before/after compares.
public struct Lesson: Sendable {
    public var name: String
    public var source: String
    public var steps: [LessonStep]
    /// The opening and closing steps (e.g. a scan lying on the back, and the final rest).
    public var before: String, after: String

    public init(name: String, source: String = "", steps: [LessonStep], before: String, after: String) {
        self.name = name; self.source = source; self.steps = steps; self.before = before; self.after = after
    }

    public func step(_ id: String) -> LessonStep? { steps.first { $0.id == id } }
}

public enum LessonFileError: Error, CustomStringConvertible {
    case unknown(field: String, value: String, step: String)
    case missingStep(String)
    public var description: String {
        switch self {
        case .unknown(let f, let v, let s): "step \(s): unknown \(f) '\(v)'"
        case .missingStep(let id): "the before/after step '\(id)' is not in the lesson"
        }
    }
}

extension Lesson {
    struct File: Decodable {
        var name: String
        var source: String?
        var before: String?, after: String?
        var steps: [Step]
    }
    struct Step: Decodable {
        var id: String, label: String, posture: String
        var source: String?
        var legs: LegsSpec?
        var spine: SpineSpec?
        var tone: [ToneSpec]?
        var provenance: ProvenanceSpec?
        var relation: String?
        var claim: ClaimSpec?
        var note: String?
        var minutes: Double?
    }
    struct LegsSpec: Decodable { var left: Double, right: Double; var feetStanding: Bool? }
    struct SpineSpec: Decodable {
        var flexion: Double?, sideBend: Double?, rotation: Double?
        var lumbarFlexion: Double?, thoracicFlexion: Double?, lumbarSideBend: Double?, thoracicSideBend: Double?
        var lumbarRotation: Double?, thoracicRotation: Double?
    }
    struct ToneSpec: Decodable { var region: String; var side: String?; var factor: Double }
    struct ProvenanceSpec: Decodable { var position: String?, shape: String?, tone: String? }
    struct ClaimSpec: Decodable { var kind: String; var side: String?; var lowerThan: String?; var higherThan: String?; var text: String }

    /// Decode a lesson from JSON data.
    public static func decode(_ data: Data) throws -> Lesson {
        let f = try JSONDecoder().decode(File.self, from: data)
        let steps = try f.steps.map(step)
        let before = f.before ?? steps.first?.id ?? "", after = f.after ?? steps.last?.id ?? ""
        for id in [before, after] where !steps.contains(where: { $0.id == id }) { throw LessonFileError.missingStep(id) }
        return Lesson(name: f.name, source: f.source ?? "", steps: steps, before: before, after: after)
    }

    /// Load a lesson file.
    public static func load(path: String) throws -> Lesson {
        try decode(Data(contentsOf: URL(fileURLWithPath: path)))
    }

    static func side(_ s: String, _ step: String) throws -> Side {
        switch s { case "left": return .left; case "right": return .right
        default: throw LessonFileError.unknown(field: "side", value: s, step: step) }
    }

    static func step(_ s: Step) throws -> LessonStep {
        let postures: [String: BodyConfiguration] = [
            "seated": .seated, "standing": .standing, "supine": .supine, "rightSideDown": .rightSideDown, "leftSideDown": .leftSideDown,
            "reclined45": .reclined45, "prone": .prone,
        ]
        guard var c = postures[s.posture] else { throw LessonFileError.unknown(field: "posture", value: s.posture, step: s.id) }
        if let l = s.legs { c = c.with(Legs(left: l.left, right: l.right, feetStanding: l.feetStanding ?? true)) }
        if let sp = s.spine {
            let split = SpineShape(flexion: sp.flexion ?? 0, sideBend: sp.sideBend ?? 0, rotation: sp.rotation ?? 0)
            c.spine.lumbarFlexion += split.lumbarFlexion + (sp.lumbarFlexion ?? 0)
            c.spine.thoracicFlexion += split.thoracicFlexion + (sp.thoracicFlexion ?? 0)
            c.spine.lumbarSideBend += split.lumbarSideBend + (sp.lumbarSideBend ?? 0)
            c.spine.thoracicSideBend += split.thoracicSideBend + (sp.thoracicSideBend ?? 0)
            c.spine.lumbarRotation += split.lumbarRotation + (sp.lumbarRotation ?? 0)
            c.spine.thoracicRotation += split.thoracicRotation + (sp.thoracicRotation ?? 0)
        }
        let regions: [String: RegionTone.Region] = ["frontAbdomen": .frontAbdomen, "flanks": .flanks, "lowerRibs": .lowerRibs, "upperRibs": .upperRibs]
        c.tone = try (s.tone ?? []).map { t in
            guard let r = regions[t.region] else { throw LessonFileError.unknown(field: "tone region", value: t.region, step: s.id) }
            return RegionTone(r, side: try t.side.map { try side($0, s.id) }, t.factor)
        }
        func prov(_ v: String?, _ field: String) throws -> Provenance {
            guard let v else { return .inferred }
            guard let p = Provenance(rawValue: v) else { throw LessonFileError.unknown(field: field, value: v, step: s.id) }
            return p
        }
        let claim: LessonClaim
        if let k = s.claim {
            switch k.kind {
            case "sideMore": claim = .sideMore(try side(k.side ?? "", s.id), k.text)
            case "ribcageShare": claim = .ribcageShare(lowerThan: k.lowerThan, higherThan: k.higherThan, k.text)
            case "bellyShare": claim = .bellyShare(higherThan: k.higherThan ?? "", k.text)
            case "notRepresented": claim = .notRepresented(k.text)
            default: throw LessonFileError.unknown(field: "claim kind", value: k.kind, step: s.id)
            }
        } else { claim = .none }
        return LessonStep(s.id, source: s.source ?? "", label: s.label, c,
                          position: try prov(s.provenance?.position, "position"), shape: try prov(s.provenance?.shape, "shape"),
                          tone: try prov(s.provenance?.tone, "tone"), relation: s.relation ?? "", claim: claim,
                          note: s.note ?? "", minutes: s.minutes ?? 3)
    }
}

extension Lessons {
    /// An example lesson written for the model (not drawn from any recording): sitting, slumping and
    /// lifting with effort or lightly, then lying on the back, knees bent, one foot and then the
    /// other standing, and a final rest. Every angle, tone factor and duration is ASSUMED; the claims
    /// are the model's own predictions put as a teacher might, so the runner has something to check.
    public static let exampleJSON = #"""
    {
      "name": "Example: sitting, lying, one foot standing",
      "source": "written for breath-star as an example; not drawn from any recording",
      "before": "scan", "after": "final-rest",
      "steps": [
        {"id": "sit", "label": "sitting upright", "posture": "seated", "relation": "reference", "minutes": 2,
         "provenance": {"position": "stated", "shape": "stated", "tone": "inferred"}},
        {"id": "slump", "label": "letting the spine round forward", "posture": "seated", "spine": {"flexion": 25},
         "tone": [{"region": "frontAbdomen", "factor": 0.7}], "minutes": 2,
         "provenance": {"position": "stated", "shape": "stated", "tone": "inferred"}, "relation": "release",
         "claim": {"kind": "ribcageShare", "lowerThan": "sit", "text": "slumped, the front ribs are crowded and the ribcage takes less"}},
        {"id": "brace", "label": "sitting up by bracing the belly", "posture": "seated", "spine": {"flexion": -10},
         "tone": [{"region": "frontAbdomen", "factor": 5}, {"region": "lowerRibs", "factor": 1.5}], "minutes": 2,
         "provenance": {"position": "stated", "shape": "implied", "tone": "stated"}, "relation": "effort",
         "claim": {"kind": "ribcageShare", "higherThan": "sit", "text": "the brace pushes the breath up into the ribs"}},
        {"id": "light", "label": "sitting up lightly", "posture": "seated",
         "tone": [{"region": "frontAbdomen", "factor": 1.2}, {"region": "flanks", "factor": 1.2}], "minutes": 2,
         "provenance": {"position": "stated", "shape": "implied", "tone": "inferred"}, "relation": "release",
         "claim": {"kind": "bellyShare", "higherThan": "brace", "text": "lifted lightly, the belly takes back what the brace took"}},
        {"id": "scan", "label": "lying on the back, legs long", "posture": "supine", "minutes": 3,
         "provenance": {"position": "stated", "shape": "stated", "tone": "inferred"}, "relation": "scan",
         "claim": {"kind": "notRepresented", "text": "which side breathes more is a person's own asymmetry; the model is symmetric"}},
        {"id": "knees-bent", "label": "knees bent, feet standing", "posture": "supine", "legs": {"left": 60, "right": 60},
         "minutes": 3, "provenance": {"position": "stated", "shape": "inferred", "tone": "inferred"}, "relation": "release",
         "claim": {"kind": "bellyShare", "higherThan": "scan", "text": "with the knees up the low belly wall slackens and the belly takes more"}},
        {"id": "right-foot", "label": "right foot standing, the left leg long", "posture": "supine", "legs": {"left": 0, "right": 60},
         "tone": [{"region": "frontAbdomen", "factor": 1.5}, {"region": "flanks", "factor": 1.5}], "minutes": 5,
         "provenance": {"position": "stated", "shape": "inferred", "tone": "inferred"}, "relation": "gauge",
         "claim": {"kind": "notRepresented", "text": "which side breathes with one foot standing: a few mL either way in the model"}},
        {"id": "left-foot", "label": "left foot standing, the right leg long", "posture": "supine", "legs": {"left": 60, "right": 0},
         "tone": [{"region": "frontAbdomen", "factor": 1.5}, {"region": "flanks", "factor": 1.5}], "minutes": 5,
         "provenance": {"position": "stated", "shape": "inferred", "tone": "inferred"}, "relation": "gauge",
         "claim": {"kind": "notRepresented", "text": "the mirror of the right foot"}},
        {"id": "final-rest", "label": "final rest on the back, legs long", "posture": "supine", "minutes": 3,
         "provenance": {"position": "stated", "shape": "stated", "tone": "inferred"}, "relation": "integrative",
         "claim": {"kind": "notRepresented", "text": "identical to the scan without a slow state; the before/after is a stage-6 hypothesis"}}
      ]
    }
    """#

    /// The example lesson, decoded.
    public static let example: Lesson = try! Lesson.decode(Data(exampleJSON.utf8))
}
