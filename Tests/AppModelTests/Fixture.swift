import Foundation

/// Files in `Tests/Fixtures`, found relative to this source file so every test target can share them.
enum Fixture {
    static let directory = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appending(component: "Fixtures")

    static func data(named name: String) throws -> Data {
        try Data(contentsOf: directory.appending(component: name))
    }
}
