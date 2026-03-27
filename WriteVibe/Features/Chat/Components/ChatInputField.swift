//
//  ChatInputField.swift
//  WriteVibe
//

import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    let canSend: Bool
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        TextField("Describe your idea, draft, or edit…", text: $text, axis: .vertical)
            .lineLimit(3...20)
            .font(.body)
            .lineSpacing(4)
            .tint(.accentColor)
            .focused(focused)
            .textFieldStyle(.plain)
            .onKeyPress(.return) {
                guard canSend else { return .ignored }
                onSend()
                return .handled
            }
    }
}
