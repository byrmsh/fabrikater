// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "fabrikater",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "FabrikaterCore", swiftSettings: swiftSettings),
        .testTarget(
            name: "FabrikaterCoreTests",
            dependencies: ["FabrikaterCore"],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
