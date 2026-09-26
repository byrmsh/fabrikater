import AppModel
import FabrikaterCore
import SwiftUI

/// The ⌘K sheet: a search field over every pane, like Xcode's Open Quickly.
/// Typing filters, ↑ and ↓ move the highlight, Return or a click opens the pane, Esc closes.
struct QuickSwitcherView: View {
    let store: AppStore
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if let switcher = store.switcher {
                results(switcher)
            }
        }
        .frame(width: 520, height: 340)
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Open Quickly", text: query, prompt: Text("Jump to a pane"))
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onSubmit { store.perform(.chooseQuickSwitcherResult(nil)) }
                .onExitCommand { store.perform(.closeQuickSwitcher) }
                .onKeyPress(.downArrow) {
                    store.perform(.moveQuickSwitcherHighlight(1))
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    store.perform(.moveQuickSwitcherHighlight(-1))
                    return .handled
                }
        }
        .padding(12)
    }

    @ViewBuilder
    private func results(_ switcher: QuickSwitcher) -> some View {
        if let message = switcher.emptyMessage {
            ContentUnavailableView(message, systemImage: "magnifyingglass")
                .frame(maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                List(switcher.results, selection: choice(highlighted: switcher.highlighted)) { item in
                    QuickSwitcherRow(item: item)
                        .tag(item.id)
                }
                .onChange(of: switcher.highlighted) { _, highlighted in
                    if let highlighted { proxy.scrollTo(highlighted) }
                }
            }
        }
    }

    private var query: Binding<String> {
        Binding(get: { store.switcher?.query ?? "" }, set: { store.perform(.searchQuickSwitcher($0)) })
    }

    /// The highlight shows as the list's selection; clicking a row opens it.
    private func choice(highlighted: PaneID?) -> Binding<PaneID?> {
        Binding(
            get: { highlighted },
            set: { id in
                if let id { store.perform(.chooseQuickSwitcherResult(id)) }
            }
        )
    }
}

private struct QuickSwitcherRow: View {
    let item: SwitcherItem

    var body: some View {
        HStack(spacing: 8) {
            PaneRowView(pane: item.row)
            Spacer(minLength: 8)
            Text(item.location)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
