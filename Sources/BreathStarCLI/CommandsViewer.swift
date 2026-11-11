import BreathStar
import Foundation

// CLI commands: Viewer and visible uncertainty. Dispatched from main.swift.

/// `breathstar viewer`
func runViewer(_ args: ArraySlice<String>) {
    // Scrubbable HTML viewer of every A2 case, seated and supine: `viewer [--out PATH] [--lesson PATH]`
    // (default out/viewer.html; the lesson group shows the example lesson unless one is given).
    var path = "out/viewer.html"
    var lesson = Lessons.example
    var it = args.dropFirst().makeIterator()
    while let flag = it.next() {
        if flag == "--out", let v = it.next() { path = v }
        else if flag == "--lesson", let v = it.next() {
            do { lesson = try Lesson.load(path: v) } catch { fail("can't read lesson \(v): \(error)") }
        } else { fail("unknown option \(flag)") }
    }
    let (json, report) = viewerData(lesson: lesson)
    let html = viewerHTML.replacingOccurrences(of: "/*DATA*/null", with: String(decoding: json, as: UTF8.self))
    writeCreatingFolder(html, to: path)
    for line in report { print(line) }
    print("Wrote \(path) (\(html.utf8.count / 1024) KB).")
}

/// `breathstar uncertainty`
func runUncertainty(_ args: ArraySlice<String>) {
    // Alternative bodies (critique 2): `uncertainty [--count N] [--seed S]`.
    var count = 64, seed: UInt64 = 1, svgPath: String? = nil, ghostCount = 12
    var it = args.dropFirst().makeIterator()
    while let flag = it.next() {
        switch flag {
        case "--svg": svgPath = it.next()
        case "--ghosts": ghostCount = it.next().flatMap(Int.init) ?? ghostCount
        case "--count": count = it.next().flatMap(Int.init) ?? count
        case "--seed": seed = it.next().flatMap(UInt64.init) ?? seed
        default: fail("unknown option \(flag)")
        }
    }
    let outs = uncertaintyReport(count: count, seed: seed)
    if let path = svgPath {
        // The reference breath at end inspiration, with the first `ghostCount` alternatives under it.
        let ref = outs[0], drive = Drive()
        let cycle = lastCycle(ref.body, drive: drive)
        let svg = AnatomySVG(model: ref.body.anatomy, peak: AnatomyState(), simulated: (cycle.times, cycle.states, cycle.traces),
                             drive: drive, magnify: 4, title: "Breath Star — A2 seated: reference and \(min(ghostCount, outs.count - 1)) plausible alternatives",
                             subtitle: "Thin blue = alternative bodies at end inspiration (assumptions and marker means redrawn, refitted, recalibrated), "
                                 + "drawn on the reference's resting shape: where they spread, the motion isn't settled.",
                             still: true,
                             ghosts: outs.dropFirst().prefix(ghostCount).map { ($0.alternative.anatomy, $0.endInspiration) })
        writeCreatingFolder(svg.render(), to: path)
        print("\nWrote \(path).")
    }
}


/// Write text to a path, creating its folder first (`out/` is not in a fresh clone).
func writeCreatingFolder(_ text: String, to path: String) {
    let dir = (path as NSString).deletingLastPathComponent
    do {
        if !dir.isEmpty { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    } catch { fail("can't write \(path): \(error)") }
}
