import SwiftUI

/// The inline name field that replaces a row's label while renaming, like renaming in Finder's sidebar.
/// Return or clicking away commits, Esc cancels.
struct RenameField: View {
    let label: String
    let commit: (String) -> Void
    let cancel: () -> Void
    @ViewState private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Name", text: $text, prompt: Text(label))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { commit(text) }
            .onExitCommand(perform: cancel)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit(text) }
            }
            .onAppear { text = label }
            // Focusing in onAppear races the list re-rendering the row and leaves the field unfocused; focus it once
            // the row has settled.
            .task {
                try? await Task.sleep(for: .milliseconds(100))
                isFocused = true
            }
    }
}
