//
//  SubtitleField.swift
//  WriteVibe
//

import SwiftUI

struct SubtitleField: View {
    @Binding var text: String

    var body: some View {
        TextField("Add a subtitle…", text: $text, axis: .vertical)
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(.secondary)
            .textFieldStyle(.plain)
            .lineLimit(1...2)
    }
}
