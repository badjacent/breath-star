import Foundation

// Stage 5 of the lesson adaptation (docs/LESSON_ADAPTATION.md §6–7): a lesson as data. Each step is a
// configuration (gravity, contacts, the spine's shape, legs, tone on named regions) with where each
// field came from, the relation the step is read as (release, gauge, tracing, …), and the lesson's
// claim. The runner (`breathstar lesson`) gives per step: where the wall moves, the change from the previous step and from the
// opening scan, which rule accounts for it, an evidence label, and a verdict against the claim in
// the first critique's words ("consistent under these assumptions", "not represented",
// "contradicts this modelled case").

/// Tone on a named region: its coordinates' stiffness × factor. ×5 is the `holds` command's "held";
/// lighter factors are ASSUMED.
public struct RegionTone: Sendable, Equatable {
    public enum Region: String, Sendable, Equatable {
        case frontAbdomen = "front abdominal wall", flanks = "abdominal flanks", lowerRibs = "lower ribs",
             upperRibs = "upper ribs (neck and shoulder muscles)"
    }
    public var region: Region
    public var side: Side?
    public var factor: Double
    public init(_ region: Region, side: Side? = nil, _ factor: Double) { self.region = region; self.side = side; self.factor = factor }

    /// Held hard (a grip): ×5, as `breathstar holds`. Light, proportional tone: ×1.5 (ASSUMED).
    /// Softened below the resting tone: ×0.7 (ASSUMED).
    public static let held = 5.0, light = 1.5, softened = 0.7

    public var coordinates: [SidedCoordinate] {
        let sides = side.map { [$0] } ?? Side.allCases
        switch region {
        case .frontAbdomen: return [.abdomen]
        case .flanks: return sides.map { $0 == .left ? .flankL : .flankR }
        case .lowerRibs:
            return sides.flatMap { SidedCoordinate.on($0, [.lowerBucket, .lowerDilationTransverse]) }
                + (side == nil ? [.lowerPump, .lowerDilationAP] : [])
        case .upperRibs: return sides.flatMap { SidedCoordinate.on($0, [.upperRotation, .upperDilation]) }
        }
    }

    public var label: String {
        let s = side.map { $0 == .left ? " (left)" : " (right)" } ?? ""
        return "\(region.rawValue)\(s) ×\(String(format: "%.1f", factor))"
    }
}

/// Where a field came from: said in the lesson, implied by it, or inferred by the encoder.
public enum Provenance: String, Sendable { case stated, implied, inferred }

/// A claim the model can check: more of the breath in one place than in another, or a change from
/// another step in one direction. Anything else is "not represented".
public enum LessonClaim: Sendable {
    case none
    case notRepresented(String)
    /// The wall on `more` moves more than on the other side.
    case sideMore(Side, String)
    /// The ribcage's share falls (or rises) against the given step.
    case ribcageShare(lowerThan: String?, higherThan: String?, String)
    /// The belly's share rises against the given step.
    case bellyShare(higherThan: String, String)
}

public struct LessonStep: Sendable {
    public var id: String
    /// Where the step is in its source (step numbers, time anchors).
    public var source: String
    public var label: String
    public var configuration: BodyConfiguration
    /// Provenance of the position, the spine's shape and the tone.
    public var position: Provenance, shape: Provenance, tone: Provenance
    /// How the step relates to the breath (release, gauge, tracing, …) and how that was given.
    public var relation: String
    public var claim: LessonClaim
    public var note: String
    /// How long the step lasts, minutes (ASSUMED from the recording's pace; stage 6).
    public var minutes: Double

    public init(_ id: String, source: String, label: String, _ c: BodyConfiguration,
                position: Provenance, shape: Provenance = .inferred, tone: Provenance = .inferred,
                relation: String, claim: LessonClaim = .none, note: String = "", minutes: Double = 3) {
        self.id = id; self.source = source; self.label = label; configuration = c
        self.position = position; self.shape = shape; self.tone = tone
        self.relation = relation; self.claim = claim; self.note = note; self.minutes = minutes
    }
}

extension BodyConfiguration {
    public func toned(_ tone: [RegionTone]) -> BodyConfiguration { var c = self; c.tone = tone; return c }
}

extension SidedBody {
    /// Stiffness carried from earlier in a lesson (stage 6), per coordinate.
    public func carrying(_ m: [Double]) -> SidedBody {
        guard m.count == stiffness.count else { return self }
        var b = self
        for i in 0..<m.count { b.stiffness[i] *= m[i] }
        return b
    }

    /// Tone on named regions (stiffness × factor per region).
    public func toned(_ tone: [RegionTone]) -> SidedBody {
        var b = self
        for t in tone { for c in t.coordinates { b.stiffness[c.rawValue] *= t.factor } }
        return b
    }
}

/// Lessons: the example ships with the model (LessonFile.swift); any other lesson is a JSON file
/// loaded at run time (`Lesson.load(path:)`), so lesson encodings can be kept elsewhere.
public enum Lessons {}
