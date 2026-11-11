import Foundation

/// Calibration: five numbers per dataset (four where it lacks the upper/lower
/// ribcage split), fitted to its upright and supine points.
///
/// Each posture effect is tied to one component of gravity, so each end of the
/// range isolates part of the fit:
///
/// - Seated (all gravity axial, nothing pressing on any wall): the ribcage is
///   free. The upper-ribcage and abdomen shares fix how the free ribcage
///   compliance splits upper/lower and the upright abdominal compliance; the
///   tidal volume fixes the overall drive (the model is linear: drive scales
///   volume without changing shares).
/// - Supine (no axial gravity, full load on the back): the abdomen is at its
///   lying compliance and the ribcage is pinned. The abdomen share and the tidal
///   volume fix those two jointly. Supine's upper/lower split is then predicted.
///
/// The 45° point and every side-lying result are not fitted. 45° has guided changes
/// to the angle law, so it is a development check rather than an untouched test.
public enum Calibration {
    public struct Result: Sendable {
        public var body: BodyParameters
        public var drive: Drive

        public func distribution(_ posture: Posture, cycles: Int = 4) -> Distribution {
            Metrics.distribution(body: body, drive: drive, posture: posture, cycles: cycles)
        }
    }

    /// Calibration simulates short, coarse runs; `Engine.calibrationRunsConverge` checks this is safe.
    static let cycles = 2
    static let timeStep = 0.004

    public static func fit(_ sex: Reference.Sex) -> Result {
        fit(Reference.mendes2020(sex))
    }

    /// Fits with default body and drive, cached by dataset id (fits are deterministic).
    public static func fit(_ data: Reference.Dataset) -> Result {
        if let hit = cache.get(data.id) { return hit }
        let result = fit(data, base: BodyParameters(), drive: Drive())
        cache.set(data.id, result)
        return result
    }

    public static func fit(_ data: Reference.Dataset, base: BodyParameters, drive base0: Drive) -> Result {
        // 1. Seated: upper-ribcage share → upper/lower split (outer search),
        //    abdomen share → upright abdominal compliance (inner search).
        var body = base
        body.uprightAbdominalStiffening = 0
        body.contactStiffening = 0
        func seatedCompliance(_ b: BodyParameters) -> Double? {
            solveCompliance(target: data.seated.abdomenShare / 100, posture: .seated, body: b, drive: base0)
        }
        if let donor = data.borrowsRibcageSplitFrom,
           let donorData = Reference.datasets.first(where: { $0.id == donor }) {
            body.upperRibcageFraction = fit(donorData).body.upperRibcageFraction
        } else if let upperTarget = data.seated.upperRibcageShare.map({ $0 / 100 }) {
            func upperShare(_ fraction: Double) -> Double? {
                var b = body
                b.upperRibcageFraction = fraction
                guard let c = seatedCompliance(b) else { return nil }
                b.abdomenComplianceLying = c
                return measure(b, base0, .seated).upperRibcageShare
            }
            // More of the compliance in the upper ribcage → larger upper share.
            var lo = 0.02, hi = 0.98
            guard let shareLo = upperShare(lo), let shareHi = upperShare(hi),
                  shareLo < upperTarget, shareHi > upperTarget else {
                preconditionFailure("\(data.id): seated upper-ribcage share out of reach")
            }
            for _ in 0..<30 {
                let mid = 0.5 * (lo + hi)
                if (upperShare(mid) ?? 0) < upperTarget { lo = mid } else { hi = mid }
            }
            body.upperRibcageFraction = 0.5 * (lo + hi)
        }
        guard let seated = seatedCompliance(body) else {
            preconditionFailure("\(data.id): seated abdomen share out of reach")
        }
        body.abdomenComplianceLying = seated
        var drive = base0
        let scale = data.seated.tidalVolume / measure(body, drive, .seated).tidalVolume
        drive.diaphragmPeak *= scale
        drive.ribcageMusclePeak *= scale

        // 2. Supine: for each contact stiffening, the lying compliance that
        //    matches the abdomen share; then the stiffening whose tidal volume
        //    matches. A more pinned ribcage moves less and needs a stiffer abdomen
        //    to keep the share, so tidal volume falls as stiffening rises.
        let supineShare = data.supine.abdomenShare / 100
        func supine(_ c: Double) -> (compliance: Double, volume: Double)? {
            var b = body
            b.contactStiffening = c
            guard let lying = solveCompliance(target: supineShare, posture: .supine, body: b, drive: drive) else {
                return nil
            }
            b.abdomenComplianceLying = lying
            return (lying, measure(b, drive, .supine).tidalVolume)
        }
        let target = data.supine.tidalVolume
        func tooLittle(_ c: Double) -> Bool { supine(c).map { $0.volume < target } ?? true }
        var lo = 0.0, hi = 50.0  // contact can only stiffen
        precondition(!tooLittle(lo) && tooLittle(hi), "\(data.id): supine tidal volume \(target) out of reach")
        for _ in 0..<40 {
            let mid = 0.5 * (lo + hi)
            if tooLittle(mid) { hi = mid } else { lo = mid }
        }
        let lying = supine(lo)!.compliance

        body.contactStiffening = lo
        body.abdomenComplianceLying = lying
        body.uprightAbdominalStiffening = lying / seated - 1
        return Result(body: body, drive: drive)
    }

    static func measure(_ body: BodyParameters, _ drive: Drive, _ posture: Posture) -> Distribution {
        let sim = Simulation(body: body, drive: drive, posture: posture, timeStep: timeStep)
        return Metrics.distribution(sim.run(cycles: cycles), period: drive.period)
    }

    /// The abdominal compliance (in the given posture, with upright stiffening
    /// off) at which the abdomen's share equals target, by bisection; the share
    /// rises with compliance. nil if out of reach.
    static func solveCompliance(target: Double, posture: Posture, body base: BodyParameters,
                                drive: Drive) -> Double? {
        func share(_ c: Double) -> Double {
            var body = base
            body.abdomenComplianceLying = c
            body.uprightAbdominalStiffening = 0
            return measure(body, drive, posture).abdomenShare
        }
        var lo = 0.001, hi = 2.0
        guard share(lo) < target && share(hi) > target else { return nil }
        for _ in 0..<40 {
            let mid = 0.5 * (lo + hi)
            if share(mid) < target { lo = mid } else { hi = mid }
        }
        return 0.5 * (lo + hi)
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var results: [String: Result] = [:]
        func get(_ key: String) -> Result? { lock.withLock { results[key] } }
        func set(_ key: String, _ value: Result) { lock.withLock { results[key] = value } }
    }
    private static let cache = Cache()
}
