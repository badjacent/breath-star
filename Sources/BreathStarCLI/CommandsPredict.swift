import BreathStar
import Foundation

/// `measure-predictions`: what the model predicts for each position in the self-measurement plan
/// (reference/SELF_MEASUREMENT_PLAN.md), at the quiet tidal volume (0.56 L). Written down before
/// measuring, so the measurement can contradict it. Markers: mean surface motion over the sector,
/// end expiration → end inspiration, mm, relative to the spine.
func runMeasurePredictions(_ args: ArraySlice<String>) {
    let drive = Drive()
    var arch = SpineShape(); arch.lumbarFlexion = -15
    var midArch = SpineShape(); midArch.thoracicFlexion = -15
    let s = BodyConfiguration.seated
    let rows: [(String, String, BodyConfiguration)] = [
        ("A", "sitting upright", s),
        ("B", "sitting slumped", s.with(.slumped)),
        ("C", "sitting, lower back arched 15°", s.with(arch)),
        ("C2", "sitting, mid-back arched 15°", s.with(midArch)),
        ("D", "sitting, side-bend left 20°", s.with(SpineShape(sideBend: 20))),
        ("E", "sitting, side-bend right 20°", s.with(SpineShape(sideBend: -20))),
        ("F", "sitting, turned left 30°", s.with(SpineShape(rotation: 30))),
        ("G", "lying on the back, legs long", .supine),
        ("H", "lying on the back, knees bent", BodyConfiguration.supine.with(Legs.kneesBent)),
        ("I", "lying on the right side", .rightSideDown),
        ("J", "lying face down", .prone),
        ("K", "reclined 45°", .reclined45),
    ]
    func motion(_ b: SidedBody, _ z: ClosedRange<Double>, _ psi: ClosedRange<Double>, _ side: Side) -> (x: Double, y: Double, z: Double) {
        let sim = b.simulate(drive: drive).suffix(Int(drive.period / 0.002))
        let hi = sim.max { $0.totalLung < $1.totalLung }!.q, lo = sim.min { $0.totalLung < $1.totalLung }!.q
        return b.anatomy.sectorMotion(z: z, psi: psi, side: side, b.anatomy.sidedState(zip(hi, lo).map { $0 - $1 }))
    }
    print("Model predictions for the self-measurement plan (quiet breath 0.56 L; rules as of this commit).")
    print("rc/ab: ribcage and belly shares of the breath (two bands, after an isovolume calibration).")
    print("Markers (mm, outward): lateral lower ribs L/R (9th–10th rib level, z 13–18 / lower ribcage z 18–25),")
    print("front belly (umbilicus region, forward), front upper chest (forward).\n")
    print("  " + pad("", 3) + pad("position", 32) + pad("rc/ab %", 11) + pad("lat. lowest L/R", 17) + pad("lat. lower L/R", 16) + pad("belly fwd", 11) + pad("chest fwd", 11) + "lungs L/R mL")
    for (id, label, c) in rows {
        let b = BodyGenerator.general(c, drive: drive).body
        let m = SidedBreath.measure(b.simulate(drive: drive), period: drive.period)
        let a = b.anatomy
        let lo = Side.allCases.map { motion(b, 13...18, 80...100, $0).x }
        let lr = Side.allCases.map { motion(b, 18...25, 80...100, $0).x }
        let belly = 0.5 * (motion(b, 4...14, -20...20, .left).y + motion(b, 4...14, -20...20, .right).y)
        let chest = 0.5 * (motion(b, a.xiphoid...a.top, -30...30, .left).y + motion(b, a.xiphoid...a.top, -30...30, .right).y)
        print("  " + pad(id, 3) + pad(label, 32) + pad("\(f((m.upperShare + m.lowerShare) * 100, 0))/\(f(m.abdomenShare * 100, 0))", 11)
              + pad("\(f(lo[0], 2))/\(f(lo[1], 2))", 17) + pad("\(f(lr[0], 2))/\(f(lr[1], 2))", 16)
              + pad(f(belly, 2), 11) + pad(f(chest, 2), 11) + "\(f(m.lung[0] * 1000, 0))/\(f(m.lung[1] * 1000, 0))")
    }
    // Knees bent (Legs, 2026-11-11): where on the belly the change shows, front wall high vs low.
    func frontBelly(_ c: BodyConfiguration, _ z: ClosedRange<Double>) -> Double {
        let b = BodyGenerator.general(c, drive: drive).body
        return 0.5 * (motion(b, z, 0...40, .left).y + motion(b, z, 0...40, .right).y)
    }
    let g = BodyConfiguration.supine, h = g.with(Legs.kneesBent)
    print("\n  G vs H, front belly (mm forward): low (2–8 cm above the iliac crests) \(f(frontBelly(g, 2...8), 2)) → \(f(frontBelly(h, 2...8), 2)),"
          + " high (10–16 cm) \(f(frontBelly(g, 10...16), 2)) → \(f(frontBelly(h, 10...16), 2)).")
    // Before/after a lesson (stage 6): the final rest against the opening scan, per hypothesis.
    var h2 = SlowHypotheses(); h2.useAndStillness = true
    let lesson = lessonArgument(args, flag: "--lesson")
    let r0 = LessonRunner.run(lesson.steps, .off), r2 = LessonRunner.run(lesson.steps, h2)
    func ab(_ r: [LessonStepResult], _ id: String) -> Double { r.first { $0.step.id == id }!.breath.abdomenShare * 100 }
    print("\n  Before/after \(lesson.name): belly share \(lesson.before) → \(lesson.after):"
          + " no slow state \(f(ab(r0, lesson.before), 1)) → \(f(ab(r0, lesson.after), 1)); H2 (use loosens, gain 0.3, τ 5 min) \(f(ab(r2, lesson.before), 1)) → \(f(ab(r2, lesson.after), 1)).")
}
