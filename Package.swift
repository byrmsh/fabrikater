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
        .target(name: "FabrikaterCore", exclude: ["CLAUDE.md"], swiftSettings: swiftSettings),
        .testTarget(
            name: "FabrikaterCoreTests",
            dependencies: ["FabrikaterCore"],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)

// SwiftUI and AppKit exist only on macOS; on Linux the package is the logic targets and their tests.
#if os(macOS)
    package.targets += [
        .target(name: "AppUI", exclude: ["CLAUDE.md"], swiftSettings: swiftSettings),
        .executableTarget(
            name: "fabrikater",
            dependencies: ["AppUI", "FabrikaterCore"],
            exclude: ["CLAUDE.md"],
            swiftSettings: swiftSettings
        ),
    ]
    package.products += [.executable(name: "fabrikater", targets: ["fabrikater"])]
#endif
