//
//  CopilotPanel.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - CopilotPanel

struct CopilotPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private var conversation: Conversation? { appState.copilotConversation }
    private var messages: [Message] {
        (conversation?.messages ?? []).sorted { $0.timestamp < $1.timestamp }
    }
    private var tokenUsage: Double {
        appState.copilotConversationId
            .map { appState.estimatedTokenUsage(for: $0) / 4096.0 } ?? 0.0
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()

            if messages.isEmpty {
                copilotEmptyState
            } else {
                messageList
            }

            Divider()
            ChatInputBar(
                text: $inputText,
                isThinking: appState.isThinkingInCopilot,
                tokenUsage: tokenUsage,
                focused: $inputFocused,
                onSend: sendMessage,
                onStop: stopGeneration
            )
            .padding(.bottom, 8)
        }
        .frame(width: 340)
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
            inputFocused = true
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("AI Copilot")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            // Model indicator
            if let conv = conversation {
                Text(conv.model.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // New chat
            Button {
                inputText = ""
                appState.newCopilotConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("New copilot chat")

            // Close
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    appState.isCopilotOpen = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Close copilot panel")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Message list

    private var messageList: some View {
        ChatScrollContainer(
            messages: messages,
            isThinking: appState.isThinkingInCopilot,
            tailID: "copilot-tail",
            tailHeight: 12,
            horizontalPadding: 12,
            verticalPadding: 12
        ) { i, msg in
            CopilotMessageRow(
                message: msg,
                isStreaming: appState.isThinkingInCopilot && i == messages.count - 1
            )
        }
    }

    // MARK: - Empty state

    private var copilotEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor.opacity(0.6))
            Text("AI Copilot")
                .font(.system(size: 15, weight: .semibold))
            Text("Ask anything about your writing,\nget ideas, or brainstorm with AI.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func sendMessage() {
        appState.bindModelContextIfNeeded(modelContext)
        let trimmed = inputText.trimmed
        guard !trimmed.isEmpty else { return }
        let id: UUID?
        if let existingId = appState.copilotConversationId,
           appState.fetchConversation(existingId) != nil {
            id = existingId
        } else {
            id = appState.newCopilotConversation()
        }
        guard let id else { return }
        if appState.send(trimmed, in: id) {
            inputText = ""
        }
    }

    private func stopGeneration() {
        guard let id = appState.copilotConversationId else { return }
        appState.stopGeneration(for: id)
    }
}

// MARK: - CopilotMessageRow

private struct CopilotMessageRow: View {
    let message: Message
    let isStreaming: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            userRow
        } else {
            assistantRow
        }
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.content)
                .font(.callout)
                .lineSpacing(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor)
                )
        }
        .padding(.vertical, 4)
    }

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
                .padding(.top, 2)

            MarkdownMessageText(content: message.content, isStreaming: isStreaming)
                .font(.callout)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
