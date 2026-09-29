// Writes the scale fixtures: a long Claude session log and a herd with dozens of panes (docs/performance.md).
// Deterministic, so running it again rewrites the same bytes:   swift scripts/make-scale-fixtures.swift
import Foundation

let fixtures = URL(filePath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "Tests/Fixtures")

func json(_ object: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    return String(decoding: data, as: UTF8.self)
}

func stamp(_ second: Int) -> String {
    String(format: "2026-09-20T%02d:%02d:%02d.000Z", (8 + second / 3600) % 24, second / 60 % 60, second % 60)
}

// MARK: The session log

let turns = 450
var lines = [json(["type": "permission-mode", "permissionMode": "default", "sessionId": "00000000-0000-4000-8000-000000000001"])]
var second = 0
var messageID = 0

func user(_ uuid: String, _ content: Any) {
    second += 1
    lines.append(json([
        "type": "user", "uuid": uuid, "timestamp": stamp(second), "cwd": "/home/user/project", "gitBranch": "main",
        "message": ["role": "user", "content": content],
    ]))
}

func assistant(_ uuid: String, _ blocks: [[String: Any]]) {
    second += 2
    messageID += 1
    lines.append(json([
        "type": "assistant", "uuid": uuid, "timestamp": stamp(second), "cwd": "/home/user/project", "gitBranch": "main",
        "message": [
            "id": "msg_\(messageID)", "role": "assistant", "model": "claude-synthetic", "content": blocks,
            "usage": ["input_tokens": 12, "cache_creation_input_tokens": 400, "cache_read_input_tokens": 60_000 + messageID],
        ],
    ]))
}

func tool(_ turn: Int, _ index: Int, _ name: String, _ input: [String: Any], result: String) {
    let id = "toolu_\(turn)_\(index)"
    assistant("a\(turn)-\(index)", [["type": "tool_use", "id": id, "name": name, "input": input]])
    user("r\(turn)-\(index)", [["type": "tool_result", "tool_use_id": id, "content": result]])
}

func codeBlock(_ turn: Int) -> String {
    let body = (0..<24).map { line in
        "    let value\(line) = try await client.fetch(id: \(turn * 100 + line), retries: \(line % 4)) // step \(line)"
    }
    return "```swift\nfunc step\(turn)() async throws {\n" + body.joined(separator: "\n") + "\n}\n```"
}

func output(_ turn: Int, lines count: Int) -> String {
    (0..<count).map { "Test Case 'Suite\(turn).test\($0)' passed (0.\(String(format: "%03d", $0)) seconds)" }
        .joined(separator: "\n")
}

for turn in 1...turns {
    user("u\(turn)", "Turn \(turn): look at module \(turn % 37) and make the retry in step \(turn) configurable")
    var reply = "## Step \(turn)\n\nI read module \(turn % 37). The retry is **fixed** at three tries; making it "
        + "configurable means threading a `RetryPolicy` through:\n\n1. the client\n2. the uploader\n   - its tests\n"
    if turn % 3 == 0 { reply += "\n" + codeBlock(turn) + "\n" }
    if turn % 11 == 0 {
        reply += "\n| Case | Before | After |\n|---|---|---|\n| cold | 3 | \(turn % 5) |\n| warm | 3 | \(turn % 4) |\n"
    }
    assistant("a\(turn)", [["type": "text", "text": reply]])
    tool(turn, 1, "Bash", ["command": "swift test --filter Suite\(turn)"], result: output(turn, lines: turn % 7 == 0 ? 60 : 6))
    if turn % 4 == 0 {
        tool(
            turn, 2, "Edit",
            [
                "file_path": "/home/user/project/Sources/Module\(turn % 37).swift",
                "old_string": "let retries = 3\nlet delay = 1.0\n",
                "new_string": "let retries = policy.retries\nlet delay = policy.delay\nlet jitter = policy.jitter\n",
            ],
            result: "The file /home/user/project/Sources/Module\(turn % 37).swift has been updated.")
    }
    if turn % 25 == 0 {
        let todos: [[String: Any]] = (1...4).map { item in
            ["content": "Step \(turn + item)", "activeForm": "Doing step \(turn + item)",
             "status": item == 1 ? "in_progress" : "pending"]
        }
        tool(turn, 3, "TodoWrite", ["todos": todos], result: "Todos have been modified successfully.")
    }
    assistant("f\(turn)", [["type": "text", "text": "Step \(turn) is configurable now and its suite passes."]])
}
try! (lines.joined(separator: "\n") + "\n").write(to: fixtures.appending(path: "claude-scale.synthetic.jsonl"), atomically: true, encoding: .utf8)

// The same log's last lines once more, for the e2e flow to append while the big conversation is open.
let more = [
    json([
        "type": "user", "uuid": "u-more", "timestamp": stamp(second + 10), "message": ["role": "user", "content": "One more turn after the long session"],
    ]),
    json([
        "type": "assistant", "uuid": "a-more", "timestamp": stamp(second + 12),
        "message": ["id": "msg_more", "role": "assistant", "content": [["type": "text", "text": "The long session still follows live."]]],
    ]),
]
try! (more.joined(separator: "\n") + "\n").write(to: fixtures.appending(path: "claude-scale-more.synthetic.jsonl"), atomically: true, encoding: .utf8)

// MARK: The herd

let statuses = ["working", "idle", "done", "blocked", "working", "idle"]
var workspaces: [[String: Any]] = []
var tabs: [[String: Any]] = []
var panes: [[String: Any]] = []
for w in 1...8 {
    workspaces.append(["workspace_id": "w\(w)", "label": "Scale \(w)", "number": w, "agent_status": "working", "focused": w == 1])
    for t in 1...4 {
        let tab = "w\(w):t\(t)"
        tabs.append(["tab_id": tab, "workspace_id": "w\(w)", "label": "tab \(t)", "number": t, "agent_status": "working", "focused": false])
        for p in 1...2 {
            let index = ((w - 1) * 4 + (t - 1)) * 2 + p
            var pane: [String: Any] = [
                "pane_id": "w\(w):p\(t)\(p)", "tab_id": tab, "workspace_id": "w\(w)", "revision": index,
                "agent_status": p == 2 && t == 4 ? "unknown" : statuses[index % statuses.count],
                "cwd": "/home/user/project-\(index)", "terminal_title_stripped": "Scale pane \(index)",
                "terminal_title": "Scale pane \(index)", "focused": index == 1,
            ]
            if !(p == 2 && t == 4) {
                pane["agent"] = "claude"
                let session = String(format: "00000000-0000-4000-8000-%012d", index)
                pane["agent_session"] = ["agent": "claude", "kind": "id", "source": "herdr:claude", "value": session]
            }
            panes.append(pane)
        }
    }
}
let snapshot: [String: Any] = [
    "id": "synthetic",
    "result": [
        "type": "session_snapshot",
        "snapshot": [
            "version": "0.9.1", "protocol": 22, "workspaces": workspaces, "tabs": tabs, "panes": panes,
            "agents": panes.filter { $0["agent"] != nil }, "layouts": [],
        ] as [String: Any],
    ] as [String: Any],
]
try! (json(snapshot) + "\n").write(to: fixtures.appending(path: "snapshot-scale.synthetic.json"), atomically: true, encoding: .utf8)
