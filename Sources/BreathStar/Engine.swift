// M1: six chest-wall compartments, two lungs, two hemidiaphragms, one abdomen.
//
// Per side s (left, right), with that side's lung, pleural space and hemidiaphragm:
//
//   Lung:          Ppl_s = -(Vl_s / CL_s) - R_s · dVl_s/dt       (airway open at 0)
//   Hemidiaphragm: Pab - Ppl_s = Pdi_s                            (muscle pressure)
//   Upper ribcage: Vrcp_s = Crcp_s · (Ppl_s + Prc)                (sees pleural pressure)
//   Lower ribcage: Vrca_s = Crca_s · ((1-f)·Ppl_s + f·Pab + Prc)  (f: zone of apposition)
//   Thorax:        Vl_s = Vrcp_s + Vrca_s + Vdi_s                 (Vdi: diaphragm descent)
//
// and one abdominal cavity with incompressible contents:
//
//   Abdomen:       Vab_L + Vab_R = Vdi_L + Vdi_R,  Vab_s = Cab_s · Pab
//
// Each lung has half the whole-lung compliance and twice the resistance.
// Compliances depend on posture (BodyParameters). What a surface method such as
// OEP sees is Vrcp, Vrca and Vab per side; what each lung takes in is Vl_s. The
// two differ per side, because a hemidiaphragm can displace the abdomen's wall
// on either side. Summed over both sides they agree exactly.
//
// Implicit Euler turns each step into a 7×7 linear system whose matrix is
// constant for a run, so it is inverted once.

public struct SideSample: Sendable, Equatable {
    public var lungVolume: Double
    public var pleuralPressure: Double
    public var diaphragmPressure: Double
    public var diaphragmDescent: Double
    public var upperRibcageVolume: Double
    public var lowerRibcageVolume: Double
    public var abdomenVolume: Double

    /// What a surface method sees on this side.
    public var surfaceVolume: Double { upperRibcageVolume + lowerRibcageVolume + abdomenVolume }
}

public struct Sample: Sendable, Equatable {
    public var time: Double
    public var activation: Double
    public var ribcageMusclePressure: Double
    public var abdominalPressure: Double
    public var left: SideSample
    public var right: SideSample

    public func side(_ s: Side) -> SideSample { s == .left ? left : right }

    public var lungVolume: Double { left.lungVolume + right.lungVolume }
    public var upperRibcageVolume: Double { left.upperRibcageVolume + right.upperRibcageVolume }
    public var lowerRibcageVolume: Double { left.lowerRibcageVolume + right.lowerRibcageVolume }
    public var ribcageVolume: Double { upperRibcageVolume + lowerRibcageVolume }
    public var abdomenVolume: Double { left.abdomenVolume + right.abdomenVolume }
    public var pleuralPressure: Double { 0.5 * (left.pleuralPressure + right.pleuralPressure) }
    public var diaphragmPressure: Double { 0.5 * (left.diaphragmPressure + right.diaphragmPressure) }
}

public struct Simulation: Sendable {
    public var body: BodyParameters
    public var drive: Drive
    public var posture: Posture
    public var timeStep: Double

    public init(body: BodyParameters, drive: Drive = Drive(), posture: Posture, timeStep: Double = 0.002) {
        self.body = body
        self.drive = drive
        self.posture = posture
        self.timeStep = timeStep
    }

    // Unknowns: [Vl_L, Vl_R, Ppl_L, Ppl_R, Pab, Vdi_L, Vdi_R]
    private enum I { static let vl = [0, 1], ppl = [2, 3], pab = 4, vdi = [5, 6] }

    public func run(cycles: Int) -> [Sample] {
        let dt = timeStep
        let cl = 0.5 * body.lungCompliance
        let r = 2 * body.resistance
        let f = body.appositionFraction
        let sides = Side.allCases
        let crcp = sides.map { body.upperRibcageCompliance($0, in: posture) }
        let crca = sides.map { body.lowerRibcageCompliance($0, in: posture) }
        let cab = sides.map { body.abdomenCompliance($0, in: posture) }
        let gain = sides.map { body.diaphragmGain($0, in: posture) }

        var a = [[Double]](repeating: [Double](repeating: 0, count: 7), count: 7)
        for s in 0..<2 {
            // Lung, implicit Euler: Ppl + Vl·(1/CL + R/dt) = (R/dt)·Vl_prev
            a[s][I.ppl[s]] = 1
            a[s][I.vl[s]] = 1 / cl + r / dt
            // Hemidiaphragm: Pab - Ppl = Pdi
            a[2 + s][I.pab] = 1
            a[2 + s][I.ppl[s]] = -1
            // Thorax: Vl - (Crcp + Crca(1-f))·Ppl - Crca·f·Pab - Vdi = (Crcp + Crca)·Prc
            a[4 + s][I.vl[s]] = 1
            a[4 + s][I.ppl[s]] = -(crcp[s] + crca[s] * (1 - f))
            a[4 + s][I.pab] = -crca[s] * f
            a[4 + s][I.vdi[s]] = -1
        }
        // Abdomen: (Cab_L + Cab_R)·Pab - Vdi_L - Vdi_R = 0
        a[6][I.pab] = cab[0] + cab[1]
        a[6][I.vdi[0]] = -1
        a[6][I.vdi[1]] = -1
        let inverse = invert(a)

        let steps = Int((Double(cycles) * drive.period / dt).rounded())
        var samples: [Sample] = []
        samples.reserveCapacity(steps + 1)
        var previous = [0.0, 0.0]

        for n in 0...steps {
            let t = Double(n) * dt
            let act = drive.activation(at: t)
            let pdi = gain.map { drive.diaphragmPeak * act * $0 }
            let prc = drive.ribcageMusclePeak * act
            var rhs = [Double](repeating: 0, count: 7)
            for s in 0..<2 {
                rhs[s] = r / dt * previous[s]  // starts from rest: previous = 0
                rhs[2 + s] = pdi[s]
                rhs[4 + s] = (crcp[s] + crca[s]) * prc
            }
            let x = multiply(inverse, rhs)
            let pab = x[I.pab]
            func side(_ s: Int) -> SideSample {
                let ppl = x[I.ppl[s]]
                return SideSample(
                    lungVolume: x[I.vl[s]], pleuralPressure: ppl,
                    diaphragmPressure: pdi[s], diaphragmDescent: x[I.vdi[s]],
                    upperRibcageVolume: crcp[s] * (ppl + prc),
                    lowerRibcageVolume: crca[s] * ((1 - f) * ppl + f * pab + prc),
                    abdomenVolume: cab[s] * pab)
            }
            previous = [x[0], x[1]]
            samples.append(Sample(time: t, activation: act, ribcageMusclePressure: prc,
                                  abdominalPressure: pab, left: side(0), right: side(1)))
        }
        return samples
    }
}

/// Total airflow at each sample, L/s (finite difference of lung volume).
public func flows(_ samples: [Sample]) -> [Double] {
    zip(samples, samples.dropFirst()).map { ($1.lungVolume - $0.lungVolume) / ($1.time - $0.time) }
}

/// Gauss–Jordan inverse with partial pivoting; the systems here are 7×7.
func invert(_ m: [[Double]]) -> [[Double]] {
    let n = m.count
    var a = m
    var inv = (0..<n).map { i in (0..<n).map { $0 == i ? 1.0 : 0.0 } }
    for col in 0..<n {
        let pivot = (col..<n).max { abs(a[$0][col]) < abs(a[$1][col]) }!
        precondition(abs(a[pivot][col]) > 1e-15, "singular system")
        a.swapAt(col, pivot)
        inv.swapAt(col, pivot)
        let p = a[col][col]
        for j in 0..<n { a[col][j] /= p; inv[col][j] /= p }
        for row in 0..<n where row != col {
            let factor = a[row][col]
            if factor == 0 { continue }
            for j in 0..<n {
                a[row][j] -= factor * a[col][j]
                inv[row][j] -= factor * inv[col][j]
            }
        }
    }
    return inv
}

func multiply(_ m: [[Double]], _ v: [Double]) -> [Double] {
    m.map { row in zip(row, v).reduce(0) { $0 + $1.0 * $1.1 } }
}
