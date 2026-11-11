/// Where one breath went: the summary the plan calls "distribution" and "phase".
/// Excursions are peak-to-trough over the last full cycle, in litres.
public struct Distribution: Sendable, Equatable {
    public var tidalVolume: Double
    public var upperRibcageExcursion: Double
    public var lowerRibcageExcursion: Double
    public var abdomenExcursion: Double
    /// Per side: what a surface method sees (both ribcage parts plus abdominal wall),
    /// and what that side's lung takes in. Index by Side.rawValue.
    public var surfaceExcursion: [Double]
    public var lungExcursion: [Double]
    public var lowerRibcageExcursionBySide: [Double]
    /// Lag of the abdomen's peak behind the ribcage's, degrees of the cycle.
    /// Negative: the abdomen peaks first. Near ±180: see-saw.
    public var abdomenLagDegrees: Double

    private var compartmentSum: Double { upperRibcageExcursion + lowerRibcageExcursion + abdomenExcursion }
    /// Amplitude shares: each compartment's peak-to-trough swing over the sum of swings, 0...1.
    /// NOT a signed contribution: a region moving inward while the lung fills still counts
    /// as a positive share here. Signed contributions are still to do (see the work plan (private)).
    public var upperRibcageShare: Double { upperRibcageExcursion / compartmentSum }
    public var lowerRibcageShare: Double { lowerRibcageExcursion / compartmentSum }
    public var ribcageShare: Double { upperRibcageShare + lowerRibcageShare }
    public var abdomenShare: Double { abdomenExcursion / compartmentSum }
}

public enum Metrics {
    /// Measures the last full cycle of a run (earlier cycles are settling).
    public static func distribution(_ samples: [Sample], period: Double) -> Distribution {
        guard let last = samples.last else {
            return Distribution(tidalVolume: 0, upperRibcageExcursion: 0, lowerRibcageExcursion: 0,
                                abdomenExcursion: 0, surfaceExcursion: [0, 0], lungExcursion: [0, 0],
                                lowerRibcageExcursionBySide: [0, 0], abdomenLagDegrees: 0)
        }
        let start = last.time - period
        let cycle = samples.filter { $0.time >= start }

        func excursion(_ value: (Sample) -> Double) -> Double {
            var lo = Double.infinity, hi = -Double.infinity
            for s in cycle { let v = value(s); lo = min(lo, v); hi = max(hi, v) }
            return hi - lo
        }
        func peakTime(_ value: (Sample) -> Double) -> Double {
            cycle.max { value($0) < value($1) }?.time ?? 0
        }

        var lag = (peakTime(\.abdomenVolume) - peakTime(\.ribcageVolume)) / period * 360
        if lag > 180 { lag -= 360 }
        if lag < -180 { lag += 360 }

        return Distribution(
            tidalVolume: excursion(\.lungVolume),
            upperRibcageExcursion: excursion(\.upperRibcageVolume),
            lowerRibcageExcursion: excursion(\.lowerRibcageVolume),
            abdomenExcursion: excursion(\.abdomenVolume),
            surfaceExcursion: Side.allCases.map { s in excursion { $0.side(s).surfaceVolume } },
            lungExcursion: Side.allCases.map { s in excursion { $0.side(s).lungVolume } },
            lowerRibcageExcursionBySide: Side.allCases.map { s in excursion { $0.side(s).lowerRibcageVolume } },
            abdomenLagDegrees: lag)
    }

    public static func distribution(body: BodyParameters, drive: Drive = Drive(), posture: Posture, cycles: Int = 4) -> Distribution {
        let sim = Simulation(body: body, drive: drive, posture: posture)
        return distribution(sim.run(cycles: cycles), period: drive.period)
    }
}
