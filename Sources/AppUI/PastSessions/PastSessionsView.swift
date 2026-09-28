import AppModel
import FabrikaterCore
import SwiftUI

/// The Past Sessions sheet (⌘Y): the sessions kept beside the selected pane's live log, newest first, like Safari's
/// History. Return or a double-click opens the highlighted session in its own window; Esc closes.
struct PastSessionsView: View {
    let store: AppStore
    @Environment(\.openWindow) private var openWindow
    @ViewState private var selection: SessionID?

    var body: some View {
        VStack(spacing: 0) {
            if let sheet = store.pastSessions.sheet {
                Text(sheet.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                Divider()
                content(sheet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { store.perform(.closePastSessions) }
                    .keyboardShortcut(.cancelAction)
                Button(PastSessionsStore.openTitle) { open(chosen) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen.map { !store.isEnabled(.openPastSession($0.window)) } ?? true)
            }
            .padding(12)
        }
        .frame(width: 560, height: 400)
        .onChange(of: store.pastSessions.sheet?.rows, initial: true) { _, rows in
            // Highlight the newest session other than the live one, which the main window already shows.
            if selection == nil || rows?.contains(where: { $0.id == selection }) != true {
                selection = (rows?.first { $0.badge == nil } ?? rows?.first)?.id
            }
        }
    }

    @ViewBuilder
    private func content(_ sheet: PastSessionsSheet) -> some View {
        if sheet.rows.isEmpty {
            if sheet.isLoading {
                ProgressView(sheet.emptyMessage ?? "")
            } else {
                ContentUnavailableView(sheet.emptyMessage ?? "", systemImage: "clock.arrow.circlepath")
            }
        } else {
            List(sheet.rows, selection: $selection) { row in
                PastSessionRowView(row: row)
            }
            .contextMenu(forSelectionType: SessionID.self) { ids in
                Button(AppCommand.openInNewWindow(nil).title) { open(row(ids.first)) }
            } primaryAction: { ids in
                open(row(ids.first))
            }
            .overlay(alignment: .bottom) {
                if let message = sheet.emptyMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
    }

    private var chosen: PastSessionRow? { row(selection) }

    private func row(_ id: SessionID?) -> PastSessionRow? {
        store.pastSessions.sheet?.rows.first { $0.id == id }
    }

    private func open(_ row: PastSessionRow?) {
        guard let row else { return }
        openWindow(value: row.window)
        store.perform(.openPastSession(row.window))
    }
}

/// One session: its first prompt, then how long ago it was written and how large its log is.
private struct PastSessionRowView: View {
    let row: PastSessionRow

    var body: some View {
        HStack(spacing: 8) {
            Text(row.title)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if let badge = row.badge {
                Text(badge)
                    .foregroundStyle(.tint)
            }
            Text(row.age)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(row.size)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .help(row.title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spoken)
    }
}
