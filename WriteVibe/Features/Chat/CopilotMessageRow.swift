//
//  CopilotMessageRow.swift
//  WriteVibe
//

import SwiftUI

struct CopilotMessageRow: View {
    let message: Message
    let previousMessage: Message?
    let isStreaming: Bool

    private var isUser: Bool { message.role == .user }

    private var rewritePreview: ChatRewritePreview? {
        guard !isUser,
              !isStreaming,
              let previousMessage,
              previousMessage.role == .user else {
            return nil
        }

        return ChatRewriteDiffSupport.preview(
            userPrompt: previousMessage.content,
            assistantResponse: message.content
        )
    }

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

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                if let rewritePreview {
                    ChatRewriteDiffCard(preview: rewritePreview)
                }

                MarkdownMessageText(content: message.content, isStreaming: isStreaming)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}