import AppModel
import FabrikaterCore
import SwiftUI
import TranscriptKit

/// A window showing one pane's conversation, opened with Open in New Window (docs/design.md, "Pane windows"). It holds
/// its own store, so closing the window frees it, and offers that store to the menu bar while it is in front.
public struct PaneWindowView: View {
    let store: AppStore
    let paneID: PaneID
    @ViewState private var window: PaneWindowStore?

    public init(store: AppStore, paneID: PaneID) {
        self.store = store
        self.paneID = paneID
    }

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
        .environment(\.textScale, store.textScale.factor)
        .frame(minWidth: 420, minHeight: 320)
        .focusedSceneValue(window)
        .onAppear {
            if window == nil {
                window = store.paneWindow(paneID)
            }
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
