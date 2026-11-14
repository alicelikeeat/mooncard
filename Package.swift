// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MoonCardCore",
    products: [.library(name: "MoonCardCore", targets: ["MoonCardCore"])],
    targets: [
        .target(name: "MoonCardCore", path: "Core"),
        .testTarget(name: "MoonCardCoreTests", dependencies: ["MoonCardCore"])
    ]
)
