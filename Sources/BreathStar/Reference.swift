/// Published measurements the model is checked against. Each value is copied
/// from reference/compartments.json (a test keeps the two in step), which in
/// turn was read from the paper's own table.
public enum Reference {
    public struct Share: Sendable, Equatable {
        public var mean: Double  // percent
        public var sd: Double
    }

    public struct PostureRow: Sendable, Equatable {
        public var upperRibcage: Share
        public var lowerRibcage: Share
        public var abdomen: Share
        public var tidalVolume: Share  // litres
    }

    public enum Sex: String, CaseIterable, Sendable {
        case men, women
    }

    /// Mendes LPS et al. Braz J Phys Ther 2020;24:240-248, Table 2. OEP, quiet breathing.
    public static func mendes2020(_ sex: Sex, _ posture: String) -> PostureRow? {
        let table: [Sex: [String: PostureRow]] = [
            .men: [
                "seated": row(37.41, 8.44, 21.93, 5.81, 40.83, 10.52, 0.84, 0.45),
                "incline45": row(30.97, 10.63, 14.25, 3.92, 55.40, 13.26, 0.59, 0.26),
                "supine": row(19.50, 9.85, 11.50, 4.36, 69.77, 13.36, 0.58, 0.28),
            ],
            .women: [
                "seated": row(43.02, 11.38, 19.51, 5.35, 37.42, 12.23, 0.53, 0.23),
                "incline45": row(39.74, 14.31, 13.13, 4.95, 46.49, 15.89, 0.44, 0.16),
                "supine": row(23.01, 10.51, 11.90, 4.63, 65.41, 13.26, 0.41, 0.16),
            ],
        ]
        return table[sex]?[posture]
    }

    public static let mendesPostures: [(name: String, posture: Posture)] = [
        ("seated", .seated), ("incline45", .incline45), ("supine", .supine),
    ]

    /// One posture's targets: the abdomen's share (percent) and tidal volume (L),
    /// with SDs where the source gives them.
    public struct Point: Sendable, Equatable {
        public var abdomenShare: Double
        public var abdomenSD: Double?
        /// Upper (pulmonary) and lower (abdominal) ribcage shares, percent, where reported.
        public var upperRibcageShare: Double? = nil
        public var upperRibcageSD: Double? = nil
        public var lowerRibcageShare: Double? = nil
        public var lowerRibcageSD: Double? = nil
        public var tidalVolume: Double
        public var tidalSD: Double?
    }

    /// A seated → 45° → supine series from one source and group.
    public struct Dataset: Sendable {
        public var id: String
        public var seated: Point
        public var incline45: Point
        public var supine: Point
        /// For a source that doesn't report the upper/lower ribcage split: the
        /// dataset whose fitted split to borrow.
        public var borrowsRibcageSplitFrom: String? = nil

        public func point(_ name: String) -> Point {
            switch name {
            case "seated": return seated
            case "incline45": return incline45
            default: return supine
            }
        }

        /// How far along from seated to supine the 45° abdominal share sits (0...1).
        public var fractionAt45: Double {
            (incline45.abdomenShare - seated.abdomenShare) / (supine.abdomenShare - seated.abdomenShare)
        }
    }

    public static func mendes2020(_ sex: Sex) -> Dataset {
        func point(_ name: String) -> Point {
            let r = mendes2020(sex, name)!
            return Point(abdomenShare: r.abdomen.mean, abdomenSD: r.abdomen.sd,
                         upperRibcageShare: r.upperRibcage.mean, upperRibcageSD: r.upperRibcage.sd,
                         lowerRibcageShare: r.lowerRibcage.mean, lowerRibcageSD: r.lowerRibcage.sd,
                         tidalVolume: r.tidalVolume.mean, tidalSD: r.tidalVolume.sd)
        }
        return Dataset(id: "mendes2020-\(sex.rawValue)", seated: point("seated"),
                       incline45: point("incline45"), supine: point("supine"))
    }

    /// Sonpeayung R et al. J Obes 2019:9539846, Figures 2 and 3: healthy control men,
    /// means printed on the plots (no SDs readable). Seated is the no-backrest
    /// position; 45° is Fowler's. Tidal volume is ribcage plus abdomen volume.
    public static let sonpeayung2019 = Dataset(
        id: "sonpeayung2019-men",
        seated: Point(abdomenShare: 36.36, abdomenSD: nil, tidalVolume: 0.35 + 0.19, tidalSD: nil),
        incline45: Point(abdomenShare: 47.89, abdomenSD: nil, tidalVolume: 0.23 + 0.20, tidalSD: nil),
        supine: Point(abdomenShare: 62.49, abdomenSD: nil, tidalVolume: 0.14 + 0.38, tidalSD: nil),
        borrowsRibcageSplitFrom: "mendes2020-men")

    /// Every seated → 45° → supine series the model is checked against.
    public static var datasets: [Dataset] {
        Sex.allCases.map { mendes2020($0) } + [sonpeayung2019]
    }

    private static func row(_ rcp: Double, _ rcpSD: Double, _ rca: Double, _ rcaSD: Double,
                            _ ab: Double, _ abSD: Double, _ vt: Double, _ vtSD: Double) -> PostureRow {
        PostureRow(
            upperRibcage: Share(mean: rcp, sd: rcpSD),
            lowerRibcage: Share(mean: rca, sd: rcaSD),
            abdomen: Share(mean: ab, sd: abSD),
            tidalVolume: Share(mean: vt, sd: vtSD))
    }
}
