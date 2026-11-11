import BreathStar
import Foundation

/// The lesson a command runs: `--file PATH` (a lesson JSON, LessonFile.swift), else the example.
func lessonArgument(_ args: ArraySlice<String>, flag: String = "--file") -> Lesson {
    guard let i = args.firstIndex(of: flag), args.index(after: i) < args.endIndex else { return Lessons.example }
    let path = args[args.index(after: i)]
    do { return try Lesson.load(path: path) } catch { fail("can't read lesson \(path): \(error)") }
}

/// `lesson [--file PATH]`: a lesson (LessonFile.swift; the example by default), step by step: the
/// breath, the change from the previous step and the opening step, which rule accounts for it, an
/// evidence label, and a verdict against the lesson's claim (docs/LESSON_ADAPTATION.md §7).
func runLesson(_ args: ArraySlice<String>) {
    let drive = Drive()
    let lesson = lessonArgument(args), steps = lesson.steps
    func breath(_ c: BodyConfiguration) -> (m: SidedBreath, drive: Double) {
        let r = BodyGenerator.general(c, drive: drive)
        return (SidedBreath.measure(r.body.simulate(drive: drive), period: drive.period), r.driveScale)
    }
    func shares(_ m: SidedBreath) -> String { "\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))" }
    var out: [String: SidedBreath] = [:]
    print("\(lesson.name): \(steps.count) steps as configurations (quiet tidal held, 0.56 L). Shares upper/lower ribcage/belly %;")
    print("chest wall left/right mL; 'why': belly-share points each ingredient accounts for (removing it one at a time).\n")
    for st in steps {
        let c = st.configuration
        let (m, d) = breath(c)
        out[st.id] = m
        // Why: remove one ingredient at a time.
        var plain = c; plain.gravity = (0, 0, -1); plain.contacts = []
        var flat = c; flat.spine = .neutral
        var loose = c; loose.tone = []
        func delta(_ x: BodyConfiguration) -> String { f((m.abdomenShare - breath(x).m.abdomenShare) * 100, 1) }
        let posture = c.posture != .upright || !c.contacts.isEmpty
        let label: String
        if !c.spine.isNeutral || !c.tone.isEmpty { label = "assumed (spine angles and tone factors unsourced)" }
        else if c.posture == .upright || c.posture == .supine { label = "anchored (a posture with data, reproduced)" }
        else { label = "derived" }
        print("▸ \(st.id): \(st.label)   [\(st.source); relation: \(st.relation)]")
        print("    configuration: \(c.name)" + (c.spine.isNeutral ? "" : ", spine flex \(f(c.spine.lumbarFlexion, 0))/\(f(c.spine.thoracicFlexion, 0))° side-bend \(f(c.spine.lumbarSideBend, 0))/\(f(c.spine.thoracicSideBend, 0))° (lumbar/thoracic)")
              + (c.tone.isEmpty ? "" : ", tone: " + c.tone.map(\.label).joined(separator: ", "))
              + "   (position \(st.position.rawValue), shape \(st.shape.rawValue), tone \(st.tone.rawValue))")
        var line = "    breath: \(shares(m))%, chest wall \(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0)), lungs \(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0)), drive ×\(f(d, 2))"
        if let scan = out[lesson.before], st.id != lesson.before { line += "   vs \(lesson.before): belly \(f((m.abdomenShare - scan.abdomenShare) * 100, 1)) pts" }
        print(line)
        print("    why (belly pts): posture/gravity \(posture ? delta(plain) : "–"), spine \(c.spine.isNeutral ? "–" : delta(flat)), tone \(c.tone.isEmpty ? "–" : delta(loose))   evidence: \(label)")
        let verdict = lessonVerdict(st, m, out, lesson: lesson, breath: { breath($0).m })
        print("    verdict: " + verdict + (st.note.isEmpty ? "" : "\n    note: " + st.note))
    }
}

/// `lesson-slow`: the slow-state hypotheses (SlowState.swift) across their unsourced sizes: the final
/// rest against the opening scan, per hypothesis. A sensitivity table, not a claim.
func runLessonSlow(_ args: ArraySlice<String>) {
    let drive = Drive()
    let lesson = lessonArgument(args), steps = lesson.steps
    var rows: [(String, SlowHypotheses)] = [("none (default)", .off)]
    for tau in [1.0, 5, 20] { var h = SlowHypotheses(); h.toneResidue = true; h.toneTau = tau; rows.append(("H1 tone residue, τ \(f(tau, 0)) min", h)) }
    for (g, tau) in [(0.15, 5.0), (0.3, 5), (0.3, 20)] {
        var h = SlowHypotheses(); h.useAndStillness = true; h.useGain = g; h.useTau = tau
        rows.append(("H2 use/stillness, gain \(f(g, 2)), τ \(f(tau, 0))", h))
    }
    var both = SlowHypotheses(); both.toneResidue = true; both.useAndStillness = true; rows.append(("H1 + H2 (τ 5, gain 0.3)", both))
    print("Slow state over \(lesson.name) (\(f(steps.reduce(0) { $0 + $1.minutes }, 0)) min, durations ASSUMED): '\(lesson.after)'")
    print("against '\(lesson.before)', quiet tidal held. Shares upper/lower/belly %; wall left/right mL.\n")
    print("  " + pad("hypothesis", 34) + pad("scan", 26) + pad("final rest", 26) + pad("Δ belly", 9) + pad("Δ L−R", 8) + "drive scan → rest")
    for (label, h) in rows {
        let r = LessonRunner.run(steps, h, drive: drive)
        let scan = r.first { $0.step.id == lesson.before }!, rest = r.first { $0.step.id == lesson.after }!
        func cell(_ m: SidedBreath) -> String {
            "\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100)) \(f(m.chestWall[0] * 1000, 0))/\(f(m.chestWall[1] * 1000, 0))"
        }
        let dlr = (rest.breath.chestWall[0] - rest.breath.chestWall[1]) - (scan.breath.chestWall[0] - scan.breath.chestWall[1])
        let ds = BodyGenerator.general({ var c = scan.step.configuration; c.carried = scan.carried; return c }(), drive: drive).driveScale
        let dr = BodyGenerator.general({ var c = rest.step.configuration; c.carried = rest.carried; return c }(), drive: drive).driveScale
        print("  " + pad(label, 34) + pad(cell(scan.breath), 26) + pad(cell(rest.breath), 26)
              + pad(f((rest.breath.abdomenShare - scan.breath.abdomenShare) * 100, 1), 9) + pad(f(dlr * 1000, 1), 8)
              + "\(f(ds, 2)) → \(f(dr, 2))")
    }
    print("""

      Reading: "if <hypothesis> at <size>, the final rest's breath differs from the opening scan by <Δ>". None of the sizes
      is sourced; H2's thixotropy evidence is recalled, not read. Nothing is fitted to the lesson's claims, and a breath felt
      beyond the trunk (from the feet to the head) is outside what the trunk model can represent.
    """)
}

/// A step's verdict against its claim (docs/LESSON_ADAPTATION.md §7), given the earlier steps' breaths.
func lessonVerdict(_ st: LessonStep, _ m: SidedBreath, _ out: [String: SidedBreath], lesson: Lesson,
                   breath: (BodyConfiguration) -> SidedBreath) -> String {
    switch st.claim {
    case .none: return "no claim encoded"
    case .notRepresented(let why): return "not represented — " + why
    case .sideMore(let side, let text):
        let more = m.chestWall[side.rawValue] - m.chestWall[1 - side.rawValue]
        return (more > 0.002 ? "consistent under these assumptions" : more < -0.002 ? "contradicts this modelled case" : "not represented (no side difference)")
            + " — \(text): \(side == .left ? "left" : "right") \(f(more * 1000, 0)) mL more"
            + " (by region, that side minus the other: upper \(f((m.upper[side.rawValue] - m.upper[1 - side.rawValue]) * 1000, 0)),"
            + " lower ribs \(f((m.lower[side.rawValue] - m.lower[1 - side.rawValue]) * 1000, 0)),"
            + " belly \(f((m.abdomen[side.rawValue] - m.abdomen[1 - side.rawValue]) * 1000, 0)) mL)"
    case .ribcageShare(let lower, let higher, let text):
        let rc = m.upperShare + m.lowerShare
        var ok = true, parts: [String] = []
        if let id = lower, let o = out[id] { ok = ok && rc < o.upperShare + o.lowerShare; parts.append("ribcage \(f(rc * 100))% vs \(id) \(f((o.upperShare + o.lowerShare) * 100))%") }
        if let id = higher, let o = out[id] { ok = ok && rc > o.upperShare + o.lowerShare; parts.append("ribcage \(f(rc * 100))% vs \(id) \(f((o.upperShare + o.lowerShare) * 100))%") }
        return (ok ? "consistent under these assumptions" : "contradicts this modelled case") + " — \(text): " + parts.joined(separator: "; ")
    case .bellyShare(let id, let text):
        if let o = out[id] {
            return (m.abdomenShare > o.abdomenShare ? "consistent under these assumptions" : "contradicts this modelled case")
                + " — \(text): belly \(f(m.abdomenShare * 100))% vs \(id) \(f(o.abdomenShare * 100))%"
        } else {
            // The comparison step comes later: compare when it is known.
            guard let later = lesson.step(id) else { return "no comparison — step '\(id)' is not in the lesson" }
            let o = breath(later.configuration)
            return (o.abdomenShare > m.abdomenShare ? "consistent under these assumptions" : "contradicts this modelled case")
                + " — \(text): belly \(f(m.abdomenShare * 100))% here vs \(id) \(f(o.abdomenShare * 100))%"
        }
    }
}
