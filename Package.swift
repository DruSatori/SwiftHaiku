// swift-tools-version: 6.0
// SwiftHaiku: a small SwiftUI-style API over RenkuOS's (Haiku's) libbe. RenkuOS has no SwiftPM yet
// (`swift build` is missing from its 6.4.3 toolchain), so this manifest is unverified on the
// target; scripts/build-cross.sh builds the same targets with swiftc and clang++ directly.
import PackageDescription

let cxx: [SwiftSetting] = [.interoperabilityMode(.Cxx)]

let package = Package(
    name: "SwiftHaiku",
    products: [
        .library(name: "SwiftHaiku", targets: ["SwiftHaiku"]),
        .executable(name: "Counter", targets: ["Counter"]),
        .executable(name: "Gallery", targets: ["Gallery"]),
    ],
    targets: [
        .target(name: "CHaikuBridge", linkerSettings: [.linkedLibrary("be")]),
        .target(name: "SwiftHaiku", dependencies: ["CHaikuBridge"], swiftSettings: cxx),
        .executableTarget(name: "Counter", dependencies: ["SwiftHaiku"], swiftSettings: cxx),
        .executableTarget(name: "Gallery", dependencies: ["SwiftHaiku"], swiftSettings: cxx),
        // An executable, not a test target: RenkuOS has neither XCTest nor Swift Testing.
        .executableTarget(name: "SwiftHaikuChecks", dependencies: ["SwiftHaiku"],
                          path: "Tests/SwiftHaikuChecks", swiftSettings: cxx),
    ],
    cxxLanguageStandard: .cxx17
)
