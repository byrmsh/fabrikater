import Foundation

/// One item of the agent's current plan, from its latest `TodoWrite` call.
public struct Todo: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed

        /// The status as words, for accessibility.
        public var title: String {
            switch self {
            case .pending: "Pending"
            case .inProgress: "In progress"
            case .completed: "Done"
            }
        }
    }

    public var content: String
    /// The present-tense wording ("Running the tests"), or empty when the call had none.
    public var activeForm: String
    public var status: Status

    public init(content: String, activeForm: String = "", status: Status) {
        self.content = content
        self.activeForm = activeForm
        self.status = status
    }

    /// What the plan shows: the present-tense wording while the item is in progress.
    public var title: String {
        status == .inProgress && !activeForm.isEmpty ? activeForm : content
    }

    /// "2 of 5 done".
    public static func progress(of todos: [Todo]) -> String {
        "\(todos.count { $0.status == .completed }) of \(todos.count) done"
    }
}

extension Transcript {
    /// The items of the latest `TodoWrite` call in a Claude session log, oldest item first. Empty when the log has
    /// no such call, or when the latest one's input is malformed: an older plan is never shown in its place.
    public static func latestTodos(inClaudeLog data: Data) -> [Todo] {
        let marker = Data("\"TodoWrite\"".utf8)
        // Newest first, and only lines naming the tool are decoded, so the rest of the log costs one byte scan.
        for line in data.split(separator: 0x0A).reversed() where line.range(of: marker) != nil {
            guard let row = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                row["type"] as? String == "assistant", row["isSidechain"] as? Bool != true,
                let blocks = (row["message"] as? [String: Any])?["content"] as? [[String: Any]],
                let call = blocks.last(where: {
                    $0["type"] as? String == "tool_use" && $0["name"] as? String == "TodoWrite"
                })
            else { continue }
            return todos(fromInput: call["input"]) ?? []
        }
        return []
    }

    /// Nil when any item is missing its content or has an unknown status.
    static func todos(fromInput input: Any?) -> [Todo]? {
        guard let items = (input as? [String: Any])?["todos"] as? [[String: Any]] else { return nil }
        var todos: [Todo] = []
        for item in items {
            guard let content = item["content"] as? String, !content.isEmpty,
                let status = (item["status"] as? String).flatMap(Todo.Status.init(rawValue:))
            else { return nil }
            todos.append(Todo(content: content, activeForm: item["activeForm"] as? String ?? "", status: status))
        }
        return todos
    }
}
