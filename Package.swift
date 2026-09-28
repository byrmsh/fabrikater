// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

/// A library target with its `CLAUDE.md` and a `<name>Tests` test target over the same dependencies.
func library(_ name: String, dependencies: [Target.Dependency] = []) -> [Target] {
    [
        .target(name: name, dependencies: dependencies, exclude: ["CLAUDE.md"], swiftSettings: swiftSettings),
        .testTarget(
            name: "\(name)Tests",
            dependencies: [.target(name: name)] + dependencies,
            swiftSettings: swiftSettings
        ),
    ]
}

let package = Package(
    name: "fabrikater",
    platforms: [.macOS(.v15)],
    targets: library("FabrikaterCore")
        + library("HostKit", dependencies: ["FabrikaterCore"])
        + library("HerdrKit", dependencies: ["FabrikaterCore", "HostKit"])
        + library("TranscriptKit", dependencies: ["FabrikaterCore", "HostKit"])
        + library("PromptKit", dependencies: ["FabrikaterCore"])
        + library("AppModel", dependencies: ["FabrikaterCore", "HerdrKit", "PromptKit", "TranscriptKit"]),
    swiftLanguageModes: [.v6]
)

// SwiftUI and AppKit exist only on macOS; on Linux the package is the logic targets and their tests.
#if os(macOS)
    // Pinned: SwiftTerm's main branch is taking breaking changes (docs/decisions/0012).
    package.dependencies += [.package(url: "https://github.com/migueldeicaza/SwiftTerm", exact: "1.20.0")]
    package.targets += [
        .target(
            name: "AppUI",
            dependencies: [
                "AppModel", "FabrikaterCore", "TranscriptKit", .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            exclude: ["CLAUDE.md"],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "fabrikater",
            dependencies: ["AppUI", "AppModel", "FabrikaterCore", "HostKit", "HerdrKit", "TranscriptKit"],
            exclude: ["CLAUDE.md"],
            swiftSettings: swiftSettings
        ),
    ]
    package.products += [.executable(name: "fabrikater", targets: ["fabrikater"])]
#endif
