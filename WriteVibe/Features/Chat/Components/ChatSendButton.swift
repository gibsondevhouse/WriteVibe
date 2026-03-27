//
//  ChatSendButton.swift
//  WriteVibe
//

import SwiftUI

struct ChatSendButton: View {
    let isThinking: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        Button(action: isThinking ? onStop : onSend) {
            Group {
                if isThinking {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(
                        canSend || isThinking
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(Color.secondary.opacity(0.2))
                    )
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canSend && !isThinking)
        .animation(.easeInOut(duration: 0.18), value: canSend)
    }
}
