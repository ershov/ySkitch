// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ySkitch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ySkitch", targets: ["YSkitch"]),
    ],
    targets: [
        .target(name: "YSkitchCore"),
        .target(name: "YSkitchUI", dependencies: ["YSkitchCore"]),
        .executableTarget(name: "YSkitch", dependencies: ["YSkitchUI"]),
        .testTarget(name: "YSkitchCoreTests", dependencies: ["YSkitchCore"]),
        .testTarget(name: "YSkitchUITests", dependencies: ["YSkitchUI"]),
    ],
    swiftLanguageModes: [.v6]
)
