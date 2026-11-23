// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ySkitch",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "ySkitch", targets: ["YSkitch"]),
    ],
    targets: [
        .target(name: "YSkitchCore"),
        .executableTarget(name: "YSkitch", dependencies: ["YSkitchCore"]),
        .testTarget(name: "YSkitchCoreTests", dependencies: ["YSkitchCore"]),
    ],
    swiftLanguageModes: [.v6]
)
