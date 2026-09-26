import AppModel
import SwiftUI
import TranscriptKit

/// The pane's conversation, oldest at the top, scrolled to the latest message.
struct TranscriptView: View {
    let conversation: ConversationStore

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if conversation.transcript.isClipped {
                        Text("Older messages are not loaded.")
                            .scaledFont(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(conversation.transcript.entries) { entry in
                        EntryView(entry: entry)
                    }
                }
                .padding(16)
            }
            .defaultScrollAnchor(.bottom)
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
