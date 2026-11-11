import BreathStar
import Foundation

// Scrubbable viewer (critique 2, §7): one self-contained HTML page that plays the solver's own
// breath with pause, scrub, speed and magnification, for every A2 case seated and supine, with the
// plausible alternative bodies as an overlay.
//
// Data contract: the drawn geometry is, to first order, linear in A2's 8 coordinates q (a2State is
// linear in q; the kinematics are linear at breathing scale). So each posture stores its resting
// paths and one displacement basis per coordinate (paths per unit q, central differences); a frame
// is just q. The page draws rest + magnification × Σ q_i·basis_i, which is the critique's
// "scale displacement vectors from the reference surface". `viewer` prints the worst error of
// that linearisation against the exact geometry at end inspiration, true scale.

/// One drawn layer: a path in raw centimetres. Side view pairs are (forward y, up z); front and
/// back views (sideways x, up z), x > 0 the person's left.
struct RawLayer {
    var key: String
    var view: String
    var d: String
}

/// The numbers in a path string, in order (the template's placeholders).
func pathNumbers(_ d: String) -> [Double] {
    var out: [Double] = [], cur = ""
    for c in d {
        if c.isNumber || c == "." || (c == "-" && cur.isEmpty) {
            cur.append(c)
        } else {
            if let v = Double(cur) { out.append(v) }
            cur = c == "-" ? "-" : ""
        }
    }
    if let v = Double(cur) { out.append(v) }
    return out
}

extension AnatomySVG {
    /// Every layer of the three views at one state, in raw centimetres.
    func rawLayers(_ s: AnatomyState) -> [RawLayer] {
        let p: (Double, Double) -> String = { "\(self.fmt($0, 6)),\(self.fmt($1, 6))" }
        var out = [
            RawLayer(key: "side.spine", view: "side", d: sideBack(s, p)),
            RawLayer(key: "side.front", view: "side", d: sideFront(s, p)),
            RawLayer(key: "side.dome", view: "side", d: sideDome(s, p)),
        ]
        for (i, r) in sideRibs([s], p).enumerated() { out.append(RawLayer(key: "side.rib\(i)", view: "side", d: r[0])) }
        out.append(RawLayer(key: "front.outline", view: "front", d: frontOutline(s, p)))
        for (i, r) in frontRibs([s], p).enumerated() { out.append(RawLayer(key: "front.rib\(i)", view: "front", d: r[0])) }
        out.append(RawLayer(key: "front.domes", view: "front", d: frontDomes(s, p)))
        out.append(RawLayer(key: "back.outline", view: "back", d: frontOutline(s, p)))
        // Back-rib vectors: from each rest point to where it has moved (the page adds a stated gain).
        var v = ""
        for z in [19.0, 21.5, 24.0, 28.0, 32.0, 36.0] {
            for side in [Side.left, .right] {
                let sign = side == .left ? 1.0 : -1.0
                let x0 = model.section(z, AnatomyState()).halfWidth[side.rawValue] * sin(135 * .pi / 180)
                let d = model.surfaceDisplacement(z: z, psiDegrees: 135, side: side, s)
                v += "M\(p(sign * x0, z)) L\(p(sign * (x0 + d.x), z + d.z)) "
            }
        }
        out.append(RawLayer(key: "back.vectors", view: "back", d: v))
        return out
    }
}

private func round5(_ x: Double) -> Double {
    guard x != 0, x.isFinite else { return 0 }
    let m = pow(10, 5 - (log10(abs(x))).rounded(.up))
    return (x * m).rounded() / m
}

/// Which coordinates a posture's frames are in: A2's 8 (symmetric) or the sided 15, with steps of
/// about a quiet breath's size per coordinate (rotations in fractions of Wilson's angles,
/// dilations, cm of diaphragm and wall) and the map to an anatomical state.
struct CoordinateMap {
    var count: Int
    var steps: [Double]
    var state: ([Double]) -> AnatomyState

    static let a2Steps = [0.02, 0.002, 0.02, 0.02, 0.002, 0.002, 0.2, 0.2]
    static func a2(_ a: AnatomyModel) -> CoordinateMap {
        CoordinateMap(count: A2Coordinate.count, steps: a2Steps, state: { a.a2State($0) })
    }
    static func sided(_ a: AnatomyModel) -> CoordinateMap {
        CoordinateMap(count: SidedCoordinate.count,
                      steps: SidedCoordinate.allCases.map { $0.symmetric.map { a2Steps[$0.rawValue] } ?? 0.2 },
                      state: { a.sidedState($0) })
    }
}

/// Rest paths and the per-coordinate displacement basis for one anatomy.
func viewerGeometry(_ anatomy: AnatomyModel, map: CoordinateMap? = nil) -> (layers: [[String: Any]], maxLinearError: ([Double]) -> Double) {
    let svg = AnatomySVG(model: anatomy, peak: AnatomyState(), drive: Drive(), magnify: 1, title: "", subtitle: "")
    let rest = svg.rawLayers(AnatomyState())
    let map = map ?? .a2(anatomy)
    let n = map.count, steps = map.steps
    var basis = [[[Double]]](repeating: [], count: rest.count)  // [layer][coordinate][number]
    for i in 0..<n {
        var plus = [Double](repeating: 0, count: n), minus = plus
        plus[i] = steps[i]; minus[i] = -steps[i]
        let lp = svg.rawLayers(map.state(plus)), lm = svg.rawLayers(map.state(minus))
        for l in rest.indices {
            let a = pathNumbers(lp[l].d), b = pathNumbers(lm[l].d)
            basis[l].append(zip(a, b).map { round5(($0 - $1) / (2 * steps[i])) })
        }
    }
    let layers: [[String: Any]] = rest.indices.map { l in
        ["key": rest[l].key, "view": rest[l].view, "d": rest[l].d, "basis": basis[l]]
    }
    // Worst point error (cm) of rest + Σ q·basis against the exact geometry.
    let check: ([Double]) -> Double = { q in
        let exact = svg.rawLayers(map.state(q))
        var worst = 0.0
        for l in rest.indices {
            let r = pathNumbers(rest[l].d), e = pathNumbers(exact[l].d)
            for j in r.indices {
                let lin = r[j] + (0..<n).reduce(0.0) { $0 + q[$1] * basis[l][$1][j] }
                worst = max(worst, abs(lin - e[j]))
            }
        }
        return worst
    }
    return (layers, check)
}

/// One case's breath: q, times and volumes at evenly spaced instants over the last full cycle.
func viewerCase(id: String, label: String, body: A2Body, drive: Drive, frames: Int = 60,
                sizing: String = "same muscle drive as the reference") -> [String: Any] {
    let dt = 0.002
    let sim = body.simulate(drive: drive, timeStep: dt)
    let perCycle = Int((drive.period / dt).rounded())
    let last = Array(sim.suffix(perCycle))
    let picked = (0..<frames).map { last[$0 * last.count / frames] }
    let t0 = picked[0].time
    let m = SignedBreath.measure(sim, period: drive.period)
    return [
        "id": id, "label": label, "sizing": sizing,
        "t": picked.map { round5($0.time - t0) },
        "q": picked.map { $0.q.map(round5) },
        "lung": picked.map { round5($0.lung) }, "upper": picked.map { round5($0.upperRegion) },
        "lower": picked.map { round5($0.lowerRegion) }, "abdomen": picked.map { round5($0.abdomenRegion) },
        "tidal": round5(m.tidalVolume), "shares": [round5(m.upperShare), round5(m.lowerShare), round5(m.abdomenShare)],
    ]
}

/// The same for a sided body: q in the 15 sided coordinates, both sides' volumes summed.
func sidedViewerCase(id: String, label: String, body: SidedBody, drive: Drive, frames: Int = 60,
                sizing: String = "same muscle drive as the reference") -> [String: Any] {
    let dt = 0.002
    let sim = body.simulate(drive: drive, timeStep: dt)
    let perCycle = Int((drive.period / dt).rounded())
    let last = Array(sim.suffix(perCycle))
    let picked = (0..<frames).map { last[$0 * last.count / frames] }
    let t0 = picked[0].time
    let m = SidedBreath.measure(sim, period: drive.period)
    func sum(_ v: [Double]) -> Double { round5(v[0] + v[1]) }
    return [
        "id": id, "label": label, "sizing": sizing,
        "t": picked.map { round5($0.time - t0) },
        "q": picked.map { $0.q.map(round5) },
        "lung": picked.map { round5($0.totalLung) }, "upper": picked.map { sum($0.upper) },
        "lower": picked.map { sum($0.lower) }, "abdomen": picked.map { sum($0.abdomen) },
        "tidal": round5(m.tidalVolume), "shares": [round5(m.upperShare), round5(m.lowerShare), round5(m.abdomenShare)],
    ]
}

func viewerData(lesson: Lesson = Lessons.example) -> (json: Data, report: [String]) {
    let drive = Drive()
    var report: [String] = []
    var postures: [[String: Any]] = []
    let seated = a2Bodies(drive: drive, volumes: GravityRules().seatedVolumes)
    let altOutcomes = alternatives(count: 12, seed: 1).compactMap { evaluate($0) }
    for (name, label, ref, cases) in [("seated", "Seated", seated.reference, seated.cases)] {
        let geo = viewerGeometry(ref.anatomy)
        let endQ = ref.endInspiration(drive: drive)
        let endState = ref.anatomy.a2State(endQ)
        let err = geo.maxLinearError(endQ)
        report.append("\(name): linear frames vs exact geometry at end inspiration, worst point \(String(format: "%.4f", err * 10)) mm (true scale)")
        let a = ref.anatomy
        let surface = name == "seated"
            ? blurSurface(a, alternatives: altOutcomes.map { ($0.alternative.anatomy, $0.endInspiration) }, reference: endState)
            : blurSurface(a)
        postures.append([
            "id": name, "label": label, "layers": geo.layers, "surface": surface,
            "diaphragm": [A2Coordinate.diaphragm.rawValue],
            "landmarks": ["costal margin": a.costalMargin, "xiphoid": a.xiphoid, "top of ribcage": a.top],
            // The reference is matched to the measured tidal volume; every other case keeps the
            // reference's muscle drive, so its breath size is a result (critique 3, section 8).
            "cases": cases.map { viewerCase(id: $0.id, label: $0.label, body: $0.body, drive: drive,
                                            sizing: $0.id == "reference" ? "matched to the measured tidal volume" : "same muscle drive as the reference") },
        ])
    }
    // The other postures come from the general rules (Settle.swift, stage 3): configuration in, body
    // out, one parameter set. Each breathes the quiet tidal volume; the drive it needs is shown.
    let quiet = GravityRules().quietTidal ?? 0.56
    func rulePosture(_ id: String, _ label: String, _ c: BodyConfiguration, lyingOnSide: Bool = false) {
        let generated = BodyGenerator.body(c, drive: drive)
        let rule = BodyGenerator.general(c, drive: drive)
        let body = generated.body, a = body.anatomy
        let map = CoordinateMap.sided(a)
        let geo = viewerGeometry(a, map: map)
        let endQ = body.endInspiration(drive: drive)
        report.append("\(id): linear frames vs exact geometry at end inspiration, worst point \(String(format: "%.4f", geo.maxLinearError(endQ) * 10)) mm (true scale); drive needed ×\(String(format: "%.2f", rule.driveScale))")
        var entry: [String: Any] = [
            "id": id, "label": label, "layers": geo.layers,
            "diaphragm": [SidedCoordinate.diaphragmL.rawValue, SidedCoordinate.diaphragmR.rawValue],
            "surface": blurSurface(a, map: map),
            "landmarks": ["costal margin": a.costalMargin, "xiphoid": a.xiphoid, "top of ribcage": a.top],
        ]
        var cases: [(String, String, SidedBody)] = [("reference", "reference breath", body),
                                                    ("diaphragm-only", "diaphragm only (rib muscles silent)", body.silenced([.ribs])),
                                                    ("ribs-only", "rib muscles only (diaphragm silent)", body.silenced([.diaphragm]))]
        if lyingOnSide {
            // Lying on the floor: the spine's rest arc (Leilnahari 2011, firm surface; Sided.swift) and the
            // breath's room-frame lift as a basis per coordinate (cm per unit q), sampled along z. The
            // floor is drawn at the trunk's lowest resting point.
            let zs = Array(stride(from: -3.0, through: 46.0, by: 0.5))
            let arcX = zs.map { round5(a.sideLyingSpine(z: $0, AnatomyState(), restingOn: .right, roomFrame: false).x) }
            let arcTilt = zs.map { round5(a.sideLyingSpine(z: $0, AnatomyState(), restingOn: .right, roomFrame: false).tilt) }
            let liftBasis = (0..<map.count).map { c -> [Double] in
                var q = [Double](repeating: 0, count: map.count)
                q[c] = map.steps[c]
                let st = map.state(q)
                return zs.map { round5(a.roomLift(z: $0, st, restingOn: .right) / 10 / map.steps[c]) }
            }
            let floor = stride(from: 0.0, through: a.top, by: 0.5).map { z in
                a.sideLyingSpine(z: z, AnatomyState(), restingOn: .right, roomFrame: false).x - a.section(z, AnatomyState()).halfWidth[1]
            }.min()!
            entry["lying"] = ["z": zs, "x": arcX, "tilt": arcTilt, "liftBasis": liftBasis, "floor": round5(floor),
                              "sagCm": round5(SideLyingArc.firmSurface.sag)] as [String: Any]
            // The floor side's deformed lower ribs stiffer (9e66086; gain ASSUMED ×2).
            cases.append(("deformed-floor-side", "floor-side ribs stiffer (deformed; assumed ×2)",
                          body.withDeformedSide().matchedToTidal(quiet, drive: drive)))
        }
        entry["cases"] = cases.map {
            sidedViewerCase(id: $0.0, label: $0.1, body: $0.2, drive: drive,
                            sizing: ["reference", "deformed-floor-side"].contains($0.0)
                                ? "quiet tidal volume (\(String(format: "%.2f", quiet)) L); the model's drive needed here ×\(String(format: "%.2f", rule.driveScale)) of seated"
                                : "same muscle drive as the reference")
        }
        if let bend = bendData(a, c.spine) { entry["bend"] = bend }
        postures.append(entry)
    }
    rulePosture("side-bend", "Seated, side-bend 20° to the left (stage 4)", BodyConfiguration.seated.with(SpineShape(sideBend: 20)))
    rulePosture("reclined", "Reclined 45° (backrest)", .reclined45)
    rulePosture("supine", "Lying on the back", .supine)
    rulePosture("knees-bent", "Lying on the back, knees bent, feet standing (Legs; sizes assumed)", BodyConfiguration.supine.with(Legs.kneesBent))
    rulePosture("right-side", "Lying on the right side (on the floor)", .rightSideDown, lyingOnSide: true)
    rulePosture("prone", "Lying face down", .prone)

    // Stage 7: the lesson, step by step (Lesson.swift). Each step shares its geometry with the
    // posture of the same gravity (the shapes don't change with tone or the spine's bend), so only
    // its breath is stored. The final rest also carries the slow-state hypotheses (H1 + H2, τ 5 min).
    do {
        let steps = lesson.steps
        var slow = SlowHypotheses(); slow.toneResidue = true; slow.useAndStillness = true
        let carried = Dictionary(uniqueKeysWithValues: LessonRunner.run(steps, slow, drive: drive).map { ($0.step.id, $0.carried) })
        var out: [String: SidedBreath] = [:]
        func breathOf(_ c: BodyConfiguration) -> SidedBreath {
            SidedBreath.measure(BodyGenerator.general(c, drive: drive).body.simulate(drive: drive), period: drive.period)
        }
        for (i, st) in steps.enumerated() {
            let c = st.configuration
            let rule = BodyGenerator.general(c, drive: drive)
            let m = SidedBreath.measure(rule.body.simulate(drive: drive), period: drive.period)
            out[st.id] = m
            let verdict = lessonVerdict(st, m, out, lesson: lesson, breath: breathOf)
            var cases: [(String, String, SidedBody)] = [("reference", "the step's breath", rule.body)]
            if st.id == lesson.before || st.id == lesson.after {
                var cs = c; cs.carried = carried[st.id]!
                cases.append(("slow", "with the slow state so far (H1 + H2, τ 5 min: a hypothesis)", BodyGenerator.general(cs, drive: drive).body))
            }
            let shape = c.spine.isNeutral ? "" : String(format: "spine: flexion %.0f/%.0f°, side-bend %.0f/%.0f° (lumbar/thoracic)",
                                                         c.spine.lumbarFlexion, c.spine.thoracicFlexion, c.spine.lumbarSideBend, c.spine.thoracicSideBend)
            var entry: [String: Any] = [
                "id": "lesson-" + st.id, "label": "\(i + 1). \(st.label)", "group": "Lesson: \(lesson.name)",
                "geometryFrom": c.posture == .upright ? "side-bend" : "supine",
                "lesson": ["index": i + 1, "total": steps.count, "label": st.label, "source": st.source, "relation": st.relation,
                           "minutes": st.minutes, "verdict": verdict, "note": st.note,
                           "configuration": [c.name, shape, c.tone.map(\.label).joined(separator: ", ")].filter { !$0.isEmpty }.joined(separator: " · "),
                           "provenance": "position \(st.position.rawValue), shape \(st.shape.rawValue), tone \(st.tone.rawValue)",
                           "drive": round5(rule.driveScale)] as [String: Any],
                "cases": cases.map { sidedViewerCase(id: $0.0, label: $0.1, body: $0.2, drive: drive,
                                                      sizing: "quiet tidal volume (\(String(format: "%.2f", quiet)) L)") },
            ]
            if let bend = bendData(c.posture == .upright ? AnatomyModel() : AnatomyModel.resting(gravity: c.gravity), c.spine) { entry["bend"] = bend }
            postures.append(entry)
        }
    }
    // Plausible alternatives (seated reference): end-inspiration paths on the reference's resting
    // shape, as `uncertainty --svg` draws them.
    let ref = seated.reference.anatomy
    var ghosts: [[String: Any]] = []
    for o in altOutcomes {
        var m = o.alternative.anatomy
        m.profile = ref.profile
        let svg = AnatomySVG(model: m, peak: AnatomyState(), drive: drive, magnify: 1, title: "", subtitle: "")
        let keep: Set<String> = ["side.front", "side.dome", "front.outline", "front.domes", "back.outline"]
        let rest = svg.rawLayers(AnatomyState()).filter { keep.contains($0.key) }
        let end = svg.rawLayers(o.endInspiration).filter { keep.contains($0.key) }
        ghosts.append(Dictionary(uniqueKeysWithValues: zip(rest, end).map { r, e in
            (r.key, ["view": r.view, "d": r.d, "delta": zip(pathNumbers(e.d), pathNumbers(r.d)).map { round5($0 - $1) }] as [String: Any])
        }))
    }
    report.append("alternatives: \(ghosts.count) seated bodies (seed 1)")
    let data: [String: Any] = [
        "period": drive.period, "inspiration": drive.dutyCycle * drive.period,
        "coordinates": A2Coordinate.allCases.map(\.label),
        "postures": postures, "ghosts": ghosts,
    ]
    return (try! JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]), report)
}

// MARK: - Blur (prototype)
//
// A model-driven blur: the trunk surface's outward (normal) motion, blurred ALONG the surface
// (not on screen, so light can't bridge gaps), at three widths, as a linear basis per A2
// coordinate. The page draws it on a front-facing figure: the front half on top, the back half as
// a softer, wider layer beneath, each vertex weighted by the projected area it stands for, so light
// per area means motion per area (no density artefacts). Per-vertex uncertainty, from the plausible
// alternatives, can soften the blur where the model isn't settled.

/// Trunk surface vertices: height z, angle ψ around the half-section, side.
struct SurfaceGrid {
    var z: [Double] = [], psi: [Double] = [], side: [Side] = []
    var u: [Double] = []      // signed arc length from the front midline (left +), cm
    var circ: [Double] = []   // circumference at that height, cm
    var area: [Double] = []   // surface area the vertex stands for, cm²
    var x2d: [Double] = []    // projected sideways position (front view), cm; left +
    var projArea: [Double] = [] // projected area in the front view, cm²
    var normal: [(x: Double, y: Double)] = []
    var count: Int { z.count }
}

func surfaceGrid(_ a: AnatomyModel) -> SurfaceGrid {
    var g = SurfaceGrid()
    let dz = 1.0, dpsi = 10.0 * .pi / 180
    for z in stride(from: 0.5, to: a.top, by: dz) {
        let sec = a.section(z, AnatomyState())
        let ap = sec.ap, b = ap / 2
        let w = sec.halfWidth[0]
        // Arc length from ψ = 0 to ψ along x = w sinψ, y = b(1 + cosψ).
        func arc(_ psi: Double) -> Double {
            let n = 60
            return (0..<n).reduce(0.0) { acc, i in
                let t = (Double(i) + 0.5) / Double(n) * psi
                return acc + (pow(w * cos(t), 2) + pow(b * sin(t), 2)).squareRoot() * psi / Double(n)
            }
        }
        let half = arc(.pi)
        for side in Side.allCases {
            let sign = side == .left ? 1.0 : -1.0
            for k in 0..<18 {
                let psiDeg = 5.0 + 10.0 * Double(k), psi = psiDeg * .pi / 180
                let ds = (pow(w * cos(psi), 2) + pow(b * sin(psi), 2)).squareRoot() * dpsi
                let nx = b * sin(psi), ny = w * cos(psi), nn = (nx * nx + ny * ny).squareRoot()
                g.z.append(z); g.psi.append(psiDeg); g.side.append(side)
                g.u.append(sign * arc(psi)); g.circ.append(2 * half)
                g.area.append(ds * dz)
                g.x2d.append(sign * w * sin(psi))
                g.projArea.append(max(0.05, abs(w * cos(psi)) * dpsi * dz))
                g.normal.append((nx / nn, ny / nn))
            }
        }
    }
    return g
}

/// Outward normal motion (cm) of every vertex for a state.
func normalMotion(_ a: AnatomyModel, _ g: SurfaceGrid, _ s: AnatomyState) -> [Double] {
    (0..<g.count).map { v in
        let d = a.surfaceDisplacement(z: g.z[v], psiDegrees: g.psi[v], side: g.side[v], s)
        return d.x * g.normal[v].x + d.y * g.normal[v].y
    }
}

/// Blur along the surface: a Gaussian in (arc length around the trunk, wrapping at the back
/// midline; height), area-weighted and normalised (total motion × area is kept).
func surfaceBlur(_ g: SurfaceGrid, sigma: Double) -> (([Double]) -> [Double]) {
    let n = g.count
    var rows: [[(Int, Double)]] = []
    rows.reserveCapacity(n)
    let cutoff = 3 * sigma
    for i in 0..<n {
        var row: [(Int, Double)] = [], total = 0.0
        for j in 0..<n {
            let dz = g.z[i] - g.z[j]
            if abs(dz) > cutoff { continue }
            let c = 0.5 * (g.circ[i] + g.circ[j])
            var du = abs(g.u[i] - g.u[j]).truncatingRemainder(dividingBy: c)
            du = min(du, c - du)
            if du > cutoff { continue }
            let w = exp(-(du * du + dz * dz) / (2 * sigma * sigma)) * g.area[j]
            row.append((j, w)); total += w
        }
        rows.append(row.map { ($0.0, $0.1 / total) })
    }
    return { f in rows.map { row in row.reduce(0.0) { $0 + $1.1 * f[$1.0] } } }
}

func round4(_ x: Double) -> Double {
    guard x != 0, x.isFinite else { return 0 }
    let m = pow(10, 4 - (log10(abs(x))).rounded(.up))
    return (x * m).rounded() / m
}

/// The blur data for one posture: vertices, and per blur width the blurred normal-motion basis
/// per A2 coordinate; optionally per-vertex relative uncertainty from alternative bodies.
func blurSurface(_ a: AnatomyModel, map: CoordinateMap? = nil, alternatives: [(anatomy: AnatomyModel, end: AnatomyState)] = [],
                 reference: AnatomyState? = nil) -> [String: Any] {
    let g = surfaceGrid(a)
    let map = map ?? .a2(a)
    let n = map.count, steps = map.steps
    let raw = (0..<n).map { i -> [Double] in
        var p = [Double](repeating: 0, count: n), m = p
        p[i] = steps[i]; m[i] = -steps[i]
        return zip(normalMotion(a, g, map.state(p)), normalMotion(a, g, map.state(m))).map { ($0 - $1) / (2 * steps[i]) }
    }
    var bases: [String: Any] = [:]
    for sigma in [2.0, 4.0, 8.0] {
        let blur = surfaceBlur(g, sigma: sigma)
        bases[String(Int(sigma))] = raw.map { blur($0).map(round4) }
    }
    var out: [String: Any] = [
        "x": g.x2d.map(round4), "z": g.z, "back": g.psi.map { $0 > 90 ? 1 : 0 },
        "projArea": g.projArea.map(round4), "bases": bases,
        "diaphragmBackShare": a.diaphragmBackShare,
    ]
    // Uncertainty: SD across alternatives of the (4 cm) blurred end-inspiration motion, relative
    // to the reference's own motion there (floored at 5% of its peak so quiet places don't blow up).
    if let refState = reference, !alternatives.isEmpty {
        let blur = surfaceBlur(g, sigma: 4)
        let ref = blur(normalMotion(a, g, refState))
        let alts = alternatives.map { alt -> [Double] in
            var m = alt.anatomy
            m.profile = a.profile
            return blur(normalMotion(m, g, alt.end))
        }
        let peak = ref.map(abs).max() ?? 1
        out["uncertainty"] = (0..<g.count).map { v -> Double in
            let xs = alts.map { $0[v] }
            let mean = xs.reduce(0, +) / Double(xs.count)
            let sd = (xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count - 1)).squareRoot()
            return round4(sd / max(abs(ref[v]), 0.05 * peak))
        }
    }
    return out
}

/// Stage 4: the spine's sideways curve for drawing (front and back views), from the side-bend angles.
func bendData(_ a: AnatomyModel, _ spine: SpineShape) -> [String: Any]? {
    guard spine.lumbarSideBend != 0 || spine.thoracicSideBend != 0 else { return nil }
    let zs = Array(stride(from: -3.0, through: 46.0, by: 0.5))
    let kl = spine.lumbarSideBend * .pi / 180 / (a.extensionPivot + 3)
    let kt = spine.thoracicSideBend * .pi / 180 / (a.top - a.extensionPivot)
    func tilt(_ z: Double) -> Double { kl * (min(z, a.extensionPivot) + 3) + kt * max(0, z - a.extensionPivot) }
    var x = 0.0, xs: [Double] = []
    for (i, z) in zs.enumerated() { if i > 0 { x += 0.5 * (tilt(z) + tilt(zs[i - 1])) * 0.5 }; xs.append(round5(x)) }
    return ["z": zs, "x": xs, "tilt": zs.map { round5(tilt($0)) }]
}
