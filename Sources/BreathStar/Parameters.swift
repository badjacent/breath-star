import Foundation

// Units throughout: volume in litres, pressure in cmH2O, time in seconds.
// Volumes are displacements from end-expiratory (relaxed) position.

public enum Side: Int, CaseIterable, Sendable {
    case left = 0, right = 1
}

/// How the body sits in gravity: the trunk's tilt back from vertical, and its
/// roll about the long axis once tilted. A support (chair back, bed, floor) is
/// assumed under whatever surface the weight rests on, as in every dataset so far.
public struct Posture: Sendable, Equatable {
    /// Trunk angle from vertical, degrees: 0 upright, 90 lying.
    public var tiltFromVertical: Double
    /// Roll when tilted, degrees: 0 on the back, +90 right side down, -90 left side down.
    /// Prone (±180) is out of scope: the front would be the loaded surface.
    public var roll: Double

    public init(tiltFromVertical: Double, roll: Double = 0) {
        precondition(abs(roll) <= 90, "roll beyond ±90° (towards prone) is not modelled")
        self.tiltFromVertical = tiltFromVertical
        self.roll = roll
    }

    public static let seated = Posture(tiltFromVertical: 0)
    public static let incline45 = Posture(tiltFromVertical: 45)
    public static let supine = Posture(tiltFromVertical: 90)
    public static let rightSideLying = Posture(tiltFromVertical: 90, roll: 90)
    public static let leftSideLying = Posture(tiltFromVertical: 90, roll: -90)

    private var tilt: Double { tiltFromVertical * .pi / 180 }
    private var rollRadians: Double { roll * .pi / 180 }

    /// Share of gravity along the body's long axis (1 upright, 0 lying).
    /// It hangs the abdominal contents from the diaphragm and the abdominal wall.
    public var axialGravity: Double { max(0, cos(tilt)) }

    /// Share of the trunk's weight pressing back onto the surface behind it
    /// (0 upright, even against a backrest; 1 lying on the back). It pins the
    /// back of the ribcage.
    public var backLoad: Double { max(0, sin(tilt) * cos(rollRadians)) }

    /// Share of the trunk's weight resting on one side's flank (1 for that side
    /// down, side-lying). It pins that side's ribcage and abdominal wall.
    public func sideLoad(_ side: Side) -> Double {
        let lateral = sin(tilt) * sin(rollRadians)  // + right down
        return max(0, side == .right ? lateral : -lateral)
    }

    public static func named(_ name: String) -> Posture? {
        switch name.lowercased() {
        case "seated", "sitting": return .seated
        case "incline45", "inclined", "45": return .incline45
        case "supine": return .supine
        case "right-side", "right-lateral", "right": return .rightSideLying
        case "left-side", "left-lateral", "left": return .leftSideLying
        default: return Double(name).map { Posture(tiltFromVertical: $0) }
        }
    }
}

/// Mechanical properties of one body, whole-body totals split equally left and
/// right. Values marked "textbook" are typical adult figures not yet tied to a
/// specific source; see reference/LITERATURE.md.
public struct BodyParameters: Sendable, Equatable {
    /// Lung compliance, both lungs, L/cmH2O (textbook ~0.2).
    public var lungCompliance: Double = 0.2
    /// Airway plus tissue resistance, whole lung, cmH2O·s/L (textbook ~2).
    public var resistance: Double = 2.0
    /// Ribcage compliance with nothing pressing on it, upper plus lower, L/cmH2O
    /// (textbook: chest wall ~0.2 split between ribcage and abdomen).
    public var ribcageCompliance: Double = 0.11
    /// Share of the free ribcage compliance in the upper (pulmonary) ribcage.
    /// Calibrated where a dataset reports the upper/lower split; else this default.
    public var upperRibcageFraction: Double = 0.6
    /// Abdominal wall compliance when lying (no axial gravity), L/cmH2O. Calibrated.
    public var abdomenComplianceLying: Double = 0.12
    /// How much upright gravity stiffens the abdominal wall (postural tone, stretched wall).
    /// Compliance = lying / (1 + stiffening × axialGravity). Calibrated.
    public var uprightAbdominalStiffening: Double = 1.0
    /// Fraction of the lower ribcage's inner surface that sees abdominal rather than
    /// pleural pressure (the zone of apposition). Fixed, unsourced.
    public var appositionFraction: Double = 0.6
    /// How much a supporting surface stiffens the wall it pins: the back of the
    /// ribcage under backLoad, a whole flank (ribcage and abdominal wall) under
    /// sideLoad. Compliance = free / (1 + stiffening × load). Calibrated on supine.
    public var contactStiffening: Double = 0
    /// How much more force the hemidiaphragm on the down side makes in side-lying
    /// (the viscera push it headward, lengthening it). Pdi × (1 + gain × sideLoad).
    /// Not calibrated (no source yet); 0 by default. See the working log (private), M1.
    public var dependentDiaphragmGain: Double = 0

    public init() {}

    public func upperRibcageCompliance(_ side: Side, in posture: Posture) -> Double {
        0.5 * ribcageCompliance * upperRibcageFraction / contact(side, posture, includesBack: true)
    }

    public func lowerRibcageCompliance(_ side: Side, in posture: Posture) -> Double {
        0.5 * ribcageCompliance * (1 - upperRibcageFraction) / contact(side, posture, includesBack: true)
    }

    public func abdomenCompliance(_ side: Side, in posture: Posture) -> Double {
        0.5 * abdomenComplianceLying / (1 + uprightAbdominalStiffening * posture.axialGravity)
            / contact(side, posture, includesBack: false)
    }

    /// Both sides together, for summaries.
    public func abdomenCompliance(in posture: Posture) -> Double {
        Side.allCases.reduce(0) { $0 + abdomenCompliance($1, in: posture) }
    }

    public func ribcageCompliance(in posture: Posture) -> Double {
        Side.allCases.reduce(0) {
            $0 + upperRibcageCompliance($1, in: posture) + lowerRibcageCompliance($1, in: posture)
        }
    }

    public func diaphragmGain(_ side: Side, in posture: Posture) -> Double {
        1 + dependentDiaphragmGain * posture.sideLoad(side)
    }

    private func contact(_ side: Side, _ posture: Posture, includesBack: Bool) -> Double {
        1 + contactStiffening * ((includesBack ? posture.backLoad : 0) + posture.sideLoad(side))
    }
}

/// The breathing drive: muscle pressures over one cycle.
public struct Drive: Sendable, Equatable {
    /// Breaths per minute.
    public var rate: Double = 16
    /// Inspiratory time as a fraction of the cycle (Mendes 2020: 0.40–0.42).
    public var dutyCycle: Double = 0.41
    /// Peak transdiaphragmatic pressure the diaphragm generates, cmH2O.
    public var diaphragmPeak: Double = 5.0
    /// Peak expanding pressure from ribcage inspiratory muscles (parasternals, scalenes),
    /// acting on upper and lower ribcage alike, cmH2O.
    public var ribcageMusclePeak: Double = 2.0
    /// Time constant of post-inspiratory relaxation, s.
    public var relaxationTime: Double = 0.25

    public init() {}

    public var period: Double { 60 / rate }

    /// Activation in 0...1 at time t: a smooth rise through inspiration, then decay.
    public func activation(at t: Double) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        let ti = dutyCycle * period
        if phase < ti {
            return 0.5 * (1 - cos(.pi * phase / ti))
        }
        // Decay, continued across the cycle boundary is negligible (period >> relaxationTime).
        return exp(-(phase - ti) / relaxationTime)
    }

    /// Activation for a muscle group that starts `onsetDelay` seconds after the others and rises
    /// over the rest of inspiration; every group releases together at the end of inspiration.
    public func activation(at t: Double, onsetDelay d: Double, relaxation tau: Double? = nil) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        let ti = dutyCycle * period
        if phase < d { return 0 }
        if phase < ti { return 0.5 * (1 - cos(.pi * (phase - d) / (ti - d))) }
        return exp(-(phase - ti) / (tau ?? relaxationTime))
    }

    /// Expiratory activation of the abdominal muscles: zero through inspiration, rising through
    /// expiration (augmenting, as transversus abdominis is described: Abe et al. 1996), peaking at 85%
    /// of expiratory time, back to zero as inspiration starts. The shape is ASSUMED.
    /// An external press held through expiration: rising over the first 10% of expiratory time, held,
    /// released over the last 10% (just before inspiration). Kouyama et al. 2016's manual assist; the
    /// ramps are ASSUMED.
    public func expiratoryPlateau(at t: Double) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        let ti = dutyCycle * period
        guard phase >= ti else { return 0 }
        let x = (phase - ti) / (period - ti)
        if x < 0.1 { let s = sin(.pi / 2 * x / 0.1); return s * s }
        if x > 0.9 { let c = cos(.pi / 2 * (x - 0.9) / 0.1); return c * c }
        return 1
    }

    public func expiratoryActivation(at t: Double) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        let ti = dutyCycle * period
        guard phase >= ti else { return 0 }
        let x = (phase - ti) / (period - ti)
        if x < 0.85 { let s = sin(.pi / 2 * x / 0.85); return s * s }
        let c = cos(.pi / 2 * (x - 0.85) / 0.15); return c * c
    }
}
