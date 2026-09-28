import FabrikaterCore
import Foundation
import HerdrKit
import Testing
import TranscriptKit

@testable import AppModel

@MainActor
struct OpenInVSCodeTests {
    private struct FakeTranscripts: TranscriptService {
        func transcript(of log: SessionLog, bytes: Int) async throws -> Transcript { Transcript(entries: []) }
    }

    private let pane = Herd.Pane(id: PaneID("w1:p1")!, tabID: "w1:t1", workspaceID: "w1")

    @Test func linksTheFolderOverRemoteSSH() {
        let url = VSCodeLink.url(host: "arch", path: "/home/user/project-1")
        #expect(url?.absoluteString == "vscode://vscode-remote/ssh-remote+arch/home/user/project-1")
    }

    @Test(arguments: [
        ("/home/user/my project", "/home/user/my%20project"),
        ("/tmp/a#b?c", "/tmp/a%23b%3Fc"),
        ("/srv/100%", "/srv/100%25"),
        ("/home/user/café", "/home/user/caf%C3%A9"),
    ])
    func percentEncodesThePath(path: String, encoded: String) {
        let url = VSCodeLink.url(host: "arch", path: path)
        #expect(url?.absoluteString == "vscode://vscode-remote/ssh-remote+arch\(encoded)")
    }

    @Test func keepsAUserInTheHost() {
        let url = VSCodeLink.url(host: "me@arch.local", path: "/srv")
        #expect(url?.absoluteString == "vscode://vscode-remote/ssh-remote+me@arch.local/srv")
    }

    @Test(arguments: ["", "relative/dir", "~/project"])
    func refusesAPathThatIsNotAbsolute(path: String) {
        #expect(VSCodeLink.url(host: "arch", path: path) == nil)
    }

    @Test func prefersTheForegroundDirectory() {
        var pane = pane
        pane.cwd = "/home/user"
        pane.foregroundCwd = "/home/user/project-1"
        #expect(
            VSCodeLink.url(host: "arch", pane: pane)?.absoluteString
                == "vscode://vscode-remote/ssh-remote+arch/home/user/project-1")
    }

    @Test func fallsBackToTheShellDirectory() {
        var pane = pane
        pane.cwd = "/home/user"
        pane.foregroundCwd = ""
        #expect(
            VSCodeLink.url(host: "arch", pane: pane)?.absoluteString
                == "vscode://vscode-remote/ssh-remote+arch/home/user")
    }

    @Test func hasNoLinkWhenNeitherDirectoryIsKnown() {
        #expect(VSCodeLink.url(host: "arch", pane: pane) == nil)
    }

    @Test func opensTheSelectedPaneOnTheConfiguredHost() throws {
        let opener = RecordingURLOpener()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FakeTranscripts(), control: FakeControl(),
            opener: opener, host: "devbox")
        store.apply(.herd(try Herd(snapshotReply: Fixture.data(named: "snapshot.synthetic.json"))))
        #expect(!store.isEnabled(.openInVSCode(nil)))
        store.perform(.selectPane(PaneID("w1:pB")!))
        #expect(store.isEnabled(.openInVSCode(nil)))
        store.perform(.openInVSCode(nil))
        store.perform(.openInVSCode(PaneID("w2:p1")!))
        #expect(
            opener.opened.map(\.absoluteString) == [
                "vscode://vscode-remote/ssh-remote+devbox/home/user/project-2",
                "vscode://vscode-remote/ssh-remote+devbox/home/user/scratch",
            ])
    }

    @Test func aPaneWithNoDirectoryOpensNothing() {
        let opener = RecordingURLOpener()
        let store = AppStore(
            herdUpdates: AsyncStream { $0.finish() }, transcripts: FakeTranscripts(), control: FakeControl(),
            opener: opener)
        store.apply(.herd(Herd(panes: [pane])))
        #expect(!store.isEnabled(.openInVSCode(pane.id)))
        store.perform(.openInVSCode(pane.id))
        #expect(opener.opened.isEmpty)
    }
}
