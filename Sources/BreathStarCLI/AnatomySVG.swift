import BreathStar
import Foundation

/// Regional volume changes at one instant, litres (one observation contract per mode).
struct VolumeTrace {
    var lung, upper, lower, abdomen: Double
}

/// Renderer: an animated SVG (SMIL) of one breath, side and front views of the trunk, with the
/// end-expiratory outline underneath and regional volume traces beside it. Two modes:
///  - simulated (A2): plays the solver's own states and traces at the same instants;
///    nothing is reconstructed;
///  - prescribed (A1): a peak pose scaled by the drive's activation, the abdomen closed by A1's
///    rule, traces from A1's observations. Labelled as prescribed.
/// Displacements are magnified by one declared factor; the traces are true scale.
struct AnatomySVG {
    var model: AnatomyModel
    /// Prescribed mode: peak state of the breath (end inspiration), before magnification.
    var peak: AnatomyState
    /// Simulated mode: the solver's states and volumes over one breath (times from 0 to period).
    var simulated: (times: [Double], states: [AnatomyState], traces: [VolumeTrace])? = nil
    var drive: Drive
    var magnify: Double
    var title: String
    var subtitle: String
    /// Draw end inspiration only (no animation), over the end-expiratory outline.
    var still = false
    /// Equally plausible alternative bodies at end inspiration (their own geometry, unmagnified
    /// state), drawn as thin translucent outlines under the reference (`breathstar uncertainty`).
    var ghosts: [(model: AnatomyModel, state: AnatomyState)] = []

    let frames = 48
    let k = 9.0  // px per cm

    func render() -> String {
        let period = drive.period
        var times = still ? [drive.dutyCycle * period] : (0..<frames).map { Double($0) / Double(frames) * period }
        // Prescribed mode: the breath follows the drive's activation; each frame's state is the
        // peak scaled, with the abdomen re-closed by A1's rule.
        var states: [AnatomyState] = times.map { t in
            let a = drive.activation(at: t)
            var s = AnatomyState()
            s.upperRib = peak.upperRib.map { $0 * a }
            s.lowerRib = peak.lowerRib.map { $0 * a }
            s.lowerPump = peak.lowerPump.map { $0 * a }
            s.diaphragm = peak.diaphragm.map { $0 * a }
            s.upperDilation = peak.upperDilation.map { $0 * a }
            s.lowerDilation = peak.lowerDilation.map { $0 * a }
            s.lowerDilationAP = peak.lowerDilationAP * a
            s.spineExtension = peak.spineExtension * a
            return model.closeAbdomen(s)
        }
        var traceData = states.map { st -> VolumeTrace in
            let o = model.observe(st)
            return VolumeTrace(lung: o.totalLung, upper: o.upperRibcage.reduce(0, +),
                               lower: o.lowerRibcage.reduce(0, +), abdomen: o.abdomen.reduce(0, +))
        }
        if let sim = simulated {
            // Simulated mode: the solver's own states and volumes, unmodified.
            if still {
                let i = sim.traces.indices.max { sim.traces[$0].lung < sim.traces[$1].lung }!
                times = [sim.times[i]]; states = [sim.states[i]]; traceData = [sim.traces[i]]
            } else {
                times = sim.times; states = sim.states; traceData = sim.traces
            }
        }
        let drawn = states.map(magnified)
        let rest = AnatomyState()

        let W = 1420.0, H = 640.0
        var out = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(W)) \(Int(H))" font-family="-apple-system, Helvetica, sans-serif" font-size="13">
        <rect width="\(Int(W))" height="\(Int(H))" fill="#fbfaf7"/>
        <text x="24" y="32" font-size="18" font-weight="600" fill="#222">\(title)</text>
        <text x="24" y="54" fill="#555">\(subtitle)</text>
        <text x="24" y="74" fill="#555">Motion magnified ×\(fmt(magnify, 0)); grey dashed = end expiration. \(still ? "Coloured = end inspiration." : "One breath, \(fmt(period, 2)) s, looping.")</text>

        """
        let dur = "\(fmt(period, 3))s"

        // Side view: forward to the right, back (spine) on the left.
        let sx = 150.0, sy = 560.0
        func side(_ y: Double, _ z: Double) -> String { "\(fmt(sx + y * k, 1)),\(fmt(sy - z * k, 1))" }
        out += "<text x=\"\(sx)\" y=\"\(sy + 34)\" fill=\"#333\" font-weight=\"600\">Side (left side facing you; front to the right)</text>\n"
        // The back (the spine line) moves with spine extension; drawn from the same field.
        out += staticPath(sideBack(rest, side), dashed: true)
        out += animatedPath(drawn.map { sideBack($0, side) }, stroke: "#8a7f72", width: 6, dur: dur)
        out += "<text x=\"\(sx - 8)\" y=\"\(fmt(sy - model.top * k - 10, 1))\" fill=\"#8a7f72\" font-size=\"11\" text-anchor=\"middle\">spine</text>\n"
        out += landmarkLines(x0: sx - 20, x1: sx + 300, sy: sy)
        func ghostPaths(_ draw: (AnatomySVG, AnatomyState) -> String) -> String {
            ghosts.map { g in
                // Drawn on the reference's resting profile, so the spread is motion, not rest shape.
                var r = self
                r.model = g.model
                r.model.profile = model.profile
                return "<path d=\"\(draw(r, r.magnified(g.state)))\" fill=\"none\" stroke=\"#5a8fc0\" stroke-width=\"1\" stroke-opacity=\"0.35\"/>\n"
            }.joined()
        }
        out += ghostPaths { $0.sideFront($1, side) } + ghostPaths { $0.sideDome($1, side) }
        out += staticPath(sideFront(rest, side), dashed: true)
        out += staticPath(sideDome(rest, side), dashed: true)
        out += animatedPath(drawn.map { sideFront($0, side) }, stroke: "#c0603a", width: 2.5, dur: dur)
        for rib in sideRibs(drawn, side) { out += animatedPath(rib, stroke: "#b08d6e", width: 1.8, dur: dur) }
        out += animatedPath(drawn.map { sideDome($0, side) }, stroke: "#3a7cc0", width: 2.5, dur: dur)
        out += "<text x=\"\(fmt(sx + 7 * k, 1))\" y=\"\(fmt(sy - 31.5 * k, 1))\" fill=\"#3a7cc0\" font-size=\"11\">diaphragm</text>\n"
        out += "<text x=\"\(fmt(sx + 22 * k, 1))\" y=\"\(fmt(sy - 38 * k, 1))\" fill=\"#b08d6e\" font-size=\"11\">ribs</text>\n"

        // Front view: the body's left on the viewer's right (facing the person).
        let fx = 600.0, fy = 560.0
        // Facing the person: their left (x > 0) appears on the viewer's right. (Fixed 2026-11-09: it
        // was mirrored; invisible for symmetric breaths.)
        func front(_ x: Double, _ z: Double) -> String { "\(fmt(fx + x * k, 1)),\(fmt(fy - z * k, 1))" }
        out += "<text x=\"\(fmt(fx - 120, 1))\" y=\"\(fy + 34)\" fill=\"#333\" font-weight=\"600\">Front (facing the person)</text>\n"
        out += ghostPaths { $0.frontOutline($1, front) } + ghostPaths { $0.frontDomes($1, front) }
        out += staticPath(frontOutline(rest, front), dashed: true)
        out += staticPath(frontDomes(rest, front), dashed: true)
        out += animatedPath(drawn.map { frontOutline($0, front) }, stroke: "#c0603a", width: 2.5, dur: dur)
        for rib in frontRibs(drawn, front) { out += animatedPath(rib, stroke: "#b08d6e", width: 1.8, dur: dur) }
        out += animatedPath(drawn.map { frontDomes($0, front) }, stroke: "#3a7cc0", width: 2.5, dur: dur)
        out += "<line x1=\"\(fx)\" y1=\"\(fy)\" x2=\"\(fx)\" y2=\"\(fmt(fy - model.top * k, 1))\" stroke=\"#8a7f72\" stroke-width=\"1\" stroke-dasharray=\"2 4\"/>\n"

        // Back view: the outline from behind (the person's left on the viewer's left), with the
        // posterolateral ribs' motion as vectors at an extra stated gain (they move under 1 mm).
        let bx = 940.0, by = 560.0, vectorGain = 4.0
        // From behind: the person's left (x > 0) appears on the viewer's left.
        func back(_ x: Double, _ z: Double) -> String { "\(fmt(bx - x * k, 1)),\(fmt(by - z * k, 1))" }
        out += "<text x=\"\(fmt(bx - 110, 1))\" y=\"\(by + 34)\" fill=\"#333\" font-weight=\"600\">Back (seen from behind)</text>\n"
        out += "<text x=\"\(fmt(bx - 150, 1))\" y=\"\(by + 52)\" fill=\"#7a6a9a\" font-size=\"11\">purple: back ribs' motion (out, up), ×\(fmt(vectorGain, 0)) more</text>\n"
        out += ghostPaths { $0.frontOutline($1, back) }
        out += staticPath(frontOutline(rest, back), dashed: true)
        out += animatedPath(drawn.map { frontOutline($0, back) }, stroke: "#c0603a", width: 2.5, dur: dur)
        out += "<line x1=\"\(bx)\" y1=\"\(by)\" x2=\"\(bx)\" y2=\"\(fmt(by - model.top * k, 1))\" stroke=\"#8a7f72\" stroke-width=\"4\" stroke-linecap=\"round\"/>\n"
        for z in [19.0, 21.5, 24.0, 28.0, 32.0, 36.0] {
            for side in [Side.left, .right] {
                let sign = side == .left ? 1.0 : -1.0
                let w = model.section(z, AnatomyState()).halfWidth[side.rawValue]
                let x0 = w * sin(135 * .pi / 180)
                let frames = drawn.map { st -> String in
                    let d = model.surfaceDisplacement(z: z, psiDegrees: 135, side: side, st)
                    return "M" + back(sign * x0, z) + " L" + back(sign * (x0 + d.x * vectorGain), z + d.z * vectorGain)
                }
                out += animatedPath(frames, stroke: "#7a6a9a", width: 2.2, dur: dur)
                out += "<circle cx=\"\(fmt(bx - sign * x0 * k, 1))\" cy=\"\(fmt(by - z * k, 1))\" r=\"2\" fill=\"#7a6a9a\"/>\n"
            }
        }

        // Traces: regional volume changes over the breath.
        if !still { out += traces(traceData, times: times, period: period, x0: 1150, y0: 150, w: 240, h: 330, dur: dur) }
        out += "</svg>\n"
        return out
    }

    func magnified(_ s: AnatomyState) -> AnatomyState {
        var m = s
        m.upperRib = s.upperRib.map { $0 * magnify }
        m.lowerRib = s.lowerRib.map { $0 * magnify }
        m.lowerPump = s.lowerPump.map { $0 * magnify }
        m.diaphragm = s.diaphragm.map { $0 * magnify }
        m.upperDilation = s.upperDilation.map { $0 * magnify }
        m.lowerDilation = s.lowerDilation.map { $0 * magnify }
        m.lowerDilationAP = s.lowerDilationAP * magnify
        m.spineExtension = s.spineExtension * magnify
        m.abdomenFront = s.abdomenFront * magnify
        m.abdomenFlank = s.abdomenFlank.map { $0 * magnify }
        return m
    }

    // MARK: side view

    func zSamples() -> [Double] { stride(from: 0.0, through: model.top, by: 0.5).map { $0 } }

    func sideBack(_ s: AnatomyState, _ p: (Double, Double) -> String) -> String {
        let pts = zSamples().map { z -> String in
            let d = model.surfaceDisplacement(z: z, psiDegrees: 180, side: .left, s)
            return p(d.y, z + d.z)
        }
        return "M" + pts.joined(separator: " L")
    }

    func sideFront(_ s: AnatomyState, _ p: (Double, Double) -> String) -> String {
        let pts = zSamples().map { z -> String in
            let ap = model.section(z, AnatomyState()).ap
            let d = model.surfaceDisplacement(z: z, psiDegrees: 0, side: .left, s)
            return p(ap + d.y, z + d.z)
        }
        return "M" + pts.joined(separator: " L")
    }

    /// Ribs drawn from head (at the spine) to front end, rotated by the pump angle.
    func sideRibs(_ states: [AnatomyState], _ p: (Double, Double) -> String) -> [[String]] {
        let ribs: [(head: Double, upper: Bool)] = [(42, true), (38.5, true), (35, true), (34.5, false), (31.5, false)]
        return ribs.map { rib in
            states.map { s in
                let drop = rib.upper ? model.upperRibDrop : model.lowerRibDrop
                let zFront = rib.head - drop
                let ap = model.section(zFront, AnatomyState()).ap
                let pumpDeg = rib.upper ? model.upperPumpDegrees : model.lowerPumpDegrees
                let r = rib.upper ? s.upperRib[0] : (s.lowerPump ?? s.lowerRib[0])
                let phi = r * pumpDeg * .pi / 180
                // Dilation opens the rib about the spine: forward distances scale by (1 + ε).
                let e = 1 + (rib.upper ? 0.5 * (s.upperDilation[0] + s.upperDilation[1]) : s.lowerDilationAP)
                let fy = (ap * cos(phi) + drop * sin(phi)) * e
                let fz = rib.head + ap * sin(phi) - drop * cos(phi)
                // Spine extension moves the whole rib with the trunk (same field as the surface).
                func moved(_ y: Double, _ z: Double) -> String {
                    let o = model.extensionOffset(y: y, z: z, s)
                    return p(y + o.dy, z + o.dz)
                }
                return "M" + moved(0, rib.head) + " Q" + moved(ap * 0.55 * e, rib.head - drop * 0.15 + ap * 0.55 * sin(phi))
                    + " " + moved(fy, fz)
            }
        }
    }

    /// Schematic dome in the midsagittal plane: up the back wall (the posterior zone of
    /// apposition), over the dome, down to the front. Its shape is assumed; its descent is
    /// the model's.
    func sideDome(_ s: AnatomyState, _ p0: (Double, Double) -> String) -> String {
        // The dome moves with spine extension too (same field as the ribs and the surface).
        func p(_ y: Double, _ z: Double) -> String {
            let o = model.extensionOffset(y: y, z: z, s)
            return p0(y + o.dy, z + o.dz)
        }
        let mean = 0.5 * (s.diaphragm[0] + s.diaphragm[1])
        // Descent at a fraction f of the depth measured from the back: u = 1 − 2f (back +1,
        // front −1). The back descends more (`diaphragmTilt`).
        func d(_ f: Double) -> Double { model.diaphragmDescent(mean, at: 1 - 2 * f) }
        let apAt = { (z: Double) in self.model.section(z, AnatomyState()).ap }
        let back0 = p(0.6, 13), backTop = p(0.8, 24 - d(0))
        let apex = p(apAt(28) * 0.42, 30.5 - d(0.42))
        let frontEnd = p(apAt(25) * 0.93, 25.2)
        let c1 = p(0.9, 29 - d(0.03)), c2 = p(apAt(28) * 0.2, 30.8 - d(0.2))
        let c3 = p(apAt(27) * 0.75, 30.2 - d(0.75)), c4 = p(apAt(26) * 0.9, 27.5 - d(0.9) * 0.6)
        return "M\(back0) L\(backTop) C\(c1) \(c2) \(apex) C\(c3) \(c4) \(frontEnd)"
    }

    // MARK: front view

    func frontOutline(_ s: AnatomyState, _ p: (Double, Double) -> String) -> String {
        let zs = zSamples()
        func lateral(_ side: Side, _ z: Double) -> (Double, Double) {
            let w = model.section(z, AnatomyState()).halfWidth[side.rawValue]
            let d = model.surfaceDisplacement(z: z, psiDegrees: 90, side: side, s)
            return (w + d.x, z + d.z)
        }
        let left = zs.map { lateral(.left, $0) }.map { p($0.0, $0.1) }
        let right = zs.reversed().map { lateral(.right, $0) }.map { p(-$0.0, $0.1) }
        return "M" + left.joined(separator: " L") + " M" + right.joined(separator: " L")
    }

    /// Rib arcs: from the front midline out to the side, each side.
    func frontRibs(_ states: [AnatomyState], _ p: (Double, Double) -> String) -> [[String]] {
        let ribs: [(zFront: Double, zSide: Double, upper: Bool)] = [(37, 39, true), (32, 34.5, true), (27, 30, true), (22.5, 26.5, false), (19, 23, false)]
        return ribs.map { rib in
            states.map { s in
                var segs: [String] = []
                for side in [Side.left, .right] {
                    let sign = side == .left ? 1.0 : -1.0
                    let w = model.section(rib.zSide, AnatomyState()).halfWidth[side.rawValue]
                    let dFront = model.surfaceDisplacement(z: rib.zFront, psiDegrees: 0, side: side, s)
                    let dSide = model.surfaceDisplacement(z: rib.zSide, psiDegrees: 90, side: side, s)
                    let a = p(sign * 2, rib.zFront + dFront.z)
                    let c = p(sign * (w + dSide.x) * 0.85, rib.zFront + dFront.z + 0.2 * (rib.zSide - rib.zFront))
                    let b = p(sign * (w + dSide.x) * 0.97, rib.zSide + dSide.z)
                    segs.append("M\(a) Q\(c) \(b)")
                }
                return segs.joined(separator: " ")
            }
        }
    }

    /// Both hemidiaphragm domes in the coronal plane: up each lateral wall (the lateral zone
    /// of apposition), over each dome, meeting at the central tendon.
    func frontDomes(_ s: AnatomyState, _ p: (Double, Double) -> String) -> String {
        var parts: [String] = []
        let center = 0.5 * (s.diaphragm[0] + s.diaphragm[1])
        for side in [Side.left, .right] {
            let sign = side == .left ? 1.0 : -1.0
            let d = s.diaphragm[side.rawValue]
            let w = { (z: Double) in self.model.section(z, AnatomyState()).halfWidth[side.rawValue] - 0.6 }
            let start = p(sign * w(17), 17), wallTop = p(sign * w(22), 23 - d)
            let c1 = p(sign * w(26), 28.5 - d), apex = p(sign * w(28) * 0.5, 30 - d)
            let c2 = p(sign * w(28) * 0.18, 30 - d), tendon = p(0, 27.5 - center)
            parts.append("M\(start) L\(wallTop) Q\(c1) \(apex) Q\(c2) \(tendon)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: drawing helpers

    func landmarkLines(x0: Double, x1: Double, sy: Double) -> String {
        [(model.top, "top of ribcage"), (model.xiphoid, "xiphoid"), (model.costalMargin, "costal margin"), (0, "iliac crest")]
            .map { z, label in
                let y = fmt(sy - z * k, 1)
                return "<line x1=\"\(x0)\" y1=\"\(y)\" x2=\"\(x1)\" y2=\"\(y)\" stroke=\"#e4ddd2\" stroke-width=\"1\"/>"
                    + "<text x=\"\(x0 - 4)\" y=\"\(y)\" dy=\"4\" fill=\"#a99f92\" font-size=\"10\" text-anchor=\"end\">\(label)</text>\n"
            }.joined()
    }

    func staticPath(_ d: String, dashed: Bool) -> String {
        "<path d=\"\(d)\" fill=\"none\" stroke=\"#9a9a9a\" stroke-width=\"1.2\"\(dashed ? " stroke-dasharray=\"4 3\"" : "")/>\n"
    }

    func animatedPath(_ frames: [String], stroke: String, width: Double, dur: String) -> String {
        if frames.count == 1 {
            return "<path d=\"\(frames[0])\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(width)\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>\n"
        }
        let values = (frames + [frames[0]]).joined(separator: ";")
        return "<path d=\"\(frames[0])\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(width)\" stroke-linejoin=\"round\" stroke-linecap=\"round\">"
            + "<animate attributeName=\"d\" dur=\"\(dur)\" repeatCount=\"indefinite\" values=\"\(values)\"/></path>\n"
    }

    func traces(_ o: [VolumeTrace], times: [Double], period: Double,
                x0: Double, y0: Double, w: Double, h: Double, dur: String) -> String {
        let series: [(String, String, [Double])] = [
            ("lung (total)", "#333", o.map(\.lung)),
            ("upper ribcage", "#c0603a", o.map(\.upper)),
            ("lower ribcage", "#b08d6e", o.map(\.lower)),
            ("abdomen", "#3a7cc0", o.map(\.abdomen)),
        ]
        let vmax = max(0.001, series.flatMap { $0.2 }.max()!), vmin = min(0, series.flatMap { $0.2 }.min()!)
        func px(_ t: Double) -> Double { x0 + t / period * w }
        func py(_ v: Double) -> Double { y0 + h - (v - vmin) / (vmax - vmin) * h }
        var out = "<text x=\"\(x0)\" y=\"\(y0 - 16)\" fill=\"#333\" font-weight=\"600\">Volume change, litres (true scale)</text>\n"
        out += "<line x1=\"\(x0)\" y1=\"\(fmt(py(0), 1))\" x2=\"\(x0 + w)\" y2=\"\(fmt(py(0), 1))\" stroke=\"#ddd\"/>\n"
        for (i, (label, color, values)) in series.enumerated() {
            let pts = zip(times, values).map { "\(fmt(px($0), 1)),\(fmt(py($1), 1))" }.joined(separator: " ")
            out += "<polyline fill=\"none\" stroke=\"\(color)\" stroke-width=\"2\" points=\"\(pts)\"/>\n"
            out += "<text x=\"\(x0)\" y=\"\(fmt(y0 + h + 26 + Double(i) * 17, 1))\" fill=\"\(color)\">\(label): peak \(fmt(values.max()!, 2)) L</text>\n"
        }
        out += "<line y1=\"\(y0)\" y2=\"\(y0 + h)\" x1=\"\(x0)\" x2=\"\(x0)\" stroke=\"#999\"><animate attributeName=\"x1\" from=\"\(x0)\" to=\"\(x0 + w)\" dur=\"\(dur)\" repeatCount=\"indefinite\"/>"
            + "<animate attributeName=\"x2\" from=\"\(x0)\" to=\"\(x0 + w)\" dur=\"\(dur)\" repeatCount=\"indefinite\"/></line>\n"
        return out
    }

    func fmt(_ x: Double, _ digits: Int) -> String { String(format: "%.\(digits)f", x) }
}
