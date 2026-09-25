// swift-tools-version: 6.0
import PackageDescription

// The game half. Pure functions over a `Shot`: no Core Motion, no UIKit, no
// haptics engine — those live in the app target next door. Everything here runs
// under `swift test` on a Mac, which is how tennis and cricket get built and
// tuned sitting down.
let package = Package(
    name: "SwingGame",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwingGame", targets: ["SwingGame"])
    ],
    dependencies: [
        .package(path: "../../core")
    ],
    targets: [
        .target(
            name: "SwingGame",
            dependencies: [.product(name: "SwingCore", package: "core")]
        ),
        .testTarget(name: "SwingGameTests", dependencies: ["SwingGame"]),
    ]
)
