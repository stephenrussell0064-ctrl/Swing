// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwingCore",
    // macOS is here so `swift test` runs from a terminal, not because anything
    // ships there. Nothing in this target touches UIKit or Core Motion — it is
    // value types and arithmetic, which is what makes it testable at all.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwingCore", targets: ["SwingCore"])
    ],
    targets: [
        .target(name: "SwingCore"),
        .testTarget(name: "SwingCoreTests", dependencies: ["SwingCore"]),
    ]
)
