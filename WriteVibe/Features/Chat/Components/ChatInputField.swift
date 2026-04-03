//
//  ChatInputField.swift
//  WriteVibe
//

import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> KeyPress.Result
    let onMoveUp: () -> KeyPress.Result
    let onMoveDown: () -> KeyPress.Result
    let onDismissSuggestions: () -> KeyPress.Result

    var body: some View {
        TextField("Describe your idea, draft, or edit…", text: $text, axis: .vertical)
            .lineLimit(3...20)
            .font(.body)
            .lineSpacing(4)
            .tint(.accentColor)
            .focused(focused)
            .textFieldStyle(.plain)
            .onKeyPress(.return) {
                onSubmit()
            }
            .onKeyPress(.upArrow) {
                onMoveUp()
            }
            .onKeyPress(.downArrow) {
                onMoveDown()
            }
            .onKeyPress(.escape) {
                onDismissSuggestions()
            }
    }
}
