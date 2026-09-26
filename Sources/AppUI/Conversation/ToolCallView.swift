import SwiftUI
import TranscriptKit

/// A one-line tool row that expands to its result.
struct ToolCallView: View {
    let call: ToolCall
    @ViewState private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let result = call.result {
                Text(result.text + (result.truncated ? "\n…" : ""))
                    .scaledFont(.callout, design: .monospaced)
                    .foregroundStyle(result.isError ? .red : .secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quinary, in: .rect(cornerRadius: 6))
            } else {
                Text("No result yet.")
                    .scaledFont(.body)
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: call.result?.isError == true ? "xmark.octagon" : "wrench.and.screwdriver")
                    .foregroundStyle(call.result?.isError == true ? .red : .secondary)
                Text(call.name)
                    .scaledFont(.body)
                    .fontWeight(.medium)
                Text(call.summary)
                    .scaledFont(.callout, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .help(call.summary)
        }
    }
}
