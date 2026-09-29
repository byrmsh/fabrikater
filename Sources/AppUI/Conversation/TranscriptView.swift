import AppModel
import SwiftUI
import TranscriptKit

/// The pane's conversation, oldest at the top, scrolled to the latest message.
struct TranscriptView: View {
    let conversation: ConversationStore
    let perform: @MainActor (AppCommand) -> Void

    var body: some View {
        if conversation.transcript.entries.isEmpty {
            if conversation.isLoading {
                ProgressView("Loading conversation…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Conversation",
                    systemImage: "text.bubble",
                    description: Text(conversation.message ?? "This session has no messages yet.")
                )
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if conversation.transcript.isClipped {
                            EarlierMessagesRow(conversation: conversation, perform: perform)
                        }
                        ForEach(conversation.transcript.entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(16)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: conversation.find.currentEntry) { _, current in
                    if let current {
                        withAnimation { proxy.scrollTo(current, anchor: .center) }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let message = conversation.message {
                    StaleBanner(message: message)
                }
            }
            .overlay(alignment: .topTrailing) {
                if conversation.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                }
            }
        }
    }

    private func row(_ entry: TranscriptEntry) -> some View {
        let toggle = conversation.toggle(for: entry)
        return EntryView(
            entry: entry, isCollapsed: conversation.isCollapsed(entry), toggle: toggle, perform: perform
        )
        .equatable()
        .environment(\.findHighlight, conversation.find.highlight(for: entry))
        .overlay {
            // The current match is outlined just outside the entry, so moving between matches never shifts the layout.
            if conversation.find.isCurrent(entry) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.tint, lineWidth: 2)
                    .padding(-6)
            }
        }
        .id(entry.id)
        .contextMenu {
            Button(AppCommand.copyMessage(entry.id).title) { perform(.copyMessage(entry.id)) }
            if let toggle {
                Button(toggle.title) { perform(toggle) }
            }
        }
    }
}

/// Shown over a transcript whose last reload failed.
struct StaleBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
            .padding(8)
    }
}
