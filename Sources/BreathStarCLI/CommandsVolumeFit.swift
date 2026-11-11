import BreathStar
import Foundation

/// `volume-fit`: the muscle-group fit with and without OEP compartment volumes (the work plan (private), item 2,
/// literature pass 12), across the lower band's stiffness. Reports the marker χ² (SD), the static
/// shares, the group pressures and the dynamic breath's shares.
func runVolumeFit(_ args: ArraySlice<String>) {
    let drive = Drive(), markers = TakashimaMarkers.sitting
    var anatomy = AnatomyModel()
    // `--arch L`: the ribs reach down to L cm at the side (AnatomyModel.lateralRibMargin).
    if let i = args.firstIndex(of: "--arch"), args.index(after: i) < args.endIndex, let v = Double(args[args.index(after: i)]) {
        anatomy.lateralRibMargin = v
        print("Ribs' lower edge: \(v) cm at the side (flat 18 cm in front).")
    }
    print("Muscle-group fit, seated: Takashima markers + tidal, optionally + Mendes men's seated shares (37.4/21.9/40.8 %, SD).")
    print("  " + pad("lower band ×", 14) + pad("volumes", 10) + pad("markers χ²(SD)", 16) + pad("in SD", 7) + pad("pressures d/u/l", 18) + "breath shares u/l/a")
    for withVolumes in [false, true] {
        for k in (args.contains("--wide") ? [2.5, 4.0, 6.0, 10.0] : [0.5, 1.0, 1.5, 2.5, 4.0]) {
            let fit = A2Body.fitMuscleGroups(anatomy: anatomy, markers: markers, tidal: 0.56, passive: A2MuscleGroup.defaultPassive,
                                             lowerBandStiffness: k, volumes: withVolumes ? .mendesMenSeated : nil)
            let inSD = fit.rows.filter { abs($0.model - $0.observation.mean) <= $0.observation.sd }.count
            let b = fit.body.timed(MuscleTiming(), drive: drive).matchedToTidal(0.56, drive: drive)
            let m = SignedBreath.measure(b.simulate(drive: drive), period: drive.period)
            print("  " + pad(f(k, 1), 14) + pad(withVolumes ? "yes" : "no", 10) + pad(f(fit.chiSquared, 2), 16) + pad("\(inSD)/\(fit.rows.count)", 7)
                  + pad(fit.pressures.map { f($0, 1) }.joined(separator: "/"), 18)
                  + "\(f(m.upperShare * 100))/\(f(m.lowerShare * 100))/\(f(m.abdomenShare * 100))%")
        }
    }
}
