import Foundation

// Stage 6 of the lesson adaptation (docs/LESSON_ADAPTATION.md §5, §9): properties that drift over a lesson, as named,
// switchable hypotheses, OFF by default. None is sourced in size, so the output is a sensitivity
// statement ("if tone settles with a 5-minute time constant, the final rest's breath has x more
// belly than the opening scan"), never "this lesson does X". Nothing here is fitted to the lesson's
// own claims.
//
// H1, tone residue: each coordinate's background tone moves toward the step's tone (first order,
// time constant τ). Deliberate tone in a step overrides it while the step lasts; once let go, the
// residue is what remains. Lying supported and unattended, the target is `unattended` (lower).
// H2, use and stillness (thixotropy): muscle just moved is looser, muscle held still is stiffer.
// "Moved" is how far the step's movement strains the coordinate's wall (Rule B's strain, saturating
// at 0.1); a step with no spine movement is still.
// Evidence (checked 2026-11-11, reference/LITERATURE.md pass 15): the ribcage's respiratory muscles
// are thixotropic (Homma & Hagbarth 2000, abstract), but the measured after-effects are on the
// operating volumes, not the stiffness: after maximal 5 s contractions the end-inspiratory volume
// rises ~0.28 L or the end-expiratory falls ~0.2 L, for 3–5 breaths (Lima et al. 2019, OEP, n = 28),
// with timing unchanged. Limb muscle stiffens while still and loosens with movement (Lakie &
// Campbell 2019). So H2's direction has support; its mechanism here (stiffness), its time constant
// (minutes) and its trigger (gentle movement) do not.

public struct SlowHypotheses: Sendable {
    public var toneResidue = false
    public var toneTau = 5.0                 // minutes
    public var unattended = 0.9              // lying, supported, unattended: tone target
    public var useAndStillness = false
    public var useTau = 5.0                  // minutes
    public var useGain = 0.3                 // fully moved → stiffness × (1 − gain)
    public var stillGain = 0.1               // held still → stiffness × (1 + gain)
    public init() {}
    public static let off = SlowHypotheses()
}

public struct LessonStepResult: Sendable {
    public var step: LessonStep
    /// The carried stiffness multipliers at the step's start, per sided coordinate.
    public var carried: [Double]
    /// The breath at the step's start (what the person brings to it).
    public var breath: SidedBreath
}

public enum LessonRunner {
    public static func run(_ steps: [LessonStep], _ h: SlowHypotheses = .off, drive: Drive = Drive()) -> [LessonStepResult] {
        let n = SidedCoordinate.count
        var tone = [Double](repeating: 1, count: n), use = tone
        let seated = BodyGenerator.general(.seated, drive: drive).body
        var out: [LessonStepResult] = []
        for st in steps {
            var c = st.configuration
            var deliberate = [Double?](repeating: nil, count: n)
            for t in c.tone { for k in t.coordinates { deliberate[k.rawValue] = (deliberate[k.rawValue] ?? 1) * t.factor } }
            let carried = (0..<n).map { i in (deliberate[i] == nil && h.toneResidue ? tone[i] : 1) * (h.useAndStillness ? use[i] : 1) }
            c.carried = carried
            let b = BodyGenerator.general(c, drive: drive).body
            out.append(LessonStepResult(step: st, carried: carried, breath: SidedBreath.measure(b.simulate(drive: drive), period: drive.period)))
            // Drift over the step.
            let lying = c.posture != .upright && !c.contacts.isEmpty
            if h.toneResidue {
                let k = exp(-st.minutes / h.toneTau)
                for i in 0..<n {
                    let target = deliberate[i] ?? (lying ? h.unattended : 1)
                    tone[i] = target + (tone[i] - target) * k
                }
            }
            if h.useAndStillness {
                let k = exp(-st.minutes / h.useTau)
                let strains = c.spine.isNeutral ? nil : seated.coordinateStrains(c.spine)
                for i in 0..<n where !SidedCoordinate(rawValue: i)!.isDiaphragm {
                    let moved = strains.map { min(1, (abs($0[i].axial) + $0[i].shear) / 0.1) } ?? 0
                    let target = moved > 0.05 ? 1 - h.useGain * moved : 1 + h.stillGain
                    use[i] = target + (use[i] - target) * k
                }
            }
        }
        return out
    }
}
