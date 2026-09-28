import Foundation

/// A file the session changed, with every edit to it in the order they were made.
public struct FileChange: Equatable, Sendable, Identifiable {
    /// The path as the tool call gave it, which for Claude Code is absolute.
    public var path: String
    public var edits: [FileEdit]

    public init(path: String, edits: [FileEdit]) {
        self.path = path
        self.edits = edits
    }

    public var id: String { path }

    /// The file's name, the last component of its path.
    public var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// The folder holding the file, or empty for a bare name.
    public var folder: String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return slash == path.startIndex ? "/" : String(path[..<slash])
    }

    public var addedLines: Int { edits.reduce(0) { $0 + $1.addedLines } }
    public var removedLines: Int { edits.reduce(0) { $0 + $1.removedLines } }

    /// "+12 −3", or "+12" when nothing was removed.
    public var lineCounts: String {
        removedLines == 0 ? "+\(addedLines)" : "+\(addedLines) −\(removedLines)"
    }

    /// "12 lines added, 3 removed", for accessibility.
    public var spokenLineCounts: String {
        let added = "\(addedLines) \(addedLines == 1 ? "line" : "lines") added"
        return removedLines == 0 ? added : "\(added), \(removedLines) removed"
    }
}

/// One `Edit`, one edit of a `MultiEdit`, or one `Write`, as the lines of a unified diff.
public struct FileEdit: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        /// Replaced `old_string` with `new_string`.
        case edit
        /// Wrote the whole file.
        case write
    }

    /// The tool call's id plus the edit's index within it.
    public var id: String
    public var kind: Kind
    public var lines: [DiffLine]
    /// Lines left out after `lines` because the edit was too long to show.
    public var omittedLines: Int

    public init(id: String, kind: Kind, lines: [DiffLine], omittedLines: Int = 0) {
        self.id = id
        self.kind = kind
        self.lines = lines
        self.omittedLines = omittedLines
    }

    public var addedLines: Int { lines.count { $0.kind == .added } + (kind == .write ? omittedLines : 0) }
    public var removedLines: Int { lines.count { $0.kind == .removed } }
}

public struct DiffLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unchanged
        case added
        case removed

        /// The unified diff's prefix: a space, "+" or "-".
        public var marker: String {
            switch self {
            case .unchanged: " "
            case .added: "+"
            case .removed: "-"
            }
        }
    }

    public var kind: Kind
    public var text: String

    public init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }
}

extension Transcript {
    /// Lines shown per edit; a longer one ends with a count of the lines left out.
    static let diffLineLimit = 400

    /// The files a Claude session log shows being changed by `Edit`, `MultiEdit` and `Write`, in the order each was
    /// first touched. Only calls whose result arrived and is not an error count: a rejected edit, a failed one and one
    /// still waiting for permission changed nothing.
    public static func changes(inClaudeLog data: Data) -> [FileChange] {
        let tools = ["Edit", "MultiEdit", "Write"].map { Data("\"\($0)\"".utf8) }
        let resultMarker = Data("\"tool_result\"".utf8)
        var pending: [String: [PendingEdit]] = [:]
        var applied: [PendingEdit] = []
        // Only lines naming an editing tool, or a result for one still waiting, are decoded.
        for line in data.split(separator: 0x0A) {
            let namesTool = tools.contains { line.range(of: $0) != nil }
            let answers =
                !pending.isEmpty && line.range(of: resultMarker) != nil
                && pending.keys.contains { line.range(of: Data($0.utf8)) != nil }
            guard namesTool || answers,
                let row = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                row["isSidechain"] as? Bool != true,
                let blocks = (row["message"] as? [String: Any])?["content"] as? [[String: Any]]
            else { continue }
            for block in blocks {
                switch block["type"] as? String {
                case "tool_use" where row["type"] as? String == "assistant":
                    guard let id = block["id"] as? String, let name = block["name"] as? String,
                        let edits = PendingEdit.edits(tool: name, id: id, input: block["input"])
                    else { continue }
                    pending[id] = edits
                case "tool_result":
                    guard let id = block["tool_use_id"] as? String, let edits = pending.removeValue(forKey: id),
                        block["is_error"] as? Bool != true
                    else { continue }
                    applied += edits
                default:
                    continue
                }
            }
        }
        return group(applied)
    }

    /// Groups edits by path, each file placed where it was first touched.
    static func group(_ edits: [PendingEdit]) -> [FileChange] {
        var changes: [FileChange] = []
        var index: [String: Int] = [:]
        for edit in edits {
            let fileEdit = edit.fileEdit
            if let at = index[edit.path] {
                changes[at].edits.append(fileEdit)
            } else {
                index[edit.path] = changes.count
                changes.append(FileChange(path: edit.path, edits: [fileEdit]))
            }
        }
        return changes
    }

    /// An edit read from a tool call, not yet turned into diff lines.
    struct PendingEdit {
        var id: String
        var path: String
        var old: String?
        var new: String

        /// Nil for another tool or a malformed input, which then changes nothing.
        static func edits(tool: String, id: String, input: Any?) -> [PendingEdit]? {
            guard let input = input as? [String: Any], let path = input["file_path"] as? String, !path.isEmpty
            else { return nil }
            switch tool {
            case "Write":
                guard let content = input["content"] as? String else { return nil }
                return [PendingEdit(id: id, path: path, old: nil, new: content)]
            case "Edit":
                guard let old = input["old_string"] as? String, let new = input["new_string"] as? String
                else { return nil }
                return [PendingEdit(id: id, path: path, old: old, new: new)]
            case "MultiEdit":
                guard let items = input["edits"] as? [[String: Any]] else { return nil }
                var edits: [PendingEdit] = []
                for (offset, item) in items.enumerated() {
                    guard let old = item["old_string"] as? String, let new = item["new_string"] as? String
                    else { return nil }
                    edits.append(PendingEdit(id: "\(id)-\(offset)", path: path, old: old, new: new))
                }
                return edits
            default:
                return nil
            }
        }

        var fileEdit: FileEdit {
            let lines =
                old.map { Transcript.diff(from: $0, to: new) } ?? Transcript.lines(of: new).map { DiffLine(.added, $0) }
            let limit = Transcript.diffLineLimit
            return FileEdit(
                id: id, kind: old == nil ? .write : .edit, lines: Array(lines.prefix(limit)),
                omittedLines: max(0, lines.count - limit))
        }
    }

    /// A line diff of `old` to `new`: unchanged lines, then removals before additions at each change.
    public static func diff(from old: String, to new: String) -> [DiffLine] {
        let a = lines(of: old)
        let b = lines(of: new)
        // Beyond this the table costs too much for a fragment; show the old text removed and the new text added.
        guard a.count * b.count <= 250_000 else {
            return a.map { DiffLine(.removed, $0) } + b.map { DiffLine(.added, $0) }
        }
        // common[i][j]: the longest common subsequence of a[i...] and b[j...].
        var common = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in a.indices.reversed() {
            for j in b.indices.reversed() {
                common[i][j] = a[i] == b[j] ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1])
            }
        }
        var result: [DiffLine] = []
        var i = 0
        var j = 0
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] {
                result.append(DiffLine(.unchanged, a[i]))
                i += 1
                j += 1
            } else if i < a.count, j == b.count || common[i + 1][j] >= common[i][j + 1] {
                result.append(DiffLine(.removed, a[i]))
                i += 1
            } else {
                result.append(DiffLine(.added, b[j]))
                j += 1
            }
        }
        return result
    }

    /// The lines of `text`; a trailing newline does not add an empty last line, and empty text has none.
    static func lines(of text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        return lines
    }
}
