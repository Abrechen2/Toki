// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TokiCore", targets: ["TokiCore"])
    ],
    targets: [
        .target(name: "TokiCore"),
        .testTarget(name: "TokiCoreTests", dependencies: ["TokiCore"])
    ]
)
