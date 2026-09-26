import Foundation
import HerdrKit

/// Where Open Folder in VS Code sends its link. The app hands it to the system; tests read `RecordingURLOpener`.
@MainActor
public protocol URLOpener: AnyObject {
    func open(_ url: URL)
}

/// Keeps every URL opened: the default for tests.
@MainActor
public final class RecordingURLOpener: URLOpener {
    public private(set) var opened: [URL] = []

    public init() {}

    public func open(_ url: URL) { opened.append(url) }
}

/// VS Code Remote-SSH's link to a folder on the host: `vscode://vscode-remote/ssh-remote+<host><path>`.
public enum VSCodeLink {
    /// The link to the pane's folder: the foreground process's directory when Herdr knows it, else the shell's.
    public static func url(host: String, pane: Herd.Pane) -> URL? {
        let folders = [pane.foregroundCwd, pane.cwd].compactMap { $0 }.filter { !$0.isEmpty }
        return folders.first.flatMap { url(host: host, path: $0) }
    }

    /// Nil unless `path` is absolute and `host` is not empty.
    public static func url(host: String, path: String) -> URL? {
        guard !host.isEmpty, path.hasPrefix("/"),
            let host = host.addingPercentEncoding(withAllowedCharacters: hostAllowed),
            let path = path.addingPercentEncoding(withAllowedCharacters: pathAllowed)
        else { return nil }
        return URL(string: "vscode://vscode-remote/ssh-remote+\(host)\(path)")
    }

    /// Unreserved characters and `/`: everything else in a folder name is escaped, so VS Code gets it back verbatim.
    private static let pathAllowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/")
    private static let hostAllowed = pathAllowed.subtracting(CharacterSet(charactersIn: "/")).union(
        CharacterSet(charactersIn: "@"))
}
