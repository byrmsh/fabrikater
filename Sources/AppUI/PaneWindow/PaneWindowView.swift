import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// A window showing one pane's conversation, opened with Open in New Window (docs/design.md, "Pane windows").
public struct PaneWindowView: View {
    let session: HostSession
    let paneID: PaneID

    public init(session: HostSession, paneID: PaneID) {
        self.session = session
        self.paneID = paneID
    }

    public var body: some View {
        HostWindow(
            session: session, make: { [paneID] in $0.paneWindow(paneID) }, isClosed: { $0.isClosed },
            content: { PaneWindowContent(window: $0) })
    }
}

/// The pane as the main window shows it, once the first herd has named it.
struct PaneWindowContent: View {
    let window: PaneWindowStore

    var body: some View {
        if let header = window.header {
            PaneDetail(model: window, header: header, notice: window.notice)
        } else if let notice = window.notice {
            ContentUnavailableView(notice, systemImage: "rectangle.slash")
                .navigationTitle(window.paneID.rawValue)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(window.paneID.rawValue)
        }
    }
}
