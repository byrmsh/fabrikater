import TranscriptKit

/// What the changes inspector shows for the selected pane (B12): the files its session changed, or why there are none.
public struct ChangesPanel: Equatable, Sendable {
    public var files: [FileChange]
    /// The empty state's title and sentence, when there are no files.
    public var emptyTitle: String
    public var emptyDetail: String
    /// Said under the list when the log was read only in part, so older changes may be missing.
    public var footnote: String?

    public init(transcript: Transcript, isLoading: Bool = false) {
        files = transcript.changes
        emptyTitle = isLoading ? "Loading Changes" : "No Changes"
        emptyDetail = isLoading ? "Reading the session log." : "This session has not changed any files."
        footnote = transcript.isClipped ? "Changes from earlier in the session may be missing." : nil
    }

    /// "3 files", the inspector's subtitle.
    public var summary: String {
        files.count == 1 ? "1 file" : "\(files.count) files"
    }
}

extension ConversationStore {
    public var changesPanel: ChangesPanel {
        ChangesPanel(transcript: transcript, isLoading: isLoading && transcript.entries.isEmpty)
    }
}
