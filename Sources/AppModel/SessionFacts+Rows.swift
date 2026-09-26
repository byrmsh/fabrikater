// B11: the session facts popover's rows, from the facts TranscriptKit reads out of the log.

import Foundation
import TranscriptKit

/// One line of the session facts popover: "Branch" and "main".
public struct FactRow: Equatable, Sendable, Identifiable {
    public var label: String
    public var value: String

    public var id: String { label }

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

extension SessionFacts {
    /// Shown in place of the rows when the log carries none of the facts.
    public static let emptyMessage = "The session's log has no details yet."

    /// The facts the log carries, in a fixed order; a fact the log lacks has no row.
    /// - Parameter isClipped: the log was read from partway through, so its first timestamp is not the session's start.
    public func rows(isClipped: Bool, dateStyle: Date.FormatStyle = .dateTime) -> [FactRow] {
        [
            model.map { FactRow("Model", $0) },
            workingDirectory.map { FactRow("Folder", $0) },
            gitBranch.map { FactRow("Branch", $0) },
            firstSeen.map { FactRow(isClipped ? "Earliest read" : "Started", $0.formatted(dateStyle)) },
            contextTokens.map { FactRow("Context", Self.formatTokens($0)) },
        ].compactMap(\.self)
    }
}
