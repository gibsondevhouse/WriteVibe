//
//  ConversationRow.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ConversationRow

struct ConversationRow: View {
    @Environment(AppState.self) private var appState
    let conversation: Conversation
    @State private var isRenaming = false
    @State private var renameText = ""

    private var relativeTimestamp: String {
        let cal = Calendar.current
        if cal.isDateInToday(conversation.updatedAt) {
            return conversation.updatedAt.formatted(.dateTime.hour().minute())
        } else if cal.isDateInYesterday(conversation.updatedAt) {
            return "Yesterday"
        } else {
            return conversation.updatedAt.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    private var inferredModeIcon: (name: String, color: Color)? {
        WritingMode.inferIcon(from: conversation.title)
    }

    private var modelLabel: String {
        switch conversation.model {
        case .ollama:
            let name = conversation.modelIdentifier ?? "Local"
            return name.components(separatedBy: ":").first ?? "Local"
        default:
            return conversation.model.rawValue.components(separatedBy: " ").first ?? conversation.model.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let modeIcon = inferredModeIcon {
                    Image(systemName: modeIcon.name)
                        .font(.caption2)
                        .foregroundStyle(modeIcon.color.opacity(0.7))
                }
                Text(conversation.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(modelLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .fixedSize()
                Text(relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .fixedSize()
            }
            if let last = conversation.messages.last {
                Text(last.content)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("Rename") {
                renameText = conversation.title
                isRenaming = true
            }
            Button("Delete", role: .destructive) {
                appState.deleteConversation(conversation.id)
            }
        }
        .alert("Rename Thread", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                appState.renameConversation(conversation.id, to: renameText)
            }
        } message: {
            Text("Enter a new title for this thread.")
        }
    }
}
