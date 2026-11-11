// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BreathStar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BreathStar", targets: ["BreathStar"]),
        .executable(name: "breathstar", targets: ["BreathStarCLI"]),
    ],
    targets: [
        // Optimised even in debug builds: the simulations run ~250× slower unoptimised (the full
        // test suite took 80–120 min in debug, 20 s optimised). Testing stays enabled.
        .target(name: "BreathStar", path: "Sources/BreathStar",
                swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .executableTarget(
            name: "BreathStarCLI",
            dependencies: ["BreathStar"],
            path: "Sources/BreathStarCLI"
        ),
        .testTarget(
            name: "BreathStarTests",
            dependencies: ["BreathStar"],
            path: "Tests/BreathStarTests"
        ),
    ]
)
