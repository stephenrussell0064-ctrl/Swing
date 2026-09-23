// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwingProtocol",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwingProtocol", targets: ["SwingProtocol"])
    ],
    targets: [
        .target(name: "SwingProtocol"),
        .testTarget(name: "SwingProtocolTests", dependencies: ["SwingProtocol"]),
    ]
)
