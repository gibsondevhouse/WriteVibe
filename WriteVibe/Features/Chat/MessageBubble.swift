//
//  MessageBubble.swift
//  WriteVibe
//

import SwiftUI

// MARK: - MessageBubble

struct MessageBubble: View {
    let message:    Message
    let isLast:     Bool
    let isStreaming: Bool
    let showAvatar: Bool
    let topPad:     CGFloat

    @State private var isHovered = false
    @State private var copied    = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser { userTurn } else { assistantTurn }
        }
        .padding(.top, topPad)
        .onHover { isHovered = $0 }
    }

    // MARK: - User Turn

    private var userTurn: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(message.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor)
                }
                .frame(maxWidth: 480, alignment: .trailing)

            if isHovered {
                timestamp
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Assistant Turn

    private var assistantTurn: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownMessageText(content: message.content, isStreaming: isStreaming)
                .textSelection(.enabled)

            if isHovered || isLast {
                messageActions
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isLast)
    }

    // MARK: - Message Actions

    private var messageActions: some View {
        HStack(spacing: 2) {
            MessageActionButton(
                symbol: copied ? "checkmark" : "doc.on.doc",
                label:  copied ? "Copied!" : "Copy"
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }

            MessageActionButton(symbol: "hand.thumbsup",   label: "Good response") { }
            MessageActionButton(symbol: "hand.thumbsdown", label: "Bad response")  { }

            if isLast {
                MessageActionButton(symbol: "arrow.counterclockwise", label: "Regenerate") { }
            }

            Spacer()
        }
    }

    private var timestamp: some View {
        Text(message.timestamp, style: .time)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - MessageActionButton

struct MessageActionButton: View {
    let symbol: String
    let label:  String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .frame(width: 28, height: 28)
                .background {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
