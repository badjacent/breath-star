import Testing
@testable import BreathStar

/// Stage 2 acceptance (Configuration.swift): the three postures, given as configurations, reproduce
/// the numbers they had when each was built by hand.
@Suite struct Configuration {
    static let drive = Drive()
    static let seated = BodyGenerator.seatedSymmetric(drive: drive)

    func breath(_ c: BodyConfiguration) throws -> SidedBreath {
        SidedBreath.measure(try BodyGenerator.handFitted(c, drive: Self.drive).body.simulate(drive: Self.drive), period: Self.drive.period)
    }

    @Test func seatedReproducesSymmetric() throws {
        let a = SignedBreath.measure(Self.seated.simulate(drive: Self.drive), period: Self.drive.period)
        let b = try breath(.seated)
        #expect(abs(a.tidalVolume - b.tidalVolume) < 0.005)
        #expect(abs(a.upperShare - b.upperShare) < 0.005 && abs(a.abdomenShare - b.abdomenShare) < 0.005)
        #expect(abs(b.lung[0] - b.lung[1]) < 1e-4)  // integration noise only
    }

    @Test func supineReproducesSymmetric() throws {
        let sup = BodyGenerator.supineSymmetric(from: Self.seated, drive: Self.drive).body
        let a = SignedBreath.measure(sup.simulate(drive: Self.drive), period: Self.drive.period)
        let b = try breath(.supine)
        #expect(abs(a.abdomenShare - b.abdomenShare) < 0.015 && abs(a.upperShare - b.upperShare) < 0.015)
        #expect(b.abdomenShare > 0.7)  // supine breath is mostly belly (Takashima)
    }

    @Test func sideLyingFloorLungAndMirror() throws {
        let r = try breath(.rightSideDown), l = try breath(.leftSideDown)
        let floorShare = r.lung[1] / (r.lung[0] + r.lung[1])
        #expect(abs(floorShare - 0.563) < 0.01)  // fitted to Amano 2024 / Grant 2011
        #expect(abs(r.abdomenShare - 0.809) < 0.01)
        #expect(abs(r.lung[0] - l.lung[1]) < 0.002 && abs(r.lung[1] - l.lung[0]) < 0.002)
    }

    @Test func contactsMatter() throws {
        let with = try breath(.rightSideDown)
        let without = try breath(BodyConfiguration(name: "no bed", gravity: (-1, 0, 0)))
        #expect(abs(with.chestWall[0] - without.chestWall[0]) > 0.01)  // the bed spring pushes the upper side
        let sup = try breath(BodyConfiguration(name: "no floor", gravity: (0, -1, 0)))
        #expect(sup.abdomenShare < (try breath(.supine)).abdomenShare)  // no ribcage restraint
    }

    @Test func otherDirectionsRefused() {
        #expect(throws: ConfigurationError.self) { try BodyGenerator.handFitted(BodyConfiguration(name: "prone", gravity: (0, 1, 0))) }
        #expect(throws: ConfigurationError.self) { try BodyGenerator.handFitted(BodyConfiguration(name: "half", gravity: (-1, -1, 0))) }
        #expect(BodyConfiguration(name: "tilt", gravity: (-0.2, 0, -1)).posture == .upright)  // ~11°: still upright
    }
}
