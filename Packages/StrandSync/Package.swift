// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StrandSync",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "StrandSync", targets: ["StrandSync"])],
    targets: [
        .target(name: "StrandSync"),
        .testTarget(name: "StrandSyncTests", dependencies: ["StrandSync"]),
    ]
)
