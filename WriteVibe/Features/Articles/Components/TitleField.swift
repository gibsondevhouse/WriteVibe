//
//  TitleField.swift
//  WriteVibe
//

import SwiftUI

struct TitleField: View {
    @Binding var text: String

    var body: some View {
        TextField("Title", text: $text, axis: .vertical)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.primary)
            .textFieldStyle(.plain)
            .lineLimit(1...3)
    }
}
