import AppModel
import SwiftUI
import TranscriptKit

/// The inspector listing the files the selected pane's session changed, each expanding to its edits as a diff.
struct ChangesView: View {
    let panel: ChangesPanel
    let perform: (AppCommand) -> Void
    @ViewState private var expanded: Set<String> = []

    var body: some View {
        if panel.files.isEmpty {
            ContentUnavailableView(
                panel.emptyTitle, systemImage: "doc.text.magnifyingglass", description: Text(panel.emptyDetail))
        } else {
            // A scroll view rather than a sidebar-style List: the List's outline rows hide their text from
            // accessibility, as the herd sidebar's tab rows do.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    Text(panel.summary)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    ForEach(panel.files) { file in
                        DisclosureGroup(isExpanded: isExpanded(file.id)) {
                            ForEach(file.edits) { edit in
                                DiffView(edit: edit)
                            }
                        } label: {
                            FileChangeRow(file: file)
                        }
                        .contextMenu {
                            Button(AppCommand.copyPath(file.path).title) { perform(.copyPath(file.path)) }
                        }
                    }
                    if let footnote = panel.footnote {
                        Text(footnote)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        }
    }

    private func isExpanded(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isOn in
                if isOn { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }
}

private struct FileChangeRow: View {
    let file: FileChange

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.folder)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text(file.lineCounts)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(file.spokenLineCounts)
        }
        .help(file.path)
    }
}
