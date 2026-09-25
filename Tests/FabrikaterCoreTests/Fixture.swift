import Foundation

/// Files in `Tests/Fixtures`, found relative to this source file so every test target can share them.
enum Fixture {
    static func data(named name: String) throws -> Data {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(components: "Fixtures", name)
        return try Data(contentsOf: url)
    }
}
