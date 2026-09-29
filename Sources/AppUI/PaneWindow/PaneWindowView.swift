import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// A window showing one pane's conversation, opened with Open in New Window (docs/design.md, "Pane windows"). It holds
/// its own store, so closing the window frees it, and offers that store to the menu bar while it is in front. Connecting
/// to another host closes it.
public struct PaneWindowView: View {
    let session: HostSession
    let paneID: PaneID
    @ViewState private var window: PaneWindowStore?
    @Environment(\.dismiss) private var dismiss

    public init(session: HostSession, paneID: PaneID) {
        self.session = session
        self.paneID = paneID
    }

    private var store: AppStore { session.store }

    public var body: some View {
        Group {
            if let window {
                // A navigation container gives the window the same title bar and toolbar as the main window's detail.
                NavigationStack {
                    PaneWindowContent(window: window)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferred(store.preferences.preferences, scale: store.textScale)
        .frame(minWidth: 420, minHeight: 320)
        .focusedSceneValue(window)
        .onAppear {
            if window == nil {
                window = store.paneWindow(paneID)
            }
        }
        .onChange(of: window?.isClosed == true) { _, closed in
            if closed { dismiss() }
        }
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
