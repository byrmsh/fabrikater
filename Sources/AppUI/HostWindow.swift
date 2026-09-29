import AppModel
import SwiftUI

/// A window of its own over one store that the connected host's `AppStore` makes: a pane window or a past session's
/// window. The window holds the store, so closing the window frees it, and offers it to the menu bar while it is in
/// front. Connecting to another host closes the store, and with it the window.
struct HostWindow<Store: AnyObject & Observable, Content: View>: View {
    let session: HostSession
    /// Makes the window's store from the connected host's store, once.
    let make: @MainActor (AppStore) -> Store
    let isClosed: @MainActor (Store) -> Bool
    @ViewBuilder let content: @MainActor (Store) -> Content
    @ViewState private var window: Store?
    @Environment(\.dismiss) private var dismiss

    private var store: AppStore { session.store }

    var body: some View {
        Group {
            if let window {
                // A navigation container gives the window the same title bar and toolbar as the main window's detail.
                NavigationStack {
                    content(window)
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
                window = make(store)
            }
        }
        .onChange(of: isWindowClosed) { _, closed in
            if closed { dismiss() }
        }
    }

    private var isWindowClosed: Bool {
        guard let window else { return false }
        return isClosed(window)
    }
}
