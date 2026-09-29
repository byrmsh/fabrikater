import FabrikaterCore
import Foundation
import HerdrKit
import Observation
import TranscriptKit

/// What a past session's window shows: the session's log, and its first prompt as the window title. SwiftUI opens one
/// window per value and restores it with the window, so the value is `Codable`.
public struct SessionWindowID: Hashable, Codable, Sendable {
    public let log: SessionLog
    public let title: String

    public init(log: SessionLog, title: String) {
        self.log = log
        self.title = title
    }
}

/// Lists nothing: the default where no host is behind the app, as in most tests.
public struct NoSessionHistory: SessionHistory {
    public init() {}

    public func pastSessions(besides log: SessionLog) async throws -> [PastSession] { [] }
}

/// One row of the Past Sessions sheet.
public struct PastSessionRow: Identifiable, Hashable, Sendable {
    public let id: SessionID
    public let window: SessionWindowID
    /// The first prompt, or a stand-in for the live session before its first prompt.
    public let title: String
    /// "3h ago".
    public let age: String
    /// "1.2 MB".
    public let size: String
    /// Marks the pane's own, live session.
    public let badge: String?
    /// VoiceOver's reading of the whole row.
    public let spoken: String

    init(_ session: PastSession, now: Date) {
        id = session.id
        title = session.title.isEmpty ? "New session" : session.title
        window = SessionWindowID(log: session.log, title: title)
        let activity = ActivityText(since: session.modified, now: now)
        age = activity.short == "now" ? "Just now" : "\(activity.short) ago"
        size = Self.size(session.bytes)
        badge = session.isCurrent ? "Current" : nil
        spoken = [title, badge, activity.spoken, size].compactMap(\.self).joined(separator: ", ")
    }

    /// A log size in the largest unit that keeps it at or above 1, one decimal below 10: "731 bytes", "48 KB", "1.2 MB".
    static func size(_ bytes: Int) -> String {
        let units = ["KB", "MB", "GB"]
        guard bytes >= 1024 else { return bytes == 1 ? "1 byte" : "\(bytes) bytes" }
        var value = Double(bytes) / 1024
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        let rounded = value < 10 ? (value * 10).rounded() / 10 : value.rounded()
        let number = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return "\(number) \(units[unit])"
    }
}

/// The Past Sessions sheet's contents while it is open.
public struct PastSessionsSheet: Equatable, Sendable {
    /// "Sessions in project-1": the folder the pane's agent runs in.
    public var title: String
    public var rows: [PastSessionRow] = []
    public var isLoading = true
    /// Why no row but the live one shows: still loading, the listing failed, or there is nothing else.
    public var emptyMessage: String?
}

/// The conversations the selected pane's agent kept for its working directory, listed in a sheet; choosing one opens it
/// read-only in a window of its own (M8, docs/design.md "Past sessions").
@MainActor
@Observable
public final class PastSessionsStore {
    /// The sheet while it is open.
    public private(set) var sheet: PastSessionsSheet?
    /// The sheet's default button, which opens the highlighted session.
    nonisolated public static let openTitle = "Open"

    private let history: any SessionHistory
    private let now: @Sendable () -> Date
    private let log = Log(category: "AppModel")
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?

    init(history: any SessionHistory, now: @escaping @Sendable () -> Date) {
        self.history = history
        self.now = now
    }

    /// Whether `pane` runs an agent whose sessions can be listed: one whose log the app reads.
    static func canList(_ pane: Herd.Pane?) -> Bool {
        pane?.sessionLog != nil
    }

    /// Opens the sheet for `pane` and lists its sessions.
    func open(_ pane: Herd.Pane) {
        guard let sessionLog = pane.sessionLog else { return }
        loadTask?.cancel()
        let folder = [pane.foregroundCwd, pane.cwd].compactMap(\.self).first { !$0.isEmpty }
            .map { $0.split(separator: "/").last.map(String.init) ?? $0 }
        sheet = PastSessionsSheet(
            title: folder.map { "Sessions in \($0)" } ?? "Past Sessions", emptyMessage: "Loading sessions…")
        loadTask = Task {
            let result: Result<[PastSession], any Error>
            do {
                result = .success(try await history.pastSessions(besides: sessionLog))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, sheet != nil else { return }
            show(result)
        }
    }

    func close() {
        loadTask?.cancel()
        sheet = nil
    }

    private func show(_ result: Result<[PastSession], any Error>) {
        sheet?.isLoading = false
        switch result {
        case .success(let sessions):
            let now = now()
            sheet?.rows = sessions.map { PastSessionRow($0, now: now) }
            sheet?.emptyMessage = sessions.contains { !$0.isCurrent } ? nil : "No other sessions in this folder."
        case .failure(let error):
            log.error("listing past sessions failed")
            sheet?.emptyMessage = "Could not list sessions: \(error)"
        }
    }
}

/// A past session's window: its conversation, read-only, with the commands that act on a conversation alone.
@MainActor
@Observable
public final class SessionWindowStore {
    public let id: SessionWindowID
    public let conversation: ConversationStore
    /// Set once the host the session was read from is let go of; the window closes.
    public private(set) var isClosed = false
    private let clipboard: any Clipboard

    init(_ id: SessionWindowID, transcripts: any TranscriptService, clipboard: any Clipboard) {
        self.id = id
        self.clipboard = clipboard
        conversation = ConversationStore(transcripts: transcripts)
        conversation.show(id.log)
    }

    public var title: String { id.title }
    /// Says the conversation is read here, not answered.
    public var subtitle: String { "Past Session" }

    func close() {
        conversation.close()
        isClosed = true
    }

    /// Whether `command` acts on the conversation, the only thing this window has.
    func handles(_ command: AppCommand) -> Bool {
        conversation.isEnabled(command) != nil
    }

    public func perform(_ command: AppCommand) {
        conversation.perform(command, clipboard: clipboard)
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        conversation.isEnabled(command) ?? false
    }
}
