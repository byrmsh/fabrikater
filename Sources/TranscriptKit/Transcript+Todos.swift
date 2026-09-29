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
        TodoReader.reading(data).todos
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

/// The plan of the latest `TodoWrite` call read so far.
struct TodoReader: ClaudeRowReader {
    private(set) var todos: [Todo] = []

    mutating func read(_ row: [String: Any], number: Int) {
        guard row["type"] as? String == "assistant", let blocks = ClaudeLog.blocks(of: row),
            let call = blocks.last(where: {
                $0["type"] as? String == "tool_use" && $0["name"] as? String == "TodoWrite"
            })
        else { return }
        todos = Transcript.todos(fromInput: call["input"]) ?? []
    }
}
