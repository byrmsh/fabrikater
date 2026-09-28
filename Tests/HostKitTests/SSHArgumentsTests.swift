import FabrikaterCore
import Testing

@testable import HostKit

struct SSHArgumentsTests {
    private let host = HostAlias("arch")!

    @Test func snapshotIsAOneOffCommand() {
        #expect(
            SSHArguments.arguments(for: .herdrSnapshot, host: host) == [
                "-o", "BatchMode=yes", "-o", "ControlMaster=auto", "-o", "ControlPath=~/.ssh/cm-fabrikater-%C",
                "-o", "ControlPersist=10m", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3",
                "-o", "Compression=yes", "arch", "--", "herdr api snapshot",
            ])
    }

    @Test func eventsStreamWithoutATerminal() {
        let arguments = SSHArguments.arguments(for: .herdrEvents, host: host)
        #expect(
            Array(arguments.suffix(4)) == [
                "-T", "arch", "--", #"socat - UNIX-CONNECT:"$HOME/.config/herdr/herdr.sock""#,
            ])
    }

    @Test func claudeLogTailQuotesTheSessionID() throws {
        let session = try #require(SessionID("00000000-0000-4000-8000-000000000019"))
        let script = HostCommand.claudeLogTail(session: session, bytes: 1024).remoteScript
        #expect(
            script.hasPrefix(
                "f=$(ls -1t ~/.claude/projects/*/'00000000-0000-4000-8000-000000000019.jsonl' 2>/dev/null"
                    + " | head -n 1); [ -n \"$f\" ] || exit 44; "))
        #expect(script.hasSuffix("; tail -c 1024 \"$f\""))
    }

    @Test func claudeLogFollowStreamsTheTailWithoutATerminal() throws {
        let session = try #require(SessionID("00000000-0000-4000-8000-000000000019"))
        let arguments = SSHArguments.arguments(for: .claudeLogFollow(session: session, bytes: 65536), host: host)
        #expect(Array(arguments.suffix(4).prefix(3)) == ["-T", "arch", "--"])
        let script = try #require(arguments.last)
        #expect(script.hasPrefix(HostCommand.claudeLog(session)))
        #expect(script.hasSuffix("; exec tail -c 65536 -F \"$f\""))
    }

    @Test func paneScreenReadsOnlyTheVisibleScreen() throws {
        let pane = try #require(PaneID("w3:pQ"))
        #expect(
            HostCommand.herdrPaneScreen(pane).remoteScript == "herdr pane read 'w3:pQ' --source visible --format ansi")
    }

    @Test func shellQuotingSurvivesSingleQuotes() {
        #expect(shellQuoted("a'b") == #"'a'\''b'"#)
    }

    @Test(arguments: ["arch", "my-host.example", "user@host", "host_1"])
    func acceptsHostAliases(_ raw: String) {
        #expect(HostAlias(raw)?.rawValue == raw)
    }

    @Test(arguments: ["", "-oProxyCommand=evil", "arch host", "arch;ls", "arch\n", "$(id)"])
    func rejectsHostAliases(_ raw: String) {
        #expect(HostAlias(raw) == nil)
    }
}
